-- Copyright © 2008-2014 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt
-- modified for Pioneer Scout+ (c)2012-2014 by walterar <walterar2@gmail.com>
-- Work in progress.

local Lang               = import("Lang")
local Engine             = import("Engine")
local Game               = import("Game")
local EquipDef           = import("EquipDef")
local SmallLabeledButton = import("ui/SmallLabeledButton")
local InfoGauge          = import("ui/InfoGauge")

local ui = Engine.ui

local l = Lang.GetResource("ui-core");

local function trim(s) return s:find'^%s*$' and '' or s:match'^%s*(.*%S)' end

local econTrade = function ()

	local cash = Game.player:GetMoney()

	local player = Game.player

--	local usedCabins = Game.player:GetEquipCount("CABIN", "PASSENGER_CABIN")
--	local totalCabins = Game.player:GetEquipCount("CABIN", "UNOCCUPIED_CABIN") + usedCabins

	-- Using econTrade as an enclosure for the functions attached to the
	-- buttons in the UI object that it returns. Seems like the most sane
	-- way to handle it; hopefully the enclosure will evaporate shortly
	-- after the UI is disposed of.

	-- Make a cargo list widget that we can revisit and update
	local cargoListWidget = ui:Margin(0)

	function updateCargoListWidget ()

		local cargoNameColumn = {}
		local cargoQuantityColumn = {}
		local cargoJettisonColumn = {}

		for i = 1,#Constants.EquipType do
			local type = Constants.EquipType[i]
			if type ~= "NONE" then
				local et = EquipDef[type]
				local slot = et.slot
				if slot == "CARGO" then
					local count = Game.player:GetEquipCount(slot, type)
					if count > 0 then
						table.insert(cargoNameColumn, ui:Label(et.name))
						table.insert(cargoQuantityColumn, ui:Label(count.."t"))

						local jettisonButton = SmallLabeledButton.New(l.JETTISON)
						jettisonButton.button.onClick:Connect(function ()
							Game.player:Jettison(type)
							updateCargoListWidget()
							cargoListWidget:SetInnerWidget(updateCargoListWidget())
						end)
						table.insert(cargoJettisonColumn, jettisonButton.widget)
					end
				end
			end
		end

		-- Function returns a UI with which to populate the cargo list widget
		return
			ui:VBox(10):PackEnd({
				ui:Label(l.CARGO):SetFont("HEADING_NORMAL"),
				ui:Scroller():SetInnerWidget(
					ui:Grid(3,1)
						:SetColumn(0, { ui:VBox():PackEnd(cargoNameColumn) })
						:SetColumn(1, { ui:VBox():PackEnd(cargoQuantityColumn) })
						:SetColumn(2, { ui:VBox():PackEnd(cargoJettisonColumn) })
				)
			})
	end

	cargoListWidget:SetInnerWidget(updateCargoListWidget())

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

	local fuelGauge = InfoGauge.New({
		label          = ui:NumberLabel("PERCENT_INTEGER"),
		warningLevel   = 0.1,
		criticalLevel  = 0.05,
		levelAscending = false,
	})
	fuelGauge.label:Bind("valuePercent", Game.player, "fuel")
	fuelGauge.gauge:Bind("valuePercent", Game.player, "fuel")

	-- Define the refuel button
	local refuelButton = SmallLabeledButton.New(l.REFUEL)
	local refuelMaxButton = SmallLabeledButton.New(l.REFUEL_FULL)

	local xfuel = 'WATER'
	if FuelHydrogen == true then xfuel = 'HYDROGEN' end

	local refuelButtonRefresh = function ()
		if Game.player.fuel == 100 or Game.player:GetEquipCount('CARGO', xfuel) == 0 then
		refuelButton.widget:Disable()
		refuelMaxButton.widget:Disable()
		end
		local fuel_percent = Game.player.fuel/100
		fuelGauge.gauge:SetValue(fuel_percent)
		fuelGauge.label:SetValue(fuel_percent)
	end
	refuelButtonRefresh()

	local refuel = function ()
		-- UI button where the player clicks to refuel...
		Game.player:Refuel(1)
		-- ...then we update the cargo list widget...
		cargoListWidget:SetInnerWidget(updateCargoListWidget())

		refuelButtonRefresh()
	end
	local refuelMax = function ()
		repeat
			Game.player:Refuel(1)
		until Game.player.fuel == 100 or Game.player:GetEquipCount('CARGO', xfuel) == 0
		cargoListWidget:SetInnerWidget(updateCargoListWidget())

		refuelButtonRefresh()
	end

	refuelButton.button.onClick:Connect(refuel)
	refuelMaxButton.button.onClick:Connect(refuelMax)

	return ui:Expand():SetInnerWidget(
		ui:Grid({48,4,48},1)
			:SetColumn(0, {
				ui:Margin(5, "HORIZONTAL",
					ui:VBox(20):PackEnd({
						ui:Grid(2,1)
							:SetColumn(0, {
								ui:VBox():PackEnd({
									"",
									ui:Label(l.CASH..": "..showCurrency(cash,2)):SetFont('HEADING_NORMAL'),
--										:SetColor({ r = 0.8, g = 1.0, b = 0.4 }),
									ui:Margin(10),
									ui:Label(l.CARGO_SPACE..":"),
									"",
									ui:Margin(10),
								})
							})
							:SetColumn(1, {
								ui:VBox():PackEnd({
									"",
									"",
									ui:Margin(10),
									ui:Margin(0, "HORIZONTAL",
										ui:HBox(10):PackEnd({
											ui:Align("MIDDLE",
												ui:HBox(10):PackEnd({
													cargoGauge,
												})
											),
											ui:VBox():PackEnd({
												cargoUsedLabel,
												cargoFreeLabel,
											}):SetFont("XSMALL"),
										})
									),
									"",
--									ui:Grid(2,1):SetRow(0, { ui:Label(l.TOTAL..totalCabins), ui:Label(l.USED..": "..usedCabins) }),
									ui:Margin(10),
								})
							}),
						ui:Grid({50,10,40},1)
							:SetRow(0, {
								ui:HBox(5):PackEnd({
									ui:Label(trim(l.FUEL)..":"),
									fuelGauge,
								}),
								nil,
								ui:VBox(5):PackEnd({
									refuelButton.widget,
									refuelMaxButton.widget,
								}),
							})
					})
				)
			})
			:SetColumn(2, {
				cargoListWidget
			})
	)
end

return econTrade
