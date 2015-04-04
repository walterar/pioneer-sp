-- Copyright © 2008-2015 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt
-- modified for Pioneer Scout+ (c)2012-2015 by walterar <walterar2@gmail.com>
-- Work in progress.

local Engine      = import("Engine")
local Lang        = import("Lang")
local Game        = import("Game")
local Ship        = import("Ship")
local ShipDef     = import("ShipDef")
local Player      = import("Player")
local SystemPath  = import("SystemPath")
local ErrorScreen = import("ErrorScreen")
local equipment   = import("Equipment")

local cargo      = equipment.cargo
local misc       = equipment.misc
local laser      = equipment.laser
local hyperspace = equipment.hyperspace

local ui = Engine.ui

local l   = Lang.GetResource("ui-core");
local myl = Lang.GetResource("module-myl") or Lang.GetResource("module-myl", "en");

local setupPlayer1 = function ()
	Game.player:SetShipType('eagle_lrf')
	Game.player:SetLabel(Ship.MakeRandomLabel('Federation'))
	Game.player:AddEquip(hyperspace['hyperdrive_1'])
	Game.player:AddEquip(laser.pulsecannon_1mw)
	Game.player:AddEquip(misc.atmospheric_shielding)
	Game.player:AddEquip(misc.autopilot)
	Game.player:AddEquip(misc.scanner)
	Game.player:AddEquip(misc.missile_guided, 2)
	Game.player:AddEquip(cargo.hydrogen, 1)
	Game.player:SetMoney(100)
end

local setupPlayer2 = function ()
	Game.player:SetShipType("centurion")
	Game.player:SetLabel(Ship.MakeRandomLabel('Confederation'))
	Game.player:AddEquip(hyperspace["hyperdrive_1"])
	Game.player:AddEquip(laser.pulsecannon_1mw)
	Game.player:AddEquip(misc.atmospheric_shielding)
	Game.player:AddEquip(misc.autopilot)
	Game.player:AddEquip(misc.scanner)
	Game.player:AddEquip(cargo.hydrogen, 1)
	Game.player:SetMoney(100)
end

local setupPlayer3 = function ()
	Game.player:SetShipType("anax")
	Game.player:SetLabel(Ship.MakeRandomLabel('Empire'))
	--Game.player:AddEquip(equipment.laser.pulsecannon_1mw)
	Game.player:AddEquip(misc.atmospheric_shielding)
	Game.player:AddEquip(misc.autopilot)
	Game.player:AddEquip(misc.scanner)
--	Game.player:AddEquip(cargo.hydrogen, 2)
	Game.player:SetMoney(100)
end

local setupPlayer4 = function ()
	Game.player:SetShipType("sidie_m")
	Game.player:SetLabel(Ship.MakeRandomLabel('Independent'))
	Game.player:AddEquip(hyperspace["hyperdrive_2"])
	Game.player:AddEquip(misc.atmospheric_shielding)
	Game.player:AddEquip(misc.autopilot)
	Game.player:AddEquip(misc.scanner)
	Game.player:AddEquip(cargo.hydrogen, 4)
	Game.player:SetMoney(100)
end


local loadGame = function (path)
	local ok, err = pcall(Game.LoadGame, path)
	if not ok then
		ErrorScreen.ShowError(l.COULD_NOT_LOAD_GAME .. err)
	end
end

local doLoadDialog = function ()
	ui:NewLayer(
		ui.templates.FileDialog({
			title       = l.LOAD,
			helpText    = l.SELECT_GAME_TO_LOAD,
			path        = "savefiles",
			selectLabel = l.LOAD_GAME,
			onSelect    = loadGame,
			onCancel    = function () ui:DropLayer() end
		})
	)
end

local doSettingsScreen = function()
	ui.layer:SetInnerWidget(
		ui.templates.Settings({
			closeButtons = {
				{ text = l.RETURN_TO_MENU, onClick = function () ui.layer:SetInnerWidget(ui.templates.MainMenu()) end }
			}
		})
	)
end

local doQuitConfirmation = function()
	if Engine.GetConfirmQuit() then
		ui:NewLayer(
			ui.templates.QuitConfirmation({
				onConfirm = function () Engine.Quit() end,
				onCancel  = function () ui:DropLayer() end
			})
		)
	else
		Engine.Quit()
	end
end

local buttonDefs = {
	{   l.START_AT_EARTH,    function () Game.StartGame(SystemPath.New(0,0,0,0,Engine.rand:Integer(4,9)))   setupPlayer1() end },
	{   l.START_AT_NEW_HOPE, function () Game.StartGame(SystemPath.New(1,-1,-1,0,Engine.rand:Integer(4,7))) setupPlayer2() end },
	{ myl.START_AT_ACHERNAR, function () Game.StartGame(SystemPath.New(4,-9,-16,0,Engine.rand:Integer(16,20))) setupPlayer3() end },
	{ myl.START_AT_LAVE,     function () Game.StartGame(SystemPath.New(-2,1,90,0,2)) setupPlayer4() end },
	{ l.LOAD_GAME, doLoadDialog },
	{ l.OPTIONS,   doSettingsScreen },
	{ l.QUIT,      doQuitConfirmation },
}

local anims = {}

local buttonSet = {}
for i = 1,#buttonDefs do
	local def = buttonDefs[i]
	local button = ui:Button(ui:HBox():PackEnd(ui:Label(def[1])))
	button.onClick:Connect(def[2])
	if i < 10 then button:AddShortcut(i) end
	if i == 10 then button:AddShortcut("0") end
	buttonSet[i] = button
	table.insert(anims, {
		widget = button,
		type = "IN",
		easing = "ZERO",
		target = "POSITION_X_REV",
		duration = i * 0.05,
		next = {
			widget = button,
			type = "IN",
			easing = "LINEAR",
			target = "POSITION_X_REV",
			duration = 0.4,
		}
	})
end

local headingLabel = ui:Label("Pioneer Scout Plus"):SetFont("HEADING_XLARGE"):SetColor({ r = 0.8, g = 1.0, b = 0.4 })
table.insert(anims, {
	widget = headingLabel,
	type = "IN",
	easing = "LINEAR",
	target = "OPACITY",
	duration = 0.4,
})

local versionLabel = ui:Label("G22 full version"):SetFont("HEADING_XSMALL"):SetColor({ r = 0.8, g = 1.0, b = 0.4 })
table.insert(anims, {
	widget = versionLabel,
	type = "IN",
	easing = "LINEAR",
	target = "OPACITY",
	duration = 0.4,
})

local menu =
	ui:Grid(1, { 0.2, 0.6, 0.2 })
		:SetRow(0, {
			ui:Grid({ 0.1, 0.8, 0.1 }, 1)
				:SetCell(1, 0,
					ui:Align("LEFT",
						headingLabel
					)
				)
		})
		:SetRow(1, {
			ui:Grid(2,1)
				:SetColumn(1, {
					ui:Align("MIDDLE",
						ui:VBox(10):PackEnd(buttonSet):SetFont("HEADING_NORMAL")
					)
				} )
		})
		:SetRow(2, {
			ui:Grid({ 0.1, 0.8, 0.1 }, 1)
				:SetCell(1, 0,
					ui:Align("RIGHT",
						versionLabel
					)
				)
		})

ui.templates.MainMenu = function (args)
	for _,anim in ipairs(anims) do ui:Animate(anim) end
	return menu
end
