-- Scout.lua for Pioneer Scout+ (c)2013-2014 by walterar <walterar2@gmail.com>
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
local NameGen    = import("NameGen")
local Format     = import("Format")
local Serializer = import("Serializer")
local Character  = import("Character")
local InfoFace   = import("ui/InfoFace")
local Timer      = import("Timer")

local l = Lang.GetResource("module-scout") or Lang.GetResource("module-scout","en")

 -- don't produce missions for further than this many light years away
local max_scout_dist = 30

-- scanning time 600 = 10 minutes (3600 = 1 h )
local scan_time = 600

-- CallEvery(xTimeUp,....
local xTimeUp = 10

local radius_min = 1.5
local radius_max = 1.6

-- minimum $350 reward in local missions
local local_reward = 350

-- Get the UI class
local ui = Engine.ui

local scout_flavours = {
	{
		localscout = 0,-- 1
		urgency    = 0.0,
		risk       = 0,
	}, {
		localscout = 0,-- 2
		urgency    = 0.0,
		risk       = 0,
	}, {
		localscout = 0,-- 3
		urgency    = 0.1,
		risk       = 2,
	}, {
		localscout = 0,-- 4
		urgency    = 1.0,
		risk       = 2,
	}, {
		localscout = 0,-- 5
		urgency    = 0.4,
		risk       = 3,
	}, {
		localscout = 1,-- 6
		urgency    = 0.1,
		risk       = 0,
	}, {
		localscout = 1,-- 7
		urgency    = 0.8,
		risk       = 1,
	}
}

-- add strings to scout flavours
for i = 1,#scout_flavours do
	local f = scout_flavours[i]
	f.adtext        = l["ADTEXT_"..i]
	f.introtext1    = l["INTROTEXT1_"..i]
	f.introtext2    = l["INTROTEXT2_"..i]
	f.whysomuchtext = l["WHYSOMUCHTEXT_"..i]
	f.successmsg    = l["SUCCESSMSG_"..i]
end

local ScoutHostileMessages = {
	l.hostilemessage1,
	l.hostilemessage2,
	l.hostilemessage3,
	l.hostilemessage4,
  }

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

		local introtext1 = string.interp(scout_flavours[ad.flavour].introtext1, {
			name       = ad.client.name,
			faction    = faction.name,
			police     = faction.policeName,
			military   = faction.militaryName,
			cash       = Format.Money(ad.reward),
			systembody = sbody.name,
			system     = sys.name,
			sectorx    = ad.location.sectorX,
			sectory    = ad.location.sectorY,
			sectorz    = ad.location.sectorZ,
			dist       = string.format("%.2f", ad.dist),
		})
		form:SetMessage(introtext1)

		local introtext2 = string.interp(scout_flavours[ad.flavour].introtext2, {
			name       = ad.client.name,
			faction    = faction.name,
			police     = faction.policeName,
			military   = faction.militaryName,
			cash       = Format.Money(ad.reward),
			systembody = sbody.name,
			system     = sys.name,
			sectorx    = ad.location.sectorX,
			sectory    = ad.location.sectorY,
			sectorz    = ad.location.sectorZ,
		})

	elseif option == 1 then
		form:SetMessage(scout_flavours[ad.flavour].whysomuchtext)

	elseif option == 2 then
		form:SetMessage(l.I_need_the_information_by .. Format.Date(ad.due))

	elseif option == 4 then
		if ad.risk == 0 then
			form:SetMessage(l["MessageRisk0_" .. Engine.rand:Integer(1,2)])
		elseif ad.risk == 1 then
			form:SetMessage(l.MessageRisk1)--" .. Engine.rand:Integer(1,x)))
		elseif ad.risk == 2 then
			form:SetMessage(l.MessageRisk2)--" .. Engine.rand:Integer(1,x)))
		elseif ad.risk == 3 then
			form:SetMessage(l["MessageRisk3_" .. Engine.rand:Integer(1,2)])
		end
	elseif option == 5 then
			form:SetMessage(l.additional_information)

	elseif option == 3 then
		if (MissionsSuccesses - MissionsFailures) < 5 and ad.risk > 0 then
			form:SetMessage(l.You_do_not_have_enough_experience_for_this_mission)
			return
		end
		if Game.player:GetEquip('RADARMAPPER',1) == "NONE" then
			form:SetMessage(l.You_have_not_installed_RADAR_MAPPER)
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
			due         = ad.due,
			flavour     = ad.flavour,
			status      = 'ACTIVE',
		}

		table.insert(missions,Mission.New(mission))
		Game.player:SetHyperspaceTarget(mission.location:GetStarSystem().path)
		form:SetMessage(l.Excellent_I_await_your_report)
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
	local reward, due, location, nearbysystem
	local client = Character.New()
	local flavour = Engine.rand:Integer(1,#scout_flavours)
	local urgency = scout_flavours[flavour].urgency
	local risk = scout_flavours[flavour].risk
	local	faction = Game.system.faction
-- local system
	if scout_flavours[flavour].localscout == 1 then
		nearbysystem = Game.system
		local nearbystations = nearbysystem:GetBodyPaths()
		local HasPop = 1
		while HasPop > 0 do
			if HasPop > #nearbystations then return end
			location = nearbystations[Engine.rand:Integer(1,#nearbystations)]
			local CurBody = location:GetSystemBody()
			if CurBody.superType == "ROCKY_PLANET"
				and CurBody.type ~= "PLANET_ASTEROID"
			then break end
			HasPop = HasPop + 1
		end
		local dist = station:DistanceTo(Space.GetBody(location.bodyIndex))
		if dist < 1000 then return end
		reward = local_reward + (math.sqrt(dist) / 15000) * (1.5+urgency) * (1+nearbysystem.lawlessness)
		due = Game.time + ((4*24*60*60) * (Engine.rand:Number(1.5,3.5) - urgency))
	else
-- remote system
		local nearbysystems =	Game.system:GetNearbySystems(max_scout_dist,
			function (s) return #s:GetBodyPaths() > 0 and s.population == 0 end)
		if #nearbysystems == 0 then return end
		nearbysystem = nearbysystems[Engine.rand:Integer(1,#nearbysystems)]
		local dist = nearbysystem:DistanceTo(Game.system)
		local nearbybodys = nearbysystem:GetBodyPaths()

		local HasPop = 1
		while HasPop > 0 do
			if HasPop > #nearbybodys then return end
			location = nearbybodys[Engine.rand:Integer(1,#nearbybodys)]
			local CurBody = location:GetSystemBody()
			if CurBody.superType == "ROCKY_PLANET"
				and CurBody.type ~= "PLANET_ASTEROID"
			then break end
			HasPop = HasPop + 1
		end

		local scoutplus = 1
		if nearbysystem.explored == 0 then scoutplus = 1.+ Engine.rand:Number(1) end
		reward = tariff(dist,risk,urgency,location) * 4 * scoutplus
		due = term(dist*2,urgency)

	end

	local ad = {
		station  = station,
		flavour  = flavour,
		client   = client,
		location = location,
		dist     = Game.system:DistanceTo(location),
		due      = due,
		risk     = risk,
		urgency  = urgency,
		reward   = reward,
		isfemale = isfemale,
		faceseed = Engine.rand:Integer(),
	}

	local sbody = ad.location:GetSystemBody()

	ad.desc = string.interp(scout_flavours[flavour].adtext, {
		faction    = faction.name,
		police     = faction.policeName,
		military   = faction.militaryName,
		system     = nearbysystem.name,
		cash       = Format.Money(ad.reward),
		dist       = string.format("%.2f", ad.dist),
		systembody = sbody.name,
	})

--	local ref = station:AddAdvert(ad.desc, onChat, onDelete)
--	ads[station:AddAdvert(ad.desc, onChat, onDelete)] = ad
	local ref = station:AddAdvert({
		description = ad.desc,
		icon        = ad.risk > 0 and "scout_danger" or "scout",
		onChat      = onChat,
		onDelete    = onDelete})
	ads[ref] = ad

end

local onCreateBB = function (station)
	local num = Engine.rand:Integer(math.ceil(Game.system.population))
	for i = 1,num do
		makeAdvert(station)
	end
end

local onUpdateBB = function (station)
--	if station == Game.player:GetDockedWith() then
		for ref,ad in pairs(ads) do
			if scout_flavours[ad.flavour].localscout == 0
				and ad.due < Game.time + 5*60*60*24 then
				ad.station:RemoveAdvert(ref)
			elseif scout_flavours[ad.flavour].localscout == 1
				and ad.due < Game.time + 2*60*60*24 then
				ad.station:RemoveAdvert(ref)
			end
		end
		if Engine.rand:Integer(12*60*60) < 60*60 then
			makeAdvert(station)
		end
--	end
end

local mapped = function(body)
	local CurBody = Game.player.frameBody or body
	if CurBody == nil then return end
	local faction = Game.system.faction
	local mission
	for ref,mission in pairs(missions) do
		if Game.time > mission.due then mission.status = "FAILED" end
		if Game.system == mission.location:GetStarSystem() then

			if mission.status == "COMPLETED" then return end

			local PhysBody = CurBody.path:GetSystemBody()
			if PhysBody and CurBody.path == mission.location then
				local TimeUp = 0
				if DangerLevel == 2 then
					radius_min = 1.3
					radius_max = 1.4
				else
					radius_min = 1.5
					radius_max = 1.6
				end

				local count = Engine.rand:Integer(15,40)
				local outhostiles = 0

				Timer:CallEvery(xTimeUp, function ()
					if mission.status == "COMPLETED" then return 1 end
					if not pcall(function () return CurBody:DistanceTo(Game.player) end) then
						return 1
					end
					local Dist = CurBody:DistanceTo(Game.player)
					if Dist < PhysBody.radius * radius_min
						and (mission.status == 'ACTIVE'
						or mission.status == "SUSPENDED") then
						local lapse = scan_time / 60
						Comms.ImportantMessage(l.Distance_reached .. lapse .. l.minutes, l.computer)
						mission.status = "MAPPING"
					elseif Dist > PhysBody.radius * radius_max and mission.status == "MAPPING" then
						Comms.ImportantMessage(l.MAPPING_interrupted, l.computer)
						mission.status = "SUSPENDED"
						TimeUp = 0
						return 1
					end
					if mission.status == "MAPPING" then
						TimeUp = TimeUp + xTimeUp
						if count == 55 then
							count = 0
							outhostiles = 1
							local risk = scout_flavours[mission.flavour].risk
							local ship = ship_hostil(risk)
							if ship then
								local hostile_greeting = string.interp(ScoutHostileMessages
											[Engine.rand:Integer(1,#(ScoutHostileMessages))],
											{client = mission.client.name, location = mission.location:GetSystemBody().name })
									Comms.ImportantMessage(hostile_greeting, ship.label)
							end
						end
						if outhostiles == 0 then count = count + 1 end
						if TimeUp >= scan_time then
							mission.status = "COMPLETED"
							Comms.ImportantMessage(l.COMPLETE_MAPPING, l.computer)
-- decide destino de entrega
							local iflocal = scout_flavours[mission.flavour].localscout
							if iflocal == 0 and (((mission.faction == faction.name) and Engine.rand:Integer(2) == 1)
															or Engine.rand:Integer(3) == 1)
							then
								local nearbystations = StarSystem:GetNearbyStationPaths(Engine.rand:Integer(10,20), nil,function (s) return
		(s.type ~= 'STARPORT_SURFACE') or (s.parent.type ~= 'PLANET_ASTEROID') end)
								local newlocation = nil
								newlocation = nearbystations[Engine.rand:Integer(1,#nearbystations)]
								if newlocation == nil then
									mission.location = mission.backstation
									Game.player:SetHyperspaceTarget(mission.location:GetStarSystem().path)
								else
									mission.location = newlocation
									Game.player:SetHyperspaceTarget(mission.location:GetStarSystem().path)
									Comms.ImportantMessage(l.You_will_be_paid_on_my_behalf_in_new_destination,
 												mission.client.name)
								end
							else
								mission.location = mission.backstation
								Game.player:SetHyperspaceTarget(mission.location:GetStarSystem().path)
							end
						end
					end
					if mission.status == "COMPLETED" then return 1 end
				end)

			end
		end
	end
end

local onFrameChanged = function (body)
	if body:isa("Ship") and body:IsPlayer() then
		if body.frameBody == nil then return end
		mapped(body)
	end
end

local onShipDocked = function (player, station)
	if not player:IsPlayer() then return end
	local mission
	local faction = Game.system.faction
	for ref, mission in pairs(missions) do

		if Game.time > mission.due then
--			mission.status == "FAILED"
			_G.MissionsFailures = MissionsFailures + 1
				mission:Remove()
				missions[ref] = nil
--			return
		end

		if mission.status == "COMPLETED" then
			if mission.faction == faction.name then
				if station.path == mission.location then
					Comms.ImportantMessage((scout_flavours[mission.flavour].successmsg), mission.client.name)
					player:AddMoney(mission.reward)
					_G.MissionsSuccesses = MissionsSuccesses + 1
					mission:Remove()
					missions[ref] = nil
				end
			else
				local multiplier = Game.system.lawlessness
				if multiplier < .02 then multiplier = 1 + multiplier end -- si son muy chantas te dejan seco
				local money = math.floor(Game.player:GetMoney() * multiplier)
				Game.player:AddCrime("TRADING_ILLEGAL_GOODS", money)
				Comms.ImportantMessage(l.Unauthorized_data_here_is_REMOVED, faction.militaryName)
				Comms.ImportantMessage(l.You_have_been_fined .. Format.Money(money), faction.policeName)
--				_G.MissionsFailures = MissionsFailures + 1
				mission:Remove()
				missions[ref] = nil
			end
		end
	end
end

local loaded_data

local onGameStart = function ()
	ads = {}
	missions = {}

	if loaded_data then
		for k,ad in pairs(loaded_data.ads) do
			ads[ad.station:AddAdvert({
				description = ad.desc,
				icon        = ad.risk > 0 and "scout_danger" or "scout",
				onChat      = onChat,
				onDelete    = onDelete})] = ad
		end
		missions = loaded_data.missions
		loaded_data = nil
	end

	local CurBody = Game.player.frameBody
	local mission
	for ref,mission in pairs(missions) do
		if CurBody and CurBody.path ~= mission.location then return end
		if Game.time > mission.due then
			mission.status = "FAILED"
			_G.MissionsFailures = MissionsFailures + 1
			mission:Remove()
			missions[ref] = nil
			return
		end
		mapped(CurBody)
	end

end

local onClick = function (mission)
	local dist = Game.system and string.format("%.2f", Game.system:DistanceTo(mission.location)) or "zzz"

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
		return ui:Grid(2,1)
		:SetColumn(0,{ui:VBox(10):PackEnd({ui:MultiLineText((scout_flavours[mission.flavour].introtext1):interp(
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
							dist       = dist,
							cash       = Format.Money(mission.reward),
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
													ui:MultiLineText(mission.location:GetStarSystem().name.." ("..mission.location.sectorX..","..mission.location.sectorY..","..mission.location.sectorZ..")")
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
													ui:Label(dist.." ly")
												})
											}),
		})})
		:SetColumn(1, {
			ui:VBox(10):PackEnd(InfoFace.New(mission.client))
		})
	elseif mission.status =="COMPLETED" then
		return ui:Grid(2,1)
		:SetColumn(0,{ui:VBox(10):PackEnd({ui:MultiLineText((scout_flavours[mission.flavour].introtext2):interp(
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
							cash       = Format.Money(mission.reward),
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
													ui:MultiLineText(mission.location:GetStarSystem().name.." ("..mission.location.sectorX..","..mission.location.sectorY..","..mission.location.sectorZ..")")
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
--[[										ui:Grid(2,1)
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
										"",--]]
										ui:Grid(2,1)
											:SetColumn(0, {
												ui:VBox():PackEnd({
													ui:Label(l.Distance)
												})
											})
											:SetColumn(1, {
												ui:VBox():PackEnd({
													ui:Label(dist.." ly")
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

local serialize = function ()
	return { ads = ads, missions = missions }
end

local unserialize = function (data)
	loaded_data = data
end

Event.Register("onCreateBB", onCreateBB)
Event.Register("onUpdateBB", onUpdateBB)
Event.Register("onFrameChanged", onFrameChanged)
Event.Register("onShipDocked", onShipDocked)
Event.Register("onGameStart", onGameStart)

Mission.RegisterType('Scout','Scout',onClick)

Serializer:Register("Scout", serialize, unserialize)
