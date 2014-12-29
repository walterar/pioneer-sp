-- Traffic.lua for Pioneer Scout+ by walterar Copyright © 2012-2014 <walterar2@gmail.com>
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt
-- Work in progress, pre alpha 0.--
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
--local Format     = import("Format")
local Eq         = import("Equipment")
local StarSystem = import("StarSystem")--XXX
local Constant   = import("Constant")

local misc       = Eq.misc
local laser      = Eq.laser
local hyperspace = Eq.hyperspace
local cargo      = Eq.cargo

local l = Lang.GetResource("core") or Lang.GetResource("core","en")
local myl = Lang.GetResource("module-myl") or Lang.GetResource("module-myl","en");

local TraffiShip   = {}
local ShipsCount   = 0
local spawnDocked  = false
local Target       = nil
local Police       = nil
local GroundShips  = nil
local SpaceShips   = nil
local basePort     = nil
local lastPort     = nil
local nextPort     = nil

local ShipStatic   = {}
local StaticCount  = 0

local loaded_data  = nil
local collided     = {}
local coll_count   = 0
local playerAlert  = "NONE"
local policeAlert  = "NONE"
local npshipAlert  = "NONE"
local playerStatus = nil

local pol_ai_compl = false
local warning      = false
local fineDetect   = false
local shipX        = nil
local activateON   = false


local reinitialize = function ()
	TraffiShip   = {}
	ShipsCount   = 0
	ShipStatic   = {}
	StaticCount  = 0
	spawnDocked  = false
	Target       = nil
	Police       = nil
	basePort     = nil
	lastPort     = nil
	nextPort     = nil
	collided     = {}
	coll_count   = 0
	playerAlert  = "NONE"
	policeAlert  = "NONE"
	npshipAlert  = "NONE"
	playerStatus = nil
	pol_ai_compl = false
	warning      = false
	fineDetect   = false
	shipX        = nil
	activateON   = false
end

local erase_old_spawn = function ()
	if Police then
--
		Police:Explode()
		Police=nil
	end
	if ShipsCount == 0 then return end
	if Game.time > 10 then
		for i = 1, ShipsCount do
			if TraffiShip[i] and TraffiShip[i].flightState ~= "HYPERSPACE" then
				TraffiShip[i]:Explode()
				TraffiShip[i]=nil
			end
		end
	end
	if StaticCount and StaticCount > 0 then
		for i = 1, StaticCount do
--
			ShipStatic[i]:Explode()
			ShipStatic[i] = nil
		end
	end
	TraffiShip   = {}
	ShipsCount   = 0
	basePort     = nil
	spawnDocked  = false
	playerStatus = nil
	ShipStatic   = {}
	StaticCount  = 0
	activateON   = false
end

local replace_and_spawn = function (n)
	local truestation = basePort
	Timer:CallAt(Game.time+10, function ()--XXX
--
		if not basePort or truestation ~= basePort then
--
		return end
		local ships_traffic
		if basePort.isGroundStation then
			ships_traffic = GroundShips
		else
			ships_traffic = SpaceShips
		end
		local drive
		local nship = {}
		repeat
			nship[n] = ships_traffic[Engine.rand:Integer(1,#ships_traffic)]
			drive = hyperspace["hyperdrive_"..tostring(nship[n].hyperdriveClass)]
		until drive
		TraffiShip[n] = Space.SpawnShipNear(nship[n].id,Game.player,110, 110)
		if drive then
			TraffiShip[n]:AddEquip(drive)
			TraffiShip[n]:AddEquip(cargo.hydrogen,drive.capabilities.hyperclass ^ 2)
		end
		nship = nil
		if not basePort.isGroundStation then TraffiShip[n]:AddEquip(misc.scanner) end
		if TraffiShip[n]:CountEquip(misc.shield_generator) > 0 then
			TraffiShip[n]:AddEquip(misc.atmospheric_shielding)
		end
		if Engine.rand:Integer(1) > 0 then
			TraffiShip[n]:SetLabel(Ship.MakeRandomLabel(Game.system.faction.name))
		else
			TraffiShip[n]:SetLabel(Ship.MakeRandomLabel())
		end
--
		TraffiShip[n]:AIDockWith(basePort)
	end)
end

local activate = function (i)
	if not basePort or not basePort:exists() then return end
	local drive
	local min = 40--XXX
	if basePort.isGroundStation then min = 20 end
	local xtime = Game.time+Engine.rand:Integer(min,60*5)
	local truestation = basePort
	Timer:CallAt(xtime, function ()
		if not basePort or truestation ~= basePort then return end
		local sbody = basePort.path:GetSystemBody()
		local body = Space.GetBody(sbody.parent.index)
		if not body or not TraffiShip[i] then return end
		if TraffiShip[i].flightState ~= "DOCKED"
				or (npshipAlert ~= "NONE" and TraffiShip[i]:DistanceTo(Game.player) < 5000)
		then return end--XXX
		TraffiShip[i]:AIEnterLowOrbit(body)
		if Engine.rand:Integer(1) > 0 then
			local timeundock = Game.time + 30--XXX orbitales - mas tiempo para salto = mas lejos
			if basePort.isGroundStation then timeundock = Game.time + 10 end
			Timer:CallAt(timeundock, function ()
				if not TraffiShip[i] or TraffiShip[i].flightState == "DOCKING" then return end
				local range = TraffiShip[i].hyperspaceRange
				if range > 30 then range = 30 end
				local nearbystations = StarSystem:GetNearbyStationPaths(range, nil,function (s) return
					(s.type ~= 'STARPORT_SURFACE') or (s.parent.type ~= 'PLANET_ASTEROID') end)
				local system_target = nearbystations[Engine.rand:Integer(1,#nearbystations)]
				if system_target == nil then return end
--				local systems = Game.system:GetNearbySystems(range)
--				if #systems < 1 then return end
--				local system_target = systems[Engine.rand:Integer(1,#systems)]
				local JumpShip = TraffiShip[i]
				local status = JumpShip:HyperjumpTo(system_target)
--				local status = JumpShip:HyperjumpTo(system_target.path)

				if status == "OK" then
					TraffiShip[i] = nil
--
				else
--
					TraffiShip[i]:AIEnterLowOrbit(body)
				end
				Timer:CallAt(Game.time+(60*5), function ()--XXX
					if basePort and basePort:exists() then replace_and_spawn(i) end
				end)
			end)
		end
	end)
end

local traffic_docked = function ()
	if activateON then return end
	activateON = true
--
	for i=1, ShipsCount do
		activate(i)
	end
end

local spawnShipsDocked = function ()
	if spawnDocked == true then return end
	if Game.time < 10 then basePort = Game.player:GetDockedWith() end
	if not basePort then return end
--
	spawnDocked = true
	local free_police = 1
	local posib = 5
	local starports = #Space.GetBodies(function (body) return body.superType == 'STARPORT' end)
	if Game.time < 10 then posib = 6 end
	if Engine.rand:Integer(5) < posib then--XXX
		if starports < 3 then
			Police = Space.SpawnShipDocked("police_viper", basePort)
		elseif starports > 2 and starports < 6 then
			Police = Space.SpawnShipDocked("police_pacifier", basePort)
		else
			Police = Space.SpawnShipDocked("police_mecha", basePort)
		end
	end
	if Police then
		if Police:GetEquipFree("laser_front") > 0 then
			Police:AddEquip(laser.pulsecannon_dual_1mw)--XXX
			Police:AddEquip(misc.laser_cooling_booster)
		end
		Police:AddEquip(misc.atmospheric_shielding)
		Police:AddEquip(misc.scanner)
		Police:SetLabel(l.POLICE_SHIP_REGISTRATION)
		free_police = 0
--
	else
--
	end
	local ships_traffic
	ShipsCount = basePort.numDocks - 2
	if basePort.isGroundStation then
		ships_traffic = GroundShips
	else
		ships_traffic = SpaceShips
	end
	if Game.time > 10 then ShipsCount = Engine.rand:Integer(1,ShipsCount) end
	if not ships_traffic or ShipsCount == 0 then return end
	ShipsCount = ShipsCount + free_police
	local ships_traffic_count = #ships_traffic
--
	local n=0
	local ship1
	local drive
	local drivenum
	for i = 1, ShipsCount do
		repeat
			ship1 = ships_traffic[Engine.rand:Integer(1,ships_traffic_count)]
			drivenum = ship1.hyperdriveClass
			drive = hyperspace["hyperdrive_"..tostring(drivenum)]
			TraffiShip[i] = Space.SpawnShipDocked(ship1.id, basePort)
--
			n = (n or 0) + 1
			if n > 10 then break end
		until TraffiShip[i]
		n=0
		if not TraffiShip[i] then
			ShipsCount = i-1
--
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
--
	end
end

local onShipDocked = function (ship, station)
	if ship:IsPlayer() then
		basePort = station
		if activateON == false then traffic_docked() end
	return end
	if ship == Police then pol_ai_compl = false end
	for i=1, ShipsCount do
		if ship == TraffiShip[i] then
			basePort = station
			activate(i)
		break end
	end
--
end

local policeStopFire = function ()--XXX la única forma de que deje de disparar.
	Police:CancelAI()
	if Police:GetEquipFree("laser_front") < 1 then
		Police:RemoveEquip(laser.pulsecannon_dual_1mw)
		Police:RemoveEquip(misc.laser_cooling_booster)
	end
end

local onAICompleted = function (ship, ai_error)
	if ship == Police and not pol_ai_compl then
		if Police:GetDockedWith() then return end
		pol_ai_compl = true
--
		policeStopFire()
		shipX = nil
		Police:AIDockWith(basePort)
		warning = false
--
	end
	if ship:GetDockedWith() then return end
	if ship:IsPlayer() then
		if Target and Target == Game.player:FindNearestTo("SPACESTATION") and ai_error == "NONE" then
--
			basePort = Target
			if not spawnDocked then spawnShipsDocked() end
			activateON = false
			traffic_docked()
			return
		elseif Target == Game.player:FindNearestTo("PLANET") and ai_error == "NONE"  then
--
		end
	else
		if basePort then
			for i = 1, ShipsCount do
				if ship == TraffiShip[i] then
					local state = ship.flightState
--
					if ai_error == "REFUSED_PERM" and state == "FLYING" then
						local star = Game.player:FindNearestTo("STAR")
						if not star or not TraffiShip[i] then return end
						TraffiShip[i]:AIEnterHighOrbit(star)
--
					elseif ai_error == "NONE" and state ~= "DOCKING" then
						TraffiShip[i]:AIDockWith(basePort)
--
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
--
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
	if not coll_count or coll_count > 10 then
		collided = {}
		coll_count = 0
	else
		coll_count = coll_count + 1
	end
	collided[coll_count] = ship.label..other.label
--
	if collided[1]==collided[coll_count] then
		for i=1, ShipsCount do
			if ship == TraffiShip[i] then
--
				TraffiShip[i]:Explode()
				TraffiShip[i] = nil
				coll_count = 0
				collided = {}
				replace_and_spawn(i)--XXX
				break
			end
		end
	end
--
	ship:SetHullPercent(1)
	ship:AIFlyTo(ship.frameBody)
end

local onShipDestroyed = function (ship, attacker)
	if not ShipsCount or ShipsCount == 0 then return end
	for i=1, ShipsCount do
		if ship == TraffiShip[i] then
--
			TraffiShip[i] = nil
			replace_and_spawn(i)
			break
		end
	end
	if ship == Police then
--
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
--	local targetPlayer = player:GetNavTarget()
--	if targetPlayer then
--
--	else
--
--	end
	if fine > 0 then
--
		Comms.ImportantMessage(myl.Warning_You_must_go_back_to_the_Station_now_or_you_will_die_soon, police)
		if Police:GetEquipFree("laser_front") > 0 then
			Police:AddEquip(laser.pulsecannon_dual_1mw)--XXX
			Police:AddEquip(misc.laser_cooling_booster)
		end
		local crime = "ESCAPE"
		player:AddCrime(crime, crime_fine(crime))
		pol_ai_compl = false
		Police:AIKill(player)
	end
	Timer:CallEvery(4, function ()--XXX
		if Game.system ~= system then return true end-- chequea no salto hiperespacial aquí
		if not basePort or not Police or not Police:exists() then return true end
		if fine == 0 or player:GetNavTarget() == basePort then
			policeStopFire()
			shipX = nil
			pol_ai_compl = false
--
			Police:AIFlyTo(basePort)
			warning = false
--
			return true
		end
	end)
end

local distance
local sensorDistance = function (every)
--
	local every = every or 5
	local player = Game.player
	if not basePort then return end
--
	distance = nil
	local spawnErased = false
	local distancia_alcanzada = false
	local system = Game.system
	Timer:CallEvery(every, function ()
		if Game.system ~= system then return true end-- verifica no salto hiperespacial aquí
		if not basePort then return false end
		distance = player:DistanceTo(basePort) or 0
		if distance > 300 and playerStatus == "outbound" and distancia_alcanzada == false then--XXX
			distancia_alcanzada = true
			if fineDetect then
--
				warning = false
				actionPolice()
			else
--
			end
		elseif distance > 100e3 and playerStatus == "outbound" and not spawnErased then
--
			Target = Game.player:GetNavTarget()-- asegura target por si no hay cambio de frame
			spawnErased = true-- evita repeticion
			erase_old_spawn()
			return true
		elseif  distance < 100e3 and not spawnDocked and not playerStatus then-- genera spawn
			playerStatus = "inbound"
--
			spawnShipsDocked()
			if not basePort.isGroundStation then
				spawnShipsStatics()
			end
			return true
		end
	end)
end

local onFrameChanged = function (body)
	if activateON then return end
	if body:isa("Ship") and body:IsPlayer() then
		if not body.frameBody then return end
		Target = Game.player:GetNavTarget()
		if not Target or Target == lastPort then return end
		local closestStation = Game.player:FindNearestTo("SPACESTATION")
--		local closestPlanet = Game.player:FindNearestTo("PLANET")
		if Target.type == 'STARPORT_ORBITAL'
			or Target.type == 'STARPORT_SURFACE' then
			nextPort = Target
--
--
			dist = Game.player:DistanceTo(nextPort)
--
			if nextPort == closestStation then
--
				basePort = nextPort
--
				sensorDistance()
			end
		else
--
--
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
		and Game.player:DistanceTo(ship) > 100e3 then
		ship:Explode()
		ship = nil
	return end
	if shipX and shipX:exists() and shipX == ship then return end
	if ship
		and ship:exists()
		and Police
		and Police:DistanceTo(ship) < 100e3
		and (Police:DistanceTo(Game.player) > 5000 or Game.player:GetDockedWith())
	then
		if Police:GetEquipFree("laser_front") > 0 then
			Police:AddEquip(laser.pulsecannon_dual_1mw)--XXX
			Police:AddEquip(misc.laser_cooling_booster)
		end
		shipX = ship
--
		pol_ai_compl = false
		Police:AIKill(shipX)
		shipX:SetHullPercent(0)
		shipX:AIKill(Police)
	end
end)

Event.Register("onShipAlertChanged", function (ship, alert)
	playerAlert = "NONE"
	policeAlert = "NONE"
	npshipAlert = "NONE"
	if ship:IsPlayer() then
		playerAlert = alert
--
	elseif ship == Police then
		policeAlert = alert
--
		if alert == "NONE" and (Police.flightState == "FLYING" or Police.flightState == "DOCKING")then
			policeStopFire()
			pol_ai_compl = false
			Police:AIFlyTo(basePort)
--
		end
	elseif ship and basePort and not basePort.isGroundStation then
--
		npshipAlert = alert
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
		if distance and distance < 2500 then

--			local money = math.floor(Game.player:GetMoney()*30/100) --XXX
			local money = crime_fine("ILLEGAL_JUMP")
			Game.player:AddCrime("ILLEGAL_JUMP", money)
			Comms.ImportantMessage(myl.ILLEGAL_JUMP .."  ".. myl.You_has_been_fined .. showCurrency(money), Game.system.faction.policeName)
			distance = nil
		end
--
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
			and def.id ~= ('amphiesma')
			and def.id ~= ('constrictor_a')
			and def.id ~= ('constrictor_b')
			and def.id ~= ('cobra_mk1_a')
			and def.id ~= ('cobra_mk1_b')
			and def.id ~= ('cobra_mk1_c')
			and def.id ~= ('malabar')
			and def.id ~= ('molamola')
			and def.id ~= ('viper_hw')
			and def.id ~= ('viper_lz')
			and def.id ~= ('viper_mw')
			and def.id ~= ('viper_tw')
			and def.id ~= ('vatakara')
			and def.id ~= ('wave')
	end, pairs(ShipDef)))
	SpaceShips = utils.build_array(utils.filter(function (k,def)
		return def.tag == 'SHIP'
			and def.capacity > 19
			and def.capacity < 501
			and def.hyperdriveClass > 0
	end, pairs(ShipDef)))

	if loaded_data then
		TraffiShip   = loaded_data.TraffiShip
		ShipsCount   = loaded_data.ShipsCount
		spawnDocked  = loaded_data.spawnDocked
		Target       = loaded_data.Target
		Police       = loaded_data.Police
		basePort     = loaded_data.basePort
		lastPort     = loaded_data.lastPort
		nextPort     = loaded_data.nextPort
		playerAlert  = loaded_data.playerAlert
		policeAlert  = loaded_data.policeAlert
		npshipAlert  = loaded_data.npshipAlert
		playerStatus = loaded_data.playerStatus
		pol_ai_compl = loaded_data.pol_ai_compl
		warning      = loaded_data.warning
		fineDetect   = loaded_data.fineDetect
		shipX        = loaded_data.shipX

		activateON   = false
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
	return {
	TraffiShip   = TraffiShip or nil,
	ShipsCount   = ShipsCount,
	spawnDocked  = spawnDocked,
	Target       = Target,
	Police       = Police or nil,
	basePort     = basePort,
	lastPort     = lastPort,
	nextPort     = nextPort,
	playerAlert  = playerAlert,
	policeAlert  = policeAlert,
	npshipAlert  = npshipAlert,
	playerStatus = playerStatus,
	pol_ai_compl = pol_ai_compl,
	warning      = warning,
	fineDetect   = fineDetect,
	shipX        = shipX or nil
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
	Target       = nil
	Police       = nil
	basePort     = nil
	collided     = nil
	coll_count   = nil
	loaded_data  = nil
	playerStatus = nil
	pol_ai_compl = nil
	warning      = nil
	fineDetect   = nil
	shipX        = nil
	activateON   = nil
	playerAlert  = nil
	policeAlert  = nil
	npshipAlert  = nil
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
