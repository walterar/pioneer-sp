-- Copyright © 2008-2015 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt
-- modified for Pioneer Scout+ (c)2012-2015 by walterar <walterar2@gmail.com>
-- Work in progress.

local Lang = import("Lang")
local Comms = import("Comms")
local Event = import("Event")

local l = Lang.GetResource("module-system") or Lang.GetResource("module-system","en")

local onShipFuelChanged = function (ship, state)
	if ship:IsPlayer() and (state == "WARNING" or state == "EMPTY") then
		if MATTcapacitor then
--			Comms.ImportantMessage(t('The propellent cell has been recharged.'))
			ship:SetFuelPercent(50)
		elseif state == "WARNING" then
			Comms.ImportantMessage(l.YOUR_FUEL_TANK_IS_ALMOST_EMPTY)
		elseif state == "EMPTY" then
			Comms.ImportantMessage(l.YOUR_FUEL_TANK_IS_EMPTY)
		end
	end
end

Event.Register("onShipFuelChanged", onShipFuelChanged)
