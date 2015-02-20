-- Player.lua for Pioneer Scout+ (c)2012-2015 by walterar <walterar2@gmail.com>
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
local Eq         = import("Equipment")
local Constant   = import("Constant")
local Music      = import("Music")

local l = Lang.GetResource("module-00-player") or Lang.GetResource("module-00-player","en");
local le = Lang.GetResource("equipment-core") or Lang.GetResource("equipment-core","en");
local lc    = Lang.GetResource("ui-core")

local shipData = {}
local loaded_data
local damaged = false
local shipNeutralized = false

-- globales
_G.MissionsSuccesses = 0
_G.MissionsFailures  = 0
_G.ShotsSuccessful   = 0
_G.ShotsReceived     = 0
_G.OriginFaction     = "no"
_G.ShipFaction       = "no"
_G.PrevPos           = "no"
_G.PrevFac           = "no"
_G.DangerLevel       = 0
_G.FuelHydrogen      = false
_G.MissileActive     = 0
_G.autoCombat        = false
_G.DEMPsystem        = false
_G.MATTcapacitor     = false
_G.playerAlert       = "NONE"

local welcome = function ()
	if (not Game.system) then return end
	local factionName = Game.system.faction.name
	if PrevFac ~= factionName then
		Comms.Message(l.You_are_in_space_controlled_by.." " .. factionName, Game.system.faction.militaryName)
		if Game.system.population == 0 then
			if Game.system.explored == true then
				explored = l.Explored
			else
				explored = l.Unexplored
			end
			Comms.Message(l.System_uninhabited .. explored)
		end
	end
	local prefix = string.upper(string.sub(factionName, 1 , 2))
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
		shipNeutralized = false
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
		local target = player:FindNearestTo("PLANET") or player:FindNearestTo("STAR")
		local timeundock = 8
		if station.isGroundStation then timeundock = 3 end
		local trueSystem = Game.system
		Timer:CallAt(Game.time + timeundock, function ()
			if trueSystem == Game.system then player:AIEnterLowOrbit(target) end
		end)
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
		_G.PrevPos           = shipData.prev_pos or "no"
		_G.PrevFac           = shipData.prev_fac or "no"
		_G.DangerLevel       = shipData.danger_level or 0
		_G.FuelHydrogen      = shipData.fuel_hydrogen or false
		_G.MissileActive     = shipData.missile_active or 0
		_G.autoCombat        = shipData.auto_combat or false
		_G.DEMPsystem        = shipData.demp_system or false
		_G.MATTcapacitor     = shipData.matt_capacitor or false
		_G.playerAlert       = shipData.player_alert or "NONE"
	else

		_G.MissionsSuccesses = 0
		_G.MissionsFailures  = 0
		_G.ShotsSuccessful   = 0
		_G.ShotsReceived     = 0
		_G.PrevPos           = "no"
		_G.PrevFac           = "no"
		_G.FuelHydrogen      = false
		_G.MissileActive     = 0
		_G.autoCombat        = false
		_G.DEMPsystem        = false
		_G.MATTcapacitor     = false
		_G.playerAlert       = "NONE"

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

local shipWithCannon = function (ship)
		if (ship:GetEquipFree("laser_front") < ship:GetEquipSlotCapacity("laser_front"))
			or (ship:GetEquipFree("laser_rear") < ship:GetEquipSlotCapacity("laser_rear")) then
			return true
	end
end

local onShipAlertChanged = function (ship, alert)
--	if Music.IsPlaying() and alert=="NONE" then Music.FadeIn(song, 0.5, false) end
	if ship:IsPlayer() then
		if DEMPsystem then
			if alert == "SHIP_FIRING" and autoCombat then
				ship:SetInvulnerable(true)
			else
				ship:SetInvulnerable(false)
			end
		end
		_G.playerAlert = alert
	end
end
Event.Register("onShipAlertChanged", onShipAlertChanged)

local trigger = 0
local onShipHit = function (ship, attacker)
	if ship:IsPlayer() then
		_G.ShotsReceived = (ShotsReceived or 0) + 1
		trigger = trigger + 1
		if attacker
			and trigger > 4
			and DEMPsystem == true
		then
			Music.Play("music/core/demp/demp", false)
			Comms.Message(attacker.label..l.neutralized_by..le.DEMP)
			shipNeutralized = true
			attacker:CancelAI()
			trigger = 0
		end
		if trigger == 1 then ship:SetInvulnerable(false) end
		local hullIntegrity = math.ceil(ship.hullMassLeft/ShipDef[ship.shipId].hullMass*100)
		if hullIntegrity == 100 then damaged = false
		elseif hullIntegrity < 90 and not damaged then
			damaged = true
			local chance = Engine.rand:Integer(0,9)
			if chance == 0 then
				ship:SetFuelPercent(ship.fuel/2)
				Comms.ImportantMessage(l.Damage_Control_Propellant)
			elseif chance == 1 then
				ship:RemoveEquip(Eq.misc.scanner)
				ship:AddEquip(Eq.cargo.rubbish,1)
				Comms.ImportantMessage(l.Damage_Control_Radar)
			elseif chance == 2 and hullIntegrity < 30 then
				ship:RemoveEquip(Eq.misc.autopilot)
				ship:AddEquip(Eq.cargo.rubbish,1)
				Comms.ImportantMessage(l.Damage_Control_Autopilot)
			end
		end
		if autoCombat == false or shipWithCannon(ship) == false then return end
		local target = ship:GetCombatTarget()
		if attacker and (not target and ship:DistanceTo(attacker) < 4000)
			or (target and target ~= attacker and
					ship:DistanceTo(attacker) < ship:DistanceTo(target)) then
			if attacker then
				shipNeutralized = false
				ship:CancelAI()
				ship:SetCombatTarget(attacker)
				ship:AIKill(attacker)
			end
		end
	elseif ship and ship:exists() and attacker and attacker:exists() and attacker:IsPlayer() then
		if MissileActive > 0 then
			_G.MissileActive = MissileActive - 1
		else
			_G.ShotsSuccessful = (ShotsSuccessful or 0) + 1
		end
		if not shipNeutralized then ship:AIKill(attacker) end
	elseif ship and ship:exists()
		and attacker and attacker:exists()
		and not attacker:IsPlayer() then
		attacker:SetHullPercent(0)
		ship:SetHullPercent(0)
	end
end
Event.Register("onShipHit", onShipHit)

local penalized
local onShipFiring = function (ship)

	if ship
		and ship:exists()
		and ship:IsPlayer()
		and policingArea()
		and playerAlert ~= "SHIP_FIRING"
	then
		if penalized then return end
		penalized=true
		Timer:CallAt(Game.time + 5, function ()
			penalized = false
		end)
		local crime = "UNLAWFUL_WEAPONS_DISCHARGE"
		Comms.ImportantMessage(string.interp(lc.X_CANNOT_BE_TOLERATED_HERE,
			{crime=Constant.CrimeType[crime].name}), Game.system.faction.policeName)
		ship:AddCrime(crime, crime_fine(crime))
	end

	if not autoCombat
		or not ship
		or not ship:exists()
		or ship:IsPlayer()
		or Game.player:GetDockedWith()
	then return end
	local player = Game.player
	local target = player:GetCombatTarget()
	if (not target and player:DistanceTo(ship) < 5001)
		or (target and target ~= ship
			and player:DistanceTo(ship) < player:DistanceTo(target)) then
		player:SetCombatTarget(ship)
		if shipWithCannon(player) then
			player:CancelAI()
			player:AIKill(ship)
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
			prev_pos           = PrevPos,
			prev_fac           = PrevFac,
			danger_level       = DangerLevel,
			fuel_hydrogen      = FuelHydrogen,
			missile_active     = MissileActive,
			auto_combat        = autoCombat,
			demp_system        = DEMPsystem,
			matt_capacitor     = MATTcapacitor,
			player_alert       = playerAlert
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
	_G.PrevPos           = nil
	_G.PrevFac           = nil
	_G.FuelHydrogen      = nil
	_G.MissileActive     = nil
	_G.autoCombat        = nil
	_G.DEMPsystem        = nil
	_G.MATTcapacitor     = nil
	_G.playerAlert       = nil
end
Event.Register("onGameEnd", onGameEnd)

Event.Register("onShipEquipmentChanged", function(ship, equipType)
	if not ship:IsPlayer() then return end
	if (ship:GetEquipFree("demp") < ship:GetEquipSlotCapacity("demp")) then
		_G.DEMPsystem=true end
	if (ship:GetEquipFree("capacitor") < ship:GetEquipSlotCapacity("capacitor")) then
		_G.MATTcapacitor=true end
end)

Event.Register("onAutoCombatON",function()
	if (Game.player:GetEquipFree("autocombat") < Game.player:GetEquipSlotCapacity("autocombat")) then
		Comms.Message(l.AutoCombatON)
		_G.autoCombat = true
	end
end)

Event.Register("onAutoCombatOFF",function()
	if (Game.player:GetEquipFree("autocombat") < Game.player:GetEquipSlotCapacity("autocombat")) then
		Comms.Message(l.AutoCombatOFF)
		if playerAlert == "SHIP_FIRING" then
			Game.player:CancelAI()
		end
		_G.autoCombat = false
	end
end)

Serializer:Register("ShipID", serialize, unserialize)
