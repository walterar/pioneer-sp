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
local ll = Lang.GetResource("core") or Lang.GetResource("core","en")

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
_G.SpaMember         = false
_G.DangerLevel       = 0
_G.FuelHydrogen      = false
_G.MissileActive     = 0
_G.autoCombat        = false

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
			Timer:CallAt(Game.time + 5, function ()
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
		_G.SpaMember         = shipData.spa_member or false
		_G.PrevPos           = shipData.prev_pos or "no"
		_G.PrevFac           = shipData.prev_fac or "no"
		_G.DangerLevel       = shipData.danger_level or 0
		_G.FuelHydrogen      = shipData.fuel_hydrogen or false
		_G.MissileActive     = shipData.missile_active or 0
		_G.autoCombat        = shipData.auto_combat or false
	else

		_G.MissionsSuccesses = 0
		_G.MissionsFailures  = 0
		_G.ShotsSuccessful   = 0
		_G.ShotsReceived     = 0
		_G.PrevPos           = "no"
		_G.PrevFac           = "no"
		_G.SpaMember         = false
		_G.FuelHydrogen      = false
		_G.MissileActive     = 0
		_G.autoCombat        = false
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
	if ship:IsPlayer() and SpaMember == true then
		if alert == "SHIP_FIRING" and autoCombat then
			ship:SetInvulnerable(true)
			if not autoCombat then
				Comms.Message("Presione BloqMayusc para activar/desactivar AutoCombate")
			end
		else
			ship:SetInvulnerable(false)
		end
	end
end
Event.Register("onShipAlertChanged", onShipAlertChanged)

local trigger = 0
local onShipHit = function (ship, attacker)
	if ship:IsPlayer() and autoCombat == true then
		if attacker then ship:SetCombatTarget(attacker) end
		if attacker and attacker.label == ll.POLICE_SHIP_REGISTRATION then return end
		if (ship:GetEquipFree("LASER") < ShipDef[ship.shipId].equipSlotCapacity.LASER)
			and SpaMember == true
			and attacker then
			ship:CancelAI()
			ship:AIKill(attacker)
		end
		_G.ShotsReceived = (ShotsReceived or 0) + 1
		trigger = trigger + 1
		if trigger > 4 and attacker and SpaMember == true then
			attacker:CancelAI()
			trigger = 0
		elseif trigger == 1 then ship:SetInvulnerable(false)
		end
	elseif attacker and attacker:IsPlayer() then
		if MissileActive > 0 then
			_G.MissileActive = MissileActive - 1
		else
			_G.ShotsSuccessful = (ShotsSuccessful or 0) + 1
		end
	end
end
Event.Register("onShipHit", onShipHit)

local onShipFiring = function (ship)
	if not ship or not ship:exists() then return end
	if ship ~= Police and ship:DistanceTo(Game.player) > 100e3 then ship:Explode() return end
	if ship:IsPlayer() then
--		if not Game.player:GetCombatTarget() then
--			print("PLAYER ESTA DISPARANDO SUS CAÑONES")
--		end
	else
		if ship ~= Game.player:GetCombatTarget() then
--			print(ship.label.." ESTA DISPARANDO SUS CAÑONES A "..Format.Distance(ship:DistanceTo(Game.player)))
			if Game.player:GetDockedWith() then return end
			if autoCombat and Game.player:DistanceTo(ship) < 5001 then
				Game.player:SetCombatTarget(ship)
				if Game.player:GetEquipFree("LASER") < ShipDef[Game.player.shipId].equipSlotCapacity.LASER then
					Game.player:AIKill(ship)
				end
--			elseif not autoCombat then
--				print("AutoCombate está desactivado")
			end
		end
	end
end
Event.Register("onShipFiring", onShipFiring)

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
			fuel_hydrogen      = FuelHydrogen,
			missile_active     = MissileActive,
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
	_G.FuelHydrogen      = nil
	_G.MissileActive     = nil
	_G.autoCombat        = nil
end
Event.Register("onGameEnd", onGameEnd)


Event.Register("onAutoCombatON",function()
	Comms.Message("AutoCombate ACTIVADO")
	_G.autoCombat = true end)

Event.Register("onAutoCombatOFF",function()
	Comms.Message("AutoCombate DESACTIVADO")
	_G.autoCombat = false end)

Serializer:Register("ShipID", serialize, unserialize)
