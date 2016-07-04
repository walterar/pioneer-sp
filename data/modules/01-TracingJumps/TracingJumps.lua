-- TracingJumps.lua for Pioneer Scout+ (c)2012-2016 by walterar <walterar2@gmail.com>
-- Detection and track of jumps to hyperspace that occur in the vicinity of the player,
-- for possible persecution.
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt
-- Work in progress.

local Lang       = import("Lang")
local Engine     = import("Engine")
local Game       = import("Game")
local Event      = import("Event")
local Format     = import("Format")
local Serializer = import("Serializer")
local Character  = import("Character")
local ShipDef    = import("ShipDef")
local Space      = import("Space")
local Timer      = import("Timer")
local Eq         = import("Equipment")
local StarSystem = import("StarSystem")
local Comms      = import("Comms")
local MessageBox = import("ui/MessageBox")

local lh = Lang.GetResource("tracingjumps") or Lang.GetResource("tracingjumps","en")

local jumps = {}
local ships_jumped = {}
local loaded_data

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

local ChekOverdue = function ()
	for i,v in pairs(Character.persistent.player.hjumps) do
		if Game.time > v.due+60 then
			table.remove(Character.persistent.player.hjumps,i)
		end
	end
	for i,v in pairs(ships_jumped) do
		if Game.time > v.dest_time+60 then
			table.remove(ships_jumped,i)
		end
	end
end

_G.ShipJump = function (ship)
	if ship.flightState == "DOCKING"
		or ship.flightState == "UNDOCKING"
		or ship.flightState == "HYPERSPACE" then
	return end
	local range = ship.hyperspaceRange
	local status, fuel, duration
	if range and range > 0 then
		if range > 30 then range = 30 end
		local frontWeapon = table.unpack(ship:GetEquip("laser_front"))
		frontWeapon = frontWeapon or nil
		local nearbystations = StarSystem:GetNearbyStationPaths(range, nil,function (s)
			return (s.type ~= 'STARPORT_SURFACE') or (s.parent.type ~= 'PLANET_ASTEROID') end)
		local system_target
		if nearbystations and #nearbystations > 0 then
			system_target = nearbystations[Engine.rand:Integer(1,#nearbystations)]
		end
		local label       = ship.label
		local ship_name   = ShipDef[ship.shipId].name
		local ship_model  = ShipDef[ship.shipId].modelName
		local laser_front = frontWeapon
		local engineClass = ShipDef[ship.shipId].hyperdriveClass
		local shields     = ship:CountEquip(Eq.misc.shield_generator)
		local dest_path   = system_target
		local from_path   = Game.system.path
		if system_target ~= nil then
			local shipx = {
				label       = label,
				ship_model  = ship_model,
				ship_name   = ship_name,
				laser_front = laser_front,
				engineClass = engineClass,
				mil_engine 	= nil,
				shields     = shields,
				dest_time   = nil,
				dest_path   = dest_path,
				from_path   = from_path
			}
			status, fuel, duration = ship:HyperjumpTo(dest_path)
			if not tracingJumps then ship = nil return true end
			if status == "OK" then
				local FreeTons = ship.freeCapacity
				local FreeLaser = ship:GetEquipFree("laser_front")
				local hyperdrive = table.unpack(ship:GetEquip("engine"))
				shipx.dest_time = Game.time+duration+shipx.engineClass
				shipx.mil_engine = string.match (hyperdrive.l10n_key,'MIL') or false
				table.insert(ships_jumped,shipx)
				local cannon = "no"
				if FreeLaser then
					cannon = shipx.laser_front:GetName()
				end
				ship = nil--XXX
				Timer:CallAt(Game.time+shipx.engineClass+1, function ()
					MessageBox.OK(
								 lh.SHIP_LABEL.." : ["..shipx.label..
					"]\n"..lh.SHIP_NAME.." : ["..shipx.ship_name..
					"]\n"..lh.JUMPED_TO.." : "..shipx.dest_path:GetStarSystem().name..
					 "\n"..lh.HYPERDRIVE.." : "..hyperdrive:GetName()..
					 "\n"..lh.GUNS.." : "..cannon..
					 "\n"..lh.SHIELDS.." : "..shipx.shields..
					 "\n"..lh.ARRIVAL_DATE.." : "..Format.Date(shipx.dest_time),lh.OK, "TOP_LEFT", false, false)
				end)
				local jump = {
					label       = shipx.label,
					model       = shipx.ship_name,
					location    = shipx.dest_path,
					due         = shipx.dest_time,
					guns        = cannon,
					shields     = shipx.shields
				}
				table.insert(Character.persistent.player.hjumps,jump)
				status = true
			end
		end
	end
	return status
end

local IncomingJump = function ()
	local incoming
	ChekOverdue()
	for i,v in pairs(ships_jumped) do
		if Game.time < v.dest_time then
			if v.dest_path:IsSameSystem(Game.system.path) then
				incoming = true
				switchEvents()
				local cannon = "no"
				local hyperdrive, hyperfuel
				if v.mil_engine then
					hyperdrive = Eq.hyperspace['hyperdrive_mil'..tostring(v.engineClass)]
					hyperfuel = Eq.cargo.military_fuel
				else
					hyperdrive = Eq.hyperspace['hyperdrive_'..tostring(v.engineClass)]
					hyperfuel = Eq.cargo.hydrogen
				end
				if v.laser_front then cannon = v.laser_front:GetName() end
				MessageBox.OK(
							 lh.SHIP_APPROACHING.." : ["..v.label..
				"]\n"..lh.SHIP_NAME.." : ["..v.ship_name..
				"]\n"..lh.COMING_FROM.." : "..v.from_path:GetStarSystem().name..
				 "\n"..lh.HYPERDRIVE.." : "..hyperdrive:GetName()..
				 "\n"..lh.GUNS.." : "..cannon..
				 "\n"..lh.SHIELDS.." : "..v.shields..
				 "\n"..lh.ARRIVAL_DATE.." : "..Format.Date(v.dest_time),lh.OK, "TOP_LEFT", false, false)--]]
	 print("\n"..lh.SHIP_APPROACHING.." : ["..v.label..
				"]\n"..lh.SHIP_NAME.." : ["..v.ship_name..
				"]\n"..lh.COMING_FROM.." : "..v.from_path:GetStarSystem().name..
				 "\n"..lh.HYPERDRIVE.." : "..hyperdrive:GetName()..
				 "\n"..lh.GUNS.." : "..cannon..
				 "\n"..lh.SHIELDS.." : "..v.shields..
				 "\n"..lh.ARRIVAL_DATE.." : "..Format.Date(v.dest_time).." <<<<<<<<<<<<<<<<<<<<<<<\n")
				local AU = 149597870700
				if Game.system and Game.player and Game.time < (v.dest_time-20) then
					Timer:CallAt(v.dest_time-15, function ()
						if Game.player:DistanceTo(Game.player:FindNearestTo("PLANET")
								or Game.player:FindNearestTo("STAR")) > AU*5 then
							_G.targetShip =
								Space.SpawnShipNear(v.ship_model, Game.player, 10, 20, {v.from_path, v.dest_time})
						else
							_G.targetShip =
								Space.SpawnShip(v.ship_model, 9, 11, {v.from_path, v.dest_time})
						end
						Timer:CallAt(Game.time+25, function ()
							if ShipExists(targetShip) and targetShip.flightState ~= "HYPERSPACE"then
								targetShip:SetLabel(v.label)
								targetShip:AddEquip(hyperdrive)
								targetShip:AddEquip(hyperfuel,(math.floor(v.engineClass ^ 2) / 2))
								targetShip:AddEquip(Eq.misc.atmospheric_shielding)
								targetShip:AddEquip(Eq.misc.scanner)
								targetShip:AddEquip(Eq.misc.autopilot)
								targetShip:AddEquip(Eq.misc.shield_generator,v.shields)
								targetShip:AddEquip(v.laser_front)
								targetShip:SetFuelPercent()
								if targetShip:DistanceTo(Game.player) < 1e4
								or Game.player:GetCombatTarget() == targetShip then
									Game.player:SetNavTarget()
									targetShip:AIKill(Game.player)
									print(targetShip.label.." attacks to "..Game.player.label)
								else
									local act_msg = false
									local target = _nearbystationsLocals[Engine.rand:Integer(1,#_nearbystationsLocals)]
									if target then target = Space.GetBody(target.bodyIndex) end
									if target and targetShip:DistanceTo(target) > AU*50 then
										target = targetShip:FindNearestTo("SPACESTATION")
										if target and targetShip:DistanceTo(target) > AU*50 then target = nil end
									end
									if target then
										act_msg = true
										print(targetShip.label.." flying to "..target.label)
										targetShip:AIDockWith(target)
									elseif not ShipJump(targetShip) then
										target = targetShip:FindNearestTo("PLANET") or targetShip:FindNearestTo("STAR")
										targetShip:AIEnterLowOrbit(target)
										act_msg = true
										print(targetShip.label.." flying to "..target.label)
									end
									if act_msg then
										Comms.Message(lh.TARGET_SHIP_FLYING_TO:interp(
											{label = targetShip.label, target = target.label}))
									end
								end
							else
								print("Ship NOT appeared, possibly in hyperspace or permanently lost")
							end
						end)
					end)
				end
			end
		end
	end
	return incoming
end

local onShipDocked = function (ship, station)
	if ship:IsPlayer() then return end
	local hyperfuel, timeundock, pass
	for i,v in pairs(ships_jumped) do
		if v.label == ship.label then
			if v.mil_engine then
				hyperfuel = Eq.cargo.military_fuel
			else
				hyperfuel = Eq.cargo.hydrogen
			end
			local count = math.floor((v.engineClass ^ 2)/2)
			count = count - ship:CountEquip(hyperfuel)
			ship:AddEquip(hyperfuel,count)
			ships_jumped = {}
			pass = true
			break
		end
	end
	ChekOverdue()
	if pass then
		local undocked = false
		Timer:CallEvery(2, function ()
			if undocked then return true end
			if Game.player:DistanceTo(station) < 1500 then
				timeundock = Game.time + 60
				Timer:CallAt(timeundock, function ()
					if undocked then return true end
					undocked = ship:Undock()
					if undocked then
						timeundock = Game.time + 40--XXX orbitals
						if station.isGroundStation then timeundock = Game.time + 5 end
						Timer:CallAt(timeundock, function ()
							ShipJump(ship)
						end)
						return true
					end
				end)
			end
		end)
	end
end

local onShipDestroyed = function (ship, attacker)
	for i,v in pairs(ships_jumped) do
		if v.label == ship.label then
			table.remove(ships_jumped,i)
		end
	end
	for i,v in pairs(Character.persistent.player.hjumps) do--XXX
		if v.label == ship.label then
			table.remove(Character.persistent.player.hjumps,i)
		end
	end
	if ship == targetShip then
		ship = nil
		_G.targetShip = nil
	end
end

local onEnterSystem = function (ship)
	if not ship:IsPlayer() then return end
	Timer:CallAt(Game.time+2, function ()
		IncomingJump()
	end)
end

local onGameStart = function ()
	if type(loaded_data) == "table" then
		ships_jumped = {}
		ships_jumped = loaded_data.jumped
		loaded_data = nil
	end
	Timer:CallAt(Game.time+2, function ()
		IncomingJump()
	end)
end

local serialize = function ()
	return {jumped = ships_jumped}
end

local unserialize = function (data)
	loaded_data = data
end

switchEvents = function()
	local status = false
	Event.Deregister("onShipDocked", onShipDocked)
	Event.Deregister("onShipDestroyed", onShipDestroyed)
	if (ships_jumped and #ships_jumped > 0) or ShipExists(targetShip) then
		Event.Register("onShipDocked", onShipDocked)
		Event.Register("onShipDestroyed", onShipDestroyed)
		status = true
	end
	return status
end

Event.Register("onGameStart", onGameStart)
Event.Register("onEnterSystem", onEnterSystem)

Serializer:Register("hyperjumps", serialize, unserialize)
