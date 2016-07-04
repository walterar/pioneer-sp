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

local l  = Lang.GetResource("ui-core") or Lang.GetResource("ui-core","en")
local lm = Lang.GetResource("miscellaneous") or Lang.GetResource("miscellaneous","en")

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

local shipTarget

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
--print("NO ES UNA NAVE ACTIVA")
			return false
		end
	end
end


local ShipsAvailable = function ()
	GroundShips = utils.build_array(utils.filter(function (k,def)
		return def.tag == 'SHIP'
			and def.capacity > 19
			and def.capacity < 501
			and def.hyperdriveClass > 0
			and def.equipSlotCapacity.atmo_shield > 0
			and def.id ~= ('ac33')
			and def.id ~= ('amphiesma')
			and def.id ~= ('bowfin')
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
			and def.id ~= ('bowfin')
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
	return
end


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
	if Game.player:GetCombatTarget() then return false end--XXX

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
			if ShipExists(TraffiShip[i]) then
				TraffiShip[i]:Disappear()
				TraffiShip[i]=nil
			end
		end
	end

	if StaticCount and StaticCount > 0 then
		for i = 1, StaticCount do
			if ShipExists(ShipStatic[i]) then
				ShipStatic[i]:Disappear()
				ShipStatic[i] = nil
			end
		end
	end

	clear()
	return true
end


local addWeapons = function (ship)
	local max_laser_size = ship.freeCapacity - Eq.misc.shield_generator.capabilities.mass
	local laserdefs = utils.build_array(utils.filter(function (k,l)
		return l:IsValidSlot('laser_front')
			and l.capabilities.mass <= max_laser_size
			and l.l10n_key:find("PULSECANNON")
	end, pairs(Eq.laser)))
	local laserdef = laserdefs[Engine.rand:Integer(1,#laserdefs)]
	ship:AddEquip(laserdef)
	if DangerLevel > 0 and Eq.misc.laser_cooling_booster.capabilities.mass < ship.freeCapacity then
		ship:AddEquip(Eq.misc.laser_cooling_booster)
	end
	for i=1, DangerLevel+1 do
		if Eq.misc.shield_generator.capabilities.mass < ship.freeCapacity then
			ship:AddEquip(Eq.misc.shield_generator, 1)
		else break
		end
	end
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
		local ship_type = ShipDef[TraffiShip[n].shipId]
		if ship_type.equipSlotCapacity.atmo_shield > 0 then
			TraffiShip[n]:AddEquip(Eq.misc.atmospheric_shielding)
		end
		if Engine.rand:Integer(1) > 0 then
			TraffiShip[n]:SetLabel(Ship.MakeRandomLabel(Game.system.faction.name))
		else
			TraffiShip[n]:SetLabel(Ship.MakeRandomLabel())
		end
		addWeapons(TraffiShip[n])
		TraffiShip[n]:AIDockWith(basePort)
	end)
end


function activate (i)
	if not basePort or not basePort:exists() then return end
	local xtime = lastTime+Engine.rand:Integer(20,50)--XXX
	lastTime = xtime
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
print(TraffiShip[i].label.." NOT UNDOCK.")
			break end
		until success
		local timeundock = Game.time + 20--XXX orbitals
		if basePort.isGroundStation then timeundock = Game.time + 3 end
		Timer:CallAt(timeundock, function ()
			if not ShipExists(TraffiShip[i])
				or TraffiShip[i].flightState ~= "FLYING"
			then return end
			local ship = TraffiShip[i]
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
--print("nearby body target found = "..target.label)
			else
				target = ship:FindNearestTo("PLANET") or ship:FindNearestTo("STAR")
--print("nearby body target not found, target alternative = "..target.label)
			end
			if not target or not ShipExists(ship) then return end
--print("ship "..ship.label.." to low orbit of "..target.label)
			ship:AIEnterLowOrbit(target)
			if Engine.rand:Integer(1) < 1
				or ship == Game.player:GetCombatTarget() then-- XXX hyperspace
				Timer:CallAt(Game.time + 5, function ()
					if not ShipExists(ship)
						or ship.flightState == "DOCKING"
						or ship.flightState == "UNDOCKING"
--						or MissileActive > 0--XXX
					then return end
					if ShipJump(ship) then
						replace_and_spawn(i)
					else
						if ShipExists(ship) then ship:Explode() end
						replace_and_spawn(i)
					return end
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
		if ShipExists(TraffiShip[i]) and TraffiShip[i].flightState =="DOCKED" then
			activate(i)
		end
	end
end


local spawnShipsDocked = function ()
	if spawnDocked == true then return end
	if Game.time < 10 then basePort = Game.player:GetDockedWith() end
	if not basePort then return end
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
	if not ships_traffic or ShipsCount == 0 then return end
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
		addWeapons(TraffiShip[i])
		if Engine.rand:Integer(1,2) > 1 then
			TraffiShip[i]:SetLabel(Ship.MakeRandomLabel(Game.system.faction.name))
		else
			TraffiShip[i]:SetLabel(Ship.MakeRandomLabel())
		end
	end
	if ShipExists(shipTarget) and ShipExists(TraffiShip[i]) then
		TraffiShip[i] = shipTarget
		shipTarget = nil
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
						if Game.player:GetCombatTarget() ~= TraffiShip[i] then
							TraffiShip[i]:AIDockWith(basePort)
						else
							--XXX
							shipTarget = TraffiShip[i]
							TraffiShip[i] = nil
							--XXX busca otherPort y
							local nearPorts = Space.GetBodies(function (body)
								return body.superType == 'STARPORT' and body.superType ~= lastPort
							end)
							if nearPorts and #nearPorts > 0 then
								local otherPort = nearPorts[Engine.rand:Integer(1, #nearPorts)]
								if otherPort then
									shipTarget:AIDockWith(otherPort)
								else
									if not ShipJump(shipTarget) then
										shipTarget:Explode()
									end
								end
							end
						end
					end
				end
			end
		end
	end
end


local spawnShipsStatics = function ()
	if Game.time < 10 then basePort = Game.player:GetDockedWith() end
	if not basePort or (basePort and basePort.isGroundStation) then return end
	local pop = Game.system.population
	if pop == 0 then return end
	local Rand= Engine.rand
	local shipdefs = utils.build_array(utils.filter(function (k,def)
		return def.tag == 'STATIC_SHIP' end, pairs(ShipDef)))
	if #shipdefs > 0 then
		StaticCount = Rand:Integer(0,math.min(Rand:Integer(0,4),1+math.floor(math.ceil(pop))))
		if StaticCount < 1 then return end
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
print(ShipDef[TraffiShip[i].shipId].name.." "..ship.label.." is collided by "..other.label.." and destroyed")
				TraffiShip[i]:Explode()
				replace_and_spawn(i)
			return end
		end
	end
end


local onShipDestroyed = function (ship, attacker)
	if ShipsCount and ShipsCount > 0 then
		for i=1, ShipsCount do
			if ship == TraffiShip[i] then
--print(ShipDef[TraffiShip[i].shipId].name.." "..ship.label.." is destroyed by "..attacker.label)
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
		Comms.ImportantMessage(lm.WARNING_YOU_MUST_GO_BACK, police)
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
		if Game.system ~= system-- chequea no salto hiperespacial aquí
			or not basePort
			or not ShipExists(Police)
		then
			return true
		end
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
				if target == basePort then return false end
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
	local NextNearbyStation = Game.player:FindNearestTo("SPACESTATION")
	if lastPort == NextNearbyStation then return end
	if not target and Game.player:DistanceTo(NextNearbyStation) < 20e3 then
		target = Game.player:FindNearestTo("SPACESTATION")
	end
	if not target or Game.player:DistanceTo(target) > 100e3 then return end
	if not basePort or target ~= basePort then
		activateON = false
	end
	if activateON then return end
	if target.superType == 'STARPORT' then
		nextPort = target
		local dist = Game.player:DistanceTo(nextPort)
		if dist < 100e3 then
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


local onShipFiring = function (ship)
	if not ShipExists(ship)
		or ship:IsPlayer()
		or ship == Police
	then return end
	if ShipExists(ship)
		and ShipExists(Police)
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
end


local onShipAlertChanged = function (ship, alert)
	if ship ~= Police then return end
	if alert == "NONE" and Police.flightState == "FLYING" then
		policeStopFire()
		pol_ai_compl = false
		Police:AIFlyTo(basePort)
	end
end


local onShipUndocked = function (ship, station)
	if not ship:IsPlayer() then return end
	playerStatus = "outbound"
	lastPort = station
	local crime,fine = Game.player:GetCrime()
	if fine and fine > 0 then
		fine = showCurrency(fine)
		local police = Game.system.faction.policeName.." "..basePort.label
		Comms.ImportantMessage(lm.YOU_HAVE_COMMITTED_A_CRIME_AND_MUST_PAY..fine, police)
		fineDetect = true
	end
	sensorDistance()
end


local onEnterSystem = function (ship)
	if Game.system.population == 0 then return end
	Event.Register("onShipDocked", onShipDocked)
	Event.Register("onShipUndocked", onShipUndocked)
	Event.Register("onAICompleted", onAICompleted)
	Event.Register("onShipAlertChanged", onShipAlertChanged)
	Event.Register("onFrameChanged", onFrameChanged)
	Event.Register("onShipFiring", onShipFiring)
	Event.Register("onShipCollided", onShipCollided)
	Event.Register("onShipDestroyed", onShipDestroyed)

	ShipsAvailable()
end


local onLeaveSystem = function (ship)
	if ship:IsPlayer() then
		ship:CancelAI()
		if distance and distance < 2500 then
			local money = crime_fine("ILLEGAL_JUMP")
			Game.player:AddCrime("ILLEGAL_JUMP", money)
			Comms.ImportantMessage(lm.ILLEGAL_JUMP .."  ".. lm.YOU_HAS_BEEN_FINED .. showCurrency(money), Game.system.faction.policeName)
			distance = nil
		end
		reinitialize()
		Event.Deregister("onShipDocked", onShipDocked)
		Event.Deregister("onShipUndocked", onShipUndocked)
		Event.Deregister("onAICompleted", onAICompleted)
		Event.Deregister("onShipAlertChanged", onShipAlertChanged)
		Event.Deregister("onFrameChanged", onFrameChanged)
		Event.Deregister("onShipFiring", onShipFiring)
		Event.Deregister("onShipCollided", onShipCollided)
		Event.Deregister("onShipDestroyed", onShipDestroyed)
	end
end


local onGameStart = function ()
	if Game.system.population == 0 then return end

	Event.Register("onShipDocked", onShipDocked)
	Event.Register("onShipUndocked", onShipUndocked)
	Event.Register("onAICompleted", onAICompleted)
	Event.Register("onShipAlertChanged", onShipAlertChanged)
	Event.Register("onFrameChanged", onFrameChanged)
	Event.Register("onShipFiring", onShipFiring)
	Event.Register("onShipCollided", onShipCollided)
	Event.Register("onShipDestroyed", onShipDestroyed)

	ShipsAvailable()

	if type(loaded_data) == "table" then

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
		shipTarget   = loaded_data.shipTarget

		if ShipsCount and ShipsCount > 0 then
			for i = 1, ShipsCount do
				if not TraffiShip[i] then
					print("NOT EXIST TraffiShip["..i.."] at init, REPLACE")
					replace_and_spawn(i)
				end
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

	if ShipsCount and ShipsCount > 0 then
		for i = 1, ShipsCount do
			if not ShipExists(TraffiShip[i])
				or TraffiShip[i].flightState == "HYPERSPACE" then
				TraffiShip[i]= nil
			end
		end
	end

	if not ShipExists(Police) then Police = nil end

	if shipTarget and not ShipExists(shipTarget) then
		shipTarget = nil
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
	shipTarget   = shipTarget
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
	shipTarget   = nil
end

Event.Register("onEnterSystem", onEnterSystem)
Event.Register("onLeaveSystem", onLeaveSystem)
Event.Register("onGameStart", onGameStart)
Event.Register("onGameEnd", onGameEnd)

Serializer:Register("Traffic", serialize, unserialize)
