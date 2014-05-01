-- Autosave.lua for Pioneer Scout+ by walterar Copyright © 2012-2014 <walterar2@gmail.com>
-- this is an code adapted for Scout+ of idea and code of John Bartholomew
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt
-- Work in progress.--

local Game  = import("Game")
local Event = import("Event")

local function Saver(savename)
	return function (ship)
		if ship:IsPlayer() then
			Game.SaveGame(savename)
		end
	end
end

local SaveDocked   = Saver('_docked')

Event.Register('onShipDocked', SaveDocked)
Event.Register('onShipLanded', SaveDocked)
