-- Copyright © 2008-2015 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt

local Game      = import("Game")
local Event     = import("Event")
local Character = import("Character")
local Comms     = import("Comms")
local Constant  = import("Constant")

local Lang = import("Lang")

local l = Lang.GetResource("module-statstracking")
local lc    = Lang.GetResource("ui-core")

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
-- >         'COMPETENT','DANGEROUS','DEADLY','ELITE'
--
local onShipDestroyed = function (ship, attacker)
	if attacker:isa('Ship') and attacker:IsPlayer() then
		-- Increment player's kill count
		Character.persistent.player.killcount = Character.persistent.player.killcount + 1
		PlayerDamagedShips[ship]=nil
		if Character.persistent.player.killcount == 1--      level 0 HARMLESS
			or Character.persistent.player.killcount == 8--    level 1 MOSTLY_HARMLESS
			or Character.persistent.player.killcount == 16--   level 2 POOR
			or Character.persistent.player.killcount == 32--   level 3 AVERAGE
			or Character.persistent.player.killcount == 64--   level 4 ABOVE_AVERAGE
			or Character.persistent.player.killcount == 128--  level 5 COMPETENT
			or Character.persistent.player.killcount == 512--  level 6 DANGEROUS
			or Character.persistent.player.killcount == 1024-- level 7 DEADLY
			or Character.persistent.player.killcount == 2048-- level 8 ELITE
			or Character.persistent.player.killcount == 4096-- level 9 GOD OF DEATH :)
		then
			local station = attacker:FindNearestTo("SPACESTATION")
			if not station or station:DistanceTo(attacker) > 100e3 then
				Comms.Message(l.WELL_DONE_COMMANDER_YOUR_COMBAT_RATING_HAS_IMPROVED,l.PIONEERING_PILOTS_GUILD)
			else
				local crime = "MURDER"
				Comms.ImportantMessage(string.interp(lc.X_CANNOT_BE_TOLERATED_HERE, {crime=Constant.CrimeType[crime].name}), Game.system.faction.policeName)
				local fine = math.max(1, 1+math.floor(Constant.CrimeType[crime].basefine * (1.0-Game.system.lawlessness)))
				Game.player:AddCrime(crime, fine)
			end
		end
	elseif PlayerDamagedShips[ship] then
		Character.persistent.player.assistcount = Character.persistent.player.assistcount + 1
	end
end
Event.Register("onShipDestroyed",onShipDestroyed)

local onShipHit = function (ship, attacker)
	if attacker and attacker:isa("Ship") and attacker:IsPlayer() then
		if ship then
			PlayerDamagedShips[ship]=true
			local station = attacker:FindNearestTo("SPACESTATION") or nil-- quiero estar seguro :)
			if station and station:DistanceTo(attacker) < 100000 then
				local crime = "PIRACY"
				Comms.ImportantMessage(string.interp(lc.X_CANNOT_BE_TOLERATED_HERE, {crime=Constant.CrimeType[crime].name}), Game.system.faction.policeName)
				local fine = math.max(1, 1+math.floor(Constant.CrimeType[crime].basefine * (1.0-Game.system.lawlessness)))
				Game.player:AddCrime(crime, fine)
			end
		end
	end
end
Event.Register("onShipHit",onShipHit)
