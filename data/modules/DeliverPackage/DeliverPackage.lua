-- Copyright © 2008-2014 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt
-- modified for Pioneer Scout+ (c)2013 by walterar <walterar2@gmail.com>
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
local InfoFace   = import("ui/InfoFace")

local l   = Lang.GetResource("module-deliverpackage")
local myl = Lang.GetResource("module-myl") or Lang.GetResource("module-myl","en")

-- Get the UI class
local ui = Engine.ui

-- don't produce missions for further than this many light years away
local max_delivery_dist = 30

local AU = 149600000000

local num_pirate_taunts = 10

local flavours = {
	{
		urgency       = 0,-- 0
		risk          = 0,
		localdelivery = false,
	}, {
		urgency       = 0.1,-- 1
		risk          = 2,
		localdelivery = false,
	}, {
		urgency       = 0.6,-- 2
		risk          = 1,
		localdelivery = false,
	}, {
		urgency       = 0.4,-- 3
		risk          = 3,
		localdelivery = false,
	}, {
		urgency       = 0.1,-- 4
		risk          = 0,
		localdelivery = false,
	}, {
		urgency       = 0.1,-- 5
		risk          = 0,
		localdelivery = true,
	}, {
		urgency       = 0.2,-- 6
		risk          = 0,
		localdelivery = true,
	}, {
		urgency       = 0.4,-- 7
		risk          = 0,
		localdelivery = true,
	}, {
		urgency       = 0.6,-- 8
		risk          = 0,
		localdelivery = true,
	}, {
		urgency       = 0.8,-- 9
		risk          = 0,
		localdelivery = true,
	}
}

-- add strings to flavours
for i = 1,#flavours do
	local f = flavours[i]
	f.adtext        = l["FLAVOUR_" .. i-1 .. "_ADTEXT"]
	f.introtext     = l["FLAVOUR_" .. i-1 .. "_INTROTEXT"]
	f.whysomuchtext = l["FLAVOUR_" .. i-1 .. "_WHYSOMUCHTEXT"]
	f.successmsg    = l["FLAVOUR_" .. i-1 .. "_SUCCESSMSG"]
	f.failuremsg    = l["FLAVOUR_" .. i-1 .. "_FAILUREMSG"]
end

local ads = {}
local missions = {}

local onChat = function (form, ref, option)
	local ad = ads[ref]

	form:Clear()

	if option == -1 then
		form:Close()
		return
	end

	if option == 0 then
		form:SetFace(ad.client)

		local sys   = ad.location:GetStarSystem()
		local sbody = ad.location:GetSystemBody()

		local introtext = string.interp(flavours[ad.flavour].introtext, {
			name     = ad.client.name,
			cash     = format_num(ad.reward, 2, "$", "-"),
			starport = sbody.name,
			system   = sys.name,
			sectorx  = ad.location.sectorX,
			sectory  = ad.location.sectorY,
			sectorz  = ad.location.sectorZ,
			dist     = string.format("%.2f", ad.dist),
		})

		form:SetMessage(introtext)

	elseif option == 1 then
		form:SetMessage(flavours[ad.flavour].whysomuchtext)

	elseif option == 2 then
		form:SetMessage(l.IT_MUST_BE_DELIVERED_BY..Format.Date(ad.due))

	elseif option == 4 then

		if ad.risk == 0 and Engine.rand:Integer(1) == 0 then
			form:SetMessage(l.I_HIGHLY_DOUBT_IT)
		elseif ad.risk == 0 then
			form:SetMessage(l.NOT_ANY_MORE_THAN_USUAL)
		end
		if ad.risk == 1 then
			form:SetMessage(l.THIS_IS_A_VALUABLE_PACKAGE_YOU_SHOULD_KEEP_YOUR_EYES_OPEN)
		elseif ad.risk == 2 then
			form:SetMessage(l.IT_COULD_BE_DANGEROUS_YOU_SHOULD_MAKE_SURE_YOURE_ADEQUATELY_PREPARED)
		elseif ad.risk == 3 then
			form:SetMessage(l.THIS_IS_VERY_RISKY_YOU_WILL_ALMOST_CERTAINLY_RUN_INTO_RESISTANCE)
		end

	elseif option == 3 then
		if (MissionsSuccesses - MissionsFailures < 5) and ad.risk > 0 then
			form:SetMessage(myl.have_enough_experience)
			return
		end
		form:RemoveAdvertOnClose()

		ads[ref] = nil

		local mission = {
			type     = "Delivery",
			client   = ad.client,
			location = ad.location,
			risk     = ad.risk,
			reward   = ad.reward,
			due      = ad.due,
			flavour  = ad.flavour
		}

		table.insert(missions,Mission.New(mission))
		Game.player:SetHyperspaceTarget(mission.location:GetStarSystem().path)

		form:SetMessage(l.EXCELLENT_I_WILL_LET_THE_RECIPIENT_KNOW_YOU_ARE_ON_YOUR_WAY)

		return
	end

	form:AddOption(l.WHY_SO_MUCH_MONEY, 1)
	form:AddOption(l.HOW_SOON_MUST_IT_BE_DELIVERED, 2)
	form:AddOption(l.WILL_I_BE_IN_ANY_DANGER, 4)
	form:AddOption(l.COULD_YOU_REPEAT_THE_ORIGINAL_REQUEST, 0)
	form:AddOption(l.OK_AGREED, 3)
end

local onDelete = function (ref)
	ads[ref] = nil
end

local makeAdvert = function (station)
	local reward, due, location, dist
	local client = Character.New()
	local flavour = Engine.rand:Integer(1,#flavours)
	local urgency = flavours[flavour].urgency
	local risk = flavours[flavour].risk

	if flavours[flavour].localdelivery == true then
		local nearbystations = Game.system:GetStationPaths()
		location = nearbystations[Engine.rand:Integer(1,#nearbystations)]
		if location == station.path then return end
		local locdist = Space.GetBody(location.bodyIndex)
		dist = station:DistanceTo(locdist)
		if dist < 1000 then return end
		reward = 150 + (math.sqrt(dist) / 15000) * (1+urgency)
		due = Game.time + ((4*24*60*60) * (Engine.rand:Number(1.5,3.5) - urgency))
	else
		local nearbystations = StarSystem:GetNearbyStationPaths(max_delivery_dist, nil,function (s) return
			(s.type ~= 'STARPORT_SURFACE') or (s.parent.type ~= 'PLANET_ASTEROID') end)
		location = nil
		location = nearbystations[Engine.rand:Integer(1,#nearbystations)]
		if location == nil then return end
		dist = location:DistanceTo(Game.system)
		reward = tariff(dist,risk,urgency,location)
		due = term(dist,urgency)
	end

	local ad = {
		station  = station,
		flavour  = flavour,
		client   = client,
		location = location,
		dist     = dist,
		due      = due,
		risk     = risk,
		urgency  = urgency,
		reward   = reward,
		isfemale = isfemale,
		faceseed = Engine.rand:Integer(),
	}

	ad.desc = string.interp(flavours[flavour].adtext, {
		starport = ad.location:GetSystemBody().name,
		system   = ad.location:GetStarSystem().name,
		cash     = format_num(ad.reward, 2, "$", "-"),
	})
	ads[station:AddAdvert({
		description = ad.desc,
		icon        = ad.risk > 0 and "delivery_danger" or "delivery",
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
		if flavours[ad.flavour].localdelivery == false
			and ad.due < Game.time + 5*60*60*24 then -- five day timeout for inter-system
			ad.station:RemoveAdvert(ref)
		elseif flavours[ad.flavour].localdelivery == true
			and ad.due < Game.time + 2*60*60*24 then -- two day timeout for locals
			ad.station:RemoveAdvert(ref)
		end
	end
	if Engine.rand:Integer(12*60*60) < 60*60 then -- roughly once every twelve hours
		makeAdvert(station)
	end
end

local hostilactive = 0
local onFrameChanged = function (body)
	if body:isa("Ship") and body:IsPlayer() and body.frameBody ~= nil then
		local syspath = Game.system.path
		for ref,mission in pairs(missions) do
			if mission.status == "ACTIVE" and mission.location:IsSameSystem(syspath) then
				local target_distance_from_entry = body:DistanceTo(Space.GetBody(mission.location.bodyIndex))
				if target_distance_from_entry > AU/1000 then return end
				local risk = flavours[mission.flavour].risk
				if risk > 0 and hostilactive == 0 then ship = ship_hostil(risk) end
				if ship and hostilactive == 0 then
					hostilactive = 1
					local hostile_greeting = string.interp(l["PIRATE_TAUNTS_"..Engine.rand:Integer(1,num_pirate_taunts)-1], {
								client = mission.client.name, location = mission.location:GetSystemBody().name,})
					Comms.ImportantMessage(hostile_greeting, ship.label)
				end
			end
			if mission.status == "ACTIVE" and Game.time > mission.due then
				mission.status = 'FAILED'
			end
		end
	end
end

local onShipDocked = function (player, station)
	if not player:IsPlayer() then return end
	for ref,mission in pairs(missions) do
		if mission.location == station.path then
			if Game.time > mission.due then
				Comms.ImportantMessage(flavours[mission.flavour].failuremsg, mission.client.name)
				_G.MissionsFailures = MissionsFailures + 1
			else
				Comms.ImportantMessage(flavours[mission.flavour].successmsg, mission.client.name)
				_G.MissionsSuccesses = MissionsSuccesses + 1
				player:AddMoney(mission.reward)
			end
			mission:Remove()
			missions[ref] = nil
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
				icon        = ad.risk > 0 and "delivery_danger" or "delivery",
				onChat      = onChat,
				onDelete    = onDelete})] = ad
		end
		missions = loaded_data.missions
		loaded_data = nil
	end
end

local onClick = function (mission)

	local dist = Game.system and string.format("%.2f", Game.system:DistanceTo(mission.location)) or "zzz"
	local danger
	if mission.risk == 0 then
		if Engine.rand:Integer(1) == 0 then
			danger = (l.I_HIGHLY_DOUBT_IT)
		else
			danger = (l.NOT_ANY_MORE_THAN_USUAL)
		end
	elseif mission.risk == 1 then
		danger = (l.THIS_IS_A_VALUABLE_PACKAGE_YOU_SHOULD_KEEP_YOUR_EYES_OPEN)
	elseif mission.risk == 2 then
		danger = (l.IT_COULD_BE_DANGEROUS_YOU_SHOULD_MAKE_SURE_YOURE_ADEQUATELY_PREPARED)
	elseif mission.risk == 3 then
		danger = (l.THIS_IS_VERY_RISKY_YOU_WILL_ALMOST_CERTAINLY_RUN_INTO_RESISTANCE)
	end

	return ui:Grid(2,1)
		:SetColumn(0,{ui:VBox(10):PackEnd({ui:MultiLineText((flavours[mission.flavour].introtext):interp({
														name     = mission.client.name,
														starport = mission.location:GetSystemBody().name,
														system   = mission.location:GetStarSystem().name,
														sectorx  = mission.location.sectorX,
														sectory  = mission.location.sectorY,
														sectorz  = mission.location.sectorZ,
														cash     = format_num(mission.reward, 2, "$", "-"),
														dist     = dist})
										),
										ui:Margin(10),
										ui:Grid(2,1)
											:SetColumn(0, {
												ui:VBox():PackEnd({
													ui:Label(l.SPACEPORT)
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
													ui:Label(l.SYSTEM)
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
													ui:MultiLineText(danger)
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
													ui:Label(dist.." "..l.LY)
												})
											}),
		})})
		:SetColumn(1, {
			ui:VBox(10):PackEnd(InfoFace.New(mission.client))
		})
end

local serialize = function ()
	return
		{ ads      = ads,
			missions = missions
		}
end

local unserialize = function (data)
	loaded_data = data
end

Event.Register("onCreateBB", onCreateBB)
Event.Register("onUpdateBB", onUpdateBB)
Event.Register("onFrameChanged", onFrameChanged)
Event.Register("onShipDocked", onShipDocked)
Event.Register("onGameStart", onGameStart)

Mission.RegisterType('Delivery',l.DELIVERY,onClick)

Serializer:Register("DeliverPackage", serialize, unserialize)
