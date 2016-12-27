-- SearchRescue.lua Author Claudius Mueller 2015-2016  Copyright © 2008-2016 Pioneer Developers.
-- Modified and renamed to sar.lua for Pioneer Scout Plus by Walter Arnolfo <walterar2@gmail.com>
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt
-- Work in progress.

local Engine     = import("Engine")
local Lang       = import("Lang")
local Game       = import("Game")
local Space      = import("Space")
local Comms      = import("Comms")
local Event      = import("Event")
local Mission    = import("Mission")
local Music      = import("Music")
local Format     = import("Format")
local Serializer = import("Serializer")
local Character  = import("Character")
local Eq         = import("Equipment")
local ShipDef    = import("ShipDef")
local Ship       = import("Ship")
local StarSystem = import("StarSystem")
local utils      = import("utils")
local Timer      = import("Timer")

local MsgBox   = import("ui/MessageBox")
local SLButton = import("ui/SmallLabeledButton")
local InfoFace = import("ui/InfoFace")

local ls = Lang.GetResource("module-sar") or Lang.GetResource("module-sar","en")
local lx = Lang.GetResource("module-sar-xtras") or Lang.GetResource("module-sar-xtras","en")
local lm = Lang.GetResource("miscellaneous") or Lang.GetResource("miscellaneous","en")

local ui = Engine.ui

-- basic variables for mission creation
local max_mission_dist =   15-- Ly max radius distance for remote missions target location

local min_close_dist   =  200--Km min to max distance for local missions on "THIS_PLANET"
local max_close_dist   = 1000--Km

local max_interaction_dist    = 50 -- [meters] 0 to max distance for successful interaction with target
local target_interaction_time =  5 -- [sec] interaction time to load/unload one unit of cargo/person

local AU = 149597870700
local beacon_receiver_range = AU/2

-- global containers and variables
local aircontrol_chars = {}    -- saving specific aircontrol character per spacestation
local ads              = {}    -- currently active ads in the system
local missions         = {}    -- accepted missions that are currently active

local cargo_item = function()
	local item
	local sel = Engine.rand:Integer(0,1)
	if sel == 0 then
		item = "military_fuel"
	else
		item = "hydrogen"
	end
	return item
end

local shipsAvail = function ()
 return utils.build_array(utils.filter(function (k,def)
		return def.tag == 'SHIP'
--			and def.manufacturer == 'p66'
--			and def.manufacturer == 'albr'
--			and def.manufacturer == 'mandarava_csepel'
--			and def.manufacturer == 'haber'
--			and def.manufacturer == 'kaluri'
			and def.hyperdriveClass > 0
			and def.hyperdriveClass < 8
			and def.equipSlotCapacity.atmo_shield > 0
			and def.capacity > 29
			and def.capacity < 501
			and def.equipSlotCapacity.cabin > 0
			and def.maxCrew > 1
	end, pairs(ShipDef)))
end

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

local StopAction = function (mission)
	local action = true
	if ShipExists(mission.target)
		and Game.system
		and mission.target.flightState ~= "HYPERSPACE" then
		action = false
	end
	return action
end

local urgency_set = function()
	return Engine.rand:Number(1)
end

local risk_set = function()
	return Engine.rand:Integer(0,3)
end

local StrToObj = function (item,slot)
-- Convert equipment reference String To Object
-- rem: type = "nil" "number", "string", "boolean,
-- "table", "function", "thread" or "userdata".
	if type(item) == "string" then
		local item = string.lower (item)
		local slot = slot or Eq.cargo
		for name,obj in pairs(slot) do
			if type(obj) == "table" and name == item then
			return obj
			end
		end
	end
end

local flavours = {

-- Rescatar tripulación y/o pasajeros de una nave accidentada en planeta local
-- ESPECIAL: número de tripulantes/pasajeros a recojer es aleatorio
	{
		id               = 1,-- local pickUp
		loctype          = "LOCAL_PLANET",--"NAVE ACCIDENTADA en la superficie de {planet}." local pickUp
		pickup_crew      = 1,
		pickup_pass      = 1,
		deliver_crew     = 0,
		deliver_pass     = 0,
		deliver_item     = nil,
		urgency          = urgency_set(),
		risk             = 0,
		reward_immediate = false-- retorna
	},

-- Suministrar propelente a la nave varada en superficie cerca de "esta" estación
	{
		id               = 2,
		loctype          = "THIS_PLANET",--"NAVE SIN PROPELENTE en ruta a {starport}."
		pickup_crew      = 0,
		pickup_pass      = 0,
		deliver_crew     = 0,
		deliver_pass     = 0,
		deliver_item     = "hydrogen",
		urgency          = urgency_set(),
		risk             = 0,
		reward_immediate = true
	},

	-- Transportar 1 tripulante (Piloto) a la nave encallada cerca de Starport
	{
		id               = 3,
		loctype          = "THIS_PLANET",--"EMERGENCIA MÉDICA en nave cercana a {starport}."
		pickup_crew      = 0,
		pickup_pass      = 0,
		deliver_crew     = 1,
		deliver_pass     = 0,
		deliver_item     = nil,
		urgency          = urgency_set(),
		risk             = 0,
		reward_immediate = true
	},

	-- suministrar propelente a una la nave varada en un planeta local
	{
		id               = 4,
		loctype          = "LOCAL_PLANET",--"NAVE SIN PROPELENTE en {planet}."
		pickup_crew      = 0,
		pickup_pass      = 0,
		deliver_crew     = 0,
		deliver_pass     = 0,
		deliver_item     = "hydrogen",
		urgency          = urgency_set(),
		risk             = 0,
		reward_immediate = true
	},

	-- Suministrar propelente a una nave en órbita del planeta de "esta" estación
	{
		id               = 5,
		loctype          = "LOCAL_SPACE",--"NAVE SIN PROPELENTE sobre {starport}."
		pickup_crew      = 0,
		pickup_pass      = 0,
		deliver_crew     = 0,
		deliver_pass     = 0,
		deliver_item     = "hydrogen",
		urgency          = urgency_set(),
		risk             = 0,
		reward_immediate = true
	},

	-- rescue all crew + passengers from ship stranded in unoccupied system
	-- SPECIAL: number of crew/pass to pickup is picked randomly during ad creation
	-- Rescate de tripulación y/o pasajeros de una nave varada en planeta de sistema inhabitado
	-- ESPECIAL: número de tripulantes/pasajeros a recojer es aleatorio
	{
		id               = 6,
		loctype          = "REMOTE_PLANET",--"NAVE PERDIDA en sistema {system}."
		pickup_crew      = 1,
		pickup_pass      = 1,
		deliver_crew     = 0,
		deliver_pass     = 0,
		deliver_item     = nil,
		urgency          = urgency_set(),
		risk             = "var",
		reward_immediate = false
	},

	-- take replacment crew to ship stranded in unoccupied system
	-- SPECIAL: number of crew to deliver is picked randomly during ad creation
	-- Transportar tripulación de reemplazo a una nave orbitando un planeta en sistema inhabitado max 15 ly
	-- ESPECIAL: número de tripulantes para entregar es escogido al azar durante la creación de anuncios
	{
		id               = 7,
		loctype          = "REMOTE_SPACE",--"TRANSPORTE DE TRIPULANTES URGENTE a sistema {system}."
		pickup_crew      = 0,
		pickup_pass      = 0,
		deliver_crew     = 1,
		deliver_pass     = 0,
		deliver_item     = nil,
		urgency          = 1,
		risk             = risk_set(),
		reward_immediate = true
	},

	-- Suministrar combustible (higrógeno o militar) a una nave en órbita de planeta en sistema remoto
	{
		id               = 8,
		loctype          = "REMOTE_SPACE",--"NAVE SIN COMBUSTIBLE en sistema {system} a {dist}."
		pickup_crew      = 0,
		pickup_pass      = 0,
		deliver_crew     = 0,
		deliver_pass     = 0,
		deliver_item     = "var",
		urgency          = urgency_set(),
		risk             = "var",
		reward_immediate = true
	}
}

-- add strings to flavours
for i = 1,#flavours do
	local f = flavours[i]
	f.adtext          = ls["FLAVOUR_" .. f.id .. "_ADTEXT"]
	f.introtext       = ls["FLAVOUR_" .. f.id .. "_INTROTEXT"]
--	f.whysomuchtext   = lx["FLAVOUR_" .. f.id .. "_WHYSOMUCHTEXT"]
	f.locationtext    = ls["FLAVOUR_" .. f.id .. "_LOCATIONTEXT"]
	f.typeofhelptext  = ls["FLAVOUR_" .. f.id .. "_TYPEOFHELPTEXT"]
	f.howmuchtimetext = ls["FLAVOUR_" .. f.id .. "_HOWMUCHTIMETEXT"]
	f.successmsg      = ls["FLAVOUR_" .. f.id .. "_SUCCESSMSG"]
	f.failuremsg      = ls["FLAVOUR_" .. f.id .. "_FAILUREMSG"]
	f.transfermsg     = ls["FLAVOUR_" .. f.id .. "_TRANSFERMSG"]
end

local containerContainsKey = function (container, key)
-- Return true if key is in container and false if not.
	return container[key] ~= nil
end

local removeMission = function (mission)
	local ref, cabins
	for i,v in pairs(missions) do
		if v == mission then
			cabins = mission.pickup_pass_orig + mission.pickup_crew_orig
			if cabins > 0 and mission.status == 'TRIP_BACK' then
				Game.player:RemoveEquip(Eq.misc.cabin_occupied, cabins)
				Game.player:AddEquip(Eq.misc.cabin, cabins)
			end
			ref = i
			break
		end
	end
	mission:Remove()
	if missions[ref] then missions[ref] = nil end--XXX
	switchEvents()
end


-- basic mission functions

-- This function returns the number of flavours of the given string str
-- It is assumed that the first flavour has suffix '_1'
local getNumberOfFlavours = function (str)
	-- Returns the number of flavours of the given string (assuming first flavour has suffix '_1').
	-- Taken from CargoRun.lua.
	local num = 1
	while ls[str .. "_" .. num] do
		num = num + 1
	end
	return num - 1
end

--local mToAU = function (meters)	-- Transform meters into AU.
--	return meters/149597870700
--end

local splitName = function (name)
	-- Splits the supplied name into first and last name and returns a table of both separately.
	-- Idea from http://stackoverflow.com/questions/2779700/lua-split-into-words.
	local names = {}
	for word in name:gmatch("%w+") do table.insert(names, word) end
	return names
end

local decToDegMinSec = function (coord_orig)
	-- Converts geographic coordinates from decimal to degree/minutes/seconds format
	-- and returns a string.
	local coord = math.abs(coord_orig)
	local degrees = math.floor(coord)
	local minutes = math.floor(60*(coord - degrees))
	local seconds = math.floor(3600 * ((coord - degrees) - minutes / 60))
	if coord_orig < 0 then degrees = degrees * -1 end
	local str = string.format("%i° %i' %i\"", degrees, minutes, seconds)
	return str
end

local getAircontrolChar = function (spacestation)
	-- Get the correct aircontrol character for the supplied spacestation. If it does not exist
	-- create one and store it.
	if containerContainsKey(aircontrol_chars, spacestation) then
		return aircontrol_chars[spacestation]
	else
		local char = Character.New()
		aircontrol_chars[spacestation] = char
		return char
	end
end

local randomLatLong = function (station)
	-- Provide a set of random latitude and longitude coordinates for ship placement that are:
	-- (a) random, within max_close_dist from starting base if base is provided, or
	-- (b) completely random.
	local lat, long, dist

	-- calc new lat/lon based on distance and bearing
	-- formulas taken from http://www.movable-type.co.uk/scripts/latlong.html
	if station then
		local old_lat, old_long = station:GetGroundPosition()
		local planet_radius = station.path:GetSystemBody().parent.radius / 1000
		local bearing = math.rad(Engine.rand:Number(0,360))

		dist = Engine.rand:Integer(min_close_dist,max_close_dist) -- min distance is 200 km--1 km XXX

		lat = math.asin(math.sin(old_lat) * math.cos(dist/planet_radius) + math.cos(old_lat) *
					math.sin(dist/planet_radius) * math.cos(bearing))
		long = old_long + math.atan2(math.sin(bearing) * math.sin(dist/planet_radius) * math.cos(old_lat),
					math.cos(dist/planet_radius) - math.sin(old_lat) * math.sin(lat))
	else
		lat = Engine.rand:Number(-90,90)
		lat = math.rad(lat)
		long = Engine.rand:Number(-180,180)
		long = math.rad(long)
	end
	return lat, long, dist
end

local passengersPresent = function (ship)
	-- Check if any passengers are present on the ship.
	if ship:CountEquip(Eq.misc.cabin_occupied) > 0 then return true end
end

local freeCabin = function (ship)-- Check if the ship has space for passengers.
	if ship:CountEquip(Eq.misc.cabin) > 0 then return true end
end

local cargoPresent = function (ship, item, load)-- Check if this cargo item is present on the ship.
	if ship:CountEquip(StrToObj(item,slot)) >= load then return true end
end

local cargoSpace = function (ship,load)-- Check if the ship has space for additional cargo.
	if ship:GetEquipFree('cargo') >= load then return true end
end

local addCrew = function (ship, crew_member)-- Add a crew member to the supplied ship.
	if ship:CrewNumber() == ship.maxCrew then return end
	if not crew_member then crew_member = Character.New() end
	ship:Enroll(crew_member)
end

local removeCrew = function (ship)-- Remove a crew member from the supplied ship.
	if ship:CrewNumber() == 0 then return end
	local crew_member
	for member in ship:EachCrewMember() do
		crew_member = member
		break
	end
	ship:Dismiss(crew_member)
	return crew_member
end

local addPassenger = function (ship)-- Add a passenger to the supplied ship.
	if not freeCabin(ship) then return end
	ship:RemoveEquip(Eq.misc.cabin, 1)
	ship:AddEquip(Eq.misc.cabin_occupied, 1)
end

local removePassenger = function (ship)-- Remove a passenger from the supplied ship.
	if not passengersPresent(ship) then return end
	ship:RemoveEquip(Eq.misc.cabin_occupied, 1)
	ship:AddEquip(Eq.misc.cabin, 1)
end

local createTargetShip = function (mission)
	local shipSelect
	for n=1,#shipsAvailable do
		if shipsAvailable[n].name == mission.shipTarget_name then
			shipSelect = shipsAvailable[n]
			break
		end
	end
	if not shipSelect then return false end

	-- spawn ship
	local ship, min, max
	local radius = mission.planet_target:GetSystemBody().radius/1000
	min = radius*1.4
	max = radius*1.5
	if mission.flavour.loctype == "THIS_PLANET" or mission.flavour.loctype == "LOCAL_PLANET"
	then-- en superficie de planeta local / Lat-Lon
		ship = Space.SpawnShipLanded(shipSelect.id,
			Space.GetBody(mission.planet_target.bodyIndex), mission.lat, mission.long)
	elseif mission.flavour.loctype == "LOCAL_SPACE" then-- orbitando planeta local
		ship = Space.SpawnShipNear(shipSelect.id,
			Space.GetBody(mission.station_target.bodyIndex), min, max)
		ship:AIFlyTo(ship:FindNearestTo('PLANET'))--XXX AIEnterLowOrbit no
	elseif Game.system.path == mission.system_target:GetStarSystem().path then
		if mission.flavour.loctype == "REMOTE_SPACE" then-- orbitando planeta remoto
			ship = Space.SpawnShipNear(shipSelect.id,
				Space.GetBody(mission.planet_target.bodyIndex), min, max)
			ship:AIFlyTo(ship:FindNearestTo('PLANET'))--XXX AIEnterLowOrbit no
		elseif mission.flavour.loctype == "REMOTE_PLANET" then-- en superficie de planeta remoto / Lat-Lon
			ship = Space.SpawnShipLanded(shipSelect.id,
				Space.GetBody(mission.planet_target.bodyIndex), mission.lat, mission.long)
		end
	end
	if not ship then return false end

	ship:SetLabel(mission.shiplabel)
	for _ = 1, mission.crew_num do
		ship:Enroll(Character.New())
	end

-- define and install hyperdrive and fuel
	local default_drive = shipSelect.hyperdriveClass
	if mission.deliver_item then
		if mission.deliver_item == 'military_fuel' then
			if default_drive > 4 then default_drive = 4 end
			ship:AddEquip(Eq.hyperspace['hyperdrive_mil'..tostring(default_drive)])
			ship:SetFuelPercent(50)--XXX
		else
			ship:AddEquip(Eq.hyperspace['hyperdrive_'..tostring(default_drive)])
			ship:SetFuelPercent(50)--XXX
		end
	else
		ship:AddEquip(Eq.hyperspace['hyperdrive_'..tostring(default_drive)])
		ship:AddEquip(Eq.cargo.hydrogen,default_drive*default_drive/2)
		ship:SetFuelPercent(50)
	end

	-- install laser
	local max_laser_size
	if default_drive then
		max_laser_size = (shipSelect.capacity - Eq.hyperspace['hyperdrive_'..
			tostring(default_drive)].capabilities.mass)
	else
		max_laser_size = shipSelect.capacity
	end
	local laserdefs = utils.build_array(utils.filter(function (k,l) return l:IsValidSlot('laser_front')
						and l.capabilities.mass <= max_laser_size
						and l.l10n_key:find("PULSECANNON") end, pairs(Eq.laser)))
	local laserdef = laserdefs[Engine.rand:Integer(1,#laserdefs)]
	ship:AddEquip(laserdef)

	-- install atmo_shield
	ship:AddEquip(Eq.misc.atmospheric_shielding)

	-- load passengers
	if mission.pickup_pass > 0 then
		ship:AddEquip(Eq.misc.cabin_occupied, mission.pickup_pass)
	end

	-- install shield_generator
	for i=1, mission.risk+1 do
		if Eq.misc.shield_generator.capabilities.mass < ship.freeCapacity then
			ship:AddEquip(Eq.misc.shield_generator, 1)
		else break
		end
	end

	if ShipExists(ship) then
		return ship
	else
		return false
	end
end

local onChat = function (form, ref, option)
	-- Ad has been clicked on in banter board.
	local ad = ads[ref]
	form:Clear()

	if option == -1 then
		form:Close()
		return
	end

	form:SetFace(ad.client)

	if option == 0 then
		local introtext = string.interp(ad.flavour.introtext, {
			name         = ad.client.name,
			entity       = ad.entity,
			problem      = ad.problem,
			cash         = Format.Money(ad.reward or 0),
			ship         = ad.shipTarget_name or "unknown",
			starport     = ad.station_orig:GetSystemBody().name,
			shiplabel    = ad.shiplabel,
			system       = ad.system_target:GetStarSystem().name,
			planet       = ad.planet_target:GetSystemBody().name
			})
		form:SetMessage(introtext)

--	elseif option == 1 then
--		form:SetMessage(ad.flavour.whysomuchtext)

	elseif option == 1 then

		local locationtext = string.interp(ad.flavour.locationtext, {
			starport     = ad.station_orig:GetSystemBody().name,
			shiplabel    = ad.shiplabel,
			system       = ad.system_target:GetStarSystem().name,
			sectorx      = ad.system_target.sectorX,
			sectory      = ad.system_target.sectorY,
			sectorz      = ad.system_target.sectorZ,
			dist         = _distTxt(ad.location),
			lat          = decToDegMinSec(math.rad2deg(ad.lat)),
			long         = decToDegMinSec(math.rad2deg(ad.long)),
			planet       = ad.planet_target:GetSystemBody().name
		})
		form:SetMessage(locationtext)

	elseif option == 2 then
		local cargo
		if ad.deliver_item then
			cargo = StrToObj(ad.deliver_item,slot):GetName()
		else
			cargo = lx.NONE
		end

		local typeofhelptext = string.interp(ad.flavour.typeofhelptext, {
			starport     = ad.station_orig:GetSystemBody().name,
			crew         = ad.crew_num,
			pass         = ad.pickup_pass,
			deliver_crew = ad.deliver_crew,
			load         = ad.quantity_cargo,
			cargo        = cargo
		})
		form:SetMessage(typeofhelptext)

	elseif option == 3 then
		local howmuchtimetext = string.interp(ad.flavour.howmuchtimetext, {due = Format.Date(ad.due)})
		form:SetMessage(howmuchtimetext)
--[[
	elseif option == 4 then
		if ad.risk == 0 and Engine.rand:Integer(1) == 0 then
			form:SetMessage(lx.I_HIGHLY_DOUBT_IT.."\n*\n*")
		elseif ad.risk == 0 then
			form:SetMessage(lx.NOT_ANY_MORE_THAN_USUAL.."\n*\n*")
		end
		if ad.risk == 1 then
			form:SetMessage(lx.YOU_SHOULD_KEEP_YOUR_EYES_OPEN.."\n*\n*")
		elseif ad.risk == 2 then
			form:SetMessage(lx.IT_COULD_BE_DANGEROUS.."\n*\n*")
		elseif ad.risk == 3 then
			form:SetMessage(lx.THIS_IS_VERY_RISKY.."\n*\n*")
		end
--]]
	elseif option == 4 then

		if (MissionsSuccesses - MissionsFailures) < 5 and ad.risk > 0 then
			form:SetMessage("\n* "..lx.have_enough_experience.."\n*\n*")
			return
		end

		local cabins = ad.pickup_crew+ad.deliver_crew+ad.pickup_pass+ad.deliver_pass or 0
		if cabins > Game.player:CountEquip(Eq.misc.cabin) then
			local denytext = string.interp(ls.EQUIPMENT,
								{unit = cabins,
						equipment = ls.UNOCCUPIED_PASSENGER_CABINS})
			form:SetMessage(denytext)
			return
		end

		if NavAssist then
			if Game.system.path ~= ad.system_target:GetStarSystem().path then
				Game.player:SetHyperspaceTarget(ad.system_target:GetStarSystem().path)
			end
		end
		form:RemoveAdvertOnClose()
		ads[ref] = nil

		local mission = {
-- these variables are hardcoded and need to be filled
			type     = "sar",
			client   = ad.client,
			location = ad.location,
			date     = ad.date,
			due      = ad.due,
			reward   = ad.reward,
			status   = "ACTIVE",

-- these variables are script specific
			station_orig       = ad.station_orig,
			planet_orig        = ad.planet_orig,
			system_orig        = ad.system_orig,
			station_target     = ad.station_target,
			planet_target      = ad.planet_target,
			system_target      = ad.system_target,
			entity             = ad.entity,
			problem            = ad.problem,
			dist               = ad.dist,
			risk               = ad.risk,
			flavour            = ad.flavour,
			target             = "uncreated",
			lat                = ad.lat,
			long               = ad.long,
			shipTarget_name    = ad.shipTarget_name,
			shiplabel          = ad.shiplabel,
			crew_num           = ad.crew_num,

			deliver_item       = ad.deliver_item,
			quantity_cargo     = ad.quantity_cargo,

-- "..._orig" => original variables from ad
			pickup_crew_orig   = ad.pickup_crew,
			pickup_pass_orig   = ad.pickup_pass,
			deliver_crew_orig  = ad.deliver_crew,
			deliver_pass_orig  = ad.deliver_pass,

-- variables are changed based on completion status
			pickup_crew        = ad.pickup_crew,
			pickup_pass        = ad.pickup_pass,
			deliver_crew       = ad.deliver_crew,
			deliver_pass       = ad.deliver_pass,

			pickup_crew_check  = "NOT",
			pickup_pass_check  = "NOT",
			deliver_crew_check = "NOT",
			deliver_pass_check = "NOT",
			deliv_cargo_check  = "NOT",
			cargo_pass         = {},
			searching          = false
		}

		-- create target ship if in the same systems, otherwise create when jumping there
		if mission.flavour.loctype ~= "REMOTE_SPACE" or mission.flavour.loctype ~= "REMOTE_PLANET" then
			mission.target = createTargetShip(mission)
		end

		-- load crew/passenger
		if ad.deliver_crew > 0 then
			for i=1,ad.deliver_crew do
				local passenger = Character.New()
				addPassenger(Game.player)
				table.insert(mission.cargo_pass, passenger)
			end
		end
		if ad.deliver_pass > 0 then
			for i=1,ad.deliver_pass do
				local passenger = Character.New()
				addPassenger(Game.player)
				table.insert(mission.cargo_pass, passenger)
			end
		end
		form:SetMessage(ls.THANK_YOU_ACCEPTANCE_TXT)
		table.insert(missions,Mission.New(mission))
		switchEvents()
		return
	end
--	form:AddOption(lx.WHY_SO_MUCH_MONEY, 1)
	form:AddOption(ls.WHERE_IS_THE_TARGET, 1)
	form:AddOption(ls.TYPE_OF_HELP, 2)
	form:AddOption(ls.HOW_MUCH_TIME, 3)
--	form:AddOption(lx.WILL_I_BE_IN_ANY_DANGER, 4)
	form:AddOption(ls.COULD_YOU_REPEAT_THE_ORIGINAL_REQUEST, 0)
	form:AddOption(ls.OK_AGREED, 4)
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

	local station_orig = station.path
--	if Space.GetBody(station_orig:GetSystemBody().parent.index).type=="PLANET_ASTEROID" then return end
	local planet_orig  = Space.GetBody(station_orig:GetSystemBody().parent.index).path
	local system_orig  = Game.system.path

	local flavour, station_target, planet_target, system_target
--	local flavour = flavours[manualFlavour] or flavours[Engine.rand:Integer(1,#flavours)]
	if station.isGroundStation
		and station:FindNearestTo("PLANET").type ~= "PLANET_ASTEROID"
--		and Space.GetBody(station_orig:GetSystemBody().parent.index).type ~= "PLANET_ASTEROID"
	then
		flavour = flavours[Engine.rand:Integer(1,#flavours)]
	else
		flavour = flavours[Engine.rand:Integer(7,8)]
	end

	-- abort if flavour incompatible with space station type
--	if flavour.loctype == "THIS_PLANET" and station.isGroundStation == false then return end

	local due, dist, client, entity, problem, location
	local lat  = 0
	local long = 0

	local urgency = flavour.urgency
	if urgency > 0 then urgency = urgency_set() end

	local risk = flavour.risk
	if risk == "var" then
		risk = risk_set()
	elseif risk > 0 then
		risk = risk_set() + 1
	else
		risk = 0
	end

	if flavour.loctype == "THIS_PLANET" then

		station_target = station_orig
		planet_target  = planet_orig
		system_target  = system_orig
		location       = planet_target

		lat, long, dist = randomLatLong(station)

		local reward_base = 350
		due    =_local_due(station,location,urgency,false)
		reward = reward_base*(1+dist/1000)*(1+urgency)*(1+Game.system.lawlessness)

	elseif flavour.loctype == "LOCAL_PLANET" then

		local nearbyplanets = _localPlanetsWithoutStations
		if #nearbyplanets == 0 then return end

		station_target  = nil
		planet_target   = nearbyplanets[Engine.rand:Integer(1,#nearbyplanets)]
		system_target   = system_orig
		location        = planet_target
		lat, long, dist = randomLatLong()

		local dist1 = station:DistanceTo(Space.GetBody(planet_target.bodyIndex))
		local dist2= Space.GetBody(planet_target.bodyIndex)
			:DistanceTo(Space.GetBody(planet_target.bodyIndex):FindNearestTo("SPACESTATION"))
		local body_label = Space.GetBody(planet_target.bodyIndex).label
		if dist1 > dist2 and body_label ~= 'Venus' and body_label ~= 'Mercury' then
		return end

-- 1 día = 3 AU = 448794000000 ej. 4 dias 12 AU / plutón a 33 AU = 1795176000000 // 4 a 11 dias
		local round = true
		if flavour.reward_immediate then round = false end
		due =_local_due(station,location,urgency,round)

		local reward_base = 550
		dist = station:DistanceTo(Space.GetBody(location.bodyIndex))
		reward = reward_base+(reward_base*(1+(dist/AU))*(1+urgency)*(1+Game.system.lawlessness))

	elseif flavour.loctype == "LOCAL_SPACE" then

		station_target = station_orig
		planet_target  = planet_orig
		system_target  = system_orig
		location       = planet_target

		local reward_base = 650

		dist = station:DistanceTo(Space.GetBody(location.bodyIndex))

		due    =_local_due(station,location,urgency,false)
		reward = reward_base+(reward_base*(1+math.sqrt(dist/AU))*(1+urgency)*(1+Game.system.lawlessness))

	elseif flavour.loctype == "REMOTE_SPACE" or flavour.loctype == "REMOTE_PLANET" then

		local remotesystems = Game.system:GetNearbySystems(15,
			function (s) return #s:GetBodyPaths() > 0 and s.population == 0 and s.explored == true end)
		if #remotesystems == 0 then return end
		remotesystem = remotesystems[Engine.rand:Integer(1,#remotesystems)]
		local remotebodies = remotesystem:GetBodyPaths()
		local checkedBodies = 0
		while checkedBodies <= #remotebodies do
			location = remotebodies[Engine.rand:Integer(1,#remotebodies)]
			currentBody = location:GetSystemBody()
			if validsystem(remotesystem.path)
				and currentBody.superType == "ROCKY_PLANET"
				and currentBody.type ~= "PLANET_ASTEROID" then
				break
			end
			location = nil
			currentBody = nil
			checkedBodies = checkedBodies + 1
		end
		if not currentBody or not location then return end
		planet_target = location
		if flavour.loctype == "REMOTE_PLANET" then lat, long, dist = randomLatLong() end
		system_target = remotesystem.path
		local multiplier = Engine.rand:Number(1.5,1.6)
		if Game.system.faction ~= system_target:GetStarSystem().faction then
			multiplier = multiplier * Engine.rand:Number(1.3,1.5)
		end
		station_target = nil

		local reward_base = 800
		dist = system_orig:DistanceTo(system_target)
		local round = true
		if flavour.reward_immediate then round = false end
		due    = _remote_due(dist,urgency,round)
		reward = reward_base*(1+math.sqrt(dist))*(1+urgency)*(1+Game.system.lawlessness)*(1+risk/6)
	end

	local shipTarget, shiplabel
	local crew_num     = 0
	local pickup_crew  = 0
	local pickup_pass  = 0
	local deliver_crew = 0
	local deliver_pass = 0

	shipTarget = shipsAvailable[Engine.rand:Integer(1,#shipsAvailable)]

	if not shipTarget then
		print("Could not find appropriate ship type for this mission!")
		return
	end

	if flavour.id == 1 or flavour.id == 6 then
		pickup_crew = Engine.rand:Integer(shipTarget.minCrew,shipTarget.maxCrew)
		pickup_pass = Engine.rand:Integer(1,shipTarget.cabin)
	elseif flavour.id == 3 then deliver_crew = 1
	elseif flavour.id == 7 then
		if shipTarget.minCrew > 1 then
			deliver_crew = shipTarget.minCrew -1
		else
			return
		end
	end

	if flavour.deliver_pass > 0 then
		deliver_pass = Engine.rand:Integer(1,shipTarget.cabin)
	end

	local crew_num = math.max(pickup_crew, deliver_crew)

	local shiplabel = Ship.MakeRandomLabel()

	local localities_local = {system_orig:GetStarSystem().name}
	if station_orig then
		table.insert(localities_local, station_orig.label)
	end
	if planet_orig then
		table.insert(localities_local, planet_orig:GetSystemBody().name)
	end
	local localities_target = {system_target:GetStarSystem().name}
	if station_target then
		table.insert(localities_target, station_target:GetSystemBody().name)
	end
	if planet_target then
		table.insert(localities_target, planet_target:GetSystemBody().name)
	end

	if flavour.id == 6 then
		client = Character.New()
		local entity_types = {"ENTITY_RESEARCH", "ENTITY_GENERAL"}
		local entity_type = entity_types[Engine.rand:Integer(1, #entity_types)]
		entity = string.interp(ls[entity_type.."_".. Engine.rand:Integer(1, getNumberOfFlavours(entity_type))],
					{locality = localities_local[Engine.rand:Integer(1,#localities_local)]})
		local problem_type
		if entity_type == "ENTITY_RESEARCH" then problem_type = "PROBLEM_RESEARCH"
		else problem_type = "PROBLEM_GENERAL" end
		problem = string.interp(ls[problem_type .. "_"..
				Engine.rand:Integer(1, getNumberOfFlavours(problem_type))],
					{locality = localities_target[Engine.rand:Integer(1,#localities_target)]})
	elseif flavour.id == 7 then
		client = Character.New()
		local lastname = splitName(client.name)[2]
		entity = string.interp(ls["ENTITY_FAMILY_BUSINESS_" .. Engine.rand:Integer(1, getNumberOfFlavours("ENTITY_FAMILY_BUSINESS"))],
						{locality = localities_local[Engine.rand:Integer(1,#localities_local)],
					name = lastname})
		problem = string.interp(ls["PROBLEM_CREW_" .. Engine.rand:Integer(1, getNumberOfFlavours("PROBLEM_CREW"))],
					{locality = localities_target[Engine.rand:Integer(1,#localities_target)]})
	else
		client = getAircontrolChar(station)
	end

	local extra = reward and ((pickup_crew )+(pickup_pass )+(deliver_crew or 0)+(deliver_pass))
	if extra > 0 then
		reward = reward + (extra * (Eq.misc.cabin.price * 1.15))
		if ((pickup_crew)+(pickup_pass)) > 0 then
			reward = (reward * 1.2)
		end
	end

	local amount_cargo, cargo_price
	if flavour.deliver_item == "var" then flavour.deliver_item = cargo_item() end
	local item = StrToObj(flavour.deliver_item,slot)
	if item then cargo_price = item.price end
	if cargo_price then
		if flavour.id > 7 then
			amount_cargo = math.floor(math.pow(shipTarget.hyperdriveClass,2)/2)
		else
			amount_cargo = math.floor(shipTarget.fuelTankMass * 0.25)
		end
		if not amount_cargo or amount_cargo < 1 then amount_cargo = 1 end
		reward = reward + (cargo_price*amount_cargo*1.15)
	end

	local ad = {--XXX ad
		location        = location,
		station_orig    = station_orig,
		planet_orig     = planet_orig,
		system_orig     = system_orig,
		station_target  = station_target,
		planet_target   = planet_target,
		system_target   = system_target,
		flavour         = flavour,
		client          = client,
		entity          = entity,
		problem         = problem,
		dist            = dist,
		date            = Game.time,
		due             = due,
		urgency         = urgency,
		risk            = risk,
		reward          = reward,
		shipTarget_name = shipTarget.name,
		crew_num        = crew_num,
		pickup_crew     = pickup_crew,
		pickup_pass     = pickup_pass,
		deliver_crew    = deliver_crew,
		deliver_pass    = deliver_pass,
		deliver_item    = flavour.deliver_item,
		quantity_cargo  = amount_cargo,
		shiplabel       = shiplabel,
		lat             = lat,
		long            = long
	}

	local staport_label, planet_label, system_label
	if station_target then starport_label = station_target:GetSystemBody().name else starport_label = nil end
	if planet_target then planet_label = planet_target:GetSystemBody().name else planet_label = nil end
	if system_target then system_label = system_target:GetStarSystem().name else system_label = nil end

	ad.desc = string.interp(flavour.adtext, {
						starport = starport_label,
						planet   = planet_label,
						system   = system_label or "NOT",
						dist     = _distTxt(location)
	})
	local ref = station:AddAdvert({
			description = ad.desc,
			icon        = ad.risk > 0 and "rescue_danger" or "rescue",
			onChat      = onChat,
			onDelete    = onDelete
	})
	ads[ref] = ad
	return ad
end

	local findBeaconDone = false
local findBeacon = function ()
	if beaconReceiver then
		local beaconDistance
		for ref,mission in pairs(missions) do
			if Game.system.path == mission.system_target:GetStarSystem().path
				and ShipExists(mission.target) and mission.status ~= 'TRIP_BACK'
			then
				if findBeaconDone then return end
				if mission.flavour.loctype == "REMOTE_SPACE" or mission.flavour.loctype == "LOCAL_SPACE" then
					beaconDistance = beacon_receiver_range
				elseif mission.target.flightState == "LANDED" then
					beaconDistance = 50e6-- 50.000 km
				end
				if beaconDistance and Game.player:DistanceTo(mission.target) < beaconDistance then
					findBeaconDone = true
					Game.player:SetNavTarget()
					Game.player:SetNavTarget(mission.target)
					Music.Play("music/core/fx/beacon",false)
					local alert = string.interp(lx.ALERT_BRS,{target_label = mission.target.label})
					Comms.ImportantMessage(alert)
				end
			end
		end
		return findBeaconDone
	end
end

local missionStatus = function (mission)
	local status = "NOT"
	if   mission.pickup_crew_check  == "COMPLETE"
		or mission.pickup_pass_check  == "COMPLETE"
		or mission.deliver_crew_check == "COMPLETE"
		or mission.deliver_pass_check == "COMPLETE"
		or mission.deliv_cargo_check  == "COMPLETE" then
		status = "COMPLETE"
	end
	if mission.pickup_crew_check == "PARTIAL" or mission.pickup_crew_check  == "ABORT" or
		mission.pickup_pass_check  == "PARTIAL" or mission.pickup_pass_check  == "ABORT" or
		mission.deliver_crew_check == "PARTIAL" or mission.deliver_crew_check == "ABORT" or
		mission.deliver_pass_check == "PARTIAL" or mission.deliver_pass_check == "ABORT" or
		mission.deliv_cargo_check  == "PARTIAL" or mission.deliv_cargo_check  == "ABORT" then
		status = "PARTIAL"
	end
	return status
end

local missionStatusReset = function (mission)
	if mission.pickup_crew_check  == "PARTIAL" then mission.pickup_crew_check  = "NOT" end
	if mission.pickup_pass_check  == "PARTIAL" then mission.pickup_pass_check  = "NOT" end
	if mission.deliver_crew_check == "PARTIAL" then mission.deliver_crew_check = "NOT" end
	if mission.deliver_pass_check == "PARTIAL" then mission.deliver_pass_check = "NOT" end
	if mission.deliv_cargo_check  == "PARTIAL" then mission.deliv_cargo_check  = "NOT" end
end

local closeMission = function (mission)
	if Game.time > mission.due then
		Comms.ImportantMessage(mission.flavour.failuremsg)
		_G.MissionsFailures = MissionsFailures + 1
		removeMission(mission)
	else
		if missionStatus(mission) == "COMPLETE" then
			local successtxt = string.interp(mission.flavour.successmsg, {cash = Format.Money(mission.reward)})
			Comms.ImportantMessage(successtxt)
			_G.MissionsSuccesses = MissionsSuccesses + 1
			Game.player:AddMoney(mission.reward)
			removeMission(mission)
		elseif missionStatus(mission) == "PARTIAL" then
			Comms.ImportantMessage(ls.PARTIAL)
			missionStatusReset(mission)
		end
	end
end

local InteractionDistance = function (mission)
	if Game.system then
		local dist = Game.player:DistanceTo(mission.target)
		if dist <= max_interaction_dist then
			return true
		else

			if Game.player:GetNavTarget() == mission.target
				and Game.player:GetCombatTarget() == mission.target
			then
				Game.player:SetNavTarget()
				Game.player:SetCombatTarget()
			end

			return false
		end
	end
end

local pickupCrew = function (mission)
	local todo = mission.pickup_crew_orig
	if mission.target:CrewNumber() == 0 then
		Comms.ImportantMessage(ls.MISSING_CREW)
		mission.pickup_crew_check = "ABORT"
		return
	elseif not freeCabin(Game.player) then
		Comms.ImportantMessage(ls.FULL_PASSENGERS)
		local done = mission.pickup_crew_orig - mission.pickup_crew
		local resulttxt = string.interp(ls.RESULT_PICKUP_CREW, {todo = todo, done = done})
		Comms.ImportantMessage(resulttxt)
		if mission.pickup_pass > 0 then
			local todo_pass = mission.pickup_pass_orig
			local done_pass = mission.pickup_pass_orig - mission.pickup_pass
			local resulttxt_pass = string.interp(ls.RESULT_PICKUP_PASS, {todo = todo_pass, done = done_pass})
			Comms.ImportantMessage(resulttxt_pass)
		end
		mission.pickup_crew_check = "PARTIAL"
		return
	else
		local crew_member = removeCrew(mission.target)
		addPassenger(Game.player)
		table.insert(mission.cargo_pass, crew_member)
		local boardedtxt = string.interp(ls.BOARDED_PASSENGER, {name = crew_member.name})
		Comms.ImportantMessage(boardedtxt)
		mission.crew_num = mission.crew_num - 1
		mission.pickup_crew = mission.pickup_crew - 1
		local done = mission.pickup_crew_orig - mission.pickup_crew
		if todo == done then
			local resulttxt = string.interp(ls.RESULT_PICKUP_CREW, {todo = todo, done = done})
			Comms.ImportantMessage(resulttxt)
			mission.pickup_crew_check = "COMPLETE"
		end
	end
end

local pickupPassenger = function (mission)
	local todo = mission.pickup_pass_orig
	if not passengersPresent(mission.target) then
		Comms.ImportantMessage(ls.MISSING_PASS)
		mission.pickup_pass_check = "ABORT"
		return
	elseif not freeCabin(Game.player) then
		Comms.ImportantMessage(ls.FULL_PASSENGERS)
		local done = mission.pickup_pass_orig - mission.pickup_pass
		local resulttxt = string.interp(ls.RESULT_PICKUP_PASS, {todo = todo, done = done})
		Comms.ImportantMessage(resulttxt)
		mission.pickup_pass_check = "PARTIAL"
		return
	else
		local passenger = Character.New()
		removePassenger(mission.target)
		addPassenger(Game.player)
		table.insert(mission.cargo_pass, passenger)
		local boardedtxt = string.interp(ls.BOARDED_PASSENGER, {name = passenger.name})
		Comms.ImportantMessage(boardedtxt)
		mission.pickup_pass = mission.pickup_pass - 1
		local done = mission.pickup_pass_orig - mission.pickup_pass
		if todo == done then
			local resulttxt = string.interp(ls.RESULT_PICKUP_PASS, {todo = todo, done = done})
			Comms.ImportantMessage(resulttxt)
			mission.pickup_pass_check = "COMPLETE"
		end
	end
end

local deliverCrew = function (mission)
	local todo = mission.deliver_crew_orig
	local maxcrew = ShipDef[mission.target.shipId].maxCrew
	if not passengersPresent(Game.player) then
		Comms.ImportantMessage(ls.MISSING_CREW)
		mission.deliver_crew_check = "ABORT"
		return
	elseif mission.target:CrewNumber() > maxcrew then
		Comms.ImportantMessage(ls.FULL_CREW)
		mission.deliver_crew_check = "PARTIAL"
		return
	else
		local crew_member
		for _,passenger in pairs(mission.cargo_pass) do
			crew_member = passenger
			break
		end
		mission.cargo_pass[crew_member] = nil
		removePassenger(Game.player)
		addCrew(mission.target, crew_member)
		mission.crew_num = mission.crew_num + 1
		local deliverytxt = string.interp(ls.DELIVERED_PASSENGER, {name = crew_member.name})
		Comms.ImportantMessage(deliverytxt)
		mission.deliver_crew = mission.deliver_crew - 1
		local done = mission.deliver_crew_orig - mission.deliver_crew
		if todo == done then
			local resulttxt = string.interp(ls.RESULT_DELIVERY_CREW, {todo = todo, done = done})
			Comms.ImportantMessage(resulttxt)
			mission.deliver_crew_check = "COMPLETE"
		end
	end
end

local deliverPassenger = function (mission)
	local todo = mission.deliver_pass_orig
	if not passengersPresent(Game.player) then
		Comms.ImportantMessage(ls.MISSING_PASS)
		mission.deliver_pass_check = "ABORT"
		return
	elseif not freeCabin(mission.target) then
		Comms.ImportantMessage(ls.FULL_PASSENGERS)
		mission.deliver_pass_check = "PARTIAL"
		return
	else
		local passenger = table.remove(mission.cargo_pass, 1)
		removePassenger(Game.player)
		addPassenger(mission.target)
		local deliverytxt = string.interp(ls.DELIVERED_PASSENGER, {name = passenger.name})
		Comms.ImportantMessage(deliverytxt)
		mission.deliver_pass = mission.deliver_pass - 1
		local done = mission.deliver_pass_orig - mission.deliver_pass
		if todo == done then
			local resulttxt = string.interp(ls.RESULT_DELIVERY_PASS, {todo = todo, done = done})
			Comms.ImportantMessage(resulttxt)
			mission.deliver_pass_check = "COMPLETE"
		end
	end
end

local deliverCargo = function (mission)
	if missionStatus(mission) == "COMPLETE" then return true end
	local deliver_cargo = mission.deliver_item
	local cargo_name = StrToObj(mission.deliver_item,slot):GetName()
	local cargo_load = mission.quantity_cargo
	if not cargoPresent(Game.player, deliver_cargo, cargo_load) then
		local missingtxt = string.interp(ls.MISSING_COMM, {cargotype = cargo_name})
		Comms.ImportantMessage(missingtxt)
		mission.deliv_cargo_check = "ABORT"
		return
	elseif not cargoSpace(mission.target, cargo_load) then
		Comms.ImportantMessage(ls.FULL_CARGO)
		mission.deliv_cargo_check = "PARTIAL"
		return
	else
		local resulttxt = string.interp(ls.RESULT_DELIVERY_COMM, {
		done = cargo_load, todo = cargo_load, cargotype = cargo_name})
		Comms.ImportantMessage(resulttxt)
		if mission.deliver_item then
			deliver_cargo = StrToObj(mission.deliver_item,slot)
		end
		Game.player:RemoveEquip(deliver_cargo, cargo_load)
		mission.target:AddEquip(deliver_cargo, cargo_load)
		mission.deliv_cargo_check = "COMPLETE"
		missionStatus(mission)
		return true
	end
end

local interactionCounter = function (counter, total_interaction_time)
	counter = counter + 1
	if counter >= total_interaction_time then
		return true, counter
	else
		return false, counter
	end
end

local working
local interactWithTarget = function (mission)
	if working or not InteractionDistance(mission) then return end
	if StopAction(mission) or missionStatus(mission) == "COMPLETE" then
		working = false
		return true
	end
	working = true
	local packages = (
		target_interaction_time+(mission.quantity_cargo or 0 )+mission.pickup_crew+
		mission.pickup_pass+mission.deliver_crew+mission.deliver_pass )
	local total_interaction_time = packages
	local distance_reached_txt = string.interp(ls.INTERACTION_DISTANCE_REACHED,
			{seconds = total_interaction_time-4})
	Comms.ImportantMessage(distance_reached_txt)
	local song, song2
	if Music.IsPlaying then song = Music.GetSongName() end
	if mission.quantity_cargo and mission.quantity_cargo > 0 then
		song2 = "music/core/fx/liquid_transfer"
	else
		song2 = "music/core/fx/rescue01"
	end
	Music.Play(song2,true)
	Timer:CallAt(Game.time + total_interaction_time, function ()
		Music.Stop()
		if song then Music.Play(song, false) end
	end)
	local counter = 0
	Timer:CallEvery(1, function ()
		if StopAction(mission)
		or (done and missionStatus(mission) == "COMPLETE")
		then
			working = false
			return true
		end
		local done = true
		if not InteractionDistance(mission) then
			Comms.ImportantMessage(ls.INTERACTION_ABORTED)
			searchForTarget()
			working = false
			return true
		end
		local actiontime
		actiontime, counter = interactionCounter(counter, total_interaction_time)
		if actiontime then
			if mission.pickup_crew > 0 and mission.pickup_crew_check ~= "PARTIAL" then
				done = false
				pickupCrew(mission)
			elseif mission.deliver_crew > 0 and mission.deliver_crew_check ~= "PARTIAL" then
				done = false
				deliverCrew(mission)
			elseif mission.pickup_pass > 0 and mission.pickup_pass_check ~= "PARTIAL" then
				done = false
				pickupPassenger(mission)
			elseif mission.deliver_pass > 0 and mission.deliver_pass_check ~= "PARTIAL" then
				done = false
				deliverPassenger(mission)
			elseif mission.deliver_item and mission.deliv_cargo_check ~= "PARTIAL" then
				done = deliverCargo(mission)
			end
			if done and missionStatus(mission) == "COMPLETE" then
				if mission.flavour.reward_immediate == true then--2 3 4 5 7 8 / pago inmediato termina mision
--[[
		2 suministra combustible y cobra / la nave va a puerto? o explota? / "THIS_PLANET"
		3 transporta piloto y cobra / la nave va a puerto? o explota? / "THIS_PLANET"
		4 suministra combustible y cobra / la nave va a puerto? o explota? / "LOCAL_PLANET"
		5 suministra combustible y cobra / la nave va a puerto? o explota? / "LOCAL_SPACE
		7 transporta tripulante/s y cobra / la nave salta o explota / "REMOTE_SPACE"
		8 suministra combustible y cobra / la nave salta o explota / "REMOTE_SPACE"
--]]
					Comms.ImportantMessage(lx.MISSION_ACCOMPLISHED)
					Timer:CallAt(Game.time + 5, function ()-- se aleja de mission.target
						if StopAction(mission) then return end
						if beaconReceiver then
							Game.player:AIEnterLowOrbit(mission.target:FindNearestTo('PLANET'))
						end -- el jugador se aleja y decide su futuro
								-- la nave vuela a diferentes objetivos o salta hiperespacio
						if Game.player:GetNavTarget() == mission.target then Game.player:SetNavTarget() end
						if Game.player:GetCombatTarget() == mission.target then Game.player:SetCombatTarget() end
						Timer:CallAt(Game.time + 5, function ()-- mission.target despega
							if StopAction(mission) then return end
							if mission.target.flightState == "LANDED" then mission.target:BlastOff() end
							Timer:CallAt(Game.time + 5, function ()-- mission.target se dirige a su destino
								if StopAction(mission) then return end
								if mission.target.flightState == "FLYING" then
									if mission.flavour.id > 1 and mission.flavour.id < 6 then--2 3 4 5 vuela y eplota
										mission.target:AIDockWith(mission.target:FindNearestTo("SPACESTATION"))
										Timer:CallAt(Game.time + Engine.rand:Integer(30,50), function ()
											if StopAction(mission) then return end
											mission.target:Explode()
											mission.target = nil
										end)
									elseif mission.flavour.id > 6 then-- 7 8 salta a hiperespacio o explota
										mission.target:AIFlyTo(mission.target:FindNearestTo("STAR"))
										Timer:CallAt(Game.time + Engine.rand:Integer(10,20), function ()
											if StopAction(mission) then return end
											if not ShipJump(mission.target) then
												mission.target:Explode()
												mission.target = nil
											end
										end)
									end
								else
									mission.target:Explode()
									mission.target = nil
								end
							end)
						end)
					end)
					closeMission(mission)-- cuidado donde se ubica esto XXX
					working = false
				else-- el jugador retorna con tripulantes o pasajeros 1 6
--		1 recoge tripulantes o pasajeros y retorna / la nave explota / "LOCAL_PLANET"
--		6 recoge tripulantes o pasajeros y retorna / la nave explota / "REMOTE_PLANET"
					mission.status = 'TRIP_BACK'
					Comms.ImportantMessage(lx.MISSION_ACCOMPLISHED_PARTIALLY)
--					if mission.station_orig:IsSameSystem(Game.system.path) then-- 1
--						mission.due = _local_due(Game.player,mission.station_orig,0,false)
--					else-- 6
--						local dist = mission.system_target:DistanceTo(mission.system_orig)
--						mission.due = _remote_due(dist,0,false)
--					end
					mission.location = mission.station_orig
					if NavAssist and Game.system.path ~= mission.location:GetStarSystem().path then
						Game.player:SetHyperspaceTarget(mission.location:GetStarSystem().path)
					end
					Timer:CallAt(Game.time + 5, function ()
						if StopAction(mission) then return end
						if beaconReceiver then
							Game.player:AIEnterLowOrbit(Game.player:FindNearestTo('PLANET'))
						end
						Timer:CallAt(Game.time + Engine.rand:Integer(10,20), function ()
							if StopAction(mission) then return end
							mission.target:Explode()
							mission.target = nil
						end)
					end)
				end
				local trueSystem = Game.system
				Timer:CallAt(Game.time + 10, function ()
					if Game.system ~= trueSystem then return true end
					searchForTarget()
					findBeaconDone = false
					findBeacon()
				end)
				working = false
				return true
			else
				working = false
				return false
			end
		end
	end)
end

	local outhostiles
function searchForTarget()
	for ref,mission in pairs(missions) do
		if mission.status ~= 'TRIP_BACK' then
			if Game.time > mission.due
				and mission.flavour.reward_immediate == true
			then
				closeMission(mission)
				searchForTarget()
			end
			if Game.system.path == mission.system_target:GetStarSystem().path
				and (mission.target == "uncreated" or not ShipExists(mission.target))
			then
				mission.target = createTargetShip(mission)
			end
			if mission.target and not mission.searching
				and Game.system.path == mission.system_target:GetStarSystem().path
				and (((mission.flavour.loctype == "REMOTE_SPACE" or mission.flavour.loctype == "LOCAL_SPACE")
				and mission.target.flightState == "FLYING") or mission.target.flightState == "LANDED")
			then
				if Game.player.frameBody == mission.target.frameBody then
					mission.searching = true
					local distance_reached = true
					local true_system = Game.system
					Timer:CallEvery(1, function ()
						if Game.system ~= true_system then
							mission.searching = false
							return true
						elseif not ShipExists(mission.target)
							or Game.player.frameBody ~= mission.target.frameBody then
							mission.searching = false
							return false
						else
							if not outhostiles and mission.risk > 0
								and Game.player:DistanceTo(mission.target) < 5e3--5 Km
							then
								outhostiles = true
								Timer:CallAt(Game.time + Engine.rand:Integer(10,20), function ()
									local ship = ship_hostil(mission.risk)
									if ship then
										Game.player:CancelAI()
										Game.player:SetCombatTarget()
										Music.Play("music/core/fx/warning",false)
										local warning_txt = string.interp(lm.WARNING, {hostile = mission.risk})
										Comms.ImportantMessage(warning_txt)
									end
								end)
							end
							if not InteractionDistance(mission) then
								if not distance_reached then
									Comms.ImportantMessage(ls.INTERACTION_ABORTED)
									distance_reached = true
								end
								return false
							else
								if Game.time > mission.due then
									Comms.ImportantMessage(ls.SHIP_UNRESPONSIVE)
									mission.status = "FAILED"
									return true
								else
									mission.searching = false
									interactWithTarget(mission)
									return true
								end
							end
						end
					end)
				end
			end
		end
	end
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
		if ad.station_orig == station.path then
			if (ad.flavour.loctype == "THIS_PLANET"
				or ad.flavour.loctype == "LOCAL_SPACE") then
				timeout = 60*60 -- 1 hour timeout for locals
			end
			if (Game.time - ad.date >= timeout) then
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


local onClick = function (mission)
	local setTargetButton = SLButton.New(lm.SET_TARGET, 'NORMAL')
	setTargetButton.button.onClick:Connect(function ()
		if not Game.system then return end
		if not NavAssist then MsgBox.Message(lm.NOT_NAV_ASSIST) return end
		if not beaconReceiver then MsgBox.Message(lm.NOT_BEACON_RECEIVER) return end
		if Game.system.path ~= mission.location:GetStarSystem().path then
			Game.player:SetHyperspaceTarget(mission.location:GetStarSystem().path)
		else
			if ShipExists(mission.target) and Game.player:DistanceTo(mission.target) < 50e6 then
				if beaconReceiver then
					Game.player:SetNavTarget(mission.target)
				end
			else
				Game.player:SetNavTarget(Space.GetBody(mission.location.bodyIndex))
			end
		end
	end)

	local dist_txt = lx.OUT_OF_RANGE
	if Game.system then
		if ShipExists(mission.target) then
			if Game.player:DistanceTo(mission.target)/AU > 0.01 then
				dist_txt = _distTxt(mission.location)
			elseif Game.player:DistanceTo(mission.target) < beacon_receiver_range then
				dist_txt = Game.player:DistanceTo(mission.target)/1000
				dist_txt = string.format("%.2f",dist_txt).." "..lm.KM
			end
		else
			dist_txt = _distTxt(mission.location)
		end
	else
		dist_txt = lm.HYPERSPACE
	end

	local merchandise = lx.NONE
	if mission.quantity_cargo and mission.deliver_item then
		local itemName = StrToObj(mission.deliver_item,slot):GetName()
		merchandise = string.interp(lx.COMMODITY, {
					quantity = mission.quantity_cargo,
					product  = itemName
		})
	end

	local payment_address = mission.station_orig:GetSystemBody().name
	if mission.flavour.reward_immediate == true then payment_address = ls.PLACE_OF_ASSISTANCE end
	local mission_target
	if mission.lat == 0 and mission.long == 0 then
		mission_target = mission.planet_target:GetSystemBody().name.."\n"..ls.ORBIT
	else
		mission_target = mission.planet_target:GetSystemBody().name..
											"\n"..ls.LAT.." "..decToDegMinSec(math.rad2deg(mission.lat))
									.." // "..ls.LON.." "..decToDegMinSec(math.rad2deg(mission.long))
	end
	local mission_system = mission.system_target:GetStarSystem().name
									.." ("..mission.system_target.sectorX
									.. ","..mission.system_target.sectorY
									.. ","..mission.system_target.sectorZ..")"
	if mission.status == 'TRIP_BACK' then
		mission_target = "???"
		mission_system = "???"
	end

	return
			ui:Grid({68,32},1)
				:SetColumn(0,{ui:VBox():PackEnd({
					ui:Margin(10),
					ui:Grid(2,1)
						:SetColumn(0, {ui:VBox():PackEnd({ui:Label(ls.TARGET_SHIP_ID)})})
						:SetColumn(1, {ui:VBox():PackEnd({ui:MultiLineText(mission.shipTarget_name
									.." <"..mission.shiplabel.."> ")})}),
					ui:Grid(2,1)
						:SetColumn(0, {ui:VBox():PackEnd({ui:Label(ls.LAST_KNOWN_LOCATION)})})
						:SetColumn(1, {ui:VBox():PackEnd({ui:MultiLineText(mission_target)
								})}),
					ui:Margin(5),
					ui:Grid(2,1)
						:SetColumn(0, {ui:VBox():PackEnd({ui:Label(ls.SYSTEM)})})
						:SetColumn(1, {ui:VBox():PackEnd({
								ui:MultiLineText(mission_system)})}),
					ui:Grid(2,1)
						:SetColumn(0, {ui:VBox():PackEnd({ui:Label(ls.DISTANCE)})})
						:SetColumn(1, {ui:VBox():PackEnd({ui:Label(dist_txt),
													"",
													setTargetButton.widget})}),
					ui:Margin(10),
					ui:Grid(2,1)
						:SetColumn(0, {ui:VBox():PackEnd({ui:Label(lx.CREWS_TO_PICK_UP)})})
						:SetColumn(1, {ui:VBox():PackEnd({ui:MultiLineText(mission.pickup_crew_orig)})}),
					ui:Grid(2,1)
						:SetColumn(0, {ui:VBox():PackEnd({ui:Label(lx.PASSENGERS_TO_PICK_UP)})})
						:SetColumn(1, {ui:VBox():PackEnd({ui:MultiLineText(mission.pickup_pass_orig)})}),
					ui:Margin(5),
					ui:Grid(2,1)
						:SetColumn(0, {ui:VBox():PackEnd({ui:Label(lx.CREWS_TO_BE_SENT)})})
						:SetColumn(1, {ui:VBox():PackEnd({ui:MultiLineText(mission.deliver_crew_orig)})}),
					ui:Grid(2,1)
						:SetColumn(0, {ui:VBox():PackEnd({ui:Label((lx.PASSENGERS_TO_BE_SENT))})})
						:SetColumn(1, {ui:VBox():PackEnd({ui:MultiLineText(mission.deliver_pass_orig)})}),
					ui:Margin(5),
					ui:Grid(2,1)
						:SetColumn(0, {ui:VBox():PackEnd({ui:Label(lx.COMMODITY_TO_DELIVERY)})})
						:SetColumn(1, {ui:VBox():PackEnd({ui:MultiLineText(merchandise)})}),
					ui:Margin(10),
					ui:Grid(2,1)
						:SetColumn(0, {ui:VBox():PackEnd({ui:Label(ls.REWARD)})})
						:SetColumn(1, {ui:VBox():PackEnd({ui:MultiLineText(showCurrency(mission.reward))})}),
					ui:Margin(5),
					ui:Grid(2,1)
						:SetColumn(0, {ui:VBox():PackEnd({ui:Label(ls.PAYMENT_LOCATION)})})
						:SetColumn(1, {ui:VBox():PackEnd({ui:Label(payment_address)})}),
					ui:Grid(2,1)
						:SetColumn(0, {ui:VBox():PackEnd({ui:Label(ls.SYSTEM)})})
						:SetColumn(1, {ui:VBox():PackEnd({
								ui:MultiLineText(mission.system_orig:GetStarSystem().name
									.." ("..mission.system_orig.sectorX
									..","..mission.system_orig.sectorY
									..","..mission.system_orig.sectorZ..")")})}),
					ui:Margin(5),
					ui:Grid(2,1)
						:SetColumn(0, {ui:VBox():PackEnd({ui:Label(ls.DEADLINE)})})
						:SetColumn(1, {ui:VBox():PackEnd({ui:Label(Format.Date(mission.due))})}),
		})})
		:SetColumn(1, {ui:VBox(10):PackEnd(InfoFace.New(mission.client))})
end

local onShipDestroyed = function (ship, attacker)
	for ref,mission in pairs(missions) do
		if ship == mission.target then
			if attacker == Game.player then
				_G.MissionsFailures = MissionsFailures + 1
				mission:Remove()
				missions[ref] = nil
			end
		end
	end
end

local onFrameChanged = function (body)
	if not body:isa("Ship") or not body:IsPlayer() then return end
	searchForTarget()
	findBeaconDone = false
	findBeacon()
end

local onShipDocked = function (player, station)
	if not player:IsPlayer() then return end
	outhostiles = false
	findBeaconDone = false--XXX
	for ref, mission in pairs(missions) do
		if Game.time > mission.due
			or (mission.station_orig:IsSameSystem(Game.system.path)
			and Space.GetBody(mission.station_orig.bodyIndex) == station) then
			closeMission(mission)
		end
	end
end

local onShipUndocked = function (ship, station)
	if not ship:IsPlayer() then return end
	Timer:CallAt(Game.time + 8, function ()
		searchForTarget()
		findBeaconDone = false
		findBeacon()
	end)
end

local onEnterSystem = function (player)
	if not player:IsPlayer() or not switchEvents() then return end
	findBeaconDone = false
	outhostiles = false
	local syspath = Game.system.path
	for ref,mission in pairs(missions) do
		if mission.system_target:IsSameSystem(syspath) and mission.due > Game.time then
			shipsAvailable = shipsAvail()
			mission.target = createTargetShip(mission)
			return
		end
	end
end

local loaded_data
local onGameStart = function ()
	ads = {}
	missions = {}
	if type(loaded_data) == "table" then
		for k,ad in pairs(loaded_data.ads) do
			local ref = Space.GetBody(ad.station_orig.bodyIndex):
				AddAdvert({
				description = ad.desc,
				icon        = ad.risk > 0 and "rescue_danger" or "rescue",
				onChat      = onChat,
				onDelete    = onDelete
			})
		ads[ref] = ad
		end
		missions = loaded_data.missions
		loaded_data = nil
		for ref,mission in pairs(missions) do
			if mission.searching then mission.searching = false end
		end
	end
	shipsAvailable = shipsAvail()
	if switchEvents() then
		searchForTarget()
		findBeaconDone = false
		findBeacon()
	end
end

local serialize = function ()
	for ref,mission in pairs(missions) do
		if mission.system_target == Game.system.path
			and not ShipExists(mission.target) then
			mission.target = "uncreated"
		end
	end
	return { ads = ads, missions = missions }
end

local unserialize = function (data)
	loaded_data = data
end

switchEvents = function()
	local status = false
	Event.Deregister("onFrameChanged", onFrameChanged)
	Event.Deregister("onShipDocked", onShipDocked)
	Event.Deregister("onShipUndocked", onShipUndocked)
	Event.Deregister("onShipDestroyed", onShipDestroyed)
	for ref,mission in pairs(missions) do
		if Game.time > mission.due or mission.location:IsSameSystem(Game.system.path) then
			Event.Register("onFrameChanged", onFrameChanged)
			Event.Register("onShipDocked", onShipDocked)
			Event.Register("onShipUndocked", onShipUndocked)
			Event.Register("onShipDestroyed", onShipDestroyed)
			status = true
		end
	end
	return status
end

Event.Register("onCreateBB", onCreateBB)
Event.Register("onUpdateBB", onUpdateBB)
Event.Register("onEnterSystem", onEnterSystem)
Event.Register("onGameStart", onGameStart)

Mission.RegisterType("sar",ls.SAR,onClick)

Serializer:Register("sar", serialize, unserialize)
