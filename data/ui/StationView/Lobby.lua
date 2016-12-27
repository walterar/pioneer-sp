-- Copyright © 2008-2016 Pioneer Developers. See AUTHORS.txt for details
-- Modified 2012-2016 by walterar for Pioneer Scout Plus
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt

local Character  = import("Character")
local Engine     = import("Engine")
local Format     = import("Format")
local Game       = import("Game")
local Lang       = import("Lang")
local Player     = import("Player")
local Rand       = import("Rand")
local Space      = import("Space")
local StarSystem = import("StarSystem")
local Eq         = import("Equipment")

local InfoFace   = import("ui/InfoFace")
local MessageBox = import("ui/MessageBox")

local l  = Lang.GetResource("ui-core")
local lm = Lang.GetResource("miscellaneous")
local le = Lang.GetResource("module-explore") or Lang.GetResource("module-explore","en")

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
	end)

	local faction_msg
	if Game.system.faction.name == "Confederation" then
		faction_msg = lm.FACTION_CONFEDERATION
	elseif Game.system.faction.name == "Federation" then
		faction_msg = lm.FACTION_FEDERATION
	elseif Game.system.faction.name == "Empire" then
		faction_msg = lm.FACTION_EMPIRE
	else
		faction_msg = lm.FACTION_INDEPENDIENT
	end

	local near_station, dist, near_station_msg
	local near_station_msg = ""
	local success
	repeat
		near_station = _bodyPathToBody(_nearbystationsLocals[Engine.rand:Integer(1,#_nearbystationsLocals)])
		if near_station ~= station then
			success = true
			dist = Format.Distance(station:DistanceTo(near_station))
			near_station_msg = string.interp(lm.DO_NOT_FORGET_TO_VISIT, {
								station = near_station.label, dist    = dist})
		end
	until success or #_nearbystationsLocals < 2

	local PRICE_OF_MAPS = string.interp(le.PRICE_OF_MAPS,
			{price = showCurrency(Game.player:GetDockedWith():GetEquipmentPrice(Eq.cargo.hydrogen)*100)})

	return
		ui:Grid({60,1,39},1)
			:SetColumn(0, {
				ui:VBox(10):PackEnd({
					ui:Label(station.label):SetFont("HEADING_LARGE"),
					ui:HBox(10),
					ui:Label(faction_msg),
					ui:HBox(5),
					ui:Label(near_station_msg),
					ui:HBox(5),
					ui:Label(PRICE_OF_MAPS),

					ui:Expand(),
					ui:Align("MIDDLE", launchButton),
				})
			})
			:SetColumn(2, {
				face.widget
			})
end

return lobby
