-- 00-utils.lua for Pioneer Scout+ (c)2013-2014 by walterar <walterar2@gmail.com>
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt
-- Work in progress.

--local Lang       = import("Lang")
local Engine     = import("Engine")
local Game       = import("Game")
local StarSystem = import("StarSystem")
local Space      = import("Space")
local utils      = import("utils")
local EquipDef   = import("EquipDef")
local ShipDef    = import("ShipDef")
local Ship       = import("Ship")

-- a tariff (reward) calculator
_G.tariff = function (dist,risk,urgency,locate)
	local typ = 70 -- $70 * light year, basic.(+risk+urgency+lawlessness-population)*multiplier

	local sectorz = math.abs(locate.sectorZ)
	if sectorz > 50 then sectorz = 50 end

	local multiplier = 1 + ((math.abs(locate.sectorX) + math.abs(locate.sectorY) + sectorz)/100)
	if string.sub(Game.player.label,1,2) == string.upper(string.sub(Game.system.faction.name,1,2)) then
		multiplier = multiplier * 1.3--Engine.rand:Number(1.2,1.4)
	end

	local population = Game.system.population
	if population > 1 then population = 1 end
	return math.ceil(((dist * typ)
		* (1 + (risk/3))
		* (1 + urgency)
		* (1 + Game.system.lawlessness)
		/ (1 + (population/2)))
		* multiplier)
end

-- a time limit (due) calculator
_G.term = function (dist,urgency)
	return Game.time + ((dist * (1.5 - urgency)) * 86400)
end

-- a attackers (hostile - pirates) generator
_G.ship_hostil = function (risk)
	if risk < 1 then return end
	local hostil,hostile
	local count_hostiles = Engine.rand:Integer(1,risk)
	if DangerLevel > 1 then count_hostiles = risk end
	local capacity1 = 20
	local capacity2 = 400
	if DangerLevel > 1 then
		capacity1 = 40
		capacity2 = 400
	end
	local hostiles = utils.build_array(utils.filter(function (k,def)
		return
			def.tag == 'SHIP'
			and def.capacity >= capacity1
			and def.capacity <= capacity2
			and def.defaultHyperdrive ~= "NONE"--inter_shuttle 20t no cannon
		end, pairs(ShipDef)))
	if #hostiles > 0 then
		while count_hostiles > 0 do
			count_hostiles = count_hostiles - 1
			if Engine.rand:Number(1) <= risk then
				local hostile = hostiles[Engine.rand:Integer(1,#hostiles)]
				local default_drive = hostile.defaultHyperdrive
				local max_laser_size = hostile.capacity - EquipDef[default_drive].mass
				local laserdefs = utils.build_array(utils.filter(function (k,def)
					return
						def.slot == 'LASER'
						and def.mass <= max_laser_size
						and string.sub(def.id,0,11) == 'PULSECANNON'
					end, pairs(EquipDef)))
				local laserdef = laserdefs[Engine.rand:Integer(1,#laserdefs)]
				hostil = Space.SpawnShipNear(hostile.id, Game.player,2,2)
				hostil:AddEquip(default_drive)
				hostil:AddEquip(laserdef.id)
				hostil:SetLabel(Ship.MakeRandomLabel())
				hostil:AIKill(Game.player)
			end
		end
	end
	return hostil
end

-- GetNearbyStation by John Bartolomew
--
-- Gets a list of stations in nearby systems that match some criteria.
--
-- Example:
--
--   local orbital_ports = Game.system:GetNearbyStationPaths(
--       30, nil, function (station) return station.type == 'STARPORT_ORBITAL' end, true)
--
--   for i = 1, #orbital_ports do
--       local path = orbital_ports[i]
--       print(path, ' -- ', path:GetSystemBody().name, ' in system ', path:GetStarSystem().name)
--   end
--
-- Parameters:
--
--   range_ly        Range limit for nearby systems to search.
--   system_filter   [optional] function, taking a StarSystem object, used to filter systems.
--   station_filter  [optional] function, taking a SystemBody object, used to filter stations.
--   include_local   [optional] if this is true, then stations in the origin system will be included.
--
function StarSystem:GetNearbyStationPaths(range_ly, system_filter, station_filter, include_local)
	local full_system_filter
	if system_filter then
		full_system_filter = function (sys) return (#sys:GetStationPaths() > 0) and system_filter(sys) end
	else
		full_system_filter = function (sys) return (#sys:GetStationPaths() > 0) end
	end
	local nearby_systems = Game.system:GetNearbySystems(range_ly, full_system_filter)

	local function filter_and_add_stations(output_table, sys)
		local station_paths = sys:GetStationPaths()
		for j = 1, #station_paths do
			local station_path = station_paths[j]
			local station = station_path :GetSystemBody()
			if station_filter == nil or station_filter(station) then
				table.insert(output_table, station_path)
			end
		end
	end

	local nearby_stations = {}
	if include_local == true then
		filter_and_add_stations(nearby_stations, self)
	end
	for i = 1, #nearby_systems do
		filter_and_add_stations(nearby_stations, nearby_systems[i])
	end

	return nearby_stations
end
