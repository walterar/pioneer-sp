-- Copyright © 2008-2016 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt

local Game    = import("Game")
local Engine  = import("Engine")
local Lang    = import("Lang")
local Event   = import("Event")

local TabView   = import("ui/TabView")
local InfoGauge = import("ui/InfoGauge")

local l  = Lang.GetResource("ui-core") or Lang.GetResource("ui-core","en")
local ls = Lang.GetResource("miscellaneous") or Lang.GetResource("miscellaneous","en")

local lobby           = import("StationView/Lobby")
local bulletinBoard   = import("StationView/BulletinBoard")
local commodityMarket = import("StationView/CommodityMarket")
local shipMarket      = import("StationView/ShipMarket")
local equipmentMarket = import("StationView/EquipmentMarket")
local shipRepairs     = import("StationView/ShipRepairs")
local police          = import("StationView/Police")

local ui = Engine.ui

local tabGroup
ui.templates.StationView = function (args)
	if tabGroup then
		tabGroup:SwitchFirst()
		return tabGroup.widget
	end

	tabGroup = TabView.New()

	local player = Game.player

	local cashLabel = ui:NumberLabel("MONEY")
	cashLabel:Bind("value", player, "cash")

	local cargoGauge = ui:Gauge()
	local cargoUsedLabel = ui:Label("")
	local cargoFreeLabel = ui:Label("")
	local function cargoUpdate ()
		cargoGauge:SetUpperValue(player.totalCargo)
		cargoGauge:SetValue(player.usedCargo)
		cargoUsedLabel:SetText(string.interp(l.CARGO_T_USED, { amount = player.usedCargo }))
		cargoFreeLabel:SetText(string.interp(l.CARGO_T_FREE, { amount = player.totalCargo-player.usedCargo }))
	end
	player:Connect("usedCargo", cargoUpdate)
	player:Connect("totalCargo", cargoUpdate)
	cargoUpdate()
	local footer =
		ui:Margin(15, "TOP",
			ui:Margin(5, "VERTICAL",
				ui:Grid({30,30,30},1):SetRow(0, {
					ui:Margin(10, "HORIZONTAL",
						ui:HBox():PackEnd({
							l.CASH..": ",
							cashLabel,
						})
					),
					ui:Margin(10, "HORIZONTAL",
						ui:HBox(10):PackEnd({
							ui:Align("LEFT",
								ui:HBox(10):PackEnd({
									l.CARGO..":",
									cargoGauge,
								})
							),
							ui:VBox():PackEnd({
								cargoUsedLabel,
								cargoFreeLabel,
							}):SetFont("XSMALL"),
						})
					),
					ui:Margin(10, "HORIZONTAL",
						ui:Align("RIGHT",
							l.LEGAL_STATUS..": "..ls.CHECK_WITH_THE_POLICE
						)
					),
				})
			)
		)

	tabGroup:AddTab({ id = "lobby",           title = l.LOBBY,            icon = "Info",       template = lobby           })
	tabGroup:AddTab({ id = "bulletinBoard",   title = l.BULLETIN_BOARD,   icon = "Clipboard",  template = bulletinBoard   })
	tabGroup:AddTab({ id = "commodityMarket", title = l.COMMODITY_MARKET, icon = "Cart",       template = commodityMarket })
	tabGroup:AddTab({ id = "shipMarket",      title = l.SHIP_MARKET,      icon = "Rocketship", template = shipMarket      })
	tabGroup:AddTab({ id = "equipmentMarket", title = l.EQUIPMENT_MARKET, icon = "Radio",      template = equipmentMarket })
	tabGroup:AddTab({ id = "shipRepairs",     title = l.SHIP_REPAIRS,     icon = "Tools",      template = shipRepairs     })
	tabGroup:AddTab({ id = "police",          title = l.POLICE,           icon = "Shield",     template = police          })

	tabGroup:SetFooter(footer)

	return tabGroup.widget
end

Event.Register("onGameEnd", function ()
	tabGroup = nil
end)
