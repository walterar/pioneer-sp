-- Autosave.lua for Pioneer Scout+ by walterar Copyright © 2012-2015 <walterar2@gmail.com>
-- this is an code adapted for Scout+ of idea and code of John Bartholomew
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt
-- Work in progress.--

local Game  = import("Game")
local Event = import("Event")
local Timer = import("Timer")

local function Saver(savename)
	return function (ship)
		if ship and ship:IsPlayer() then
			Timer:CallAt(Game.time+4, function ()--XXX
			Game.SaveGame(savename)
			end)
		end
	end
end

local SaveDocked   = Saver('_last-docked')

Event.Register('onShipDocked', SaveDocked)
Event.Register('onShipLanded', SaveDocked)
