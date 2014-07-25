-- Battle.lua for Pioneer Scout+ (c)2012-2014 by walterar <walterar2@gmail.com>
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt
-- Work in progress.

local ShipDef    = import("ShipDef")
local utils      = import("utils")
local Event      = import("Event")
local Game       = import("Game")
local Space      = import("Space")
local SystemPath = import("SystemPath")
local Engine     = import("Engine")
local Ship       = import("Ship")
local Timer      = import("Timer")
local Eq         = import("Equipment")

local battle_active = false
local max_hostiles = 5
local hostil = {}

local shipWithCannon = function (ship)
	if ship:IsPlayer() then
		if (ship:GetEquipFree("laser_front") < ship:GetEquipSlotCapacity("laser_front"))
			or (ship:GetEquipFree("laser_rear") < ship:GetEquipSlotCapacity("laser_rear")) then
			return true
		end
	end
end

Event.Register("onEnterSystem", function (ship)
	if not ship:IsPlayer() or Game.system.population == 0 then return end
	if Engine.rand:Integer(3) < 1 then--XXX
		battle_active = true
		Timer:CallAt(Game.time+Engine.rand:Integer(2,5), function ()
			local hostiles = utils.build_array(utils.filter(function (k,def)
				return
					def.tag == 'SHIP'
					and def.capacity > 19
					and def.capacity < 501
					and def.hyperdriveClass > 0
			end, pairs(ShipDef)))
			if (#hostiles * 2) == 0 then return end
			local n = Engine.rand:Integer(2,#hostiles)
			if n > max_hostiles then n = max_hostiles end
			for i = 1, n do
				hostil[i] = hostiles[Engine.rand:Integer(1,#hostiles)]
				local default_drive = Eq.hyperspace['hyperdrive_'..tostring(hostil[i].hyperdriveClass)]
				local max_laser_size = hostil[i].capacity - default_drive.capabilities.mass
				local laserdefs = utils.build_array(utils.filter(function (k,l)
					return l:IsValidSlot('laser_front')
						and l.capabilities.mass <= max_laser_size
						and l.l10n_key:find("PULSECANNON")
				end, pairs(Eq.laser)))
				local laserdef = laserdefs[Engine.rand:Integer(1,#laserdefs)]
				hostil[i] = Space.SpawnShipNear(hostil[i].id, ship,2,3)
--				hostil[i]:AddEquip(default_drive)
				hostil[i]:AddEquip(laserdef)
				hostil[i]:SetLabel(Ship.MakeRandomLabel())
			end
			for i = 1, n-1 do
				hostil[i]:AIKill(hostil[i+1])
			end
			if shipWithCannon(ship)
				and DangerLevel > 1 and Engine.rand:Integer(2) > 1 then--XXX
				Timer:CallAt(Game.time+Engine.rand:Integer(10,20), function ()
					if hostil[1] and hostil[1]:exists() then hostil[1]:AIKill(ship) end
					if hostil[n] and hostil[n]:exists() then hostil[n]:AIKill(ship) end
				end)
			end
		end)
	end
end)

local t = 0
Event.Register("onShipHit",  function (ship, attacker)
	if battle_active == false
		or not ship
		or not attacker
		or ship:IsPlayer()
		or attacker:IsPlayer() then
		return
	end
	t = t + 1
	if t > 2 then
		t = 0
		ship:CancelAI()
		ship:Explode()
		ship = nil
		Timer:CallAt(Game.time+4, function ()
			if not attacker or not attacker:exists() then return end
			attacker:CancelAI()
			attacker:Explode()
			attacker = nil
		end)
	end
end)

Event.Register("onFrameChanged", function (body)
	if body:isa("Ship")
		and body:IsPlayer()
		and battle_active
	then
		battle_active = false
		for i = 1, max_hostiles do
			if hostil[i] and hostil[i]:exists() then
--				print(hostil[i].label.." (RESTO DE BATTLE) ELIMINADA")
				hostil[i]:Explode()
				hostil[i] = nil
			end
		end
		hostil = {}
	end
end)
