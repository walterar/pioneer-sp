-- Copyright © 2008-2016 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt
-- modified for Pioneer Scout+ (c)2012-2015 by walterar <walterar2@gmail.com>
-- Work in progress.

local Lang       = import("Lang")
local Engine     = import("Engine")
local Game       = import("Game")
local Space      = import("Space")
local StarSystem = import("StarSystem")
local Comms      = import("Comms")
local Event      = import("Event")
local Mission    = import("Mission")
local Format     = import("Format")
local Serializer = import("Serializer")
local Character  = import("Character")
local ShipDef    = import("ShipDef")
local Ship       = import("Ship")
local eq         = import("Equipment")
local utils      = import("utils")
local Timer      = import("Timer")
local Music      = import("Music")

local MsgBox   = import("ui/MessageBox")
local InfoFace = import("ui/InfoFace")
local SLButton = import("ui/SmallLabeledButton")

-- Get the language resource
local l  = Lang.GetResource("module-taxi") or Lang.GetResource("module-taxi","en")
local lm = Lang.GetResource("miscellaneous") or Lang.GetResource("miscellaneous","en")

-- Get the UI class
local ui = Engine.ui

-- don't produce missions for further than this many light years away
local max_taxi_dist = 30
-- max number of passengers per trip
local max_group = 10

local num_corporations = 12
local num_pirate_taunts = 4

local target_distance_from_entry = 0

local flavours = {
	{
		single = false,-- flavour 0
		urgency = 0,
		risk = 0
	}, {
		single = false,-- flavour 1
		urgency = 0,
		risk = 0
	}, {
		single = false,-- flavour 2
		urgency = 0,
		risk = 0
	}, {
		single = true,-- flavour 3
		urgency = 0.13,
		risk = 1
	}, {
		single = true,-- flavour 4
		urgency = 0.3,
		risk = 0
	}, {
		single = true,-- flavour 5
		urgency = 0.1,
		risk = 0
	}, {
		single = true,-- flavour 6
		urgency = 0.02,
		risk = 0
	}, {
		single = true,-- flavour 7
		urgency = 0.15,
		risk = 3
	}, {
		single = true,-- flavour 8
		urgency = 0.6,
		risk = 0
	}, {
		single = true,-- flavour 9
		urgency = 0.85,
		risk = 2
	}, {
		single = true,-- flavour 10
		urgency = 0.9,
		risk = 2
	}, {
		single = true,-- flavour 11
		urgency = 1,
		risk = 1
	}, {
		single = true,-- flavour 12
		urgency = 0,
		risk = 2
	}
}

-- add strings to flavours
for i = 1,#flavours do
	local f = flavours[i]
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

local Exists = function (ship)
	local exists = false
	if ship:exists() then
		exists = true
	end
	return exists
end
local ShipExists = function (ship)
	if ship then
		ok,val = pcall(Exists, ship)
		if ok then
			return val
		else
			return false
		end
	end
end

local add_passengers = function (group)
	Game.player:RemoveEquip(eq.misc.cabin,  group)
	Game.player:AddEquip(eq.misc.cabin_occupied, group)
	passengers = passengers + group
end

local remove_passengers = function (group)
	Game.player:RemoveEquip(eq.misc.cabin_occupied,  group)
	Game.player:AddEquip(eq.misc.cabin, group)
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

		local introtext = string.interp(flavours[ad.flavour].introtext, {
			name     = ad.client.name,
			cash     = showCurrency(ad.reward),
			starport = ad.location:GetSystemBody().name,
			system   = ad.location:GetStarSystem().name,
			sectorx  = ad.location.sectorX,
			sectory  = ad.location.sectorY,
			sectorz  = ad.location.sectorZ,
			dist     = ad.dist
		})

		form:SetMessage(introtext)

	elseif option == 1 then
		local corporation = l["CORPORATIONS_"..Engine.rand:Integer(0,num_corporations-1)]
		local whysomuch = string.interp(flavours[ad.flavour].whysomuch, {
			corp     = corporation
		})

		form:SetMessage(whysomuch)

	elseif option == 2 then
		local howmany = string.interp(flavours[ad.flavour].howmany, {
			group = ad.group
		})

		form:SetMessage(howmany)

	elseif option == 3 then
		if (MissionsSuccesses - MissionsFailures < 5) and ad.risk > 0 then
			form:SetMessage(lm.HAVE_ENOUGH_EXPERIENCE)
			return
		end
		if not Game.player.cabin_cap or Game.player.cabin_cap < ad.group then
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
			date     = ad.date,
			due      = ad.due,
			group    = ad.group,
			flavour  = ad.flavour
		}

		table.insert(missions,Mission.New(mission))

		if NavAssist and Game.system.path ~= mission.location:GetStarSystem().path then
			Game.player:SetHyperspaceTarget(mission.location:GetStarSystem().path)
		end

		form:SetMessage(l.EXCELLENT)
		switchEvents()
		return
	elseif option == 4 then
		if flavours[ad.flavour].single then
			form:SetMessage(l.I_MUST_BE_THERE_BEFORE..Format.Date(ad.due).."\n*\n*")
		else
			form:SetMessage(l.WE_WANT_TO_BE_THERE_BEFORE..Format.Date(ad.due).."\n*\n*")
		end

	elseif option == 5 then
		form:SetMessage(flavours[ad.flavour].danger)
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


local makeAdvert = function (station)
	local reward, due, location
	local flavour = Engine.rand:Integer(1,#flavours)
	if _nearbystationsRemotes and #_nearbystationsRemotes > 0 then
		location = _nearbystationsRemotes[Engine.rand:Integer(1,#_nearbystationsRemotes)]
	end
	if location == nil then return end

	local client  = Character.New()
	local urgency = flavours[flavour].urgency
	local risk    = flavours[flavour].risk
	local group   = 1
	if flavours[flavour].single == false then
		group = Engine.rand:Integer(2,max_group)
	end

	local dist = location:DistanceTo(Game.system)
	local taxiplus = 1.8
	if group > 1 then taxiplus = (taxiplus*group)-1 end
	reward = tariff (dist,risk,urgency,location) * taxiplus
	due    = _remote_due(dist,urgency,false)

	local dist_txt = _distTxt(location)

	local ad = {
		station  = station,
		flavour  = flavour,
		client   = client,
		location = location,
		dist     = dist_txt,
		date     = Game.time,
		due      = due,
		group    = group,
		risk     = risk,
		urgency  = urgency,
		reward   = reward,
		faceseed = Engine.rand:Integer()
	}

	ad.desc = string.interp(flavours[flavour].adtext, {
		starport = ad.location:GetSystemBody().name,
		system   = ad.location:GetStarSystem().name,
		cash     = showCurrency(ad.reward)
	})
	ads[station:AddAdvert({
		description = ad.desc,
		icon        = ad.risk > 0 and "taxi_danger" or "taxi",
		onChat      = onChat,
		onDelete    = onDelete})] = ad
end

local onCreateBB = function (station)
	for i = 1,Engine.rand:Integer(Engine.rand:Integer(0,_maxAdv),_maxAdv) do
		makeAdvert(station)
	end
end

local onUpdateBB = function (station)
	local num = 0--Engine.rand:Integer(1)-- 50% of the time, give away 1
	local timeout = 24*60*60 -- default 1 day timeout for inter-system
	for ref,ad in pairs(ads) do
		if ad.station == station then
--			if flavours[ad.flavour].localdelivery then timeout = 60*60 end -- 1 hour timeout for locals
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

	local hostilactive = false
local onFrameChanged = function (body)
	if hostilactive then return end
	if body:isa("Ship") and body:IsPlayer() and body.frameBody ~= nil then
		for ref,mission in pairs(missions) do
			local risk = flavours[mission.flavour].risk
			if risk < 1 then return end
			if mission.status == "ACTIVE" and mission.location:IsSameSystem(Game.system.path) then
				local target_distance_from_entry = body:DistanceTo(Space.GetBody(mission.location.bodyIndex))
				if target_distance_from_entry > 500000e3 then return end
				Timer:CallEvery(3, function ()
					if hostilactive then return true end
					if body:DistanceTo(Space.GetBody(mission.location.bodyIndex)) > 100000e3 then return false end
					ship = ship_hostil(risk)
					if ShipExists(ship) then
						hostilactive = true
						local hostile_greeting = string.interp(
									l["PIRATE_TAUNTS_"..Engine.rand:Integer(1,num_pirate_taunts)-1],
										{client = mission.client.name})
						Comms.ImportantMessage(hostile_greeting, ship.label)
						Music.Play("music/core/fx/escalating-danger",false)
						return true
					else
						return true
					end
				end)
			end
			if mission.status == "ACTIVE" and Game.time > mission.due then
				mission.status = 'FAILED'
				Comms.ImportantMessage(flavours[mission.flavour].wherearewe, mission.client.name)
			end
		end
	end
end

local onShipDocked = function (player, station)
	if not player:IsPlayer() then return end
	hostilactive = false
	for ref,mission in pairs(missions) do
		if mission.location == station.path or mission.status == 'FAILED' then
			if Game.time > mission.due then
				Comms.ImportantMessage(flavours[mission.flavour].failuremsg, mission.client.name)
				_G.MissionsFailures = MissionsFailures + 1
				check_crime(mission,"ABDUCTION")
			else
				Comms.ImportantMessage(flavours[mission.flavour].successmsg, mission.client.name)
				player:AddMoney(mission.reward)
				_G.MissionsSuccesses = MissionsSuccesses + 1
			end
			remove_passengers(mission.group)
			mission:Remove()
			missions[ref] = nil
		end
	end
	switchEvents()
end

local onShipLanded = function (player, body)
	if not player:IsPlayer() then return end
	hostilactive = false
	for ref,mission in pairs(missions) do
		if mission.location == player:FindNearestTo("SPACESTATION").path or mission.status == 'FAILED' then
			if Game.time > mission.due or mission.status == 'FAILED' then
				Comms.ImportantMessage(flavours[mission.flavour].failuremsg, mission.client.name)
				_G.MissionsFailures = MissionsFailures + 1
				check_crime(mission,"ABDUCTION")
			else
				Comms.ImportantMessage(flavours[mission.flavour].successmsg, mission.client.name)
				player:AddMoney(mission.reward)
				_G.MissionsSuccesses = MissionsSuccesses + 1
			end
			remove_passengers(mission.group)
			mission:Remove()
			missions[ref] = nil
		end
	end
	switchEvents()
end

local onShipUndocked = function (player, station)
	if not player:IsPlayer() then return end
	local current_passengers = Game.player:GetEquipCountOccupied("cabin")-(Game.player.cabin_cap or 0)
	if current_passengers >= passengers then return end -- nothing changed, good
	for ref,mission in pairs(missions) do
		remove_passengers(mission.group)
		_G.MissionsFailures = MissionsFailures + 1
		Comms.ImportantMessage(l.HEY_YOU_ARE_GOING_TO_PAY_FOR_THIS, mission.client.name)
		mission:Remove()
		missions[ref] = nil
	end
	switchEvents()
end

local onEnterSystem = function (ship)
	if not ship:IsPlayer() or not switchEvents() then return end
end

local loaded_data
local onGameStart = function ()
	ads = {}
	missions = {}
	passengers = 0
	if type(loaded_data) == "table" then
		for k,ad in pairs(loaded_data.ads) do
			ads[ad.station:AddAdvert({
				description = ad.desc,
				icon        = ad.risk > 0 and "taxi_danger" or "taxi",
				onChat      = onChat,
				onDelete    = onDelete})] = ad
		end
		missions     = loaded_data.missions
		passengers   = loaded_data.passengers
		hostilactive = loaded_data.hostilactive
		switchEvents()
		loaded_data = nil
	end
end


local onClick = function (mission)
--	local dist = Game.system and string.format("%.2f", Game.system:DistanceTo(mission.location)) or "hyper "

	local dist_txt = _distTxt(mission.location)--,false)

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

	return ui:Grid({68,32},1)
		:SetColumn(0,{ui:VBox(10):PackEnd({ui:MultiLineText((flavours[mission.flavour].introtext):interp({
														name     = mission.client.name,
														starport = mission.location:GetSystemBody().name,
														system   = mission.location:GetStarSystem().name,
														sectorx  = mission.location.sectorX,
														sectory  = mission.location.sectorY,
														sectorz  = mission.location.sectorZ,
														cash     = showCurrency(mission.reward),
														dist     = dist_txt})
										),
										ui:Margin(10),
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
													ui:MultiLineText(string.interp(flavours[mission.flavour].howmany, {group = mission.group}))
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
													ui:MultiLineText(flavours[mission.flavour].danger)
												})
											}),
										ui:Margin(5),
										ui:Grid(2,1)
											:SetColumn(0, {
												ui:VBox():PackEnd({
													ui:Label(l.DISTANCE)
												})
											})
											:SetColumn(1, {
												ui:VBox():PackEnd({
													ui:Label(dist_txt),
													"",
													setTargetButton.widget
												})
											})
		})})
		:SetColumn(1, {
			ui:VBox(10):PackEnd(InfoFace.New(mission.client))
		})
end

local serialize = function ()
	return
		{
		ads          = ads,
		missions     = missions,
		passengers   = passengers,
		hostilactive = hostilactive,
		}
end

local unserialize = function (data)
	loaded_data = data
end

switchEvents = function()
	local status = false
--print("Taxi Events deactivated")
	Event.Deregister("onFrameChanged", onFrameChanged)
	Event.Deregister("onShipDocked", onShipDocked)
	Event.Deregister("onShipUndocked", onShipUndocked)
	Event.Deregister("onShipLanded", onShipLanded)
	for ref,mission in pairs(missions) do
		if Game.time > mission.due or mission.location:IsSameSystem(Game.system.path) then
--print("Taxi Events activate")
			Event.Register("onFrameChanged", onFrameChanged)
			Event.Register("onShipDocked", onShipDocked)
			Event.Register("onShipUndocked", onShipUndocked)
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

Mission.RegisterType('Taxi',l.TAXI,onClick)

Serializer:Register("Taxi", serialize, unserialize)
