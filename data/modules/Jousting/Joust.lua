-- Joust.lua for Pioneer Scout+ (c)2013-2014 by walterar <walterar2@gmail.com>
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt
-- Work in progress.

local Engine    = import("Engine")
local Game      = import("Game")
local Space     = import("Space")
local Comms     = import("Comms")
local Character = import("Character")
local Timer     = import("Timer")
local Event     = import("Event")
local Format    = import("Format")
local utils     = import("utils")
local EquipDef  = import("EquipDef")
local Ship      = import("Ship")
local ShipDef   = import("ShipDef")
local Lang      = import("Lang")

local l = Lang.GetResource("module-jousting") or Lang.GetResource("module-jousting","en")

local multiplier = 0
local money      = 0
local killcount  = 0

local onEnterSystem = function (player)
	if not player:IsPlayer()
		or Game.system.population > 0
		or Engine.rand:Integer(3) > 0 then
		return
	end
	_G.TrueJoust = false

	local shipdefs = utils.build_array(utils.filter(function (k,def)
		return
			def.tag == 'SHIP' and
			def.capacity > 19 and
			def.capacity < 121 and
			def.hyperdriveClass > 0
		end, pairs(ShipDef)))
	if #shipdefs == 0 then return end
	local shipdef = shipdefs[Engine.rand:Integer(1,#shipdefs)]
	local default_drive = 'DRIVE_CLASS'..tostring(shipdef.hyperdriveClass)
	local max_laser_size = shipdef.capacity - EquipDef[default_drive].mass
	local laserdefs = utils.build_array(utils.filter(function (k, def)
		return
			def.slot == 'LASER'
			and def.mass <= max_laser_size
			and string.sub(def.id,0,11) == 'PULSECANNON'
		end, pairs(EquipDef)))
	local laserdef = laserdefs[Engine.rand:Integer(1,#laserdefs)]
	local hostil = Space.SpawnShipNear(shipdef.id, player, 5, 5)
	if hostil == nil then
		print("EL HOSTIL DE JOUSTING NO HA SIDO CREADO")
	return end
	hostil:SetLabel(Ship.MakeRandomLabel())
	hostil:AddEquip(default_drive)
	hostil:AddEquip(laserdef.id)
	local msg = l["you_have_been_challenged" .. Engine.rand:Integer(1,3)]
	Comms.ImportantMessage(msg, hostil.label)
	local jousting = Game.system
	Timer:CallAt(Game.time+20, function ()
		if Game.system == jousting and hostil ~= nil then
			if (player:GetEquipFree("LASER") < ShipDef[player.shipId].equipSlotCapacity.LASER) then
				_G.TrueJoust = true
				hostil:AIKill(player)
				msg = l["the_time_has_come"..Engine.rand:Integer(1,3)]
				Comms.ImportantMessage(msg, hostil.label)
			else
				hostil:CancelAI()
				multiplier = 100 - (100 * Game.system.lawlessness)
				money = math.floor(player:GetMoney() * (multiplier/1000))
				player:AddMoney(-money)
				local nmsg = Engine.rand:Integer(1,3)
				msg = l["I_have_taken"..nmsg].." $"..money.." "..l["of_your_money"..nmsg]
				Comms.ImportantMessage(msg, hostil.label)
				_G.TrueJoust = false
			end
		end
	end)
end

local onShipHit = function (ship, attacker)
	if TrueJoust == true and ship:IsPlayer() then
		killcount = Character.persistent.player.killcount
		multiplier = 100 - (100 * Game.system.lawlessness)
		money = math.floor(ship:GetMoney() * (multiplier/1000))
	end
end

local onShipDestroyed = function (ship, attacker)
	if TrueJoust == true and attacker == Game.player then
		Timer:CallAt(Game.time+4, function ()
			if killcount < Character.persistent.player.killcount and money > 0  then
				Comms.ImportantMessage(l.the_attacker_money.." ( " .. showCurrency(money*4) .. " ) "..l.is_now_yours)
				Game.player:AddMoney(money*4)
				money = 0
			end
		end)
		_G.TrueJoust = false
	end
end

Event.Register("onShipHit", onShipHit)
Event.Register("onShipDestroyed", onShipDestroyed)
Event.Register("onEnterSystem", onEnterSystem)
