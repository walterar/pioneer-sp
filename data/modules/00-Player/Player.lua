-- Player.lua for Pioneer Scout+ (c)2013-2014 by walterar <walterar2@gmail.com>
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt
-- Work in progress.

local Lang       = import("Lang")
local Engine     = import("Engine")
local Game       = import("Game")
local Comms      = import("Comms")
local Event      = import("Event")
local Format     = import("Format")
local Serializer = import("Serializer")
local Character  = import("Character")
local ShipDef    = import("ShipDef")
local Music      = import("Music")
local Space      = import("Space")
local Timer      = import("Timer")
--local FlightLog  = import("FlightLog")

local l = Lang.GetResource("module-00-player") or Lang.GetResource("module-00-player","en")

local shipData = {}
local loaded_data

-- globales
_G.MissionsSuccesses = 0
_G.MissionsFailures  = 0
_G.ShotsSuccessful   = 0
_G.ShotsReceived     = 0
_G.OriginFaction     = "no"
_G.ShipFaction       = "no"
_G.PrevPos           = "no"
_G.PrevFac           = "no"
_G.SpaMember         = 0
_G.DangerLevel       = 0

local welcome = function ()
	if (not Game.system) then return end

	local faction = Game.system.faction
	Comms.Message(l.You_are_in_space_controlled_by.." " .. faction.name, faction.militaryName)

	if Game.system.population == 0 then
		if Game.system.explored == true then
			explored = l.Explored
		else
			explored = l.Unexplored
		end
		Comms.Message(l.System_uninhabited .. explored)
	end

	local prefix = string.upper(string.sub(Game.system.faction.name, 1 , 2))
	if prefix == "FE" or prefix == "CO" then
		_G.DangerLevel = 1
	elseif prefix == "EM" then
		_G.DangerLevel = 2
	else
		_G.DangerLevel = Engine.rand:Integer(0,2)
	end

end

local onEnterSystem = function (player)
	if player:IsPlayer() then
		welcome()
	end
end
Event.Register("onEnterSystem", onEnterSystem)

local onShipUndocked = function (player, station)
	if player:IsPlayer() then
		local faction = Game.system.faction.name
		_G.PrevPos = ((station.label)..", "..
			Game.system.name.." ("..
			(station.path.sectorX)..","..
			(station.path.sectorY)..","..
			(station.path.sectorZ)..")")
		_G.PrevFac = faction
		if station.isGroundStation then
			player:AIFlyTo(player.frameBody)
			Timer:CallAt(Game.time + 10, function ()
				player:CancelAI()
			end)
		end
	end
end
Event.Register("onShipUndocked", onShipUndocked)

local onGameStart = function ()
	if loaded_data then
		for k,v in pairs (loaded_data.shipData) do
			shipData[k] = v
		end

		_G.MissionsSuccesses = shipData.missions_successes or 0
		_G.MissionsFailures  = shipData.missions_failures or 0
		_G.ShotsSuccessful   = shipData.shots_succesful or 0
		_G.ShotsReceived     = shipData.shots_received or 0
		_G.OriginFaction     = shipData.init_faction or "no"
		_G.ShipFaction       = shipData.ship_faction or "no"
		_G.SpaMember         = shipData.spa_member or 0
		_G.PrevPos           = shipData.prev_pos or "no"
		_G.PrevFac           = shipData.prev_fac or "no"
		_G.DangerLevel       = shipData.danger_level or 0
		_G.true_joust        = shipData.true_joust or 0

	else

		_G.MissionsSuccesses = 0
		_G.MissionsFailures  = 0
		_G.ShotsSuccessful   = 0
		_G.ShotsReceived     = 0
		_G.PrevPos           = "no"
		_G.PrevFac           = "no"
		_G.SpaMember         = 0

		_G.ShipFaction       = Game.system.faction.name
		_G.OriginFaction     = ShipFaction

		local prefix = string.upper(string.sub(Game.system.faction.name,1,2))
		_G.DangerLevel = 1
		if prefix == "IN" then
			_G.DangerLevel = Engine.rand:Integer(0,2)
		elseif prefix == "EM" then
			_G.DangerLevel = 2
		end

		local label = string.format("%02s-%04d", prefix, Engine.rand:Integer(0,9999))
		Game.player:SetLabel(label)
		Comms.Message(l.YOUR_SHIP.." < "..label.." > "..l.IS_REGISTERED_IN_OUR_DOMAIN,
			Game.system.faction.militaryName)
		welcome()
	end
	loaded_data = nil
end
Event.Register("onGameStart", onGameStart)

local onShipAlertChanged = function (ship, alert)
	if ship:IsPlayer() and SpaMember == 1 then
		if alert == "SHIP_FIRING" then
			ship:SetInvulnerable(true)
		else
			ship:SetInvulnerable(false)
		end
	end
end
Event.Register("onShipAlertChanged", onShipAlertChanged)

local trigger = 0
local onShipHit = function (ship, attacker)
	if ship:IsPlayer() then
		if attacker then ship:SetCombatTarget(attacker) end
		if attacker and attacker.shipId == "police" then return end
		if (ship:GetEquipFree("LASER") < ShipDef[ship.shipId].equipSlotCapacity.LASER) and
			SpaMember == 1 and attacker then
			ship:CancelAI()
			ship:AIKill(attacker)
		end
		_G.ShotsReceived = (ShotsReceived or 0) + 1
		trigger = trigger + 1
		if trigger > 4 and attacker and SpaMember == 1 then
			if Engine.rand:Integer(1,5) == 5 then
				_G.true_joust = 0
				ship:CancelAI()
				attacker:Explode()
				Character.persistent.player.killcount = Character.persistent.player.killcount + 1
			else
				attacker:CancelAI()
			end
			trigger = 0
		elseif trigger == 1 then ship:SetInvulnerable(false)
		end
	elseif attacker:IsPlayer() then
		_G.ShotsSuccessful = (ShotsSuccessful or 0) + 1
	end
end
Event.Register("onShipHit", onShipHit)

local onShipCollided = function (ship, other)
	if other:isa('Ship') or other:isa('CargoBody') then return end
	if ship:IsPlayer() then
		ship:AIFlyTo(player.frameBody)
	end
end

local serialize = function ()
	shipData = {
			missions_successes = MissionsSuccesses,
			missions_failures  = MissionsFailures,
			shots_received     = ShotsReceived,
			shots_succesful    = ShotsSuccessful,
			init_faction       = OriginFaction,
			ship_faction       = ShipFaction,
			spa_member         = SpaMember,
			prev_pos           = PrevPos,
			prev_fac           = PrevFac,
			danger_level       = DangerLevel,
			true_joust         = true_joust,
			}
	return {shipData = shipData}
end

local unserialize = function (data)
	loaded_data = data
end

local onGameEnd = function ()
-- globales
	_G.MissionsSuccesses = nil
	_G.MissionsFailures  = nil
	_G.ShotsSuccessful   = nil
	_G.ShotsReceived     = nil
	_G.OriginFaction     = nil
	_G.ShipFaction       = nil
	_G.DangerLevel       = nil
	_G.SpaMember         = nil
	_G.PrevPos           = nil
	_G.PrevFac           = nil
	_G.true_joust        = nil
end
Event.Register("onGameEnd", onGameEnd)

Serializer:Register("ShipID", serialize, unserialize)
