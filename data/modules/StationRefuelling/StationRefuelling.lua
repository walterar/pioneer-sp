-- Copyright © 2008-2015 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt

local Lang      = import("Lang")
local Game      = import("Game")
local Comms     = import("Comms")
local Event     = import("Event")
local Format    = import("Format")
local Equipment = import("Equipment")

local l = Lang.GetResource("module-stationrefuelling")


local calculateFee = function (station)
	local fee = math.ceil(4 * (2.0-Game.system.lawlessness))
	local propeller = Equipment.cargo.water
	if FuelHydrogen then propeller = Equipment.cargo.hydrogen end
	local recharge = math.ceil(((Game.player.fuelMassLeft/Game.player.fuel)*100)-Game.player.fuelMassLeft)
	fee = fee+(recharge*station:GetEquipmentPrice(propeller))
	return fee
end


local onShipDocked = function (ship, station)
	if not ship:IsPlayer() then
		ship:SetFuelPercent() -- refuel NPCs for free.
		return
	end
	local fee = calculateFee(station)
	if ship:GetMoney() < fee then
		Comms.Message(l.THIS_IS_STATION_YOU_DO_NOT_HAVE_ENOUGH:interp({station = station.label,fee = showCurrency(fee)}))
		ship:SetMoney(0)
	else
		Comms.Message(l.WELCOME_ABOARD_STATION_FEE_DEDUCTED:interp({station = station.label,fee = showCurrency(fee)}))
		ship:AddMoney(0 - fee)
		ship:SetFuelPercent()
	end
end

Event.Register("onShipDocked", onShipDocked)
