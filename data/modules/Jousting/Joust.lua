-- Joust.lua for Pioneer Scout+ (c)2012-2015 by walterar <walterar2@gmail.com>
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
local Ship      = import("Ship")
local ShipDef   = import("ShipDef")
local Lang      = import("Lang")
local Eq        = import("Equipment")
local Music     = import("Music")

local l = Lang.GetResource("module-jousting") or Lang.GetResource("module-jousting","en")

local multiplier = 0
local money      = 0
local killcount  = 0
local TrueJoust  = false

local onShipHit = function (ship, attacker)
	if TrueJoust == true and ship:IsPlayer() then
		killcount = Character.persistent.player.killcount
	end
end

local onShipDestroyed = function (ship, attacker)
	if TrueJoust == true and attacker == Game.player then
		Timer:CallAt(Game.time+4, function ()
			if ship and killcount < Character.persistent.player.killcount and money > 0  then
				Comms.ImportantMessage(l.the_attacker_money.." ( " .. showCurrency(money*4) .. " ) "..l.is_now_yours)
				Game.player:AddMoney(money*4)
				money = 0
			end
		end)
		TrueJoust = false
	end
end

local joust = function (player)
	TrueJoust = false
	local shipdefs = utils.build_array(utils.filter(function (k,def)
		return
			def.tag == 'SHIP' and
			def.capacity > 19 and
			def.capacity < 121 and
			def.hyperdriveClass > 0
		end, pairs(ShipDef)))
	if #shipdefs == 0 then return end
	local shipdef = shipdefs[Engine.rand:Integer(1,#shipdefs)]
	local default_drive = Eq.hyperspace['hyperdrive_'..tostring(shipdef.hyperdriveClass)]
	local max_laser_size = shipdef.capacity - default_drive.capabilities.mass
	local laserdefs = utils.build_array(utils.filter(function (k,l)
		return l:IsValidSlot('laser_front')
			and l.capabilities.mass <= max_laser_size
			and l.l10n_key:find("PULSECANNON")
	end, pairs(Eq.laser)))
	local laserdef = laserdefs[Engine.rand:Integer(1,#laserdefs)]
	local hostil = Space.SpawnShipNear(shipdef.id, player, 5, 5)
	if hostil == nil then return end
	hostil:SetLabel(Ship.MakeRandomLabel())
	hostil:AddEquip(default_drive)
	hostil:AddEquip(laserdef)
	local msg = l["you_have_been_challenged" .. Engine.rand:Integer(1,3)]
	Comms.ImportantMessage(msg, hostil.label)
	local jousting = Game.system
	Timer:CallAt(Game.time+20, function ()
		if Game.system == jousting and hostil ~= nil then
			if (player:GetEquipFree("laser_front") < player:GetEquipSlotCapacity("laser_front"))
				or (player:GetEquipFree("laser_rear") < player:GetEquipSlotCapacity("laser_rear")) then
				TrueJoust = true
				hostil:AIKill(player)
				msg = l["the_time_has_come"..Engine.rand:Integer(1,3)]
				Comms.ImportantMessage(msg, hostil.label)
				Music.Play("music/core/fx/escalating-danger",false)
			else
				TrueJoust = false
				hostil:CancelAI()
				player:AddMoney(-money)
				local nmsg = Engine.rand:Integer(1,3)
				msg = l["I_have_taken"..nmsg].." $"..money.." "..l["of_your_money"..nmsg]
				Comms.ImportantMessage(msg, hostil.label)
			end
		end
	end)
end

local onEnterSystem = function (player)
	if Game.system.population > 0
		or DangerLevel == 0
		or not player:IsPlayer()
	then return end
	if Engine.rand:Integer(3) < 1 then
		multiplier = 100 - (100 * Game.system.lawlessness)
		money = math.floor(math.min(1e5, player:GetMoney()) * (multiplier/1000))
		Event.Register("onShipHit", onShipHit)
		Event.Register("onShipDestroyed", onShipDestroyed)
		joust(player)
	else
		Event.Deregister("onShipHit", onShipHit)
		Event.Deregister("onShipDestroyed", onShipDestroyed)
	end
end

Event.Register("onEnterSystem", onEnterSystem)
