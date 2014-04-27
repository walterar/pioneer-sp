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
local EquipDef   = import("EquipDef")

local max_hostiles = 5

Event.Register("onEnterSystem", function (ship)
	if Game.system.population == 0 then return end
	if ship:IsPlayer() and Engine.rand:Integer(3) > 2 then
		Timer:CallAt(Game.time+Engine.rand:Integer(2,5), function ()
			local hostiles = utils.build_array(utils.filter(function (k,def)
				return
					def.tag == 'SHIP'
					and def.capacity >= 20
					and def.capacity <= 500
					and def.hyperdriveClass > 0
			end, pairs(ShipDef)))
			if (#hostiles * 2) == 0 then return end
			local hostil = {}
			local n = Engine.rand:Integer(2,#hostiles)
			if n > max_hostiles then n = max_hostiles end
			for i = 1, n do
				hostil[i] = hostiles[Engine.rand:Integer(1,#hostiles)]
				local default_drive = 'DRIVE_CLASS'..tostring(hostil[i].hyperdriveClass)
				local max_laser_size = hostil[i].capacity - EquipDef[default_drive].mass
				local laserdefs = utils.build_array(utils.filter(function (k,def)
					return
						def.slot == 'LASER'
						and def.mass <= max_laser_size
						and string.sub(def.id,0,11) == 'PULSECANNON'
					end, pairs(EquipDef)))
				local laserdef = laserdefs[Engine.rand:Integer(1,#laserdefs)]
				hostil[i] = Space.SpawnShipNear(hostil[i].id, ship,2,3)
				hostil[i]:AddEquip(default_drive)
				hostil[i]:AddEquip(laserdef.id)
				hostil[i]:SetLabel(Ship.MakeRandomLabel())
			end
			for i = 1, n-1 do
				hostil[i]:AIKill(hostil[i+1])
			end
			if DangerLevel > 1 then hostil[n]:AIFlyTo(ship) end
			if (ship:GetEquipFree("LASER") < ShipDef[ship.shipId].equipSlotCapacity.LASER)
				and Engine.rand:Integer(3) > 2 then
				Timer:CallAt(Game.time+Engine.rand:Integer(10,20), function ()
					if not pcall(function ()
						hostil[1]:AIKill(ship)
						hostil[n]:AIKill(ship)
						end) then
					end
				end)
			end
		end)
	end
end)

local t = 0
Event.Register("onShipHit",  function (ship, attacker)
	if ship == nil or ship:IsPlayer() or attacker == nil or attacker:IsPlayer() then return end
	t = t + 1
	if t > 2 then
		t = 0
		ship:CancelAI()
		ship:Explode()
		ship = nil
		Timer:CallAt(Game.time+4, function ()
			if not pcall(function ()
				attacker:CancelAI()
				attacker:Explode()
				attacker = nil
				end) then
			end
		end)
	end
end)
