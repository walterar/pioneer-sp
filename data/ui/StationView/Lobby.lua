-- Copyright © 2008-2015 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt

local Engine     = import("Engine")
local Game       = import("Game")
local Player      = import("Player")
local Rand       = import("Rand")
local Character  = import("Character")
local Lang       = import("Lang")

local MessageBox = import("ui/MessageBox")
local InfoFace   = import("ui/InfoFace")

local l = Lang.GetResource("ui-core")

local ui = Engine.ui


local lobby = function (tab)
	local station = Game.player:GetDockedWith()

	local rand = Rand.New(station.seed)
	local face = InfoFace.New(Character.New({ title = l.STATION_MANAGER }, rand))

	local launchButton = ui:Button(l.REQUEST_LAUNCH):SetFont("HEADING_NORMAL")
	launchButton.onClick:Connect(function ()
		local crimes, fine = Game.player:GetCrime()
		if not Game.player:HasCorrectCrew() then
			MessageBox.Message(l.LAUNCH_PERMISSION_DENIED_CREW)
		elseif fine > 0 then
			MessageBox.Message(l.LAUNCH_PERMISSION_DENIED_FINED)
		elseif not Game.player:Undock() then
			MessageBox.Message(l.LAUNCH_PERMISSION_DENIED_BUSY)
		else
			Game.SwitchView()
		end
		if Engine.GetAutosaveEnabled() then
			Game.SaveGame("_last-undock")
		end
	end)

	return
		ui:Grid({60,1,39},1)
			:SetColumn(0, {
				ui:VBox(10):PackEnd({
					ui:Label(station.label):SetFont("HEADING_LARGE"),
					ui:Expand(),
					ui:Align("MIDDLE", launchButton),
				})
			})
			:SetColumn(2, {
				face.widget
			})
end

return lobby
