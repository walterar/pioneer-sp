-- Traffic.lua for Pioneer Scout+ by walterar Copyright © 2012-2014 <walterar2@gmail.com>
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt
-- Work in progress, warning.--
--
local Comms      = import("Comms")
local Engine     = import("Engine")
local Game       = import("Game")
local Space      = import("Space")
local utils      = import("utils")
local ShipDef    = import("ShipDef")
local EquipDef   = import("EquipDef")
local Ship       = import("Ship")
local Timer      = import("Timer")
local Event      = import("Event")
local Serializer = import("Serializer")

local TraffiShip  = {}
local HyperShip   = {}
local ShipsCount  = 0
local HyperCount  = 0
local IsStation   = false
local Active      = false
local Target      = nil
local Police      = nil
local GroundShips = nil
local SpaceShips  = nil
local StationBase = nil
local loaded_data = nil
local collided    = {}
local coll_count  = 0
local tsAlert     = false

local reinitialize = function ()
	TraffiShip  = {}
	HyperShip   = {}
	ShipsCount  = 0
	HyperCount  = 0
	IsStation   = false
	Active      = false
	Target      = nil
	Police      = nil
	StationBase = nil
	collided    = {}
	coll_count  = 0
end

local erase_old_actives = function ()
	if Police then
--
		Police:Explode()
		Police=nil
	end
	if ShipsCount == 0 then return end
	if Game.time > 10 then
		for i = 1, ShipsCount do
			if TraffiShip[i] ~= nil then
				local state = TraffiShip[i].flightState
--
				if state ~= "HYPERSPACE" then
--
					TraffiShip[i]:Explode()
					TraffiShip[i]=nil
				end
			end
		end
	end
	HyperShip   = {}
	HyperCount  = 0
	TraffiShip  = {}
	ShipsCount  = 0
	StationBase = nil
	Active      = false
end

local replace_and_spawn = function (n)
	local truestation = StationBase
	Timer:CallAt(Game.time+10, function ()--XXX
--
		if StationBase == nil or truestation ~= StationBase then
--
		return end
		local ships_traffic
		if StationBase.isGroundStation then
			ships_traffic = GroundShips
		else
			ships_traffic = SpaceShips
		end
		local nship = {}
		nship[n] = ships_traffic[Engine.rand:Integer(1,#ships_traffic)]
		TraffiShip[n] = Space.SpawnShipNear(nship[n].id,Game.player,110, 110)
		local drive = ShipDef[nship[n].id].hyperdriveClass
		TraffiShip[n]:AddEquip("DRIVE_CLASS"..drive)
		TraffiShip[n]:AddEquip("HYDROGEN",drive ^ 2)
		if ShipDef[nship[n].id].equipSlotCapacity.ATMOSHIELD > 0 then
			TraffiShip[n]:AddEquip('ATMOSPHERIC_SHIELDING')
		end
		if Engine.rand:Integer(1,2) > 1 then
			TraffiShip[n]:SetLabel(Ship.MakeRandomLabel(Game.system.faction.name))
		else
			TraffiShip[n]:SetLabel(Ship.MakeRandomLabel())
		end
--
		nship = nil
		TraffiShip[n]:AIDockWith(StationBase)
	end)
end

local activate = function (i)
		local min = 60--XXX
		if StationBase.isGroundStation then min = 20 end
		local xtime = Game.time+Engine.rand:Integer(min,60*5)
		local truestation = StationBase
		Timer:CallAt(xtime, function ()
			local state = Game.player.flightState
			if truestation ~= StationBase or state == "HYPERSPACE" or state == "DOCKING" then return end--XXX
			local sbody = StationBase.path:GetSystemBody()
			local body = Space.GetBody(sbody.parent.index)
			if body == nil or TraffiShip[i] == nil then return end
			state = TraffiShip[i].flightState
			if state ~= "DOCKED" then return end--XXX
			if Engine.rand:Integer(1) > 0 then
				TraffiShip[i]:AIEnterLowOrbit(body)
			else
				TraffiShip[i]:AIEnterLowOrbit(body)
				if HyperCount > 4 then
--
					HyperShip = {}
					HyperCount = 0
				end
				local timeundock
				if StationBase.isGroundStation then
					timeundock = Game.time + 10
				else
					timeundock = Game.time + 20
				end
				Timer:CallAt(timeundock, function ()--XXX
					if TraffiShip[i] == nil then return end
					state = TraffiShip[i].flightState
					if state == "DOCKING" then return end--XXX
					local range = TraffiShip[i].hyperspaceRange
					if range > 30 then range = 30 end
					local systems = Game.system:GetNearbySystems(range)
					if systems == nil then return end
					system_target = systems[Engine.rand:Integer(1,#systems)]
					HyperCount = (HyperCount or 0) + 1
					HyperShip[HyperCount] = TraffiShip[i]
					TraffiShip[i] = nil
					local status = HyperShip[HyperCount]:HyperspaceTo(system_target.path)
					if status == "OK" then
--
--
					else
--
						HyperShip[HyperCount]:Explode()
						HyperShip[HyperCount] = nil
						HyperCount = HyperCount - 1
					end
					Timer:CallAt(Game.time+(60*5), function ()--XXX
						replace_and_spawn(i)
					end)
				end)
			end
		end)
end

local traffic_docked = function ()
--
	for i=1, ShipsCount do
		activate(i)
	end
end

local active_ships = function ()
	if Active == true then return end
	if Game.time < 10 then
		reinitialize()--XXX
		StationBase = Game.player:GetDockedWith()
	end
	if not StationBase then return end
--
	Active = true
	local free_police = 1
	local posib = 2
	if Game.time < 10 then posib = 3 end
	if Engine.rand:Integer(2) < posib then--XXX
		Police = Space.SpawnShipDocked("police", StationBase)
	end
	if Police then
		Police:AddEquip('PULSECANNON_DUAL_1MW')
		Police:AddEquip('LASER_COOLING_BOOSTER')
		Police:AddEquip('ATMOSPHERIC_SHIELDING')
		Police:SetLabel("POLICE")
		free_police = 0
--
	else
--
	end
	local ships_traffic
	if StationBase.isGroundStation then
		ships_traffic = GroundShips
	else
		ships_traffic = SpaceShips
	end
	if StationBase.numDocks == 4 then
		if Game.time<10 then posib=2 else posib=1 end
		ShipsCount = Engine.rand:Integer(posib,2)
	elseif StationBase.numDocks == 6 then
		if Game.time<10 then posib=4 else posib=2 end
		ShipsCount = Engine.rand:Integer(posib,4)
	else
		if StationBase.numDocks == 14 then
			if Game.player.totalMass < 25 then
				if Game.time<10 then posib=12 else posib= 6 end
				ShipsCount = Engine.rand:Integer(posib,12)
			else
				if Game.time<10 then posib=4 else posib=2 end
				ShipsCount = Engine.rand:Integer(posib,4)
			end
		end
	end
	if not ships_traffic or ShipsCount == 0 then return end
	ShipsCount = ShipsCount + free_police
	local ship1
	local ships_traffic_count = #ships_traffic
--
	for i = 1, ShipsCount do
		ship1 = ships_traffic[Engine.rand:Integer(1,ships_traffic_count)]
		local drive = ship1.hyperdriveClass
		TraffiShip[i] = nil--XXX
		TraffiShip[i] = Space.SpawnShipDocked(ship1.id, StationBase)
		if TraffiShip[i] == nil then
			ShipsCount = i-1
--
		break end
		TraffiShip[i]:AddEquip("DRIVE_CLASS"..drive)
		TraffiShip[i]:AddEquip("HYDROGEN",drive*drive)
		if StationBase.isGroundStation
			and ShipDef[TraffiShip[i].shipId].equipSlotCapacity.ATMOSHIELD > 0 then
				TraffiShip[i]:AddEquip('ATMOSPHERIC_SHIELDING')
		end
		if Engine.rand:Integer(1,2) > 1 then
			TraffiShip[i]:SetLabel(Ship.MakeRandomLabel(Game.system.faction.name))
		else
			TraffiShip[i]:SetLabel(Ship.MakeRandomLabel())
		end
--
	end
	traffic_docked()
end

local onShipDocked = function (ship, station)
	if ship:IsPlayer() then return end
	local n
	for i=1, ShipsCount do
		if ship == TraffiShip[i] then
			n=i
			break
		end
	end
--
	Timer:CallAt(Game.time+(60*30), function ()
		StationBase = station
		return activate(n)
	end)
end

local onAICompleted = function (ship, ai_error)
	if ship:GetDockedWith() then return end
	if ship == Police then return end
	if ship:IsPlayer() then
		if IsStation == true then
--
			if Active == false then
				StationBase = Target
				active_ships()
			end
		else
			if Target ~= nil then
--
			end
		end
	else
		if StationBase ~= nil then
			for i = 1, ShipsCount do
				if ship == TraffiShip[i] then
					local state = ship.flightState
--
					if state == "DOCKING" or ai_error ~= "NONE" then
--
					return end
					ship:AIDockWith(StationBase)
				end
			end
		end
	end
end

local onFrameChanged = function (body)
	if body:isa("Ship") and body:IsPlayer() then
		if body.frameBody == nil then return end
		Target = Game.player:GetNavTarget()
		if Target == nil then return end
		local dist
		if StationBase ~= nil then
			dist = Game.player:DistanceTo(StationBase)
--
			if dist > 20000 then
--
				erase_old_actives()
			end
		end
		local closestStation = Game.player:FindNearestTo("SPACESTATION")
		local closestPlanet = Game.player:FindNearestTo("PLANET")
		if Target.type == 'STARPORT_ORBITAL'
			or Target.type == 'STARPORT_SURFACE' then
			IsStation = true
--
--
			dist = Game.player:DistanceTo(Target)
--
			if dist > 2e6 then return end
			if Target == closestStation then
				StationBase = Target
				active_ships()
			end
		else-- XXX
--
--
		end
	end
end

local onShipCollided = function (ship, other)
	if ship:IsPlayer() then return end
	if other == nil then return end
	if ShipsCount == nil or ShipsCount == 0 then return end
	if coll_count > 10 or coll_count == nil then
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
	if ShipsCount == nil or ShipsCount == 0 then return end
	for i=1, ShipsCount do
		if ship == TraffiShip[i] then
--
			TraffiShip[i] = nil
			replace_and_spawn(i)--XXX
			break
		end
	end
	if ship == Police then
--
			Police = nil
	end
end

local policeAction = function (station)
	local ship = Game.player
	local crime,fine = ship:GetCrime()
	if fine == nil or fine == 0 or Police == nil then return end
	local target
	fine = showCurrency(fine)
	local police = Game.system.faction.policeName.." "..station.label
	Comms.ImportantMessage("You_have_committed_a_crime_and_must_pay "..fine, police)
--
--
--
	Timer:CallAt(Game.time+5, function ()--XXX
		if Police and StationBase then
			Police:Undock()
			Police:AIKill(ship)
			Comms.ImportantMessage("Attention!_This_can_prove_costly_Your_life_is_not_worth "..fine, police)
--
--
		end
	end)
	Timer:CallEvery(20, function ()--XXX
		if Police and StationBase then
			Comms.ImportantMessage("Warning!_You_must_go_back_to_the_Station_now_or_you_will_die_soon.", police)
--
--
			target = Game.player:GetNavTarget()
			if target ~= nil then
				print("TARGET ES "..target.label)
			else
				print("TARGET NO EXISTE")
			end
			if target and target ~= StationBase then
				Police:AIKill(ship)
				return false
			else
--
				Police:CancelAI()--XXX no funciona si está disparando los cañones, no deja de disparar.
				Police:RemoveEquip('PULSECANNON_DUAL_1MW')--XXX la única forma de que deje de disparar.
				Police:AIDockWith(StationBase)
				Police:AddEquip('PULSECANNON_DUAL_1MW')--XXX
				return true
			end
		else
			return true
		end
	end)
end
--"You are trying to avoid a fine of $ 7.85"
--"You have committed a crime and must pay $ 7.85"
--"His escape attempts will be useless You pay $ 7.85"
--"Attention! This can prove costly Your life is not worth $ 7.85!"
--"Usted intenta evadir una multa de "
--"Usted ha cometido un delito y debe pagar "
--"Sus intentos de fuga serán inútiles. Debe pagar "
--"¡Atención! Esto puede costarle caro. Su vida no vale "

local onShipUndocked = function (ship, station)
	if not ship:IsPlayer() then return end
	Active = false
	policeAction(station)
end

local onLeaveSystem = function (ship)
	if ship:IsPlayer() then
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
			and def.equipSlotCapacity.ATMOSHIELD > 0
			and def.id ~= ('amphiesma')
			and def.id ~= ('constrictor_a')
			and def.id ~= ('constrictor_b')
			and def.id ~= ('cobra_mk1_a')
			and def.id ~= ('cobra_mk1_b')
			and def.id ~= ('cobra_mk1_c')
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
		TraffiShip  = loaded_data.traffiship
		ShipsCount  = loaded_data.shipscount
		IsStation   = loaded_data.is_station
		Active      = loaded_data.active
		Target      = loaded_data.target
		Police      = loaded_data.police
		StationBase = loaded_data.station_base

		HyperShip =  {}
		HyperCount = 0

		traffic_docked()
	else
		active_ships()
	end
	loaded_data = nil
end

local serialize = function ()
	return {
		traffiship   = TraffiShip,
		shipscount   = ShipsCount,
		is_station   = IsStation,
		active       = Active,
		target       = Target,
		police       = Police,
		station_base = StationBase
		}
end

local unserialize = function (data)
	loaded_data = data
end

local onGameEnd = function ()
	TraffiShip  = nil
	HyperShip   = nil
	ShipsCount  = nil
	HyperCount  = nil
	IsStation   = nil
	Active      = nil
	Target      = nil
	Police      = nil
	StationBase = nil
	collided    = nil
	coll_count  = nil
	loaded_data = nil
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
