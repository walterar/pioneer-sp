-- Scooping.lua for Pioneer Scout+ (c)2012-2016 by walterar <walterar2@gmail.com>
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
local ShipDef    = import("ShipDef")
local Character  = import("Character")
local InfoFace   = import("ui/InfoFace")
local Timer      = import("Timer")
local Eq         = import("Equipment")

local SmallLabeledButton = import("ui/SmallLabeledButton")
local MsgBox    = import("ui/MessageBox")
local InfoFace  = import("ui/InfoFace")
local SLButton  = import("ui/SmallLabeledButton")

local l  = Lang.GetResource("module-scooping") or Lang.GetResource("module-scooping","en")
local lm = Lang.GetResource("miscellaneous") or Lang.GetResource("miscellaneous","en")

 -- don't produce missions for further than this many light years away
local max_dist = 30

local AU = 149597870700

-- minimum $300 reward in local missions
local local_reward = 300

local old_location

local ui = Engine.ui

local LocalScoopables = {}
local GetLocalScoopables = function ()
	for _,path in pairs(Game.system:GetBodyPaths()) do
		local sbody = path:GetSystemBody()
			if sbody.isScoopable and sbody.gravity < 26 then
----print("Gravedad de "..sbody.name.."  "..sbody.gravity)
--print(sbody.name.." seed "..sbody.seed)
			table.insert(LocalScoopables, Space.GetBody(sbody.index).path)
		end
	end
	return LocalScoopables
end


local flavours = {
	{
		localscoop = false,-- 1
		urgency    = false,
		risk       = false
	}, {
		localscoop = false,-- 2
		urgency    = false,
		risk       = false
	}, {
		localscoop = false,-- 3
		urgency    = false,
		risk       = true
	}, {
		localscoop = false,-- 4
		urgency    = true,
		risk       = true
	}, {
		localscoop = false,-- 5
		urgency    = false,
		risk       = true
	}, {
		localscoop = true,-- 6
		urgency    = false,
		risk       = false
	}, {
		localscoop = true,-- 7
		urgency    = true,
		risk       = false
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

		if Game.player:CountEquip(Eq.misc.fuel_scoop) == 0
			and Game.player:CountEquip(Eq.misc.multi_scoop) == 0 then
			form:SetMessage(l.You_have_not_installed_EQUIPMENT.."\n*\n*")
			return
		end

		form:RemoveAdvertOnClose()
		ads[ref] = nil
		local mission = {
			type        = "Scooping",
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

local validsystem = function(remotesystem)
	local valid = true
	for _,explored in pairs(explored_systems) do
		if explored.system == remotesystem then
			valid = false
		end
	end
	return valid
end

local makeAdvert = function (station)
--print("Scooping makeAdvert: "..station.label.." Distancia: ".._distTxt(station.path))
	local reward, due, location, targetBody, remotesystem
	local client = Character.New()
--	local flavour = Engine.rand:Integer(6,7)
	local flavour = Engine.rand:Integer(1,#flavours)
	local urgency = flavours[flavour].urgency and Engine.rand:Number(0.2,1) or 0
	local risk = flavours[flavour].risk and Engine.rand:Integer(1,3) or 0
	local	faction = Game.system.faction

-- local system
	if flavours[flavour].localscoop then
		if #LocalScoopables == 0 then return end
		location = LocalScoopables[Engine.rand:Integer(1,#LocalScoopables)]

		local AU = 149597870700
		local dist = station:DistanceTo(Space.GetBody(location.bodyIndex))/AU
		due =_local_due(station,location,urgency,true)

		local reward_base = 450
		reward = reward_base*math.sqrt(dist)*(1+urgency)*(1+Game.system.lawlessness)

	else-- remote system
		local remotesystems = Game.system:GetNearbySystems(max_dist,
			function (s) return #s:GetBodyPaths() > 0
				and s.population == 0 and s.explored end)
		if #remotesystems == 0 then return end
		remotesystem = remotesystems[Engine.rand:Integer(1,#remotesystems)]
		local dist = Game.system:DistanceTo(remotesystem)
		local remotebodies = remotesystem:GetBodyPaths()
		local checkedBodies = 1
		while checkedBodies <= #remotebodies do
			location = remotebodies[Engine.rand:Integer(1,#remotebodies)]
			targetBody = location:GetSystemBody()
			if validsystem(remotesystem.path)
				and targetBody.isScoopable
				and targetBody.gravity < 26 then
				break
			end
			location = nil
			targetBody = nil
			checkedBodies = checkedBodies + 1
		end
		if not location then return end
		local multiplier = Engine.rand:Number(1.5,1.6)
		if Game.system.faction ~= location:GetStarSystem().faction then
			multiplier = multiplier * Engine.rand:Number(1.3,1.5)
		end

		local reward_base = 450
		reward = reward_base+(tariff(dist,risk,urgency,location)*2*multiplier)
		due = _remote_due(dist,urgency,true)
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
		icon        = ad.risk > 0 and "scooping_danger" or "scooping",
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
			if flavours[ad.flavour].localscoop then timeout = 60*60 end -- 1 hour timeout for locals
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

local checkOthersMissions = function ()
	for ref,m in pairs(missions) do
		if Game.time < m.due
			and m.status == "TRIP_BACK"
			and Game.player:CountEquip(Eq.cargo.hydrogen) < 1
			and old_location
		then
			m.location = old_location
			old_location = nil
			m.status = "ACTIVE"
		end
	end
end
--[[
local checkOthersMissions = function (mission)
	for ref,m in pairs(missions) do
		if Game.time < m.due and m.status == "TRIP_BACK" then
			if m.location ~= mission.location then
				while Game.player:CountEquip(Eq.cargo.hydrogen) > 0 do
					Game.player:Jettison(Eq.cargo.hydrogen)
				end
				m.location = old_location
				old_location = nil
				m.status = "ACTIVE"
			end
		end
	end
end
--]]

	local outhostiles, check
local start_scooping = function(mission)
--	local load = math.floor(ShipDef[Game.player.shipId].fuelTankMass / 2)
	local CurBody = Game.player.frameBody
	if not CurBody then return end
	local faction = Game.system.faction
	local PhysBody = CurBody.path:GetSystemBody()
	local TimeUp = 0
	Timer:CallEvery(2, function ()
		if mission.status == "TRIP_BACK" then return true end
		local Dist = CurBody:DistanceTo(Game.player)
		if Dist < PhysBody.radius * 1.4 and mission.status == 'ACTIVE' then
			while Game.player:CountEquip(Eq.cargo.hydrogen) > 0 do
				Game.player:Jettison(Eq.cargo.hydrogen)
			end
			if not check then
				checkOthersMissions()
				check = true
			end
			Comms.ImportantMessage(l.Distance_reached, l.computer)
			Music.Play("music/core/fx/mapping-on"..Engine.rand:Integer(1,3))
			mission.status = "WORKING"
		end
		if mission.status == "WORKING" then
			if mission.risk > 0 and not outhostiles then
				outhostiles = true
				Timer:CallAt(Game.time + Engine.rand:Integer(10*60,15*60), function ()
					local ship = ship_hostil(mission.risk)
					if ship then
						Comms.ImportantMessage(l["hostilemessage"..Engine.rand:Integer(1,hm)], ship.label)
					end
				end)
			end
			if Game.player:CountEquip(Eq.cargo.hydrogen) > 1 then--load then
				mission.status = "TRIP_BACK"
				Music.Play("music/core/fx/mapping-off",false)
				Comms.ImportantMessage(l.COMPLETE_SCOOPING, l.computer)

-- decide destino de entrega estaciones remotas - no locales
				if mission.localscoop == false
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
				old_location = mission.location
				mission.location = mission.backstation
				if NavAssist and Game.system.path ~= mission.location:GetStarSystem().path then
					Game.player:SetHyperspaceTarget(mission.location:GetStarSystem().path)
				end
				check = false
				return true
			end
		end
	end)
end

local onFrameChanged = function (body)
----print("Scooping onFrameChanged body="..body.label)
	if not body:isa("Ship") or not body:IsPlayer() then return end
	if body.frameBody == nil then return end
	if body.frameBody ~= Game.player:GetNavTarget()
		and Game.player:FindNearestTo("SPACESTATION") ~= Game.player:GetNavTarget()
	then return end
	for ref,mission in pairs(missions) do
		if Game.time < mission.due
			and mission.status == "ACTIVE"
			and Game.player:GetNavTarget()
			and mission.location == Game.player:GetNavTarget().path then
			start_scooping(mission)
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

			if Game.player:CountEquip(Eq.cargo.hydrogen) < 1 then
				mission:Remove()
				missions[ref] = nil
				return
			else
				Game.player:RemoveEquip(Eq.cargo.hydrogen, 1)
			end

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

			if Game.player:CountEquip(Eq.cargo.hydrogen) < 1 then
				mission:Remove()
				missions[ref] = nil
				return
			else
				Game.player:RemoveEquip(Eq.cargo.hydrogen, 1)
			end

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

	local dist_txt = _distTxt(mission.location)

	local setTargetButton = SLButton.New(lm.SET_TARGET, 'NORMAL')
	setTargetButton.button.onClick:Connect(function ()
		if not Game.system then return end
		if not NavAssist then MsgBox.Message(lm.NOT_NAV_ASSIST) return end
		if Game.system.path ~= mission.location:GetStarSystem().path then
			Game.player:SetHyperspaceTarget(mission.location:GetStarSystem().path)
		else
			Game.player:SetNavTarget(Space.GetBody(mission.location.bodyIndex))
		end
	end)

--[[	local setCancelButton = SLButton.New('Cancelar misión', 'NORMAL')
	setCancelButton.button.onClick:Connect(function ()
		mission:Remove()
		missions[ref] = nil
	end)--]]

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

	if mission.status == "TRIP_BACK"
		and Game.player:CountEquip(Eq.cargo.hydrogen) < 1
		and Game.player:FindNearestTo("SPACESTATION") == mission.location
	then
		mission.status ="FAILED"
	end

	if mission.status =="ACTIVE" or mission.status =="WORKING" then
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
												}),
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
										ui:Margin(6),
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
--										"",
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
							dist       = dist})
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
	elseif mission.status =="FAILED" then
		return ui:Grid(1,1):SetColumn(0,{ui:VBox(10)
			:PackEnd({ui:MultiLineText(l.failed_mission)})})
	else
		return ui:Grid(2,1):SetColumn(0,{ui:VBox(10)
			:PackEnd({ui:Label("ERROR")})})
	end
end


local onEnterSystem = function (ship)
	if not ship:IsPlayer() then return end
	LocalScoopables = {}
	LocalScoopables = GetLocalScoopables()
	switchEvents()
end


local loaded_data
local onGameStart = function ()
	ads = {}
	missions = {}
	LocalScoopables = {}
	if type(loaded_data) == "table" then
		for k,ad in pairs(loaded_data.ads) do
			ads[ad.station:AddAdvert({
				description = ad.desc,
				icon        = ad.risk > 0 and "scooping_danger" or "scooping",
				onChat      = onChat,
				onDelete    = onDelete})] = ad
		end
		missions = loaded_data.missions
		old_location = loaded_data.old_location
		switchEvents()
		loaded_data = nil
	end
	LocalScoopables = GetLocalScoopables()
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
					start_scooping(mission)
				end
			end
		end
	end
end

local serialize = function ()
	return { ads = ads,
			missions = missions,
			old_location = old_location }
end

local unserialize = function (data)
	loaded_data = data
end

switchEvents = function()
	local status = false
--print("Scooping Events deactivated")
	Event.Deregister("onFrameChanged", onFrameChanged)
	Event.Deregister("onShipDocked", onShipDocked)
	Event.Deregister("onShipLanded", onShipLanded)
	for ref,mission in pairs(missions) do
		if Game.time > mission.due or mission.location:IsSameSystem(Game.system.path) then
--print("Scooping Events activate")
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

Mission.RegisterType('Scooping','Scooping',onClick)

Serializer:Register("Scooping", serialize, unserialize)
