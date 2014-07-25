-- radioactives.lua for Pioneer Scout+ (c)2012-2014 by walterar <walterar2@gmail.com>
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt
-- Work in progress.

local Lang      = import("Lang")
local Game      = import("Game")
local Comms     = import("Comms")
local Event     = import("Event")
local Eq        = import("Equipment")

local l = Lang.GetResource("module-radioactives") or Lang.GetResource("module-radioactives","en");

local charge = 0

local onEnterSystem = function (ship)
	if ship:IsPlayer() then
		charge = 0 -- Check only the target system (Not accumulate)
		if Game.system.population > 0 then
			charge = ship:CountEquip(Eq.cargo.radioactives)
		end
	end
end

local onShipDocked = function (ship)
	if ship:IsPlayer() then
		local discharge = 0 or ship:CountEquip(Eq.cargo.radioactives)
		if charge > discharge then
			local engine = ship:GetEquip('engine',1)
			if engine then
				ship:RemoveEquip(engine)
				ship:AddEquip(Eq.cargo.rubbish,engine.capabilities.mass)
				Comms.ImportantMessage(l.You_have_been_PENALIZED)
			else
				local multiplier = Game.system.lawlessness
				if multiplier < .05 then multiplier = 1 + multiplier end
				local money = math.floor(Game.player:GetMoney() * multiplier)
				ship:AddCrime("WEAPON_DISCHARGE", money)
				Comms.ImportantMessage(l.You_have_been_FINED .. showCurrency(money), Game.system.faction.policeName)
			end
		end
		charge = 0
	end
end

Event.Register("onShipDocked", onShipDocked)
Event.Register("onEnterSystem", onEnterSystem)
