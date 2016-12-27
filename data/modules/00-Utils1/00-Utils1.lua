-- 00-utils.lua for Pioneer Scout+ (c)2012-2015 by walterar <walterar2@gmail.com>
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt
-- Work in progress.

local Engine     = import("Engine")
local Game       = import("Game")
local StarSystem = import("StarSystem")
local Space      = import("Space")
local utils      = import("utils")
local ShipDef    = import("ShipDef")
local Ship       = import("Ship")
local Lang       = import("Lang")
local Eq         = import("Equipment")
local Laws       = import("Laws")
local Music      = import("Music")
local Comms      = import("Comms")
local Format     = import("Format")

local lc = Lang.GetResource("core") or Lang.GetResource("core","en")
local lu = Lang.GetResource("ui-core") or Lang.GetResource("ui-core","en")
local lm = Lang.GetResource("miscellaneous") or Lang.GetResource("miscellaneous","en")

local AU = 149597870700

_G.songOk = function ()
--	local SongName = Music.GetSongName()
--	if SongName then Music.Stop() end
	Music.Play("music/core/fx/Ok", false)
end

local factor_x = function ()
	local locate = Game.system.path
	local sectorz = math.abs(locate.sectorZ)
	if sectorz > 50 then sectorz = 50 end
	local multiplier = 1 + ((math.abs(locate.sectorX) + math.abs(locate.sectorY) + sectorz)/100)
	if string.sub(Game.player.label,1,2) ~= string.upper(string.sub(Game.system.faction.name,1,2)) then
		multiplier = multiplier * 1.5
	end
	local lawlessness = Game.system.lawlessness
	local population = Game.system.population
	if population > 1 then population = 1+population/100
	else
		population = 1+population
	end
	return math.ceil(1
		* (1 + lawlessness)
		/ (1 + population))
		* multiplier
end

_G.crime_fine = function (crime)
	return math.max(1, 1+math.floor(
		Laws.CrimeType[crime].basefine
		* factor_x()))
end

_G.check_crime = function (mission,crime)
	if Game.time > (mission.due + (60*60*24*30)) then-- 30 dias de demora = fraude
		Comms.ImportantMessage(string.interp(lu.X_CANNOT_BE_TOLERATED_HERE,
						{ crime = Laws.CrimeType[crime].name,
							fine  = crime_fine(crime)
						}), Game.system.faction.policeName)
		Game.player:AddCrime(crime, crime_fine(crime))
		return true
	end
end

_G.TimeLeft = function (due)
	if due < Game.time then return end
	local time_left = (due - Game.time)
	local secs = string.format("%02.f",time_left%60)
	local mins = string.format("%02.f",(time_left/60)%60)
	local hours = string.format("%02.f",(time_left/60/60)%24)
	local days = string.format(lu.D_DAYS_LEFT,(time_left/60/60/24))
	return days.." "..hours..":"..mins..":"..secs
end

--_G._reward_time(mission,base)
-- a tariff (reward) calculator
_G.tariff = function (dist,risk,urgency,locate)--,base)

	local typ = 70 -- $70 * light year, basic.(+risk+urgency+lawlessness-population)*multiplier

	local sectorz = math.abs(locate.sectorZ)

	local multiplier = 1 + ((math.abs(locate.sectorX) + math.abs(locate.sectorY) + sectorz)/100)
	if string.sub(Game.player.label,1,2) == string.upper(string.sub(Game.system.faction.name,1,2)) then
		multiplier = multiplier * Engine.rand:Number(1.3,1.4)
	end

	local lawlessness = Game.system.lawlessness
	local population = Game.system.population
	if population > 1 then population = 1+population/100
	else
		population = 1+population
	end
	return math.ceil(dist * (typ
		* (1 + (risk/10)*3)
		* (1 + urgency)
		* (1 + lawlessness))
		/ (1 + population))
		* multiplier * Engine.rand:Number(1,1.3)
end

_G._local_due = function (station,location,urgency,round_trip)
	urgency = urgency or 0
	local AU = 149597870700
	local dist = station:DistanceTo(Space.GetBody(location.bodyIndex))/AU
	local double=1
	if round_trip then double=2.25 end
	local dist = dist*double
	local due
	if dist < 0.5 then
		due = Game.time + ((dist/3)*24*60*60)+(4*60*60*(2.5-urgency))
	else
		due = Game.time + ((math.sqrt(dist))*24*60*60)+((2*double*(2.5-urgency))*24*60*60)
	end
	return due
end

-- a time limit (due) calculator
_G._remote_due = function (dist,urgency,round_trip)
	local round=1
	if round_trip then round=2.25 end
	return Game.time + (math.sqrt(dist)*24*60*60)+((4*round*(2.5-urgency))*24*60*60)
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

-- a attackers (hostile - pirates) generator
_G.ship_hostil = function (risk)
	if risk < 1 then return end
	local hostil,hostile
	local count_hostiles = risk

	local hostiles = utils.build_array(utils.filter(function (k,def)
		return def.tag == 'SHIP'
			and  def.capacity >= 20
			and  def.capacity <= 100
			and  def.hyperdriveClass > 0
	end, pairs(ShipDef)))

	if #hostiles > 0 then
		while count_hostiles > 0 do
			count_hostiles = count_hostiles - 1
			local hostile = hostiles[Engine.rand:Integer(1,#hostiles)]
			local default_drive = Eq.hyperspace['hyperdrive_'..tostring(hostile.hyperdriveClass)]
			local max_laser_size = hostile.capacity - default_drive.capabilities.mass
			local laserdefs = utils.build_array(utils.filter(function (k,l)
				return l:IsValidSlot('laser_front')
					and l.capabilities.mass <= max_laser_size
					and l.l10n_key:find("PULSECANNON")
			end, pairs(Eq.laser)))
			local laserdef = laserdefs[Engine.rand:Integer(1,#laserdefs)]
			local target = Game.player:GetNavTarget()
			if target and target.type == 'STARPORT_ORBITAL' then
				hostil = Space.SpawnShipNear(hostile.id, target,10,10)--15,20)
			elseif target and target.type == 'STARPORT_SURFACE' then
				hostil = Space.SpawnShipLandedNear(hostile.id, target,50,100)
			elseif target and target:isa("Ship") then
				if target.flightState == 'LANDED' then
					hostil = Space.SpawnShipNear(hostile.id, Game.player,50,100)
				else
					hostil = Space.SpawnShipNear(hostile.id, Game.player,15,30)
				end
			else
				hostil = Space.SpawnShipNear(hostile.id, Game.player,30,30)
			end
			if ShipExists(hostil) then
				hostil:AddEquip(default_drive)
				hostil:AddEquip(laserdef)
				hostil:SetLabel(Ship.MakeRandomLabel())
				if hostil.flightState == 'LANDED' then hostil:BlastOff() end
				hostil:AIKill(Game.player)
			else
				hostil = nil
			end
		end
	end
	return hostil-- el último hostil manda mensaje intimidatorio
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

---===================================================================
-- function showCurrency(amount, decimal, prefix, neg_prefix)
-- ej. showCurrency(amount, 2, "$", "-")
-- original from sam_lie http://lua-users.org/wiki/FormattingNumbers
-- modified for Pioneer Scout+ by walterar
---===================================================================
--
local thousands_separator = "%1"..lc.NUMBER_GROUP_SEP.."%2"
local decimal_separator = lc.NUMBER_DECIMAL_POINT

local function comma_value(amount)
	local formatted = amount
	while true do
		if thousands_separator == "%1".." ".."%2" and amount <= 10000 then-- pl
			formatted, k = string.gsub(formatted, "^(-?%d%d+)(%d%d%d)", thousands_separator)
		else
	formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", thousands_separator)
		end
		if (k==0) then
			break
		end
	end
	return formatted
end

---===================================================================
-- rounds a number to the nearest decimal places
--
local function round(val, decimal)
		return tonumber(string.format("%." .. (decimal or 0) .. "f", val))
end
--====================================================================
-- given a numeric value formats output with comma to separate thousands
-- and rounded to given decimal places
--
function _G.showCurrency(amount, decimal, prefix, neg_prefix)
	local str_amount,  formatted, famount, remain
	amount     = amount     or 0
	decimal    = decimal    or 2  -- default 2 decimal places
	prefix     = prefix     or "$" -- default dollar
	neg_prefix = neg_prefix or "-" -- default negative sign

	famount = math.abs(round(amount,decimal))
	famount = math.floor(famount)

	remain = round(math.abs(amount) - famount, decimal)

-- comma to separate the thousands
	formatted = comma_value(famount)

-- attach the decimal portion
	if (decimal > 0) then
		remain = string.sub(tostring(remain),3)
		formatted = formatted .. decimal_separator .. remain .. string.rep("0", decimal - string.len(remain))
	end

-- attach prefix string e.g '$'
	formatted = (prefix or "") .. formatted

-- if value is negative then format accordingly
	if (amount<0) then
		if (neg_prefix=="()") then
			formatted = "("..formatted ..")"
		else
			formatted = neg_prefix .. formatted
		end
	end

	return formatted
end

--[[
Example usage:

amount = 1333444.1
print(showCurrency(amount,2))
print(showCurrency(amount,-2,"US$"))
Output:
1,333,444.10
US$1,333,400

amount = -22333444.5634
print(showCurrency(amount,2,"$"))
print(showCurrency(amount,2,"$","()"))
print(showCurrency(amount,3,"$","NEG "))
Output:
-$22,333,444.56
($22,333,444.56)
NEG $22,333,444.563
--]]

function _G._bodyPathToBody(BodyPath)
	local body = Space.GetBody(BodyPath.bodyIndex) or false
	return body
end

function _G.policingArea(ship)
	local ship = ship or Game.player
	local station = ship:FindNearestTo("SPACESTATION")
	local policingArea = false
	if station and station:DistanceTo(ship) < 1e5 then
		policingArea = true
	end
	return policingArea
end

function _G._distTxt(location)
	local dist_txt, dist
	if Game.system then
		if location:GetStarSystem() == Game.system then
			dist = Game.player:DistanceTo(Space.GetBody(location.bodyIndex))/AU
			if dist < 0.01 then
				dist =  Game.player:DistanceTo(Space.GetBody(location.bodyIndex))/1000
				dist_txt = string.format('%.2f %s', dist, lm.KM)
			else
				dist_txt = string.format('%.2f %s', dist, lm.AU)
			end
		else
			dist_txt = Game.system and string.format('%.2f %s', Game.system:DistanceTo(location), lm.LY)
		end
	else
		dist_txt = lm.HYPERSPACE
	end
	return dist_txt
end
