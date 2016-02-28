-- Copyright © 2008-2016 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt
-- modified for Pioneer Scout+ (c)2012-2015 by walterar <walterar2@gmail.com>
-- Work in progress.

local Game      = import("Game")
local Event     = import("Event")
local Character = import("Character")
local Comms     = import("Comms")
local Laws      = import("Laws")
local Timer     = import("Timer")

local Lang = import("Lang")

local l  = Lang.GetResource("module-statstracking") or Lang.GetResource("module-statstracking","en")
local lc = Lang.GetResource("core") or Lang.GetResource("core","en")
local lu = Lang.GetResource("ui-core") or Lang.GetResource("ui-core","en")

-- Stats-gathering module. Initially, gathers kill statistics for the player.
-- Can (and should) be expanded in the future to gather other information.

-- The information gathered here is stored in the player's character sheet.
-- This is globally available to all Lua scripts. Retrieval methods should
-- be implemented as part of Characters.lua.

-- This is used for tracking which ships were damaged by the player, so that
-- we can award assists as well as kills. One day, assists might contribute to
-- the combat rating.
local PlayerDamagedShips = {}

-- >         'HARMLESS','MOSTLY_HARMLESS','POOR','AVERAGE','ABOVE_AVERAGE',
-- >         'COMPETENT','DANGEROUS','DEADLY','ELITE','GOD OF DEATH' :)
--
local onShipDestroyed = function (ship, attacker)
	if attacker == Game.player then
		-- Increment player's kill count
		local kills = Character.persistent.player.killcount
		kills = kills + 1
		Character.persistent.player.killcount = kills
		PlayerDamagedShips[ship]=nil
		if policingArea() and playerAlert ~= "SHIP_FIRING" then
			local crime = "MURDER"
			Comms.ImportantMessage(string.interp(lu.X_CANNOT_BE_TOLERATED_HERE, {crime=Laws.CrimeType[crime].name}), Game.system.faction.policeName)
			Game.player:AddCrime(crime, crime_fine(crime))
		else
			if   kills == 1--    level 0 HARMLESS
				or kills == 8--    level 1 MOSTLY_HARMLESS
				or kills == 16--   level 2 POOR
				or kills == 32--   level 3 AVERAGE
				or kills == 64--   level 4 ABOVE_AVERAGE
				or kills == 128--  level 5 COMPETENT
				or kills == 512--  level 6 DANGEROUS
				or kills == 1024-- level 7 DEADLY
				or kills == 2048-- level 8 ELITE
				or kills == 4096-- level 9 ADDICTED TO LYING :)
			then
				Comms.Message(l.WELL_DONE_COMMANDER_YOUR_COMBAT_RATING_HAS_IMPROVED,l.PIONEERING_PILOTS_GUILD)
			end
		end
	elseif PlayerDamagedShips[ship] then
		Character.persistent.player.assistcount = Character.persistent.player.assistcount + 1
	end
end
Event.Register("onShipDestroyed",onShipDestroyed)

local penalizedCollided = false
local onShipCollided = function (ship, other)
	if (ship and ship.label == lc.MISSILE)
		or (other and other.label == lc.MISSILE)
		or not other:isa("Ship") then
	return end--XXX
	if other==Game.player and ship and (ship:isa("Ship") or ship:isa("static")) then
		PlayerDamagedShips[ship]=true
		if policingArea() and not penalizedCollided
			and Game.player:DistanceTo(Game.player:FindNearestTo("SPACESTATION")) > 20e3
		then
			penalizedCollided=true
			local crime = "PIRACY"
			Comms.ImportantMessage(string.interp(lu.X_CANNOT_BE_TOLERATED_HERE,
					{crime=Laws.CrimeType[crime].name}), Game.system.faction.policeName)
			Game.player:AddCrime(crime, crime_fine(crime))
			Timer:CallAt(Game.time + 5, function ()
				penalizedCollided = false
			end)
		end
	end
end
Event.Register("onShipCollided",onShipCollided)

local penalizedHit = false
local onShipHit = function (ship, attacker)
	if (ship and ship.label == lc.MISSILE)
		or (attacker and attacker.label == lc.MISSILE)
		or MissileActive > 0
	then return end--XXX
	if attacker == Game.player and not penalizedHit then
		if ship then
			PlayerDamagedShips[ship]=true
			if policingArea() and playerAlert ~= "SHIP_FIRING" then
				penalizedHit = true
				local crime = "PIRACY"
				Comms.ImportantMessage(string.interp(lu.X_CANNOT_BE_TOLERATED_HERE, {crime=Laws.CrimeType[crime].name}), Game.system.faction.policeName)
				Game.player:AddCrime(crime, crime_fine(crime))
				Timer:CallAt(Game.time + 5, function ()
					penalizedHit = false
				end)
			end
		end
	end
end
Event.Register("onShipHit",onShipHit)
