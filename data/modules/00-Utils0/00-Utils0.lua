-- 00-Utils0.lua for Pioneer Scout+ (c)2012-2015 by walterar <walterar2@gmail.com>
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
local Laws       = import("Laws")
local StarSystem = import("StarSystem")

local l  = Lang.GetResource("module-00-utils0") or Lang.GetResource("module-00-utils0","en")
local le = Lang.GetResource("equipment-core") or Lang.GetResource("equipment-core","en")
local lc = Lang.GetResource("core") or Lang.GetResource("core","en")
local lu = Lang.GetResource("ui-core") or Lang.GetResource("ui-core","en")

local LibsData = {}
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
_G.damageControl     = ""

--equipment
_G.autoCombat        = false
_G.DEMPsystem        = false
_G.MATTcapacitor     = false
_G.NavAssist         = false
_G.beaconReceiver    = false
_G.tracingJumps      = false

_G.MissileActive     = 0
_G.playerAlert       = "NONE"
_G.targetShip        = false

_G.deuda_total        = nil
_G.deuda_valor_cuota  = nil
_G.deuda_fecha_p_pago = nil
_G.deuda_resto_cuotas = nil


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

local onLeaveSystem = function (ship)
	if ship:IsPlayer() then
		_G._nearbystationsRemotes = nil
		_G._nearbystationsLocals = nil
		_G._localPlanetsWithoutStations = nil
	end
end


local onEnterSystem = function (ship)
	if not ship:IsPlayer() then return end
	if Game.system.population > 0 then
		_G._nearbystationsRemotes = StarSystem:GetNearbyStationPaths(max_dist, nil,function (s)
			return (s.type ~= 'STARPORT_SURFACE') or (s.parent.type ~= 'PLANET_ASTEROID')
		end)
		_G._nearbystationsLocals = Game.system:GetStationPaths()
		local nearbystations = Space.GetBodies(function (body)
			return body.superType == 'STARPORT'
		end)
		local localplanets = {}
		for _,path in pairs(Game.system:GetBodyPaths()) do
			local sbody = path:GetSystemBody()
			if sbody.superType == "ROCKY_PLANET" and sbody.type ~= "PLANET_ASTEROID" then
--				and sbody.population == 0 then-- no func Mercury population > 0 / Moon population 0
				for _=1, #nearbystations do
					if nearbystations[_].path:GetSystemBody().parent == sbody then
						sbody = nil
					break end
				end
				if sbody then table.insert(localplanets, Space.GetBody(sbody.index).path) end
			end
		end
		_G._localPlanetsWithoutStations = localplanets
		shipNeutralized = false
		welcome()
	end
end


local onShipUndocked = function (player, station)
	if not player:IsPlayer() then return end
	_G.PrevFac = Game.system.faction.name
	_G.PrevPos = ((station.label)..", "..
		Game.system.name.." ("..
		(station.path.sectorX)..","..
		(station.path.sectorY)..","..
		(station.path.sectorZ)..")")
	if station.isGroundStation and NavAssist then
		local ship = player
		local nearbybodys = Space.GetBodies(function (body)
			return body.superType == "ROCKY_PLANET"
					and body.type ~= "PLANET_ASTEROID"
		end)
		local target, target_check
		if nearbybodys and #nearbybodys > 1 then
			target_check = nearbybodys[1]
			for x = 2, #nearbybodys do
				if x < #nearbybodys then
					if ship:DistanceTo(target_check) > ship:DistanceTo(nearbybodys[x]) then
						target_check = nearbybodys[x]
					end
				end
			end
		else
			target_check = nearbybodys[1]
		end
		if target_check then
			target = target_check
		else
			target = ship:FindNearestTo("PLANET") or ship:FindNearestTo("STAR")
		end
		if not target then return end
		local trueSystem = Game.system
		Timer:CallAt(Game.time + 4, function ()
			if trueSystem ~= Game.system then return end
			player:AIEnterLowOrbit(target)
		end)
	end
end


local shipWithCannon = function (ship)
	if (ship:GetEquipFree("laser_front") < ship:GetEquipSlotCapacity("laser_front"))
		or (ship:GetEquipFree("laser_rear") < ship:GetEquipSlotCapacity("laser_rear")) then
		return true
	end
end


local onShipAlertChanged = function (ship, alert)
	if ship:IsPlayer() then
		if (DEMPsystem or autoCombat) and alert == "SHIP_FIRING" then
			ship:SetInvulnerable(true)
		else
			ship:SetInvulnerable(false)
		end
		_G.playerAlert = alert
	end
end

	local dempSong = "music/core/fx/demp"
	local trigger = 0
	local player
local onShipHit = function (ship, attacker)
	if ShipExists(ship) and ship.label == lc.MISSILE then return end--XXX
	if ship:IsPlayer() then
		player = ship
		_G.ShotsReceived = (ShotsReceived or 0) + 1
		if ShipExists(attacker) then
			trigger = trigger + 1
			if attacker ~= player:GetCombatTarget() then
				trigger = 0
			return end
		else
			trigger = 0
			player:SetInvulnerable(true)
		return end
		if trigger > 3 and DEMPsystem then
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
		elseif hullIntegrity < 90 and damageControl == "" and not damaged then
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
		if not autoCombat or not shipWithCannon(ship) then return end
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
	elseif ShipExists(ship) and attacker and attacker:IsPlayer() then
		player = attacker
		_G.ShotsSuccessful = (ShotsSuccessful or 0) + 1
		if MissileActive > 0 then
			_G.MissileActive = MissileActive - 1
		else
			if not shipNeutralized then ship:AIKill(player) end
		end
	elseif ShipExists(ship)
		and ShipExists(attacker)
		and not attacker:IsPlayer() then
		attacker:SetHullPercent(0)
		ship:SetHullPercent(0)
	end
end

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
		Comms.ImportantMessage(string.interp(lu.X_CANNOT_BE_TOLERATED_HERE,
			{crime=Laws.CrimeType[crime].name}), Game.system.faction.policeName)
		player:AddCrime(crime, crime_fine(crime))
		Timer:CallAt(Game.time + 5, function ()
			penalized = false
		end)
	else
		if player.flightState ~= "HYPERSPACE"
			and ShipExists(ship)
			and ship:DistanceTo(player) < 5000
			and autoCombat
		then
			if Music.GetSongName() ~= FiringSong and Music.GetSongName() ~= dempSong then
				Music.FadeIn(Music.GetSongName(), 0.5, false)
				Music.Play(FiringSong, false)
			end
		end
	end

	if not ShipExists(ship)
		or ship:IsPlayer()--XXX si player disparó, return
		or player.flightState ~= "FLYING"
		or ship.label == lu.POLICE--XXX
	then return end
	local target = player:GetCombatTarget()
	if (not target and player:DistanceTo(ship) < 5000)
		or (target and target ~= ship and player:DistanceTo(ship) < player:DistanceTo(target))
	then
		if shipWithCannon(player) and autoCombat then
			player:SetCombatTarget(ship)
			player:AIKill(ship)
		end
	end
end

local checkEquipment = function (ship)
	local ship = ship or Game.player
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
	if ship:GetEquipFree("nav_assist") < 1
		and Game.player:GetEquipCountOccupied("autopilot") > 0 then
		_G.NavAssist=true
	else
		_G.NavAssist=false
	end
	if Game.player:GetEquipFree("beacon_receiver") < 1
		and Game.player:GetEquipCountOccupied("radar") > 0 then
		_G.beaconReceiver=true
	else
		_G.beaconReceiver=false
	end
	if (damageControl == l.Damage_Control_Scanner and ship:GetEquipFree("scanner") < 1)
		or (damageControl == l.Damage_Control_autopilot and ship:GetEquipFree("autopilot") < 1) then
		_G.damageControl = ""
	end
	if damageControl == l.THE_SHIPS_HYPERDRIVE_HAS_BEEN_DESTROYED_BY_A_MALFUNCTION
			and equipType:IsValidSlot("engine", ship) then
		_G.damageControl = ""
	end
end

Event.Register("onShipEquipmentChanged", function(ship, equipType)
	if not ship:IsPlayer() then return end
	checkEquipment(ship)
end)

Event.Register("onShipTypeChanged", function(ship)
	if not ship:IsPlayer() then return end
	_G.damageControl = ""
	checkEquipment(ship)
end)


Event.Register("onTracingJumpsON",function()
	if Game.player:GetEquipFree("tracingjumps") < 1 then
		_G.tracingJumps = true
		Comms.Message(l.TracingJumpsON)
		songOk()
	end
end)


Event.Register("onTracingJumpsOFF",function()
	if Game.player:GetEquipFree("tracingjumps") < 1 then
		_G.tracingJumps = false
		Comms.Message(l.TracingJumpsOFF)
		songOk()
	end
end)


Event.Register("onAutoCombatON",function()
	if Game.player:GetEquipFree("autocombat") < 1 then
		_G.autoCombat = true
		Comms.Message(l.AutoCombatON)
		songOk()
		local target = Game.player:GetCombatTarget()
		if ShipExists(target) and Game.player.flightState == "FLYING" then
			if Game.player:DistanceTo(target) > 20000 then
				Game.player:AIKamikaze(target)
				Timer:CallEvery(1, function ()
					if ShipExists(target) and Game.player:DistanceTo(target) < 15000 then
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


local onGameStart = function ()

	if loaded_data then

		for k,v in pairs (loaded_data.LibsData) do
			LibsData[k] = v
		end

		_G.MissionsSuccesses = LibsData.missions_successes or 0
		_G.MissionsFailures  = LibsData.missions_failures or 0
		_G.ShotsSuccessful   = LibsData.shots_succesful or 0
		_G.ShotsReceived     = LibsData.shots_received or 0
		_G.OriginFaction     = LibsData.init_faction or "no"
		_G.ShipFaction       = LibsData.ship_faction or "no"
		_G.PrevPos           = LibsData.prev_pos or "no"
		_G.PrevFac           = LibsData.prev_fac or "no"
--		_G.DangerLevel       = LibsData.danger_level or 0
		_G.MissileActive     = LibsData.missile_active or 0
		_G.autoCombat        = LibsData.auto_combat or false
		_G.tracingJumps      = LibsData.tracing_jumps or false
		_G.DEMPsystem        = LibsData.demp_system or false
		_G.MATTcapacitor     = LibsData.matt_capacitor or false
		_G.NavAssist         = LibsData.nav_assist or false
		_G.playerAlert       = LibsData.player_alert or "NONE"
		_G.damageControl     = LibsData.damage_control or ""
		_G.beaconReceiver    = LibsData.beacon_receiver or false

		_G.targetShip         = LibsData.terget_ship or nil

		_G.deuda_total        = LibsData.deuda_total or nil
		_G.deuda_valor_cuota  = LibsData.deuda_valor_cuota or nil
		_G.deuda_fecha_p_pago = LibsData.deuda_fecha_p_pago or nil
		_G.deuda_resto_cuotas = LibsData.deuda_resto_cuotas or nil

	else

		_G.MissionsSuccesses = 0
		_G.MissionsFailures  = 0
		_G.ShotsSuccessful   = 0
		_G.ShotsReceived     = 0
		_G.PrevPos           = "no"
		_G.PrevFac           = "no"
		_G.MissileActive     = 0
		_G.autoCombat        = false
		_G.tracingJumps      = false
		_G.DEMPsystem        = false
		_G.MATTcapacitor     = false
		_G.NavAssist         = false
		_G.playerAlert       = "NONE"
		_G.damageControl     = ""
		_G.beaconReceiver    = false
		_G.targetShip        = false
		_G.ShipFaction       = Game.system.faction.name
		_G.OriginFaction     = ShipFaction

		_G.deuda_total        = nil
		_G.deuda_valor_cuota  = nil
		_G.deuda_fecha_p_pago = nil
		_G.deuda_resto_cuotas = nil
	end
	danger_level()

	_G._nearbystationsRemotes = StarSystem:GetNearbyStationPaths(max_dist, nil,function (s)
			return s.parent.type ~= 'PLANET_ASTEROID' end)
	_G._nearbystationsLocals = Game.system:GetStationPaths()

	local nearbystations = Space.GetBodies(function (body)
		return body.superType == 'STARPORT'
	end)
	local localplanets = {}
	for _,path in pairs(Game.system:GetBodyPaths()) do
		local sbody = path:GetSystemBody()
		if sbody.superType == "ROCKY_PLANET"
			and sbody.type ~= "PLANET_ASTEROID" then
--			and sbody.population == 0 then-- no funciona Mercury population > 0 / Moon population 0
			for _=1, #nearbystations do
				if nearbystations[_].path:GetSystemBody().parent == sbody then
					sbody = nil
				break end
			end
			if sbody then table.insert(localplanets, Space.GetBody(sbody.index).path) end
		end
	end
	_G._localPlanetsWithoutStations = localplanets

	loaded_data = nil

	Timer:CallAt(Game.time + 2, function ()
		Comms.Message(l.YOUR_SHIP.." < "..Game.player.label.." > "..l.IS_REGISTERED_IN_OUR_DOMAIN,
			Game.system.faction.militaryName)
--		welcome()

		Game.player:UpdateEquipStats()
		checkEquipment(Game.player)
		if autoCombat then
			Comms.Message(l.AutoCombatON)
			songOk()
--		else
--			Comms.Message(l.AutoCombatOFF)
--			songOk()
		end
	end)
end


local serialize = function ()
	if not ShipExists(targetShip) then
		_G.targetShip = false
	end
	LibsData = {
		missions_successes = MissionsSuccesses,
		missions_failures  = MissionsFailures,
		shots_received     = ShotsReceived,
		shots_succesful    = ShotsSuccessful,
		init_faction       = OriginFaction,
		ship_faction       = ShipFaction,
		prev_pos           = PrevPos,
		prev_fac           = PrevFac,
--		danger_level       = DangerLevel,
		missile_active     = MissileActive,
		auto_combat        = autoCombat,
		tracing_jumps      = tracingJumps,
		demp_system        = DEMPsystem,
		matt_capacitor     = MATTcapacitor,
		nav_assist         = NavAssist,
		player_alert       = playerAlert,
		damage_control     = damageControl,
		beacon_eceiver     = beaconReceiver,
		deuda_total        = deuda_total,
		deuda_valor_cuota  = deuda_valor_cuota,
		deuda_fecha_p_pago = deuda_fecha_p_pago,
		deuda_resto_cuotas = deuda_resto_cuotas,
		terget_ship        = targetShip
	}

	return {LibsData = LibsData}
end


local unserialize = function (data)
	danger_level()
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
--	_G.DangerLevel       = nil
	_G.PrevPos           = nil
	_G.PrevFac           = nil
	_G.MissileActive     = nil
	_G.autoCombat        = nil
	_G.tracingJumps      = nil
	_G.DEMPsystem        = nil
	_G.MATTcapacitor     = nil
	_G.NavAssist         = nil
	_G.playerAlert       = nil
	_G.damageControl     = nil
	_G.beaconReceiver    = nil

	_G.targetShip         = nil

	_G.deuda_total        = nil
	_G.deuda_valor_cuota  = nil
	_G.deuda_fecha_p_pago = nil
	_G.deuda_resto_cuotas = nil

end


Event.Register("onShipHit", onShipHit)
Event.Register("onShipAlertChanged", onShipAlertChanged)
Event.Register("onGameStart", onGameStart)
Event.Register("onShipFiring", onShipFiring)
Event.Register("onShipUndocked", onShipUndocked)
Event.Register("onEnterSystem", onEnterSystem)
Event.Register("onLeaveSystem", onLeaveSystem)
Event.Register("onGameEnd", onGameEnd)

Serializer:Register("00-Utils0", serialize, unserialize)
