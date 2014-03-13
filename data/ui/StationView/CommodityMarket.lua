-- Copyright © 2008-2014 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt

local Engine = import("Engine")
local Lang = import("Lang")
local Game = import("Game")
local ShipDef = import("ShipDef")
local EquipDef = import("EquipDef")
local Comms = import("Comms")

local EquipmentTableWidgets = import("EquipmentTableWidgets")

local ui = Engine.ui

local l = Lang.GetResource("ui-core")

local commodityMarket = function (args)
	local stationTable, shipTable = EquipmentTableWidgets.Pair({
		stationColumns = { "icon", "name", "buy", "sell", "stock" },
		shipColumns = { "icon", "name", "amount" },
	})

	return
		ui:Grid({58,4,38},1)
			:SetColumn(0, {
				ui:VBox():PackEnd({
					ui:Label(l.AVAILABLE_FOR_PURCHASE):SetFont("HEADING_SMALL"),
					ui:Expand():SetInnerWidget(stationTable),
				})
			})
			:SetColumn(2, {
				ui:VBox():PackEnd({
					ui:Label(l.IN_CARGO_HOLD):SetFont("HEADING_SMALL"),
					ui:Expand():SetInnerWidget(shipTable),
				})
			})
end

return commodityMarket
