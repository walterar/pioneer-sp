-- Scout.lua for Pioneer Scout+ (c)2012-2015 by walterar <walterar2@gmail.com>
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt
-- Work in progress.

local Lang       = import("Lang")
local Engine     = import("Engine")
local Game       = import("Game")
local StarSystem = import("StarSystem")
local Space      = import("Space")
local Comms      = import("Comms")
local Event      = import("Event")
local Mission    = import("Mission")
local Music      = import("Music")
local NameGen    = import("NameGen")
local Format     = import("Format")
local Serializer = import("Serializer")
local Character  = import("Character")
local InfoFace   = import("ui/InfoFace")
local Timer      = import("Timer")
local Eq         = import("Equipment")

local MsgBox   = import("ui/MessageBox")
local InfoFace = import("ui/InfoFace")
local SLButton = import("ui/SmallLabeledButton")

local l  = Lang.GetResource("module-scout") or Lang.GetResource("module-scout","en")
local lm = Lang.GetResource("miscellaneous") or Lang.GetResource("miscellaneous","en")

 -- don't produce missions for further than this many light years away
local max_dist = 30

local scan_time = 600-- 10 minutes

-- CallEvery(xTimeUp,....
local xTimeUp = 10
local radius_min = 1.5
local radius_max = 1.6

local ui = Engine.ui

local flavours = {
	{
		localscout = false,-- 1
		urgency    = false,
		risk       = false
	}, {
		localscout = false,-- 2
		urgency    = false,
		risk       = false
	}, {
		localscout = false,-- 3
		urgency    = false,
		risk       = true
	}, {
		localscout = false,-- 4
		urgency    = true,
		risk       = true
	}, {
		localscout = false,-- 5
		urgency    = false,
		risk       = true
	}, {
		localscout = true,-- 6
		urgency    = false,
		risk       = false
	}, {
		localscout = true,-- 7
		urgency    = true,
		risk       = true
	}
}

-- add strings to flavours
for i = 1,#flavours do
	local f = flavours[i]
	f.adtext        = l["ADTEXT_"..i]
	f.introtext1    = l["INTROTEXT1_"..i].."\n*\n*"
	f.introtext2    = l["INTROTEXT2_"..i].."\n*\n*"
	f.whysomuchtext = l["WHYSOMUCHTEXT_"..i].."\n*\n*"
	f.successmsg    = l["SUCCESSMSG_"..i]
end

local hm = 4-- hostile message count

local ads      = {}
local missions = {}

local onChat = function (form, ref, option)
	local ad          = ads[ref]
	local backstation = Game.player:GetDockedWith().path
	local faction     = Game.system.faction
	form:Clear()
	if option == -1 then
		form:Close()
		return
	end

	if option == 0 then
		form:SetFace(ad.client)

		local sys   = ad.location:GetStarSystem()
		local sbody = ad.location:GetSystemBody()

		local introtext1 = string.interp(flavours[ad.flavour].introtext1, {
			name       = ad.client.name,
			faction    = faction.name,
			police     = faction.policeName,
			military   = faction.militaryName,
			cash       = showCurrency(ad.reward),
			systembody = sbody.name,
			system     = sys.name,
			sectorx    = ad.location.sectorX,
			sectory    = ad.location.sectorY,
			sectorz    = ad.location.sectorZ,
			dist       = ad.dist
		})
		form:SetMessage(introtext1)

		local introtext2 = string.interp(flavours[ad.flavour].introtext2, {
			name       = ad.client.name,
			faction    = faction.name,
			police     = faction.policeName,
			military   = faction.militaryName,
			cash       = showCurrency(ad.reward),
			systembody = sbody.name,
			system     = sys.name,
			sectorx    = ad.location.sectorX,
			sectory    = ad.location.sectorY,
			sectorz    = ad.location.sectorZ
		})

	elseif option == 1 then
		form:SetMessage(flavours[ad.flavour].whysomuchtext)

	elseif option == 2 then
		form:SetMessage(l.I_need_the_information_by .. Format.Date(ad.due).."\n*\n*")

	elseif option == 4 then
		if ad.risk == 0 then
			form:SetMessage(l["MessageRisk0_" .. Engine.rand:Integer(1,2)].."\n*\n*")
		elseif ad.risk == 1 then
			form:SetMessage(l.MessageRisk1.."\n*\n*")--" .. Engine.rand:Integer(1,x)))
		elseif ad.risk == 2 then
			form:SetMessage(l.MessageRisk2.."\n*\n*")--" .. Engine.rand:Integer(1,x)))
		elseif ad.risk == 3 then
			form:SetMessage(l["MessageRisk3_" .. Engine.rand:Integer(1,2)].."\n*\n*")
		end
	elseif option == 5 then
			form:SetMessage(l.additional_information.."\n*\n*")

	elseif option == 3 then
		if (MissionsSuccesses - MissionsFailures) < 5 and ad.risk > 0 then
			form:SetMessage(l.You_do_not_have_enough_experience_for_this_mission.."\n*\n*")
			return
		end

		if Game.player:CountEquip(Eq.misc.radar_mapper) == 0
			and Game.player:CountEquip(Eq.misc.advanced_radar_mapper) == 0 then
			form:SetMessage(l.You_have_not_installed_RADAR_MAPPER.."\n*\n*")
			return
		end
		form:RemoveAdvertOnClose()
		ads[ref] = nil
		local mission = {
			type        = "Scout",
			faction     = faction.name,
			police      = faction.policeName,
			military    = faction.militaryName,
			backstation = backstation,
			client      = ad.client,
			location    = ad.location,
			risk        = ad.risk,
			reward      = ad.reward,
			date        = ad.date,
			due         = ad.due,
			flavour     = ad.flavour,
			status      = 'ACTIVE'
		}

		table.insert(missions,Mission.New(mission))

		if NavAssist then
			if Game.system.path ~= mission.location:GetStarSystem().path then
				Game.player:SetHyperspaceTarget(mission.location:GetStarSystem().path)
			else
				Game.player:SetNavTarget(Space.GetBody(mission.location.bodyIndex))
			end
		end

		form:SetMessage(l.Excellent_I_await_your_report)
		switchEvents()
		return
	end

	form:AddOption(l.Why_so_much_money, 1)
	form:AddOption(l.When_do_you_need_the_data, 2)
	form:AddOption(l.What_is_the_risk, 4)
	form:AddOption(l.Have_additional_information, 5)
	form:AddOption(l.Repeat_the_original_request, 0)
	form:AddOption(l.Ok, 3)
end

local onDelete = function (ref)
	ads[ref] = nil
end

local makeAdvert = function (station)
	local reward, due, location, remotesystem
	local client = Character.New()
--	local flavour = Engine.rand:Integer(6,7)
	local flavour = Engine.rand:Integer(1,#flavours)
	local urgency = flavours[flavour].urgency and Engine.rand:Number(0.2,1) or 0
	local risk = flavours[flavour].risk and Engine.rand:Integer(1,3) or 0
	local	faction = Game.system.faction
	local currentBody

-- local system
	if flavours[flavour].localscout then

		local localbodies = _localPlanetsWithoutStations
		if #localbodies == 0 then return end
		location = localbodies[Engine.rand:Integer(1,#localbodies)]
		currentBody = location:GetSystemBody()
		if not currentBody or currentBody.superType ~= "ROCKY_PLANET" then return end

		local AU = 149597870700
		local dist = station:DistanceTo(Space.GetBody(location.bodyIndex))/AU
		due =_local_due(station,location,urgency,true)

--		due    = Game.time + (((dist/3)*24*60*60)+(4*(1.9-urgency)*24*60*60))
		local reward_base = 250
		reward = reward_base*math.sqrt(dist)*(1+urgency)*(1+Game.system.lawlessness)

	else

-- remote system
		local remotesystems = Game.system:GetNearbySystems(max_dist,
			function (s) return #s:GetBodyPaths() > 0 and s.population == 0 end)
		if #remotesystems == 0 then return end
		remotesystem = remotesystems[Engine.rand:Integer(1,#remotesystems)]
		local dist = Game.system:DistanceTo(remotesystem)
		local remotebodies = remotesystem:GetBodyPaths()
		local checkedBodies = 0
		while checkedBodies <= #remotebodies do
			location = remotebodies[Engine.rand:Integer(1,#remotebodies)]
			currentBody = location:GetSystemBody()
			if currentBody.superType == "ROCKY_PLANET"
				and currentBody.type ~= "PLANET_ASTEROID"
			then break end
			checkedBodies = checkedBodies + 1
			location = nil
			currentBody = nil
		end
		if not location then return end
		local multiplier = Engine.rand:Number(1.5,1.6)
		if Game.system.faction ~= location:GetStarSystem().faction then
			multiplier = multiplier * Engine.rand:Number(1.3,1.5)
		end
		local reward_base = 450
		reward = reward_base+(tariff(dist,risk,urgency,location)*2*multiplier)
		due    = _remote_due(dist,urgency,true)
	end

	if not location then return end

	local dist_txt = _distTxt(location)

	local ad = {
		station  = station,
		flavour  = flavour,
		client   = client,
		location = location,
		dist     = dist_txt,
		date     = Game.time,
		due      = due,
		risk     = risk,
		urgency  = urgency,
		reward   = reward,
		isfemale = isfemale,
		faceseed = Engine.rand:Integer()
	}

	ad.desc = string.interp(flavours[flavour].adtext, {
		faction    = faction.name,
		police     = faction.policeName,
		military   = faction.militaryName,
		system     = ad.location:GetStarSystem().name,
		cash       = showCurrency(ad.reward),
		dist       = ad.dist,
		systembody = ad.location:GetSystemBody().name
	})

	local ref = station:AddAdvert({
		description = ad.desc,
		icon        = ad.risk and "scout_danger" or "scout",
		onChat      = onChat,
		onDelete    = onDelete})

	ads[ref] = ad
end

local onCreateBB = function (station)
	for i = 1,Engine.rand:Integer(Engine.rand:Integer(0,_maxAdv),_maxAdv) do
		makeAdvert(station)
	end
end

local onUpdateBB = function (station)
	local num = 0
	local timeout = 24*60*60 -- default 1 day timeout for inter-system
	for ref,ad in pairs(ads) do
		if ad.station == station then
			if flavours[ad.flavour].localscout then timeout = 60*60 end -- 1 hour timeout for locals
			if (Game.time - ad.date > timeout) then
				station:RemoveAdvert(ref)
				num = num + 1--Engine.rand:Integer(1)-- 50% of the time, give away 1
			end
		end
	end
	if num > 0 then
		for i = 1,num do
			makeAdvert(station)
		end
	end
end


	local outhostiles = false
local start_mapping = function(mission)
	local suspended = 0
	local CurBody = Game.player.frameBody
	if not CurBody then return end
	local faction = Game.system.faction
	local PhysBody = CurBody.path:GetSystemBody()
	local TimeUp = 0
	if DangerLevel == 2 then
		radius_min = 1.3
		radius_max = 1.4
	else
		radius_min = 1.5
		radius_max = 1.6
	end
	local count = Engine.rand:Integer(15,40)
	Timer:CallEvery(xTimeUp, function ()
		if mission.status == "TRIP_BACK" then return true end
		local Dist = CurBody:DistanceTo(Game.player)
		if Dist < PhysBody.radius * radius_min
			and (mission.status == 'ACTIVE'
				or mission.status == 'SUSPENDED') then
			local lapse = scan_time / 60
			Comms.ImportantMessage(l.Distance_reached .. lapse .. l.minutes, l.computer)
			Music.Play("music/core/fx/mapping-on"..Engine.rand:Integer(1,3))
			mission.status = "MAPPING"
		elseif Dist > PhysBody.radius * radius_max and mission.status == "MAPPING" then
			Music.Play("music/core/fx/mapping-off",false)
			Comms.ImportantMessage(l.MAPPING_interrupted, l.computer)
			mission.status = "SUSPENDED"
			TimeUp = 0
			return false
		end
		if mission.status == "MAPPING" then
			TimeUp = TimeUp + xTimeUp
			if count == 55 and mission.risk > 0 and not outhostiles then
				count = 0
				local ship = ship_hostil(mission.risk)
				if ship then
					outhostiles = true
					Comms.ImportantMessage(l["hostilemessage"..Engine.rand:Integer(1,hm)], ship.label)
				end
			end
			if outhostiles == false then count = count + 1 end
			if TimeUp >= scan_time then
				mission.status = "TRIP_BACK"
				Music.Play("music/core/fx/mapping-off",false)
				Comms.ImportantMessage(l.COMPLETE_MAPPING, l.computer)

-- decide destino de entrega estaciones remotas - no locales

				if mission.localscout == false
					and (((mission.faction == faction.name) and Engine.rand:Integer(2) > 1)
					or Engine.rand:Integer(2) > 1)
				then
					local remotestations =
						StarSystem:GetNearbyStationPaths(Engine.rand:Integer(10,20), nil,function (s)
						return (s.type ~= 'STARPORT_SURFACE') or (s.parent.type ~= 'PLANET_ASTEROID')
					end)
					if remotestations and #remotestations > 0 then
						mission.backstation = remotestations[Engine.rand:Integer(1,#remotestations)]
						Comms.ImportantMessage(l.CHANGE_LOCATION, mission.client.name)
					end
				end
				mission.location = mission.backstation
				if NavAssist and Game.system.path ~= mission.location:GetStarSystem().path then
					Game.player:SetHyperspaceTarget(mission.location:GetStarSystem().path)
				end
				return true
			end
		end

		if mission.status == "SUSPENDED" then
			suspended = suspended + 1
			if suspended > 60 then
				suspended = 0
				return true
			end
		end

	end)
end

local onFrameChanged = function (body)
--print("Scout onFrameChanged body="..body.label)
	if not body:isa("Ship") or not body:IsPlayer() then return end
	if body.frameBody == nil then return end
	if body.frameBody ~= Game.player:GetNavTarget()
		and Game.player:FindNearestTo("SPACESTATION") ~= Game.player:GetNavTarget()
	then return end
	for ref,mission in pairs(missions) do
		if Game.time < mission.due
			and (mission.status == "ACTIVE" or mission.status == "SUSPENDED")
			and mission.location == Game.player:GetNavTarget().path then
			start_mapping(mission)
		elseif Game.time > mission.due then mission.status = "FAILED"
		end
	end
end

local onShipDocked = function (player, station)
	if not player:IsPlayer() then return end
	outhostiles = false
	local faction = Game.system.faction
	for ref, mission in pairs(missions) do
		if Game.time > mission.due then
			_G.MissionsFailures = MissionsFailures + 1
				mission:Remove()
				missions[ref] = nil
		end
		if mission.status == "TRIP_BACK" then
			if mission.faction == faction.name then
				if station.path == mission.location then
					Comms.ImportantMessage((flavours[mission.flavour].successmsg), mission.client.name)
					player:AddMoney(mission.reward)
					_G.MissionsSuccesses = MissionsSuccesses + 1
					mission:Remove()
					missions[ref] = nil
				end
			else
				local crime = "ESPIONAGE"
				Game.player:AddCrime(crime, crime_fine(crime))
				Comms.ImportantMessage(l.Unauthorized_data_here_is_REMOVED, faction.militaryName)
				Comms.ImportantMessage(l.You_have_been_fined .. showCurrency(crime_fine(crime)), faction.policeName)
				mission:Remove()
				missions[ref] = nil
			end
		end
	end
	switchEvents()
end

local onShipLanded = function (player, body)
	if not player:IsPlayer() then return end
	outhostiles = false
	local mission
	local faction = Game.system.faction
	for ref, mission in pairs(missions) do
		if Game.time > mission.due then
			_G.MissionsFailures = MissionsFailures + 1
			mission:Remove()
			missions[ref] = nil
		end
		if mission.status == "TRIP_BACK" then
			if mission.faction == faction.name then
				if mission.location == Game.player:FindNearestTo("SPACESTATION").path then
					Comms.ImportantMessage((flavours[mission.flavour].successmsg), mission.client.name)
					player:AddMoney(mission.reward)
					_G.MissionsSuccesses = MissionsSuccesses + 1
					mission:Remove()
					missions[ref] = nil
				end
			else
				local crime = "ESPIONAGE"
				Game.player:AddCrime(crime, crime_fine(crime))
				Comms.ImportantMessage(l.Unauthorized_data_here_is_REMOVED, faction.militaryName)
				Comms.ImportantMessage(l.You_have_been_fined .. showCurrency(crime_fine(crime)), faction.policeName)
				mission:Remove()
				missions[ref] = nil
			end
		end
	end
	switchEvents()
end


local onClick = function (mission)

	local setTargetButton = SLButton.New(lm.SET_TARGET, 'NORMAL')
	setTargetButton.button.onClick:Connect(function ()
		if not NavAssist then MsgBox.Message(lm.NOT_NAV_ASSIST) return end
		if Game.system.path ~= mission.location:GetStarSystem().path then
			Game.player:SetHyperspaceTarget(mission.location:GetStarSystem().path)
		else
			Game.player:SetNavTarget(Space.GetBody(mission.location.bodyIndex))
		end
	end)

	local dist_txt = _distTxt(mission.location)--,flavours[mission.flavour].localscout)

	local danger
	if mission.risk == 0 then
		danger = (l["MessageRisk0_" .. Engine.rand:Integer(1,2)])
	elseif mission.risk == 1 then
		danger = (l.MessageRisk1)--" .. Engine.rand:Integer(1,x)))
	elseif mission.risk == 2 then
		danger = (l.MessageRisk2)--" .. Engine.rand:Integer(1,x)))
	elseif mission.risk == 3 then
		danger = (l["MessageRisk3_" .. Engine.rand:Integer(1,2)])
	end

	if mission.status =="ACTIVE" or mission.status =="MAPPING" then
		return ui:Grid({68,32},1)
		:SetColumn(0,{ui:VBox(10):PackEnd({ui:MultiLineText((flavours[mission.flavour].introtext1):interp(
						{
							name       = mission.client.name,
							faction    = mission.faction,
							police     = mission.police,
							military   = mission.military,
							systembody = mission.location:GetSystemBody().name,
							system     = mission.location:GetStarSystem().name,
							sectorx    = mission.location.sectorX,
							sectory    = mission.location.sectorY,
							sectorz    = mission.location.sectorZ,
							dist       = dist_txt,
							cash       = showCurrency(mission.reward)
						})
					),
					"",
						ui:Grid(2,1)
							:SetColumn(0,{
								ui:VBox():PackEnd({
													ui:Label(l.Objective)
												})
											})
											:SetColumn(1, {
												ui:VBox():PackEnd({
													ui:MultiLineText(mission.location:GetSystemBody().name)
												})
											}),
										ui:Grid(2,1)
											:SetColumn(0, {
												ui:VBox():PackEnd({
													ui:Label(l.System)
												})
											})
											:SetColumn(1, {
												ui:VBox():PackEnd({
													ui:MultiLineText(mission.location:GetStarSystem().name
															.." ("..mission.location.sectorX
															..","..mission.location.sectorY
															..","..mission.location.sectorZ..")")
												})
											}),
										ui:Grid(2,1)
											:SetColumn(0, {
												ui:VBox():PackEnd({
													ui:Label(l.Deadline)
												})
											})
											:SetColumn(1, {
												ui:VBox():PackEnd({
													ui:Label(Format.Date(mission.due))
												})
											}),
										ui:Grid(2,1)
											:SetColumn(0, {
												ui:VBox():PackEnd({
													ui:Label(l.Danger)
												})
											})
											:SetColumn(1, {
												ui:VBox():PackEnd({
													ui:MultiLineText(danger)
												})
											}),
										"",
										ui:Grid(2,1)
											:SetColumn(0, {
												ui:VBox():PackEnd({
													ui:Label(l.Distance)
												})
											})
											:SetColumn(1, {
												ui:VBox():PackEnd({
													ui:Label(dist_txt),
													"",
													setTargetButton.widget
												})
											}),
		})})
		:SetColumn(1, {
			ui:VBox(10):PackEnd(InfoFace.New(mission.client))
		})
	elseif mission.status =="TRIP_BACK" then
		return ui:Grid({68,32},1)
		:SetColumn(0,{ui:VBox(10):PackEnd({ui:MultiLineText((flavours[mission.flavour].introtext2):interp(
						{
							name       = mission.client.name,
							faction    = mission.faction,
							police     = mission.police,
							military   = mission.military,
							systembody = mission.location:GetSystemBody().name,
							system     = mission.location:GetStarSystem().name,
							sectorx    = mission.location.sectorX,
							sectory    = mission.location.sectorY,
							sectorz    = mission.location.sectorZ,
							cash       = showCurrency(mission.reward),
							dist       = dist_txt})
					),
					"",
						ui:Grid(2,1)
							:SetColumn(0,{
								ui:VBox():PackEnd({
													ui:Label(l.Station)
												})
											})
											:SetColumn(1, {
												ui:VBox():PackEnd({
													ui:MultiLineText(mission.location:GetSystemBody().name)
												})
											}),
										ui:Grid(2,1)
											:SetColumn(0, {
												ui:VBox():PackEnd({
													ui:Label(l.System)
												})
											})
											:SetColumn(1, {
												ui:VBox():PackEnd({
													ui:MultiLineText(mission.location:GetStarSystem().name
															.." ("..mission.location.sectorX
															..","..mission.location.sectorY
															..","..mission.location.sectorZ..")")
												})
											}),
										ui:Grid(2,1)
											:SetColumn(0, {
												ui:VBox():PackEnd({
													ui:Label(l.Deadline)
												})
											})
											:SetColumn(1, {
												ui:VBox():PackEnd({
													ui:Label(Format.Date(mission.due))
												})
											}),
										ui:Grid(2,1)
											:SetColumn(0, {
												ui:VBox():PackEnd({
													ui:Label(l.Distance)
												})
											})
											:SetColumn(1, {
												ui:VBox():PackEnd({
													ui:Label(dist_txt),
													"",
													setTargetButton.widget
												})
											}),
		})})
		:SetColumn(1, {
			ui:VBox(10):PackEnd(InfoFace.New(mission.client))
		})
	elseif mission.status =="SUSPENDED" then
		return ui:Grid(2,1):SetColumn(0,{ui:VBox(10)
			:PackEnd({ui:MultiLineText(l.suspended_mission)})})
	elseif mission.status =="FAILED" then
		return ui:Grid(2,1):SetColumn(0,{ui:VBox(10)
			:PackEnd({ui:MultiLineText(l.failed_mission)})})
	else
		return ui:Grid(2,1):SetColumn(0,{ui:VBox(10)
			:PackEnd({ui:Label("ERROR")})})
	end
end

local onEnterSystem = function (ship)
	if not ship:IsPlayer() or not switchEvents() then return end
end

local loaded_data
local onGameStart = function ()
	ads = {}
	missions = {}
	if type(loaded_data) == "table" then
		for k,ad in pairs(loaded_data.ads) do
			ads[ad.station:AddAdvert({
				description = ad.desc,
				icon        = ad.risk > 0 and "scout_danger" or "scout",
				onChat      = onChat,
				onDelete    = onDelete})] = ad
		end
		missions = loaded_data.missions
		switchEvents()
		loaded_data = nil
	end

	if not Game.player.frameBody then return end
	outhostiles = false
	for ref,mission in pairs(missions) do
		if mission.location:IsSameSystem(Game.system.path) then
			if Game.time > mission.due then
				_G.MissionsFailures = MissionsFailures + 1
				mission:Remove()
				missions[ref] = nil
			else
				mission.status = 'ACTIVE'
				if mission.location == Game.player.frameBody.path then
					start_mapping(mission)
				end
			end
		end
	end
end

local serialize = function ()
	return { ads = ads, missions = missions }
end

local unserialize = function (data)
	loaded_data = data
end

switchEvents = function()
	local status = false
--print("Scout Events deactivated")
	Event.Deregister("onFrameChanged", onFrameChanged)
	Event.Deregister("onShipDocked", onShipDocked)
	Event.Deregister("onShipLanded", onShipLanded)
	for ref,mission in pairs(missions) do
		if mission.location:IsSameSystem(Game.system.path) then
--print("Scout Events activate")
			Event.Register("onFrameChanged", onFrameChanged)
			Event.Register("onShipDocked", onShipDocked)
			Event.Register("onShipLanded", onShipLanded)
			status = true
		end
	end
	return status
end

Event.Register("onCreateBB", onCreateBB)
Event.Register("onUpdateBB", onUpdateBB)
Event.Register("onEnterSystem", onEnterSystem)
Event.Register("onGameStart", onGameStart)

Mission.RegisterType('Scout','Scout',onClick)

Serializer:Register("Scout", serialize, unserialize)
