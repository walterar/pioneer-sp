-- Copyright © 2008-2015 Pioneer Developers. Author Claudius Mueller 2015
-- Modified for Pioneer Scout Plus by Walter Arnolfo <walterar2@gmail.com>
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt

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
local Equipment  = import("Equipment")
local ShipDef    = import("ShipDef")
local Ship       = import("Ship")
local utils      = import("utils")
local Timer      = import("Timer")

local InfoFace = import("ui/InfoFace")

local ls = Lang.GetResource("module-sar") or Lang.GetResource("module-sar","en")
local lx = Lang.GetResource("module-sar-xtras") or Lang.GetResource("module-sar-xtras","en")

local ui = Engine.ui

-- basic variables for mission creation
local max_mission_dist =   15 -- max distance for long distance mission target location [ly]

local min_close_dist   =  200 -- min distance for "THIS_PLANET"
local max_close_dist   = 1000 --                 or "NEAR_SPACE" target location [km]

local max_interaction_dist    = 50 -- [meters] 0 to max distance for successful interaction with target
local target_interaction_time =  5 -- [sec] interaction time to load/unload one unit of cargo/person

local max_pass = 2 -- max number of passengers on target ship (high max: 10)
local max_crew = 4 -- max number of crew on target ship (high max: 8)

local reward_near   =  800 -- basic reward for "CLOSE" mission (+/- random half of that)
local reward_medium = 3000 -- basic reward for "MEDIUM" mission (+/- random half of that)
local reward_far    = 6000 -- basic reward for "FAR" mission (+/- random half of that)

-- global containers and variables
local aircontrol_chars = {}    -- saving specific aircontrol character per spacestation
local ads              = {}    -- currently active ads in the system
local missions         = {}    -- accepted missions that are currently active

local propellant = function()
	local prop
--	if Engine.rand:Integer(0,1) < 1 then
--		prop = Equipment.cargo.military_fuel
--		prop = Equipment.cargo.hydrogen
--	else
		prop = Equipment.cargo.hydrogen
--		prop = Equipment.cargo.military_fuel
--	end
	return prop
end

local urgency_set = function()
	return Engine.rand:Number(0,1)
end

local risk_set = function()
	return Engine.rand:Integer(0,1)
end

local flavours = {

-- Rescatar tripulación y/o pasajeros de nave accidentada en planeta local
-- ESPECIAL: número de tripulantes/pasajeros a recojer es aleatorio
	{
		id               = 1,
		loctype          = "NEAR_PLANET",--"NAVE ACCIDENTADA en la superficie de {planet}." local
		pickup_crew      = 0,
		pickup_pass      = 0,
		deliver_crew     = 0,
		deliver_pass     = 0,
		deliver_cargo    = nil,
		quantity_cargo   = 0,
		urgency          = urgency_set(),
		risk             = risk_set(),
		reward_immediate = false-- retorna
	},

	-- suministrar combustible a la nave varada en superficie cerca de "esta" estación
	{
		id               = 2,
		loctype          = "THIS_PLANET",--"NAVE SIN COMBUSTIBLE en ruta a {starport}."
		pickup_crew      = 0,
		pickup_pass      = 0,
		deliver_crew     = 0,
		deliver_pass     = 0,
		deliver_cargo    = propellant(),
		quantity_cargo   = 1,
		urgency          = urgency_set(),
		risk             = risk_set(),
		reward_immediate = true
	},

	-- Transportar 1 tripulante a la nave encallada cerca de Starport
	{
		id               = 3,
		loctype          = "THIS_PLANET",--"EMERGENCIA MÉDICA en nave cercana a {starport}."
		pickup_crew      = 0,
		pickup_pass      = 0,
		deliver_crew     = 1,
		deliver_pass     = 0,
		deliver_cargo    = nil,
		quantity_cargo   = 0,
		urgency          = urgency_set(),
		risk             = risk_set(),
		reward_immediate = true
	},

	-- suministrar combustible a una la nave varada en un planeta local
	{
		id               = 4,
		loctype          = "NEAR_PLANET",--"NAVE SIN COMBUSTIBLE en {planet}."
		pickup_crew      = 0,
		pickup_pass      = 0,
		deliver_crew     = 0,
		deliver_pass     = 0,
		deliver_cargo    = propellant(),
		quantity_cargo   = 1,
		urgency          = urgency_set(),
		risk             = risk_set(),
		reward_immediate = true
	},

	-- Suministrar combustible a una nave en órbita del planeta de "esta" estación
	{
		id               = 5,
		loctype          = "NEAR_SPACE",--"NAVE SIN PROPELENTE sobre {starport}."
		pickup_crew      = 0,
		pickup_pass      = 0,
		deliver_crew     = 0,
		deliver_pass     = 0,
		deliver_cargo    = propellant(),
		quantity_cargo   = 1,
		urgency          = urgency_set(),
		risk             = risk_set(),
		reward_immediate = true
	},

	-- rescue all crew + passengers from ship stranded in unoccupied system
	-- SPECIAL: number of crew/pass to pickup is picked randomly during ad creation
	-- Rescate de tripulación y/o pasajeros de una nave varada en planeta de sistema inhabitado
	-- ESPECIAL: número de tripulantes/pasajeros a recojer es aleatorio
	{
		id               = 6,
		loctype          = "FAR_PLANET",--"NAVE PERDIDA en sistema {system}."
		pickup_crew      = 0,
		pickup_pass      = 0,
		deliver_crew     = 0,
		deliver_pass     = 0,
		deliver_cargo    = nil,
		quantity_cargo   = 0,
		urgency          = urgency_set(),
		risk             = risk_set(),
		reward_immediate = false
	},

	-- take replacment crew to ship stranded in unoccupied system
	-- SPECIAL: number of crew to deliver is picked randomly during ad creation
	-- Transportar tripulación de reemplazo a una nave orbitando un planeta en sistema inhabitado max 15 ly
	-- ESPECIAL: número de tripulantes para entregar es escogido al azar durante la creación de anuncios
	{
		id               = 7,
		loctype          = "FAR_SPACE",--"TRANSPORTE DE TRIPULANTES URGENTE a sistema {system}."
		pickup_crew      = 0,
		pickup_pass      = 0,
		deliver_crew     = 0,
		deliver_pass     = 0,
		deliver_cargo    = nil,
		quantity_cargo   = 0,
		urgency          = urgency_set(),
		risk             = risk_set(),
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


local arraySize = function (array)
-- Return the size (length) of an array that contains arbitrary entries.
	local n = 0
	for _,_ in pairs(array) do n = n + 1 end
	return n
end

local containerContainsKey = function (container, key)
-- Return true if key is in container and false if not.
	return container[key] ~= nil
end

local copyTable = function (orig)
-- Return a copy of a table. Copies only the direct children (no deep copy!).
-- Taken from http://lua-users.org/wiki/CopyTable.
	local orig_type = type(orig)
	local copy
	if orig_type == 'table' then
		copy = {}
		for orig_key, orig_value in pairs(orig) do
			copy[orig_key] = orig_value
		end
	else -- number, string, boolean, etc
		copy = orig
	end
	return copy
end

local compressTableKeys = function (t)
-- Return the table with all keys in numerical order without gaps.
-- Taken from http://www.computercraft.info/forums2/index.php?/topic/18380-how-do-i-remove-gaps-in-an-ordered-list/.
	local keySet = {}
	for i in pairs(t) do
		table.insert(keySet, i)
	end
	table.sort(keySet)
	local retVal = {}
	for i = 1, #keySet do
		retVal[i] = t[keySet[i]]
	end
	return retVal
end


local trip_back = function (mission)-- Marca la ruta de retorno al sistema de origen
	if Game.system.path == mission.system_target:GetStarSystem().path
		and not mission.flavour.reward_immediate then--XXX
		mission.location = mission.planet_local
		mission.status = "TRIP_BACK"
		if beaconReceiver then
			Timer:CallAt(Game.time + 3, function ()
				Game.player:AIEnterLowOrbit(mission.target:FindNearestTo("PLANET"))
				Game.player:SetHyperspaceTarget(mission.system_local:GetStarSystem().path)
			end)
		end
	end
end

local removeMission = function (mission)
	local ref, cabins
	for i,v in pairs(missions) do
		if v == mission then
			cabins = mission.pickup_pass_orig + mission.pickup_crew_orig
			if cabins > 0 and mission.status == "TRIP_BACK" then
				Game.player:RemoveEquip(Equipment.misc.cabin_occupied, cabins)
				Game.player:AddEquip(Equipment.misc.cabin, cabins)
			end
			ref = i
			break
		end
	end
	mission:Remove()
	if missions[ref] then missions[ref] = nil end--XXX
end


-- basic mission functions
-- =======================

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

local mToAU = function (meters)	-- Transform meters into AU.
	return meters/149597870700
end

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

local shipdefFromName = function (shipdef_name)
	-- Return the corresponding shipdef for the supplied shipdef name. Necessary because serialization
	-- crashes if actual shipdef is stored in ad. There may be a smarter way to do this!
	local shipdefs = utils.build_array(utils.filter(function (_,def) return def.tag == 'SHIP'
					and def.name == shipdef_name end, pairs(ShipDef)))
	return shipdefs[1]
end

local crewPresent = function (ship)
	-- Check if any crew is present on the ship.
	if ship:CrewNumber() > 0 then
		return true
	else
		return false
	end
end

local passengersPresent = function (ship)
	-- Check if any passengers are present on the ship.
	if ship:CountEquip(Equipment.misc.cabin_occupied) > 0 then
		return true
	else
		return false
	end
end

local passengerSpace = function (ship)-- Check if the ship has space for passengers.
	if ship:CountEquip(Equipment.misc.cabin) > 0 then
		return true
	else
		return false
	end
end

local cargoPresent = function (ship, cargo, cant)-- Check if this cargo item is present on the ship.
	local count_cargo = ship:CountEquip(cargo)
	if count_cargo >= cant then
		return true
	else
		return false
	end
end

local cargoSpace = function (ship,cargo,cant)-- Check if the ship has space for additional cargo.
	if ship:GetEquipFree("cargo") >= cant then
		return true
	else
		return false
	end
end

local addCrew = function (ship, crew_member)-- Add a crew member to the supplied ship.
	if ship:CrewNumber() == ship.maxCrew then return end
	if not crew_member then
		crew_member = Character.New()
	end
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
	if not passengerSpace(ship) then return end
	ship:RemoveEquip(Equipment.misc.cabin, 1)
	ship:AddEquip(Equipment.misc.cabin_occupied, 1)
end

local removePassenger = function (ship)-- Remove a passenger from the supplied ship.
	if not passengersPresent(ship) then return end
	ship:RemoveEquip(Equipment.misc.cabin_occupied, 1)
	ship:AddEquip(Equipment.misc.cabin, 1)
end

local addCargo = function (ship, cargo, cant)-- Add a ton of the supplied cargo item to the ship.
	if not cargoSpace(ship,cargo,cant) then return end
	ship:AddEquip(cargo, cant)
end

local removeCargo = function (ship, cargo, cant)-- Remove a ton of the supplied cargo item from the ship.
	if not cargoPresent(ship, cargo, cant) then return end
	ship:RemoveEquip(cargo, cant)
end

local passEquipmentRequirements = function (requirements)-- Check if player ship passes equipment requirements for this mission.
	if requirements == {} then return true end
	for equipment,amount in pairs(requirements) do
		if Game.player:CountEquip(equipment) < amount then return false end
	end
	return true
end

local isQualifiedFor = function(ad)
	-- Return if player is qualified for this mission.

	-- collect equipment requirements per mission flavor
	local requirements = {}
	local empty_cabins = ad.pickup_crew + ad.deliver_crew + ad.pickup_pass + ad.deliver_pass
	if empty_cabins > 0 then requirements[Equipment.misc.cabin] = empty_cabins end
	if not passEquipmentRequirements(requirements) then return false else return true end
end

-- extended mission functions
-- ==========================

local calcReward = function (flavour)
	local reward
	if flavour.loctype == "FAR_PLANET" or flavour.loctype == "FAR_SPACE" then
		reward = reward_far + Engine.rand:Number(reward_far / 2 * -1, reward_far / 2)
	elseif flavour.loctype == "NEAR_PLANET" or flavour.loctype == "NEAR_SPACE" then
		reward = reward_medium + Engine.rand:Number(reward_medium / 2 * -1, reward_medium / 2)
	else
		reward = reward_near + Engine.rand:Number(reward_near / 2 * -1, reward_near / 2)
	end
	local extra = reward and (flavour.pickup_crew+flavour.pickup_pass
			+ flavour.deliver_crew+flavour.deliver_pass)
	if extra > 0 then
		reward = reward * (extra*1.8)
		if flavour.pickup_crew+flavour.pickup_pass > 0 then
			reward = reward * 2.5
		end
	end
	return reward
end

local createTargetShipParameters = function (flavour, deliver_crew, pickup_crew, pickup_pass)
-- Create the basic parameters for the target ship. It is important to set these before ad creation
-- so certain info can be included in the ad text. The actual ship is created once the mission has
-- been accepted.

	local shipdefs = utils.build_array(utils.filter(function (_,def)
		return def.tag == 'SHIP'

			and def.basePrice > 0
			and def.hyperdriveClass > 0
			and def.equipSlotCapacity.atmo_shield > 0
			and def.capacity > 29
			and def.capacity < 501
			and def.equipSlotCapacity.cabin >= pickup_pass
			and def.maxCrew >= math.max(deliver_crew, pickup_crew)
	end, pairs(ShipDef)))


	if arraySize(shipdefs) == 0 then
		print("Could not find appropriate ship type for this mission!")
		return
	end
	shipdefs = compressTableKeys(shipdefs)
	shipdef = shipdefs[Engine.rand:Integer(1,#shipdefs)]

	-- number of crew
	local crew_num
	if pickup_crew > 0 then
		crew_num = pickup_crew
	else
		crew_num = Engine.rand:Integer(shipdef.minCrew,shipdef.maxCrew)
		crew_num = crew_num - flavour.deliver_crew
		if crew_num <= 0 then crew_num = 1 end
	end

	-- label
	local shiplabel = Ship.MakeRandomLabel()
	return shipdef, crew_num, shiplabel
end

local createTargetShip = function (mission)

	-- Create the target ship to be search for.
	local ship
	local shipdef = shipdefFromName(mission.shipdef_name)

	-- spawn ship
	if   mission.flavour.loctype == "THIS_PLANET"
		or mission.flavour.loctype == "NEAR_PLANET" then--Nave aterrizada en planeta / Lat-Lon
		ship = Space.SpawnShipLanded(shipdef.id, Space.GetBody(mission.planet_target.bodyIndex),
				mission.lat, mission.long)
	elseif mission.flavour.loctype == "NEAR_SPACE" then--en el espacio, en planeta local / Distancia
		ship = Space.SpawnShipNear(shipdef.id, Space.GetBody(mission.station_target.bodyIndex),
						10000, 15000)
		ship:AIEnterMediumOrbit(Space.GetBody(mission.planet_target.bodyIndex))
	elseif Game.system.path == mission.system_target:GetStarSystem().path then
		if mission.flavour.loctype == "FAR_SPACE" then
			ship = Space.SpawnShipNear(shipdef.id,
				Space.GetBody(mission.planet_target.bodyIndex), 10000, 15000)
			ship:AIEnterMediumOrbit(ship:FindNearestTo("PLANET"))
		elseif mission.flavour.loctype == "FAR_PLANET" then
			ship = Space.SpawnShipLanded(shipdef.id,
						Space.GetBody(mission.planet_target.bodyIndex), mission.lat, mission.long)
		end
	end

	-- misc ship settings (label, crew)
	if not ship then return end
	ship:SetLabel(mission.shiplabel)
	for _ = 1, mission.crew_num do
		ship:Enroll(Character.New())
	end

	-- load a hyperdrive (if appropriate)
	local default_drive = Equipment.hyperspace['hyperdrive_'..tostring(shipdef.hyperdriveClass)]
	if default_drive then ship:AddEquip(default_drive) end

	-- load a laser
	local max_laser_size
	if default_drive then
		max_laser_size = shipdef.capacity - default_drive.capabilities.mass
	else
		max_laser_size = shipdef.capacity
	end
	local laserdefs = utils.build_array(utils.filter(function (k,l) return l:IsValidSlot('laser_front')
						and l.capabilities.mass <= max_laser_size
						and l.l10n_key:find("PULSECANNON") end, pairs(Equipment.laser)))
	local laserdef = laserdefs[Engine.rand:Integer(1,#laserdefs)]
	ship:AddEquip(laserdef)

	-- load passengers
	if mission.pickup_pass > 0 then
		ship:AddEquip(Equipment.misc.cabin_occupied, mission.pickup_pass)
	end

	-- load atmo_shield
	if shipdef.equipSlotCapacity.atmo_shield ~= 0 then
		ship:AddEquip(Equipment.misc.atmospheric_shielding)
	end

	return ship
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
		ship         = ad.shipdef_name,
		starport     = ad.station_local:GetSystemBody().name,
		shiplabel    = ad.shiplabel,
		planet       = ad.planet_target:GetSystemBody().name
		})
		form:SetMessage(introtext)

--	elseif option == 1 then
--		form:SetMessage(ad.flavour.whysomuchtext)

	elseif option == 1 then

		if   ad.flavour.loctype == "THIS_PLANET"
			or ad.flavour.loctype == "NEAR_PLANET"
			or ad.flavour.loctype == "NEAR_SPACE" then
			dist = string.format("%.0f", ad.dist)
		else
			dist = string.format("%.2f", ad.dist)
		end

		local locationtext = string.interp(ad.flavour.locationtext, {
			starport     = ad.station_local:GetSystemBody().name,
			shiplabel    = ad.shiplabel,
			system       = ad.system_target:GetStarSystem().name,
			sectorx      = ad.system_target.sectorX,
			sectory      = ad.system_target.sectorY,
			sectorz      = ad.system_target.sectorZ,
			dist         = dist,
			lat          = decToDegMinSec(math.rad2deg(ad.lat)),
			long         = decToDegMinSec(math.rad2deg(ad.long)),
			planet       = ad.planet_target:GetSystemBody().name
		})
		form:SetMessage(locationtext)

	elseif option == 2 then
		local typeofhelptext = string.interp(ad.flavour.typeofhelptext, {
			starport     = ad.station_local:GetSystemBody().name,
			crew         = ad.crew_num,
			pass         = ad.pickup_pass,
			deliver_crew = ad.deliver_crew
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
			form:SetMessage(lx.have_enough_experience.."\n*\n*")
			return
		end

		if not isQualifiedFor(ad) then
			local cabins = ad.pickup_crew + ad.deliver_crew + ad.pickup_pass + ad.deliver_pass
			local denytext = string.interp(ls.EQUIPMENT,
				{unit = cabins, equipment = ls.UNOCCUPIED_PASSENGER_CABINS})
			form:SetMessage(denytext)
			return
		end

		if beaconReceiver then
			if Game.system.path ~= ad.system_target:GetStarSystem().path then
				Game.player:SetHyperspaceTarget(ad.system_target:GetStarSystem().path)
			end
		end
		form:RemoveAdvertOnClose()
		ads[ref] = nil

		local mission = {
-- these variables are hardcoded and need to be filled
			type               = "sar",
			client	           = ad.client,
			location           = ad.location,
			due                = ad.due,
			reward             = ad.reward,
			status             = "ACTIVE",

-- these variables are script specific
			station_local      = ad.station_local,
			planet_local       = ad.planet_local,
			system_local       = ad.system_local,
			station_target     = ad.station_target,
			planet_target      = ad.planet_target,
			system_target      = ad.system_target,
			entity             = ad.entity,
			problem            = ad.problem,
			dist               = ad.dist,
			flavour            = ad.flavour,
			target             = "NIL",
			lat                = ad.lat,
			long               = ad.long,
			shipdef_name       = ad.shipdef_name,
			shiplabel          = ad.shiplabel,
			crew_num           = ad.crew_num,

			deliver_cargo      = ad.deliver_cargo,
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
		if mission.flavour.loctype ~= "FAR_SPACE" or mission.flavour.loctype ~= "FAR_PLANET" then
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


local makeAdvert = function (station, manualFlavour)
	local due, dist, client, entity, problem, location
	local lat  = 0
	local long = 0
	-- Make advertisement for bulletin board.

	-- set flavour (manually if a second arg is given)
	local flavour = flavours[manualFlavour] or flavours[Engine.rand:Integer(1,#flavours)]

	-- abort if flavour incompatible with space station type
	if flavour.loctype == "THIS_PLANET" and station.isGroundStation == false then return end

	local urgency = flavour.urgency
	local risk    = flavour.risk
	local reward  = calcReward(flavour)

	local station_local = station.path
	local planet_local = Space.GetBody(station_local:GetSystemBody().parent.index).path
	local system_local = Game.system.path
	local station_target, planet_target, system_target

	if flavour.loctype == "THIS_PLANET" then

		station_target  = station_local
		planet_target   = planet_local
		system_target   = system_local
		location        = planet_target
		lat, long, dist = randomLatLong(station)

		due = Game.time + ((24*60*60) * (Engine.rand:Number(1.5,2) - urgency))

	elseif flavour.loctype == "NEAR_PLANET" then

		local nearbyplanets = _localPlanetsWithoutStations
		if #nearbyplanets == 0 then return nil end

		station_target  = nil
		planet_target   = nearbyplanets[Engine.rand:Integer(1,#nearbyplanets)]
		system_target   = system_local
		location        = planet_target
		lat, long, dist = randomLatLong()


-- 1 día = 3 AU = 448794000000 ej. 4 dias 12 AU / plutón a 33 AU = 1795176000000 // 4 a 11 dias

		dist = mToAU(Space.GetBody(planet_local.bodyIndex):DistanceTo(Space.GetBody(planet_target.bodyIndex)))
		due = Game.time + (((dist/3)*24*60*60) * (Engine.rand:Number(1.8,2.5) - urgency))

	elseif flavour.loctype == "NEAR_SPACE" then

		station_target = station_local
		planet_target  = planet_local
		system_target  = system_local
		location       = planet_target

		dist = Engine.rand:Integer(min_close_dist,max_close_dist)
		due = Game.time + ((4*24*60*60) * (Engine.rand:Number(1.5,3.5) - urgency))

	elseif flavour.loctype == "FAR_SPACE" or flavour.loctype == "FAR_PLANET" then

		local remotesystems = Game.system:GetNearbySystems(15,
			function (s) return #s:GetBodyPaths() > 0 and s.population == 0 end)
		if #remotesystems == 0 then return end
		remotesystem = remotesystems[Engine.rand:Integer(1,#remotesystems)]
		local remotebodies = remotesystem:GetBodyPaths()
		local checkedBodies = 0
		while checkedBodies <= #remotebodies do
			location = remotebodies[Engine.rand:Integer(1,#remotebodies)]
			currentBody = location:GetSystemBody()
			if currentBody.superType == "ROCKY_PLANET"
				and currentBody.type ~= "PLANET_ASTEROID"
			then break end
			checkedBodies = checkedBodies + 1
		end
		if not currentBody or currentBody.superType ~= "ROCKY_PLANET" then return end

		planet_target = location
		if not planet_target then return nil end

		if flavour.loctype == "FAR_PLANET" then lat, long, dist = randomLatLong() end

		system_target = remotesystem.path

		local multiplier = Engine.rand:Number(1.5,1.6)
		if Game.system.faction ~= system_target:GetStarSystem().faction then
			multiplier = multiplier * Engine.rand:Number(1.3,1.5)
		end

		station_target = nil

		dist = system_local:DistanceTo(system_target)
		local dist_tot = dist
		if not flavour.reward_immediate then dist_tot = dist * 2.5 end

		due  = term(dist_tot,urgency)

		reward = tariff(dist_tot,risk,urgency,system_target)*2*multiplier

	end
	local pickup_crew, pickup_pass, deliver_crew, deliver_pass
	if flavour.id == 1 or flavour.id == 6 then
		pickup_crew  = Engine.rand:Integer(1, max_crew)
		pickup_pass  = Engine.rand:Integer(0, max_pass)
	else
		pickup_crew  = flavour.pickup_crew
		pickup_pass  = flavour.pickup_pass
	end
	if flavour.id == 7 then
		deliver_crew = Engine.rand:Integer(1, max_crew-1)
	else
		deliver_crew = flavour.deliver_crew
	end
	deliver_pass = flavour.deliver_pass
	local localities_local = {system_local:GetStarSystem().name}
	if station_local then
		table.insert(localities_local, station_local.label)--:GetSystemBody().name)
	end
	if planet_local then
		table.insert(localities_local, planet_local:GetSystemBody().name)
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
	local shipdef, crew_num, shiplabel = createTargetShipParameters(flavour,
		deliver_crew, pickup_crew, pickup_pass)
	local ad = {
		location       = location,
		station_local  = station_local,
		planet_local   = planet_local,
		system_local   = system_local,
		station_target = station_target,
		planet_target  = planet_target,
		system_target  = system_target,
		flavour        = flavour,
		client         = client,
		entity         = entity,
		problem        = problem,
		dist           = dist,
		due            = due,
		urgency        = urgency,
		risk           = risk,
		reward         = reward,
		shipdef_name   = shipdef.name,
		crew_num       = crew_num,
		pickup_crew    = pickup_crew,
		pickup_pass    = pickup_pass,
		deliver_crew   = deliver_crew,
		deliver_pass   = deliver_pass,
		deliver_cargo  = flavour.deliver_cargo,
		quantity_cargo = flavour.quantity_cargo,
		shiplabel      = shiplabel,
		lat            = lat,
		long           = long
	}
	local staport_label, planet_label, system_label
	if station_target then starport_label = station_target:GetSystemBody().name else starport_label = nil end
	if planet_target then planet_label = planet_target:GetSystemBody().name else planet_label = nil end
	if system_target then system_label = system_target:GetStarSystem().name else system_label = nil end

	ad.desc = string.interp(flavour.adtext, {
						starport = starport_label,
						planet   = planet_label,
						system   = system_label or "NOT"
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
			if mission.target ~= "NIL" and mission.status ~= "TRIP_BACK"
				and Game.system.path == mission.system_target:GetStarSystem().path
			then
				if findBeaconDone then return end
				if mission.flavour.loctype == "FAR_SPACE" or mission.flavour.loctype == "NEAR_SPACE" then
					beaconDistance = 250e6-- 250.000 km
				elseif mission.target.flightState == "LANDED" then
					beaconDistance = 50e6-- 50.000 km
				end
				if beaconDistance and Game.player:DistanceTo(mission.target) < beaconDistance then
					findBeaconDone = true
					Game.player:SetCombatTarget(mission.target)
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

local InteractionDistance = function (mission)--XXX funcion protegida
	local dist = Game.player:DistanceTo(mission.target)
	if dist <= max_interaction_dist then
		return true
	else
		return false
	end
end
local targetInteractionDistance = function (mission)
	ok,val = pcall(InteractionDistance, mission)
	if ok then
		return val
	end
end

local pickupCrew = function (mission)
	local todo = mission.pickup_crew_orig
	if not crewPresent(mission.target) then
		Comms.ImportantMessage(ls.MISSING_CREW)
		mission.pickup_crew_check = "PARTIAL"
		return
	elseif not passengerSpace(Game.player) then
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
		mission.pickup_pass_check = "PARTIAL"
		return
	elseif not passengerSpace(Game.player) then
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
	local maxcrew = shipdefFromName(mission.shipdef_name).maxCrew
	if not passengersPresent(Game.player) then
		Comms.ImportantMessage(ls.MISSING_PASS)
		mission.deliver_crew_check = "PARTIAL"
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
		mission.deliver_pass_check = "PARTIAL"
		return
	elseif not passengerSpace(mission.target) then
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
	local deliver_cargo = mission.deliver_cargo
	local cargo_name = deliver_cargo:GetName()
	local cargo_cant = mission.quantity_cargo
	if not cargoPresent(Game.player, deliver_cargo, cargo_cant) then
		local missingtxt = string.interp(ls.MISSING_COMM, {cargotype = cargo_name})
		Comms.ImportantMessage(missingtxt)
		mission.deliv_cargo_check = "ABORT"
		return
	elseif not cargoSpace(mission.target, deliver_cargo, cargo_cant) then
		Comms.ImportantMessage(ls.FULL_CARGO)
		mission.deliv_cargo_check = "ABORT"
		return
	else
		local resulttxt = string.interp(ls.RESULT_DELIVERY_COMM, {
			done = cargo_cant, todo = cargo_cant, cargotype = cargo_name})
		Comms.ImportantMessage(resulttxt)
		removeCargo(Game.player, deliver_cargo, cargo_cant)
		addCargo(mission.target, deliver_cargo, cargo_cant)
		mission.deliv_cargo_check = "COMPLETE"
	end
end

local interactionCounter = function (counter)
	counter = counter + 1
	if counter >= target_interaction_time then
		return true, counter
	else
		return false, counter
	end
end


local go_go_go = function (mission)
	Timer:CallAt(Game.time + 5, function ()
		if beaconReceiver then
			Game.player:AIEnterLowOrbit(mission.target:FindNearestTo("PLANET"))
		end
	end)
	Timer:CallAt(Game.time + 10, function ()
		if mission.target.flightState == "LANDED"
			and missionStatus(mission) == "COMPLETE"
			and mission.flavour.reward_immediate == true
		then
			mission.target:BlastOff()
		end
		Timer:CallAt(Game.time + 5, function ()
			if mission.flavour.loctype == "FLYING" then
				if mission.target.flightState == "NEAR_SPACE" then
				mission.target:AIDockWith(mission.target:FindNearestTo("SPACESTATION"))
				elseif mission.flavour.loctype == "FAR_SPACE" then
				mission.target:AIFlyTo(mission.target:FindNearestTo("STAR"))
				elseif mission.flavour.loctype == "NEAR_PLANET"
					and missionStatus(mission) == "COMPLETE" then
					mission.target:AIDockWith(mission.target:FindNearestTo("SPACESTATION"))
				end
			end
			Timer:CallAt(Game.time + Engine.rand:Integer(30,50), function ()
				if mission.target ~= "NIL" and mission.target:exists() then
					mission.target:Explode()
					mission.target = "NIL"
				end
			end)
		end)
	end)
end


local interactWithTarget = function (mission)
	if not targetInteractionDistance(mission) then return end
	local packages = mission.pickup_crew + mission.pickup_pass + mission.deliver_crew + mission.deliver_pass
	packages = packages + mission.quantity_cargo
	local total_interaction_time = target_interaction_time * packages
	local distance_reached_txt = string.interp(ls.INTERACTION_DISTANCE_REACHED,
			{seconds = total_interaction_time})
	Comms.ImportantMessage(distance_reached_txt)
	local song
	if Music.IsPlaying then song = Music.GetSongName() end
	Music.Play("music/core/fx/rescue01",false)
	Timer:CallAt(Game.time + total_interaction_time, function ()
		Music.Stop()
		if song then Music.Play(song, false) end
	end)
	local counter = 0
	Timer:CallEvery(1, function ()
		local done = true
		if not targetInteractionDistance(mission) or mission.target == "NIL" then
			Comms.ImportantMessage(ls.INTERACTION_ABORTED)
			searchForTarget()
			return true
		end
		local actiontime
		actiontime, counter = interactionCounter(counter)
		if actiontime then
			if mission and mission.pickup_crew > 0 and mission.pickup_crew_check ~= "PARTIAL" then
				done = false
				pickupCrew(mission)
			elseif mission and mission.deliver_crew > 0 and mission.deliver_crew_check ~= "PARTIAL" then
				done = false
				deliverCrew(mission)
			elseif mission and mission.pickup_pass > 0 and mission.pickup_pass_check ~= "PARTIAL" then
				done = false
				pickupPassenger(mission)
			elseif mission and mission.deliver_pass > 0 and mission.deliver_pass_check ~= "PARTIAL" then
				done = false
				deliverPassenger(mission)
			elseif mission.quantity_cargo > 0  and
					mission.deliv_cargo_check ~= "PARTIAL" then
				deliverCargo(mission)
			end
--[[
print("mission.deliv_cargo_check = "..mission.deliv_cargo_check)
print("missionStatus(mission) = "..missionStatus(mission))

 teminacion anormal, player NO tiene el producto requerido
mission.deliv_cargo_check = ABORT < la nave no tiene cargo
missionStatus(mission) = PARTIAL  <     "        "     "

 teminacion normal, player SI tiene el producto requerido
mission.deliv_cargo_check = COMPLETE
missionStatus(mission) = COMPLETE
--]]
			if done then
				if mission.flavour.reward_immediate == true
					and missionStatus(mission) == "COMPLETE" then
					Comms.ImportantMessage(lx.MISSION_ACCOMPLISHED)
					go_go_go(mission)
					closeMission(mission)-- cuidado donde se ubica esto XXX
				elseif missionStatus(mission) == "COMPLETE" then
					trip_back(mission)
					go_go_go(mission)
				end
				Timer:CallAt(Game.time + 10, function ()
					searchForTarget()
					findBeaconDone = false
					findBeacon()
				end)
				if   missionStatus(mission) == "COMPLETE"
					or missionStatus(mission) == "PARTIAL"
					or missionStatus(mission) == "TRIP_BACK" then
					return true
				else
					return false
				end
			end
		end
	end)
end

function searchForTarget ()
	for ref,mission in pairs(missions) do
		if Game.time > mission.due
			and mission.flavour.reward_immediate == true then
		closeMission(mission) end
		if mission.target ~= "NIL"
			and Game.system.path == mission.system_target:GetStarSystem().path
			and not mission.searching
			and (((mission.flavour.loctype == "FAR_SPACE" or mission.flavour.loctype == "NEAR_SPACE")
				and mission.target.flightState == "FLYING") or mission.target.flightState == "LANDED") then
			if mission.target and Game.player.frameBody == mission.target.frameBody then
				mission.searching = true
				local message_counter = {INTERACTION_DISTANCE_REACHED = 1}
				local true_system = Game.system.path
				Timer:CallEvery(1, function ()
					if not Game.system then return true end
					if Game.system.path ~= true_system then
						mission.searching = false
						return true
					elseif mission.target ~= "NIL" and mission.target:exists()
						and Game.player.frameBody ~= mission.target.frameBody then
						mission.searching = false
						return true
					else
						if not targetInteractionDistance(mission) then
							if message_counter.INTERACTION_DISTANCE_REACHED == 0 then
								Comms.ImportantMessage(ls.INTERACTION_ABORTED)
								message_counter.INTERACTION_DISTANCE_REACHED = 1
							end
							return false
						else
							if Game.time > mission.due then
								Comms.ImportantMessage(ls.SHIP_UNRESPONSIVE)
								closeMission(mission)
								return true
							else
								interactWithTarget(mission)
								mission.searching = false
								return true
							end
						end
					end
				end)
			end
		end
	end
end

local onFrameChanged = function (body)
-- Start a new search for target every time the reference frame for player changes.
	if not body:isa("Ship") or not body:IsPlayer() then return end
	searchForTarget()
	findBeacon()
end

local onShipUndocked = function (ship, station)
	if not ship:IsPlayer() then return end
	Timer:CallAt(Game.time + 8, function ()
		searchForTarget()
		findBeacon()
	end)
end

local onCreateBB = function (station)
	local num = Engine.rand:Integer(0, math.ceil(Game.system.population))
	if num > 3 then num = 3 end
---[[
	for i = 1,num do
		makeAdvert(station)
	end
--]]
--[[
num=3
	for i = 1,num do
--		local ad = makeAdvert(station, 1)
		local ad = makeAdvert(station, 2)
--		local ad = makeAdvert(station, 3)
		local ad = makeAdvert(station, 4)
		local ad = makeAdvert(station, 5)
--		local ad = makeAdvert(station, 6)
--		local ad = makeAdvert(station, 7)
	end--]]
end

local onUpdateBB = function (station)
	for ref,ad in pairs(ads) do
		if ad.flavour.loctype == "THIS_PLANET" or ad.flavour.loctype == "NEAR_SPACE" then
			if ad.due < Game.time + 2*60*60 then
				Space.GetBody(ad.station_local.bodyIndex):RemoveAdvert(ref)
			end
		elseif ad.flavour.loctype == "NEAR_PLANET" then
			if ad.due < Game.time + 24*60*60 then
				Space.GetBody(ad.station_local.bodyIndex):RemoveAdvert(ref)
			end
		else
			if ad.due < Game.time + 4*24*60*60 then
				Space.GetBody(ad.station_local.bodyIndex):RemoveAdvert(ref)
			end
		end
	end
	if Engine.rand:Integer(12*60*60) < 60*60 then-- add ads randomly about every 12 hours
		makeAdvert(station)
	end
end

local onEnterSystem = function (player)
	if (not player:IsPlayer()) then return end
	local syspath = Game.system.path
	for ref,mission in pairs(missions) do-- spawn mission target ships in this system unless due time expired
		if mission.due > Game.time and mission.system_target:IsSameSystem(syspath) then
			mission.target = createTargetShip(mission)
			return
		end
	end
end

local onShipDocked = function (player, station)
	if not player:IsPlayer() then return end
	findBeaconDone = false--XXX
	for ref, mission in pairs(missions) do
		if Space.GetBody(mission.station_local.bodyIndex) == station then
			closeMission(mission)
		end
	end
end


local onClick = function (mission)
	local dist = Game.system and string.format("%.2f",
		Game.system:DistanceTo(mission.system_target:GetStarSystem())) or "???"
	local danger
--[[	if mission.flavour.risk == 0 then
		if Engine.rand:Integer(1) == 0 then
			danger = (lx.I_HIGHLY_DOUBT_IT)
		else
			danger = (lx.NOT_ANY_MORE_THAN_USUAL)
		end
	elseif mission.flavour.risk == 1 then
		danger = (lx.YOU_SHOULD_KEEP_YOUR_EYES_OPEN)
	elseif mission.flavour.risk == 2 then
		danger = (lx.IT_COULD_BE_DANGEROUS)
	elseif mission.flavour.risk == 3 then
		danger = (lx.THIS_IS_VERY_RISKY)
	end--]]
	local dist_for_text = Format.Distance(mission.dist or 0)
	if mission.flavour.loctype   == "THIS_PLANET" then
		dist_for_text = string.format("%.0f", mission.dist).." "..lx.KM
	elseif mission.flavour.loctype == "NEAR_SPACE" then
		dist_for_text = lx.UNKNOWN
	elseif mission.flavour.loctype == "NEAR_PLANET" then
			dist_for_text = string.format("%.2f", mission.dist or 0).." "..lx.AU
	elseif mission.flavour.loctype == "FAR_PLANET" or mission.flavour.loctype == "FAR_SPACE" then
			dist_for_text = string.format("%.2f", mission.dist or 0).." "..lx.LY
	end
	local merchandise = lx.NONE
	if mission.quantity_cargo and mission.deliver_cargo then
		merchandise = string.interp(lx.COMMODITY, {
				quantity = mission.quantity_cargo,
				product  = mission.deliver_cargo:GetName()})
	end
	Comms.ImportantMessage(merchandise)
	local payment_address = mission.station_local:GetSystemBody().name
	if mission.flavour.reward_immediate == true then payment_address = lx.THE_PLACE_OF_ASSISTANCE end
	local mission_target
	if mission.lat == 0 and mission.long == 0 then
		mission_target = mission.planet_target:GetSystemBody().name.."\n"..lx.ORBIT
	else
		mission_target = mission.planet_target:GetSystemBody().name..
											"\n"..lx.LAT.." "..decToDegMinSec(math.rad2deg(mission.lat))
									.." // "..lx.LON.." "..decToDegMinSec(math.rad2deg(mission.long))
	end
	return
			ui:Grid({68,32},1)
				:SetColumn(0,{ui:VBox():PackEnd({
					ui:Margin(10),
					ui:Grid(2,1)
						:SetColumn(0, {ui:VBox():PackEnd({ui:Label(lx.TARGET_SHIP)})})
						:SetColumn(1, {ui:VBox():PackEnd({ui:MultiLineText(mission.shipdef_name
									.." <"..mission.shiplabel.."> ")})}),
					ui:Grid(2,1)
						:SetColumn(0, {ui:VBox():PackEnd({ui:Label(lx.LAST_KNOWN_LOCATION)})})
						:SetColumn(1, {ui:VBox():PackEnd({ui:MultiLineText(mission_target)
								})}),
					ui:Margin(10),
					ui:Grid(2,1)
						:SetColumn(0, {ui:VBox():PackEnd({ui:Label(ls.SYSTEM)})})
						:SetColumn(1, {ui:VBox():PackEnd({
								ui:MultiLineText(mission.system_target:GetStarSystem().name
									.." ("..mission.system_target.sectorX
									.. ","..mission.system_target.sectorY
									.. ","..mission.system_target.sectorZ..")")})}),
					ui:Grid(2,1)
						:SetColumn(0, {ui:VBox():PackEnd({ui:Label(ls.DISTANCE)})})
						:SetColumn(1, {ui:VBox():PackEnd({ui:Label(dist_for_text)})}),
					ui:Margin(5),
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
						:SetColumn(0, {ui:VBox():PackEnd({ui:Label(lx.REWARD)})})
						:SetColumn(1, {ui:VBox():PackEnd({ui:MultiLineText(showCurrency(mission.reward))})}),
					ui:Margin(5),
					ui:Grid(2,1)
						:SetColumn(0, {ui:VBox():PackEnd({ui:Label(lx.THE_REWARD_IS_PAID_IN)})})
						:SetColumn(1, {ui:VBox():PackEnd({ui:Label(payment_address)})}),
					ui:Grid(2,1)
						:SetColumn(0, {ui:VBox():PackEnd({ui:Label(ls.SYSTEM)})})
						:SetColumn(1, {ui:VBox():PackEnd({
								ui:MultiLineText(mission.system_local:GetStarSystem().name
									.." ("..mission.system_local.sectorX
									..","..mission.system_local.sectorY
									..","..mission.system_local.sectorZ..")")})}),
					ui:Margin(5),
					ui:Grid(2,1)
						:SetColumn(0, {ui:VBox():PackEnd({ui:Label(ls.DEADLINE)})})
						:SetColumn(1, {ui:VBox():PackEnd({ui:Label(Format.Date(mission.due))})}),
--[[					ui:Margin(5),
					ui:Grid(2,1)
						:SetColumn(0, {ui:VBox():PackEnd({ui:Label(ls.DANGER)})})
						:SetColumn(1, {ui:VBox():PackEnd({ui:MultiLineText(danger)})}),--]]
		})})
		:SetColumn(1, {ui:VBox(10):PackEnd(InfoFace.New(mission.client))})
end

local onShipDestroyed = function (ship, attacker)
	for ref,mission in pairs(missions) do
		if ship == mission.target then
			mission.target = "NIL"
		end
	end
end

local loaded_data
local onGameStart = function ()
	ads = {}
	missions = {}
	if not loaded_data or not loaded_data.ads then return end
	for k,ad in pairs(loaded_data.ads) do
		local ref = Space.GetBody(ad.station_local.bodyIndex):
			AddAdvert({
				description = ad.desc,
				icon        = ad.risk > 0.4 and "rescue_danger" or "rescue",
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
	searchForTarget()
	findBeaconDone = false
	findBeacon()
end

local serialize = function ()
	return { ads = ads, missions = missions }
end

local unserialize = function (data)
	loaded_data = data
end

Event.Register("onCreateBB", onCreateBB)
Event.Register("onUpdateBB", onUpdateBB)
Event.Register("onEnterSystem", onEnterSystem)
Event.Register("onShipDocked", onShipDocked)
Event.Register("onGameStart", onGameStart)
Event.Register("onShipUndocked", onShipUndocked)
Event.Register("onFrameChanged", onFrameChanged)
Event.Register("onShipDestroyed", onShipDestroyed)

Mission.RegisterType("sar",ls.SAR,onClick)

Serializer:Register("sar", serialize, unserialize)
