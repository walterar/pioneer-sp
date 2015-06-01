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
local StarSystem = import("StarSystem")

local l  = Lang.GetResource("module-00-player") or Lang.GetResource("module-00-player","en")
local le = Lang.GetResource("equipment-core") or Lang.GetResource("equipment-core","en")
local lc = Lang.GetResource("core") or Lang.GetResource("core","en")

local shipData = {}
local loaded_data
local damaged = false
local shipNeutralized = false
local max_dist = 30

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
_G.MissileActive     = 0
_G.autoCombat        = false
_G.DEMPsystem        = false
_G.MATTcapacitor     = false
_G.playerAlert       = "NONE"
_G.damageControl     = ""
_G.fuelConvert       = false


local danger_level = function ()
	local lawlessness = Game.system.lawlessness
	if lawlessness < 0.100 then
		_G.DangerLevel = 0-- green
	elseif lawlessness >= 0.100 and lawlessness <= 0.500 then
		_G.DangerLevel = 1-- yellow
	elseif lawlessness > 0.500 then
		_G.DangerLevel = 2-- red
	end
end


local welcome = function ()
	if (not Game.system) then return end
	local factionName = Game.system.faction.name
	if PrevFac ~= factionName then
		Comms.Message(l.You_are_in_space_controlled_by.." " .. factionName, Game.system.faction.militaryName)
		Music.Play("music/core/faction/"..Game.system.faction.name,false)
		if Game.system.population == 0 then
			if Game.system.explored == true then
				explored = l.Explored
			else
				explored = l.Unexplored
			end
			Comms.Message(l.System_uninhabited .. explored)
		end
	end
	danger_level()
end

local onLeaveSystem = function (player)
	if player:IsPlayer() then
		_G._nearbystationsRemotes = nil
		_G._nearbystationsLocals = nil
	end
end
Event.Register("onLeaveSystem", onLeaveSystem)

local onEnterSystem = function (player)
	if player:IsPlayer() and Game.system.population > 0 then
		_G._nearbystationsRemotes = StarSystem:GetNearbyStationPaths(max_dist, nil,function (s) return
		(s.type ~= 'STARPORT_SURFACE') or (s.parent.type ~= 'PLANET_ASTEROID') end)
		_G._nearbystationsLocals = Game.system:GetStationPaths()
		shipNeutralized = false
		welcome()
	end
end
Event.Register("onEnterSystem", onEnterSystem)


local onShipUndocked = function (player, station)
	if player:IsPlayer() then
		_G.PrevFac = Game.system.faction.name
		_G.PrevPos = ((station.label)..", "..
			Game.system.name.." ("..
			(station.path.sectorX)..","..
			(station.path.sectorY)..","..
			(station.path.sectorZ)..")")
		local target = player:FindNearestTo("PLANET") or player:FindNearestTo("STAR")
		local timeundock = 8
		if station.isGroundStation then timeundock = 3 end
		local trueSystem = Game.system
		Timer:CallAt(Game.time + timeundock, function ()
			local current_target = player:GetNavTarget()
			if trueSystem == Game.system and (not current_target or current_target==station) then
				player:AIEnterLowOrbit(target)
			end
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
		_G.MissileActive     = shipData.missile_active or 0
		_G.autoCombat        = shipData.auto_combat or false
		_G.DEMPsystem        = shipData.demp_system or false
		_G.MATTcapacitor     = shipData.matt_capacitor or false
		_G.playerAlert       = shipData.player_alert or "NONE"
		_G.damageControl     = shipData.damage_control or ""
		_G.fuelConvert       = shipData.fuel_convert or false

	else

		_G.MissionsSuccesses = 0
		_G.MissionsFailures  = 0
		_G.ShotsSuccessful   = 0
		_G.ShotsReceived     = 0
		_G.PrevPos           = "no"
		_G.PrevFac           = "no"
		_G.MissileActive     = 0
		_G.autoCombat        = false
		_G.DEMPsystem        = false
		_G.MATTcapacitor     = false
		_G.playerAlert       = "NONE"
		_G.damageControl     = ""
		_G.fuelConvert       = false

		_G.ShipFaction       = Game.system.faction.name
		_G.OriginFaction     = ShipFaction

		danger_level()

		Comms.Message(l.YOUR_SHIP.." < "..Game.player.label.." > "..l.IS_REGISTERED_IN_OUR_DOMAIN,
			Game.system.faction.militaryName)
		welcome()
	end
	_G._nearbystationsRemotes = StarSystem:GetNearbyStationPaths(max_dist, nil,function (s) return
					(s.type ~= 'STARPORT_SURFACE') or (s.parent.type ~= 'PLANET_ASTEROID') end)
	_G._nearbystationsLocals = Game.system:GetStationPaths()
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
		if (DEMPsystem or autoCombat) and alert == "SHIP_FIRING" then
				ship:SetInvulnerable(true)
		else
				ship:SetInvulnerable(false)
		end
		_G.playerAlert = alert
	end
end
Event.Register("onShipAlertChanged", onShipAlertChanged)


local dempSong = "music/core/fx/demp"
local trigger = 0
local player
local onShipHit = function (ship, attacker)
	if ship:IsPlayer() then
		player = ship
		_G.ShotsReceived = (ShotsReceived or 0) + 1
		if attacker then
			trigger = trigger + 1
			if attacker ~= player:GetCombatTarget() then
				trigger = 0
			return end
		else
			trigger = 0
			player:SetInvulnerable(true)
		return end
		if trigger > 3 and DEMPsystem == true then
			shipNeutralized = true
			attacker:CancelAI()
			player:SetInvulnerable(true)
			Music.Play(dempSong, false)
			Comms.Message(attacker.label..l.neutralized_by..le.DEMP)
			trigger = 0
		end
		if trigger == 1 then
			player:SetInvulnerable(false)
		return end
		local hullIntegrity = math.ceil(player.hullMassLeft/ShipDef[player.shipId].hullMass*100)
		if hullIntegrity == 100 then damaged = false
		elseif hullIntegrity < 90 and not damaged then
			damaged = true
			local chance = Engine.rand:Integer(0,9)
			if chance == 0 then
				player:SetFuelPercent(ship.fuel/2)
				_G.damageControl = l.Damage_Control_Propellant
				Comms.ImportantMessage(damageControl)
			elseif chance == 1 then
				player:RemoveEquip(Eq.misc.scanner)
				player:AddEquip(Eq.cargo.rubbish,1)
				_G.damageControl = l.Damage_Control_Scanner
				Comms.ImportantMessage(damageControl)
			elseif chance == 2 and hullIntegrity < 30 then
				player:RemoveEquip(Eq.misc.autopilot)
				player:AddEquip(Eq.cargo.rubbish,1)
				_G.damageControl = l.Damage_Control_Autopilot
				Comms.ImportantMessage(damageControl)
			end
		end
		if not autoCombat or not shipWithCannon(ship)
		then return end
		local target = player:GetCombatTarget()
		if attacker and (not target and player:DistanceTo(attacker) < 4000)
			or (target and target ~= attacker and
					player:DistanceTo(attacker) < player:DistanceTo(target)) then
			if attacker then
				shipNeutralized = false
				player:CancelAI()
				player:SetCombatTarget(attacker)
				player:AIKill(attacker)
			end
		end
	elseif ship and ship:exists() and attacker and attacker:IsPlayer() then
		player = attacker
		if MissileActive > 0 then
			_G.MissileActive = MissileActive - 1
		else
			if not shipNeutralized then ship:AIKill(player) end
			_G.ShotsSuccessful = (ShotsSuccessful or 0) + 1
		end
	elseif ship and ship:exists()
		and attacker and attacker:exists()
		and not attacker:IsPlayer() then
		attacker:SetHullPercent(0)
		ship:SetHullPercent(0)
	end
end
Event.Register("onShipHit", onShipHit)


local penalized
local FiringSong = ("music/core/fx/combat0"..tostring(Engine.rand:Integer(1,4)))

local onShipFiring = function (ship)
	if not ship then return end
	local player = Game.player
	if ship == player
		and policingArea()
		and playerAlert ~= "SHIP_FIRING"
	then
		if penalized then return end
		penalized=true
		local crime = "UNLAWFUL_WEAPONS_DISCHARGE"
		Comms.ImportantMessage(string.interp(lc.X_CANNOT_BE_TOLERATED_HERE,
			{crime=Constant.CrimeType[crime].name}), Game.system.faction.policeName)
		player:AddCrime(crime, crime_fine(crime))
		Timer:CallAt(Game.time + 5, function ()
			penalized = false
		end)
	else
		if ship and ship:exists() and ship:DistanceTo(player) < 5000 and autoCombat then
			if Music.GetSongName() ~= FiringSong and Music.GetSongName() ~= dempSong then
				Music.FadeIn(Music.GetSongName(), 0.5, false)
				Music.Play(FiringSong, false)
			end
		end
	end

	if not ship
		or not ship:exists()
		or ship:IsPlayer()--XXX si player disparó, return
		or player.flightState ~= "FLYING"
		or ship.label == lc.POLICE_SHIP_REGISTRATION--XXX
	then return end

	local target = player:GetCombatTarget()

	if (not target and player:DistanceTo(ship) < 5000)
		or (target and target ~= ship and player:DistanceTo(ship) < player:DistanceTo(target))
	then
		if shipWithCannon(player) and autoCombat then
			player:SetCombatTarget(ship)
			player:AIKill(ship)
		end
--	elseif target and player:DistanceTo(ship) > 10000 then
--		player:SetCombatTarget()-- not implemented yet XXX
	end
--[[
	if target
		and ship
		and target:exists()
		and ship:exists()
		and target == ship and ship:DistanceTo(player) < 5000 then
			ship:AIKill(player)
	end
--]]
end
Event.Register("onShipFiring", onShipFiring)


Event.Register("onShipEquipmentChanged", function(ship, equipType)
	if not ship:IsPlayer() then return end
	if ship:GetEquipFree("demp") < 1 then
		_G.DEMPsystem=true
	else
		_G.DEMPsystem=false
	end
	if ship:GetEquipFree("capacitor") < 1 then
		_G.MATTcapacitor=true
	else
		_G.MATTcapacitor=false
	end
	if ship:GetEquipFree("convert") < 1 then
		_G.fuelConvert=true
	else
		_G.fuelConvert=false
	end

	if (damageControl == l.Damage_Control_Scanner and ship:GetEquipFree("scanner") < 1)
		or (damageControl == l.Damage_Control_autopilot and ship:GetEquipFree("autopilot") < 1) then
		_G.damageControl = ""
	end
end)


Event.Register("onAutoCombatON",function()
	if Game.player:GetEquipFree("autocombat") < 1 then
		_G.autoCombat = true
		Comms.Message(l.AutoCombatON)
		songOk()
		local target = Game.player:GetCombatTarget()
		if (target and target:exists()) then
			if Game.player:DistanceTo(target) > 10000 then
				Game.player:AIKamikaze(target)
				Timer:CallEvery(1, function ()
					if (target and target:exists()) and Game.player:DistanceTo(target) < 10000 then
						Game.player:AIKill(target)
						return true
					else
						return false
					end
				end)
			else
				Game.player:AIKill(target)
			end
		end
	else
		_G.autoCombat = false
	end
end)


Event.Register("onAutoCombatOFF",function()
	if Game.player:GetEquipFree("autocombat") < 1 then
		if Game.player:GetCombatTarget() then
			Game.player:CancelAI()
		end
		_G.autoCombat = false
		Comms.Message(l.AutoCombatOFF)
		songOk()
	end
end)


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
			missile_active     = MissileActive,
			auto_combat        = autoCombat,
			demp_system        = DEMPsystem,
			matt_capacitor     = MATTcapacitor,
			player_alert       = playerAlert,
			damage_control     = damageControl,
			fuel_convert       = fuelConvert
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
	_G.MissileActive     = nil
	_G.autoCombat        = nil
	_G.DEMPsystem        = nil
	_G.MATTcapacitor     = nil
	_G.playerAlert       = nil
	_G.damageControl     = nil
	_G.fuelConvert       = nil
end
Event.Register("onGameEnd", onGameEnd)

Serializer:Register("ShipID", serialize, unserialize)
