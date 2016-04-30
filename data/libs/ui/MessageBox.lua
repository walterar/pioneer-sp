-- Copyright © 2008-2016 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt

local Engine = import("Engine")
local ui = Engine.ui

local MessageBox = {}

local function setupLayerAnim (clickWidget)
	local layer = ui.layer

	local anim = ui:NewAnimation({
		widget = layer,
		type = "IN",
		easing = "LINEAR",
		target = "OPACITY",
		duration = 0.1,
	})
	ui:Animate(anim)

	local clicked = false
	clickWidget.onClick:Connect(function ()
		if clicked then return end
		clicked = true

		anim:Finish()

		ui:Animate({
			widget = layer,
			type = "OUT",
			easing = "LINEAR",
			target = "OPACITY",
			duration = 0.1,
			callback = function ()
				-- XXX mostly a hack to fix #3110
				-- something may have dropped our messagebox layer before we get here
				if ui.layer == layer then
					ui:DropLayer()
				end
			end,
		})
	end)
end

function MessageBox.Message (args, align)
	if type(args) == 'string' then
		args = { message = args }
	end

	local text = ui:MultiLineText(args.message)

	local set = align or "MIDDLE"
	local layer = ui:NewLayer(
		ui:ColorBackground(0,0,0,0.5,
			ui:Align(set,
				ui:Background(
					text
				)
			)
		)
	)

	layer:AddShortcut("enter")

	setupLayerAnim(layer)
end


function MessageBox.OK (args,txt_button, align_box, align_txt, align_button)
	if type(args) == 'string' then
		args = { message = args }
	end
	local text = ui:MultiLineText(args.message)
	local txt_button = txt_button or "OK"
	local okButton = ui:Button(txt_button)
	okButton:AddShortcut("enter")
--"MIDDLE""TOP""TOP_LEFT""TOP_RIGHT""BOTTOM""BOTTOM_LEFT""BOTTOM_RIGHT"
	local align_box    = align_box    or "MIDDLE"
	local align_txt    = align_txt    or "MIDDLE"
	local align_button = align_button or "RIGHT"
	ui:NewLayer(
		ui:ColorBackground(0,0,0,0.5,
			ui:Align(align_box,
				ui:Background(
					ui:VBox(10)
						:PackEnd(ui:Align(align_txt, text))
						:PackEnd(ui:Align(align_button, okButton))
				)
			)
		)
	)
	setupLayerAnim (okButton)
end

return MessageBox
