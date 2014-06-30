-- Copyright © 2008-2014 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt
-- modified for Pioneer Scout+ (c)2012-2014 by walterar <walterar2@gmail.com>
-- Work in progress.

local Lang       = import("Lang")
local Engine     = import("Engine")
local Game       = import("Game")
local Space      = import("Space")
local StarSystem = import("StarSystem")
local Comms      = import("Comms")
local Event      = import("Event")
local Mission    = import("Mission")
local NameGen    = import("NameGen")
local Format     = import("Format")
local Serializer = import("Serializer")
local Character  = import("Character")
local EquipDef   = import("EquipDef")
local ShipDef    = import("ShipDef")
local Ship       = import("Ship")

local InfoFace   = import("ui/InfoFace")


-- Get the language resource
local l   = Lang.GetResource("module-taxi") or Lang.GetResource("module-taxi","en");
local myl = Lang.GetResource("module-myl") or Lang.GetResource("module-myl","en");


-- Get the UI class
local ui = Engine.ui

-- don't produce missions for further than this many light years away
local max_taxi_dist = 30
-- max number of passengers per trip
local max_group = 10

local num_corporations = 12
local num_pirate_taunts = 4

local target_distance_from_entry = 0

local taxi_flavours = {
	{
		single = false,-- flavour 0
		urgency = 0,
		risk = 0,
	}, {
		single = false,-- flavour 1
		urgency = 0,
		risk = 0,
	}, {
		single = false,-- flavour 2
		urgency = 0,
		risk = 0,
	}, {
		single = true,-- flavour 3
		urgency = 0.13,
		risk = 1,
	}, {
		single = true,-- flavour 4
		urgency = 0.3,
		risk = 0,
	}, {
		single = true,-- flavour 5
		urgency = 0.1,
		risk = 0,
	}, {
		single = true,-- flavour 6
		urgency = 0.02,
		risk = 0,
	}, {
		single = true,-- flavour 7
		urgency = 0.15,
		risk = 3,
	}, {
		single = true,-- flavour 8
		urgency = 0.6,
		risk = 0,
	}, {
		single = true,-- flavour 9
		urgency = 0.85,
		risk = 2,
	}, {
		single = true,-- flavour 10
		urgency = 0.9,
		risk = 2,
	}, {
		single = true,-- flavour 11
		urgency = 1,
		risk = 1,
	}, {
		single = true,-- flavour 12
		urgency = 0,
		risk = 2,
	}
}

-- add strings to flavours
for i = 1,#taxi_flavours do
	local f = taxi_flavours[i]
	f.adtext     = l["FLAVOUR_" .. i-1 .. "_ADTEXT"]
	f.introtext  = l["FLAVOUR_" .. i-1 .. "_INTROTEXT"].."\n*\n*"
	f.whysomuch  = l["FLAVOUR_" .. i-1 .. "_WHYSOMUCH"].."\n*\n*"
	f.howmany    = l["FLAVOUR_" .. i-1 .. "_HOWMANY"].."\n*\n*"
	f.danger     = l["FLAVOUR_" .. i-1 .. "_DANGER"].."\n*\n*"
	f.successmsg = l["FLAVOUR_" .. i-1 .. "_SUCCESSMSG"]
	f.failuremsg = l["FLAVOUR_" .. i-1 .. "_FAILUREMSG"]
	f.wherearewe = l["FLAVOUR_" .. i-1 .. "_WHEREAREWE"]
end

local ads = {}
local missions = {}
local passengers = 0

local add_passengers = function (group)
	Game.player:RemoveEquip('UNOCCUPIED_CABIN', group)
	Game.player:AddEquip('PASSENGER_CABIN', group)
	passengers = passengers + group
end

local remove_passengers = function (group)
	Game.player:RemoveEquip('PASSENGER_CABIN', group)
	Game.player:AddEquip('UNOCCUPIED_CABIN', group)
	passengers = passengers - group
end

local onChat = function (form, ref, option)
	local ad = ads[ref]

	form:Clear()

	if option == -1 then
		form:Close()
		return
	end

	if option == 0 then
		form:SetFace(ad.client)

		local introtext = string.interp(taxi_flavours[ad.flavour].introtext, {
			name     = ad.client.name,
			cash     = showCurrency(ad.reward),
			starport = ad.location:GetSystemBody().name,
			system   = ad.location:GetStarSystem().name,
			sectorx  = ad.location.sectorX,
			sectory  = ad.location.sectorY,
			sectorz  = ad.location.sectorZ,
			dist     = string.format("%.2f", ad.dist),
		})

		form:SetMessage(introtext)

	elseif option == 1 then
		local corporation = l["CORPORATIONS_"..Engine.rand:Integer(0,num_corporations-1)]
		local whysomuch = string.interp(taxi_flavours[ad.flavour].whysomuch, {
			corp     = corporation,
		})

		form:SetMessage(whysomuch)

	elseif option == 2 then
		local howmany = string.interp(taxi_flavours[ad.flavour].howmany, {
			group  = ad.group,
		})

		form:SetMessage(howmany)

	elseif option == 3 then
		if (MissionsSuccesses - MissionsFailures < 5) and ad.risk > 0 then
			form:SetMessage(myl.have_enough_experience)
			return
		end
		local capacity = ShipDef[Game.player.shipId].equipSlotCapacity.CABIN
		if capacity < ad.group or Game.player:GetEquipCount('CABIN', 'UNOCCUPIED_CABIN') < ad.group then
			form:SetMessage(l.YOU_DO_NOT_HAVE_ENOUGH_CABIN_SPACE_ON_YOUR_SHIP)
			return
		end

		add_passengers(ad.group)

		form:RemoveAdvertOnClose()

		ads[ref] = nil

		local mission = {
			type     = "Taxi",
			client   = ad.client,
			location = ad.location,
			risk     = ad.risk,
			reward   = ad.reward,
			due      = ad.due,
			group    = ad.group,
			flavour  = ad.flavour
		}

		table.insert(missions,Mission.New(mission))
		Game.player:SetHyperspaceTarget(mission.location:GetStarSystem().path)

		form:SetMessage(l.EXCELLENT)

		return
	elseif option == 4 then
		if taxi_flavours[ad.flavour].single == true then

			form:SetMessage(l.I_MUST_BE_THERE_BEFORE..Format.Date(ad.due).."\n*\n*")
		else
			form:SetMessage(l.WE_WANT_TO_BE_THERE_BEFORE..Format.Date(ad.due).."\n*\n*")
		end

	elseif option == 5 then
		form:SetMessage(taxi_flavours[ad.flavour].danger)
	end

	form:AddOption(l.WHY_SO_MUCH_MONEY, 1)
	form:AddOption(l.HOW_MANY_OF_YOU_ARE_THERE, 2)
	form:AddOption(l.HOW_SOON_YOU_MUST_BE_THERE, 4)
	form:AddOption(l.WILL_I_BE_IN_ANY_DANGER, 5)
	form:AddOption(l.COULD_YOU_REPEAT_THE_ORIGINAL_REQUEST, 0)
	form:AddOption(l.OK_AGREED, 3)
end

local onDelete = function (ref)
	ads[ref] = nil
end

local locations, location
local makeAdvert = function (station)
	local reward, due, location
	local client  = Character.New()
	local flavour = Engine.rand:Integer(1,#taxi_flavours)
	local urgency = taxi_flavours[flavour].urgency
	local risk    = taxi_flavours[flavour].risk
	local group   = 1
	if taxi_flavours[flavour].single == false then
		group = Engine.rand:Integer(2,max_group)
	end

	local nearbystations = StarSystem:GetNearbyStationPaths(max_taxi_dist, nil,function (s) return
		(s.type ~= 'STARPORT_SURFACE') or (s.parent.type ~= 'PLANET_ASTEROID') end)

	local location = nil
	location = nearbystations[Engine.rand:Integer(1,#nearbystations)]
	if location == nil then return end

	local dist = location:DistanceTo(Game.system)
	local taxiplus = 1.8
	if group > 1 then taxiplus = (taxiplus*group)-1 end
	reward = tariff (dist,risk,urgency,location) * taxiplus
	due    = term (dist,urgency)

	local ad = {
		station  = station,
		flavour  = flavour,
		client   = client,
		location = location,
		dist     = dist,
		due      = due,
		group    = group,
		risk     = risk,
		urgency  = urgency,
		reward   = reward,
		isfemale = isfemale,
		faceseed = Engine.rand:Integer(),
	}

	ad.desc = string.interp(taxi_flavours[flavour].adtext, {
		starport = ad.location:GetSystemBody().name,
		system   = ad.location:GetStarSystem().name,
		cash     = showCurrency(ad.reward),
	})
	ads[station:AddAdvert({
		description = ad.desc,
		icon        = ad.risk > 0 and "taxi_danger" or "taxi",
		onChat      = onChat,
		onDelete    = onDelete})] = ad
end

local onCreateBB = function (station)
	local num = Engine.rand:Integer(0, math.ceil(Game.system.population))
	for i = 1,num do
		makeAdvert(station)
	end
end

local onUpdateBB = function (station)
	for ref,ad in pairs(ads) do
		if ad.due < Game.time + 5*60*60*24 then
			ad.station:RemoveAdvert(ref)
		end
	end
	if Engine.rand:Integer(24*60*60) < 60*60 then -- roughly once every day
		makeAdvert(station)
	end
end

local hostilactive = false
local onFrameChanged = function (body)
	if body:isa("Ship") and body:IsPlayer() and body.frameBody ~= nil then
		local syspath = Game.system.path
		for ref,mission in pairs(missions) do
			if mission.status == "ACTIVE" and mission.location:IsSameSystem(syspath) then
				target_distance_from_entry = body:DistanceTo(Space.GetBody(mission.location.bodyIndex))
				if target_distance_from_entry > 100000e3 then return end
				local risk = taxi_flavours[mission.flavour].risk
				if risk > 0 and not hostilactive then ship = ship_hostil(risk) end

				if ship and not hostilactive then
					hostilactive = true
					local pirate_greeting = string.interp(l['PIRATE_TAUNTS_'..Engine.rand:Integer(1,num_pirate_taunts)-1], { client = mission.client.name,})
						Comms.ImportantMessage(pirate_greeting, ship.label)
				end

			end
			if mission.status == "ACTIVE" and Game.time > mission.due then
				mission.status = 'FAILED'
				Comms.ImportantMessage(taxi_flavours[mission.flavour].wherearewe, mission.client.name)
			end
		end
	end
end

local onShipDocked = function (player, station)
	if not player:IsPlayer() then return end
	for ref,mission in pairs(missions) do
		if mission.location == station.path or mission.status == 'FAILED' then
			if Game.time > mission.due then
				Comms.ImportantMessage(taxi_flavours[mission.flavour].failuremsg, mission.client.name)
				_G.MissionsFailures = MissionsFailures + 1
			else
				Comms.ImportantMessage(taxi_flavours[mission.flavour].successmsg, mission.client.name)
				player:AddMoney(mission.reward)
				_G.MissionsSuccesses = MissionsSuccesses + 1
			end
			remove_passengers(mission.group)
			mission:Remove()
			missions[ref] = nil
		end
	end
end

local onShipUndocked = function (player, station)
	if not player:IsPlayer() then return end
	local current_passengers = Game.player:GetEquipCount('CABIN', 'PASSENGER_CABIN')
	if current_passengers >= passengers then return end

	for ref,mission in pairs(missions) do
		remove_passengers(mission.group)

		Comms.ImportantMessage(l.HEY_YOU_ARE_GOING_TO_PAY_FOR_THIS, mission.client.name)
		mission:Remove()
		missions[ref] = nil
	end
end

local loaded_data
local onGameStart = function ()
	ads = {}
	missions = {}
	passengers = 0
	if loaded_data then
		for k,ad in pairs(loaded_data.ads) do
			ads[ad.station:AddAdvert({
				description = ad.desc,
				icon        = ad.risk > 0 and "taxi_danger" or "taxi",
				onChat      = onChat,
				onDelete    = onDelete})] = ad
		end
		missions = loaded_data.missions
		passengers = loaded_data.passengers
		loaded_data = nil
	end
end


local onClick = function (mission)
	local dist = Game.system and string.format("%.2f", Game.system:DistanceTo(mission.location)) or "hyper "
	return ui:Grid(2,1)
		:SetColumn(0,{ui:VBox(10):PackEnd({ui:MultiLineText((taxi_flavours[mission.flavour].introtext):interp({
														name     = mission.client.name,
														starport = mission.location:GetSystemBody().name,
														system   = mission.location:GetStarSystem().name,
														sectorx  = mission.location.sectorX,
														sectory  = mission.location.sectorY,
														sectorz  = mission.location.sectorZ,
														cash     = showCurrency(mission.reward),
														dist     = dist})
										),
										"",
										ui:Grid(2,1)
											:SetColumn(0, {
												ui:VBox():PackEnd({
--													ui:Label(l.SPACEPORT)
													ui:Label(l.FROM)
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
--													ui:Label(l.SYSTEM)
													ui:Label(l.TO)
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
													ui:Label(l.GROUP_DETAILS)
												})
											})
											:SetColumn(1, {
												ui:VBox():PackEnd({
													ui:MultiLineText(string.interp(taxi_flavours[mission.flavour].howmany, {group = mission.group}))
												})
											}),
										ui:Grid(2,1)
											:SetColumn(0, {
												ui:VBox():PackEnd({
													ui:Label(l.DEADLINE)
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
													ui:Label(l.DANGER)
												})
											})
											:SetColumn(1, {
												ui:VBox():PackEnd({
													ui:MultiLineText(taxi_flavours[mission.flavour].danger)
												})
											}),
										"",
										ui:Grid(2,1)
											:SetColumn(0, {
												ui:VBox():PackEnd({
													ui:Label(l.DISTANCE)
												})
											})
											:SetColumn(1, {
												ui:VBox():PackEnd({
													ui:Label(dist.." "..l.LY)
												})
											}),
		})})
		:SetColumn(1, {
			ui:VBox(10):PackEnd(InfoFace.New(mission.client))
		})
end

local serialize = function ()
	return { ads = ads, missions = missions, passengers = passengers }
end

local unserialize = function (data)
	loaded_data = data
end

Event.Register("onCreateBB", onCreateBB)
Event.Register("onUpdateBB", onUpdateBB)
Event.Register("onFrameChanged", onFrameChanged)
Event.Register("onShipUndocked", onShipUndocked)
Event.Register("onShipDocked", onShipDocked)
Event.Register("onGameStart", onGameStart)

Mission.RegisterType('Taxi',l.TAXI,onClick)

Serializer:Register("Taxi", serialize, unserialize)
