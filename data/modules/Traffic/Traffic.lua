-- Traffic.lua for Pioneer Scout+ by walterar Copyright © 2012-2015 <walterar2@gmail.com>
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt
-- Work in progress, pre alpha 1.1--
--
local Comms      = import("Comms")
local Engine     = import("Engine")
local Game       = import("Game")
local Space      = import("Space")
local utils      = import("utils")
local ShipDef    = import("ShipDef")
local Ship       = import("Ship")
local Timer      = import("Timer")
local Event      = import("Event")
local Serializer = import("Serializer")
local Lang       = import("Lang")
local Eq         = import("Equipment")
local StarSystem = import("StarSystem")--XXX
local Laws       = import("Laws")
local Format     = import("Format")

local misc       = Eq.misc
local laser      = Eq.laser
local hyperspace = Eq.hyperspace
local cargo      = Eq.cargo

local l = Lang.GetResource("ui-core") or Lang.GetResource("ui-core","en")
local myl = Lang.GetResource("module-myl") or Lang.GetResource("module-myl","en")

local TraffiShip   = {}
local ShipsCount   = 0
local spawnDocked  = false
local Police       = nil
local GroundShips  = nil
local SpaceShips   = nil
local basePort     = nil
local lastPort     = nil
local nextPort     = nil

local ShipStatic   = {}
local StaticCount  = 0

local loaded_data  = nil
local playerStatus = nil
local lastTime     = 0
local pol_ai_compl = false
local warning      = false
local fineDetect   = false
local activateON   = false


local reinitialize = function ()
	TraffiShip   = {}
	ShipsCount   = 0
	ShipStatic   = {}
	StaticCount  = 0
	spawnDocked  = false
	Police       = nil
	basePort     = nil
	lastPort     = nil
	nextPort     = nil
	playerStatus = nil
	lastTime     = 0
	pol_ai_compl = false
	warning      = false
	fineDetect   = false
	activateON   = false
end


local erase_old_spawn = function ()
	if Game.player:GetCombatTarget() then return false end

	local clear = function ()
		TraffiShip   = {}
		ShipsCount   = 0
		spawnDocked  = false
		ShipStatic   = {}
		StaticCount  = 0
		activateON   = false
		lastTime     = 0
	end

	if Police then
		Police:SetInvulnerable(false)
		Police:Disappear()
		Police=nil
	end

	if ShipsCount == 0 then
		clear()
	return end

	if Game.time > 10 then
		for i = 1, ShipsCount do
			if TraffiShip[i] and TraffiShip[i]:exists() then
				TraffiShip[i]:Disappear()
				TraffiShip[i]=nil
			end
		end
	end

	if StaticCount and StaticCount > 0 then
		for i = 1, StaticCount do
			if ShipStatic[i] and ShipStatic[i]:exists() then
				ShipStatic[i]:Disappear()
				ShipStatic[i] = nil
			end
		end
	end

	clear()
	return true
end


local replace_and_spawn = function (n)
	TraffiShip[n] = nil
	local truestation = basePort
	Timer:CallAt(Game.time + Engine.rand:Integer(2,30), function ()--XXX
		if not basePort or truestation ~= basePort then
		return end
		local ships_traffic
		if basePort.isGroundStation then
			ships_traffic = GroundShips
		else
			ships_traffic = SpaceShips
		end
		local x=0
		local drive
		repeat
			TraffiShip[n] = ships_traffic[Engine.rand:Integer(1,#ships_traffic)]
			drive = hyperspace["hyperdrive_"..tostring(TraffiShip[n].hyperdriveClass)]
			x = (x or 0) + 1
			if x > 10 then
			break end
		until drive
		TraffiShip[n] = Space.SpawnShipNear(TraffiShip[n].id,Game.player,120, 200)
		if drive then
			TraffiShip[n]:AddEquip(drive)
			TraffiShip[n]:AddEquip(cargo.hydrogen,drive.capabilities.hyperclass ^ 2)
		end
		if not basePort.isGroundStation then TraffiShip[n]:AddEquip(misc.scanner) end
		if TraffiShip[n]:CountEquip(misc.shield_generator) > 0 then
			TraffiShip[n]:AddEquip(misc.atmospheric_shielding)
		end
		if Engine.rand:Integer(1) > 0 then
			TraffiShip[n]:SetLabel(Ship.MakeRandomLabel(Game.system.faction.name))
		else
			TraffiShip[n]:SetLabel(Ship.MakeRandomLabel())
		end
		TraffiShip[n]:AIDockWith(basePort)
	end)
end


function activate (i)
	if not basePort or not basePort:exists() then return end
	local xtime = lastTime+Engine.rand:Integer(20,50)--XXX
	lastTime = xtime
--print("Launch "..TraffiShip[i].label.." as of "..Format.Date(Game.time+lastTime))
	local truestation = basePort
	Timer:CallAt(Game.time+xtime, function ()
		if not basePort
			or truestation ~= basePort
			or not TraffiShip[i]
			or TraffiShip[i].flightState ~= "DOCKED"
		then return end
		if TraffiShip[i].alertStatus == "SHIP_NEARBY"
			and TraffiShip[i]:DistanceTo(Game.player) < 15000
			and Game.player.flightState ~= "DOCKED"
			and Game.player:GetNavTarget() == basePort
			and not basePort.isGroundStation
		then return end--XXX
		if Game.player.alertStatus == "SHIP_NEARBY"
			and Game.player.flightState == "DOCKED"
			and not basePort.isGroundStation
		then
			activate(i)
		return end
		local x=0
		repeat
			local success = TraffiShip[i]:Undock()
			x = (x or 0) + 1
			if x > 10 then
print(TraffiShip[i].label.." NO DESPEGÓ")
			break end
		until success
		local timeundock = Game.time + 20--XXX orbitals
		if basePort.isGroundStation then timeundock = Game.time + 3 end
		Timer:CallAt(timeundock, function ()
			local target = Game.player:FindNearestTo("PLANET") or Game.player:FindNearestTo("STAR")
			if not target or not TraffiShip[i] or not TraffiShip[i]:exists() then return end
			TraffiShip[i]:AIEnterLowOrbit(target)
			if Engine.rand:Integer(1) > 0 then-- XXX hyperspace
				Timer:CallAt(Game.time + 5, function ()
					if not TraffiShip[i]
						or not TraffiShip[i]:exists()
						or TraffiShip[i].flightState == "DOCKING"
						or TraffiShip[i].flightState == "UNDOCKING"
						or MissileActive > 0--XXX
					then return end
					local range = TraffiShip[i].hyperspaceRange
					if range and range > 0 then
						if range > 30 then range = 30 end
						local nearbystations = StarSystem:GetNearbyStationPaths(range, nil,function (s) return
							(s.type ~= 'STARPORT_SURFACE') or (s.parent.type ~= 'PLANET_ASTEROID') end)
						local system_target
						if nearbystations and #nearbystations > 0 then
							system_target = nearbystations[Engine.rand:Integer(1,#nearbystations)]
						end
						if system_target == nil then return end
						if TraffiShip[i].flightState == "DOCKING"
							or TraffiShip[i].flightState == "UNDOCKING" then
						return end

						local status
						if TraffiShip[i] and TraffiShip[i]:exists() then
							status = TraffiShip[i]:HyperjumpTo(system_target)
						end

						if status == "OK" then
							replace_and_spawn(i)
						else
							if TraffiShip[i] and TraffiShip[i]:exists() then TraffiShip[i]:Explode() end
							replace_and_spawn(i)
						return end
					end
				end)
			end
		end)
	end)
end


local traffic_docked = function ()
	if activateON then
	return end
	activateON = true
	for i=1, ShipsCount do
		if TraffiShip[i] and TraffiShip[i].flightState =="DOCKED" then
			activate(i)
		end
	end
end


local spawnShipsDocked = function ()
	if spawnDocked == true then
	return end
	if Game.time < 10 then basePort = Game.player:GetDockedWith() end
	if not basePort then
	return end
	spawnDocked = true
	local free_police = 1
	local posib = 5
	local starports = #Space.GetBodies(function (body) return body.superType == 'STARPORT' end)
	if Game.time < 10 then posib = 6 end
	if Engine.rand:Integer(5) < posib then--XXX
		local policy_ship
		if starports < 3 then
			policy_ship="police_viper"
		elseif starports > 2 and starports < 6 then
			policy_ship="police_pacifier"
		else
--			policy_ship="police_pumpkinseed"
			policy_ship="police_mecha"
		end
		Police = Space.SpawnShipDocked(policy_ship, basePort)
	end
	if Police then
		if Police:GetEquipFree("laser_front") > 0 then
			Police:AddEquip(laser.pulsecannon_dual_1mw)--XXX
			Police:AddEquip(misc.laser_cooling_booster)
		end
		Police:AddEquip(misc.atmospheric_shielding)
		Police:AddEquip(misc.scanner)
		Police:SetLabel(l.POLICE)
		Police:SetInvulnerable(true)
		free_police = 0
	end
	local ships_traffic
	local min = math.abs(basePort.numDocks/3)
	local max = math.abs((basePort.numDocks/2) * (2.0-Game.system.lawlessness))
	if max > basePort.numDocks-2 then max = basePort.numDocks-2 end
	if max < min then max=min end
	ShipsCount = Engine.rand:Integer(min, max)
	if basePort.isGroundStation then
		ships_traffic = GroundShips
	else
		ships_traffic = SpaceShips
	end
	if not ships_traffic or ShipsCount == 0 then
	return end
	if Game.time > 10 and ShipsCount > 2 then ShipsCount = Engine.rand:Integer(2,ShipsCount) end
	ShipsCount = ShipsCount + free_police
	local ships_traffic_count = #ships_traffic
	local x=0
	local drive
	local drivenum
	for i = 1, ShipsCount do
		repeat
			TraffiShip[i] = ships_traffic[Engine.rand:Integer(1,ships_traffic_count)]
			drivenum = TraffiShip[i].hyperdriveClass
			drive = hyperspace["hyperdrive_"..tostring(drivenum)]
			TraffiShip[i] = Space.SpawnShipDocked(TraffiShip[i].id, basePort)
			x = (x or 0) + 1
			if x > 10 then
			break end
		until TraffiShip[i]
		if not TraffiShip[i] then
			ShipsCount = i-1
		break end
		if drive then
			TraffiShip[i]:AddEquip(drive)
			TraffiShip[i]:AddEquip(cargo.hydrogen,drivenum ^ 2)
		end
		if basePort.isGroundStation
			and ShipDef[TraffiShip[i].shipId].equipSlotCapacity.atmo_shield > 0 then
			TraffiShip[i]:AddEquip(misc.atmospheric_shielding)
		else
			TraffiShip[i]:AddEquip(misc.scanner)
		end
		if Engine.rand:Integer(1,2) > 1 then
			TraffiShip[i]:SetLabel(Ship.MakeRandomLabel(Game.system.faction.name))
		else
			TraffiShip[i]:SetLabel(Ship.MakeRandomLabel())
		end
	end
	print(ShipsCount.." SHIPS IN ".. basePort.label)
end


local onShipDocked = function (ship, station)
	if ship:IsPlayer() then
		playerStatus = nil
		basePort = station
		activateON = false
		traffic_docked()
	return end
	if ship == Police then pol_ai_compl = false end
	for i=1, ShipsCount do
		if ship == TraffiShip[i] then
			basePort = station
			activate(i)
		break end
	end
end


local policeStopFire = function ()--XXX la única forma de que deje de disparar.
	Police:CancelAI()
	Police:SetInvulnerable(true)
	if Police:GetEquipFree("laser_front") < 1 then
		Police:RemoveEquip(laser.pulsecannon_dual_1mw)
		Police:RemoveEquip(misc.laser_cooling_booster)
	end
end


local onAICompleted = function (ship, ai_error)
	if ship == Police and not pol_ai_compl then
		if Police:GetDockedWith() then return end
		pol_ai_compl = true
		policeStopFire()
		Police:AIDockWith(basePort)
		warning = false
	end
	if ship:GetDockedWith() then return end
	if ship:IsPlayer() then
		if playerStatus ~= "inbound" then
			local target = Game.player:GetNavTarget()
			if target == Game.player:FindNearestTo("SPACESTATION") and ai_error == "NONE" then
				if target ~= basePort then
					erase_old_spawn()
					spawnDocked = false
					activateON = false
					basePort = target
					spawnShipsDocked()
					traffic_docked()
				end
			end
		else
			playerStatus = nil
		end
	else--NPCs
		if basePort then
			for i = 1, ShipsCount do
				if ship == TraffiShip[i] then
					local state = TraffiShip[i].flightState
					if ai_error == "REFUSED_PERM" and state == "FLYING" then
						local target = Game.player:FindNearestTo("PLANET") or Game.player:FindNearestTo("STAR")
						if not target or not TraffiShip[i] then return end
						TraffiShip[i]:AIEnterLowOrbit(target)
					elseif ai_error == "NONE" and state ~= "DOCKING" and state ~= "UNDOCKING" then
						TraffiShip[i]:AIDockWith(basePort)
					end
				end
			end
		end
	end
end


local spawnShipsStatics = function ()
	if Game.time < 10 then basePort = Game.player:GetDockedWith() end
	if not basePort or (basePort and basePort.isGroundStation) then return end
	local population = Game.system.population
	if population == 0 then return end
	local shipdefs = utils.build_array(utils.filter(function (k,def)
		return def.tag == 'STATIC_SHIP' end, pairs(ShipDef)))
	if #shipdefs > 0 then
		StaticCount = math.min(2, math.floor((math.ceil(population)+2)/3)) or 1
		for i=1, StaticCount do
			ShipStatic[i] = Space.SpawnShipParked(shipdefs[Engine.rand:Integer(1,#shipdefs)].id, basePort)
			if ShipStatic[i] then ShipStatic[i]:SetLabel(Ship.MakeRandomLabel()) end
		end
	end
end


local onShipCollided = function (ship, other)
	if ship:IsPlayer()
		or ship == Police
		or not other
		or not ShipsCount
		or ShipsCount == 0 then
	return end
	if other == basePort then
		for i=1, ShipsCount do
			if ship == TraffiShip[i] then
print(ShipDef[TraffiShip[i].shipId].name.." is collided by "..other.label.." and destroyed")
				TraffiShip[i]:Explode()
				replace_and_spawn(i)
			return end
		end
	end
end


local onShipDestroyed = function (ship, attacker)
	if ShipsCount or ShipsCount > 0 then
		for i=1, ShipsCount do
			if ship == TraffiShip[i] then
print(ShipDef[TraffiShip[i].shipId].name.." is destroyed by "..attacker.label)
				replace_and_spawn(i)
			break end
		end
	end
	if StaticCount and StaticCount > 0 then
		for i = 1, StaticCount do
			if ship == ShipStatic[i] and attacker:IsPlayer() then
				ShipStatic[i] = nil
				StaticCount = StaticCount-1
			break end
		end
	end
	if ship == Police then
		Police = nil
	end
end


local actionPolice = function ()
	if warning == true or not Police then return end
	local system = Game.system
	local player = Game.player
	player:SetNavTarget(player:FindNearestTo("STAR"))
	local crime,fine = player:GetCrime()
	local police = system.faction.policeName.." "..basePort.label
	warning = true
	if fine > 0 then
		Comms.ImportantMessage(myl.Warning_You_must_go_back_to_the_Station_now_or_you_will_die_soon, police)
		if Police:GetEquipFree("laser_front") > 0 then
			Police:AddEquip(laser.pulsecannon_dual_1mw)--XXX
			Police:AddEquip(misc.laser_cooling_booster)
		end
		local crime = "ESCAPE"
		player:AddCrime(crime, crime_fine(crime))
		pol_ai_compl = false
		Police:SetInvulnerable(false)
		Police:AIKill(player)
	end
	Timer:CallEvery(4, function ()--XXX
		if Game.system ~= system then return true end-- chequea no salto hiperespacial aquí
		if not basePort or not Police or not Police:exists() then return true end
		if fine == 0 or player:GetNavTarget() == basePort then
			policeStopFire()
			pol_ai_compl = false
			Police:AIFlyTo(basePort)
			warning = false
			return true
		end
	end)
end


local distance
function sensorDistance (every)
	local every = every or 5
	local player = Game.player
	if not basePort then return end
	distance = nil
	local spawnErased = false
	local distance_reached = false
	local system = Game.system
	Timer:CallEvery(every, function ()
		if Game.system ~= system then return true end-- verifica no salto hiperespacial aquí
		if not basePort then return false end
		distance = player:DistanceTo(basePort) or 0
-- outbound
		if playerStatus == "outbound" then
			if distance > 300 and distance_reached == false then--XXX
				distance_reached = true
				if fineDetect then
					warning = false
					actionPolice()
				return false end
			end
			if distance > 150e3 and not spawnErased then
				local target = Game.player:GetNavTarget()
				if target == basePort then
				return false end
				spawnErased = erase_old_spawn()
				if ShipsCount == 0 then playerStatus = nil end
				return spawnErased
			end
		end
--[[inbound
		if distance < 150e3 and not spawnDocked and not playerStatus then-- genera spawn
			playerStatus = "inbound"
			erase_old_spawn()
			spawnShipsDocked()
			if not basePort.isGroundStation then
				spawnShipsStatics()
			end
			return true
		end
--]]
	end)
end


local onFrameChanged = function (body)
	if body:isa("Ship") and not body:IsPlayer() then return end
	local target = Game.player:GetNavTarget()
	if not target then return end
	if target ~= basePort then
		activateON = false
	end
	if activateON then return end
	if target.superType == 'STARPORT' then
		nextPort = target
		dist = Game.player:DistanceTo(nextPort)
		if dist < 200e3 then
			playerStatus = "inbound"
			erase_old_spawn()
			lastPort=basePort
			basePort=nextPort
			activateON = false
			spawnDocked = false
			spawnShipsDocked()
			traffic_docked()
			if not nextPort.isGroundStation then
				spawnShipsStatics()
			end
		end
	end
end


Event.Register("onShipFiring", function (ship)
	if not ship
		or not ship:exists()
		or ship:IsPlayer()
		or ship == Police
	then return end
	if ship
		and ship:exists()
		and Police
		and Police:exists()
		and Police:DistanceTo(ship) < 100e3
		and (Police:DistanceTo(Game.player) > 5000 or Game.player:GetDockedWith())
	then
		if Police:GetEquipFree("laser_front") > 0 then
			Police:AddEquip(laser.pulsecannon_dual_1mw)--XXX
			Police:AddEquip(misc.laser_cooling_booster)
		end
		pol_ai_compl = false
		Police:AIKill(ship)
		ship:SetHullPercent(0)
		ship:AIKill(Police)
	end
end)


Event.Register("onShipAlertChanged", function (ship, alert)
	if ship ~= Police then return end
	if alert == "NONE" and Police.flightState == "FLYING" then
		policeStopFire()
		pol_ai_compl = false
		Police:AIFlyTo(basePort)
	end
end)


local onShipUndocked = function (ship, station)
	if not ship:IsPlayer() then return end
	playerStatus = "outbound"
	lastPort = station
	local crime,fine = Game.player:GetCrime()
	if fine and fine > 0 then
		fine = showCurrency(fine)
		local police = Game.system.faction.policeName.." "..basePort.label
		Comms.ImportantMessage(myl.You_have_committed_a_crime_and_must_pay..fine, police)
		fineDetect = true
	end
	sensorDistance()
end


local onLeaveSystem = function (ship)
	if ship:IsPlayer() then
		ship:CancelAI()
		if distance and distance < 2500 then
			local money = crime_fine("ILLEGAL_JUMP")
			Game.player:AddCrime("ILLEGAL_JUMP", money)
			Comms.ImportantMessage(myl.ILLEGAL_JUMP .."  ".. myl.You_has_been_fined .. showCurrency(money), Game.system.faction.policeName)
			distance = nil
		end
		reinitialize()
	end
end


local onGameStart = function ()
	GroundShips = utils.build_array(utils.filter(function (k,def)
		return def.tag == 'SHIP'
			and def.capacity > 19
			and def.capacity < 501
			and def.hyperdriveClass > 0
			and def.equipSlotCapacity.atmo_shield > 0
			and def.id ~= ('ac33')
			and def.id ~= ('amphiesma')
			and def.id ~= ('nerodia')
			and def.id ~= ('hullcutter')
			and def.id ~= ('deneb')
			and def.id ~= ('eagle_lrf')
			and def.id ~= ('eagle_mk2')
			and def.id ~= ('eagle_mk3')
			and def.id ~= ('caiman')
--			and def.id ~= ('constrictor_a')
--			and def.id ~= ('constrictor_b')
			and def.id ~= ('cobra_mk1_a')
			and def.id ~= ('cobra_mk1_b')
			and def.id ~= ('cobra_mk1_c')
			and def.id ~= ('malabar')
			and def.id ~= ('manta')
--			and def.id ~= ('molamola')
			and def.id ~= ('natrix')
			and def.id ~= ('sidie_m')
			and def.id ~= ('sinonatrix')
			and def.id ~= ('venturestar')
			and def.id ~= ('viper_hw')
			and def.id ~= ('viper_lz')
			and def.id ~= ('viper_mw')
			and def.id ~= ('viper_tw')
--			and def.id ~= ('vatakara')
			and def.id ~= ('wave')
	end, pairs(ShipDef)))
	SpaceShips = utils.build_array(utils.filter(function (k,def)
		return def.tag == 'SHIP'
			and def.capacity > 19
			and def.capacity < 501
			and def.hyperdriveClass > 0
			and def.id ~= ('pumpkinseed')
			and def.id ~= ('pumpkinseed_x2')
			and def.id ~= ('wave')
			and def.id ~= ('nerodia')
			and def.id ~= ('anax')
			and def.id ~= ('ac33')
			and def.id ~= ('sinonatrix')
			and def.id ~= ('amphiesma')
			and def.id ~= ('kanarascout')
			and def.id ~= ('cobra_mk1_a')
			and def.id ~= ('cobra_mk1_b')
			and def.id ~= ('cobra_mk1_c')
			and def.id ~= ('ladybird')
			and def.id ~= ('malabar')
			and def.id ~= ('natrix')
			and def.id ~= ('viper_hw')
			and def.id ~= ('viper_lz')
			and def.id ~= ('viper_mw')
			and def.id ~= ('viper_tw')
			and def.id ~= ('vatakara')
			and def.id ~= ('deneb')
	end, pairs(ShipDef)))

	if loaded_data then
		TraffiShip   = loaded_data.TraffiShip
		ShipsCount   = loaded_data.ShipsCount
		ShipStatic   = loaded_data.ShipStatic
		StaticCount  = loaded_data.StaticCount
		spawnDocked  = loaded_data.spawnDocked
		Police       = loaded_data.Police
		basePort     = loaded_data.basePort
		lastPort     = loaded_data.lastPort
		nextPort     = loaded_data.nextPort
		playerStatus = loaded_data.playerStatus
		lastTime     = loaded_data.lastTime
		pol_ai_compl = loaded_data.pol_ai_compl
		warning      = loaded_data.warning
		fineDetect   = loaded_data.fineDetect

		for i = 1, ShipsCount do
			if not TraffiShip[i] then
				print("NOT EXIST TraffiShip["..i.."] at init, REPLACE")
				replace_and_spawn(i)
			end
		end

		activateON = false
		traffic_docked()
	else
		reinitialize()
		spawnShipsStatics()
		spawnShipsDocked()
		traffic_docked()
	end
	loaded_data = nil
end


local serialize = function ()
	for i = 1, ShipsCount do
		if TraffiShip[i] and not TraffiShip[i]:exists() then
			print("NOT EXIST TraffiShip["..i.."]:exists()")
			TraffiShip[i]=nil
		end
	end

	return {
	TraffiShip   = TraffiShip,
	ShipsCount   = ShipsCount,
	ShipStatic   = ShipStatic,
	StaticCount  = StaticCount,
	spawnDocked  = spawnDocked,
	Police       = Police,
	basePort     = basePort,
	lastPort     = lastPort,
	nextPort     = nextPort,
	playerStatus = playerStatus,
	lastTime     = lastTime,
	pol_ai_compl = pol_ai_compl,
	warning      = warning,
	fineDetect   = fineDetect,
		}
end


local unserialize = function (data)
	loaded_data = data
end


local onGameEnd = function ()
	TraffiShip   = nil
	ShipsCount   = nil
	ShipStatic   = nil
	StaticCount  = nil
	spawnDocked  = nil
	Police       = nil
	basePort     = nil
	loaded_data  = nil
	playerStatus = nil
	lastTime     = nil
	pol_ai_compl = nil
	warning      = nil
	fineDetect   = nil
	activateON   = nil
	GroundShips  = nil
	SpaceShips   = nil
	basePort     = nil
	lastPort     = nil
	nextPort     = nil
	distance     = nil
end


Event.Register("onShipUndocked", onShipUndocked)
Event.Register("onGameEnd", onGameEnd)
Event.Register("onLeaveSystem", onLeaveSystem)
Event.Register("onShipDocked", onShipDocked)
Event.Register("onAICompleted", onAICompleted)
Event.Register("onFrameChanged", onFrameChanged)
Event.Register("onShipCollided", onShipCollided)
Event.Register("onShipDestroyed", onShipDestroyed)
Event.Register("onGameStart", onGameStart)

Serializer:Register("Traffic", serialize, unserialize)
