-- Autosave.lua for Pioneer Scout+ by walterar Copyright © 2012-2016 <walterar2@gmail.com>
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt
-- Work in progress.--

local Game   = import("Game")
local Engine = import("Engine")
local Event  = import("Event")
local Timer  = import("Timer")

local onShipDocked = function (ship, station)
	if not ship:IsPlayer() or not Engine.GetAutosaveEnabled() then return end
	Timer:CallAt(Game.time+5, function ()--XXX
		Game.SaveGame('docked-in_'..station.label)
	end)
end

local onShipLanded = function (ship, body)
	if not ship:IsPlayer() or not Engine.GetAutosaveEnabled() then return end
	Timer:CallAt(Game.time+5, function ()--XXX
		Game.SaveGame('landed-in_'..body.label)
	end)
end

local onShipUndocked = function (ship, station)
	if not ship:IsPlayer() or not Engine.GetAutosaveEnabled() then return end
	Game.SaveGame('undock-of_'..station.label)
end

local onShipBlastOff = function (ship, body)
	if not ship:IsPlayer() or not Engine.GetAutosaveEnabled() then return end
	Game.SaveGame('blast-of_'..body.label)
end

Event.Register("onShipBlastOff", onShipBlastOff)
Event.Register("onShipUndocked", onShipUndocked)
Event.Register('onShipDocked', onShipDocked)
Event.Register('onShipLanded', onShipLanded)
