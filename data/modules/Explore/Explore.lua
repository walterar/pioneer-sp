-- Explore.lua for Pioneer Scout+ (c)2012-2016 by walterar <walterar2@gmail.com>
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt
-- Work in progress.

local Lang       = import("Lang")
local Engine     = import("Engine")
local Game       = import("Game")
local Comms      = import("Comms")
local Event      = import("Event")
local Format     = import("Format")
local Serializer = import("Serializer")
local Character  = import("Character")
local Music      = import("Music")
local Space      = import("Space")
local Timer      = import("Timer")
local Eq         = import("Equipment")
local StarSystem = import("StarSystem")
local MessageBox = import("ui/MessageBox")

local l = Lang.GetResource("module-explore") or Lang.GetResource("module-explore","en")

local loaded_data

_G.explored_systems = {}
_G.explored_count = 0

local systemExplored = function ()
	local bodies = #Space.GetBodies(function (b)
			return b.superType and b.superType ~= 'STARPORT' and b.superType ~= 'NONE'
	end)
	local explored = {system, sector, bodies, date}
	explored.system    =  Game.system.path
	explored.sector    =  explored.system.sectorX..","..
												explored.system.sectorY..","..
												explored.system.sectorZ.."> "
	explored.bodies    =  bodies
	explored.date      =  Game.time

	MessageBox.OK(l.COMPLETE_EXPLORATION..
						"\n\n"..l.SYSTEM..explored.system:GetStarSystem().name..
							"\n"..l.SECTOR..
											" < "..explored.system.sectorX..","..
														 explored.system.sectorY..","..
														 explored.system.sectorZ.." >"..
							"\n"..l.BODIES..explored.bodies..
								"\n"..l.DATE..Format.Date(explored.date), l.OK, "TOP_LEFT", false, false)

	table.insert(_G.explored_systems, explored)
	_G.explored_count = explored_count + 1
	Game.system:Explore()
end

local exploreSystem = function (ship, body)
	if Game.system.explored
		or not ship:IsPlayer()
		or Game.player:CountEquip(Eq.misc.advanced_radar_mapper) < 1
	then return end
	local major_bodies = #Space.GetBodies(function (b)
		return b.superType and b.superType ~= 'STARPORT' and b.superType ~= 'NONE' end)
	local bodies = l.BODIES
	if major_bodies == 1 then bodies = l.BODY end
	Music.Play("music/core/fx/mapping-on"..Engine.rand:Integer(1,3))
	local counter = major_bodies*60
	local msg = l.EXPLORING_SYSTEM:interp({bodycount  = major_bodies,
																				 bodies     = bodies,
																				 body_label = body.label,
																				 system     = Game.system.name
																				 }).."\n\n"..
																				 l.PLEASE_WAIT:interp({minutes=major_bodies})
	MessageBox.OK(msg,l.OK, "TOP_LEFT", false, false)
	local trueSystem = Game.system
	local hostiles = Engine.rand:Integer(DangerLevel+1)
	if hostiles > 0 then
		Timer:CallAt(Game.time+(counter+Engine.rand:Integer(counter*2, counter*4)), function ()
			if not Game.system or Game.system ~= trueSystem then return true end
			ship_hostil(hostiles)
		end)
	end
	counter = Game.time+counter
	Timer:CallEvery(2, function ()
		if not Game.system
			or Game.system ~= trueSystem
			or Game.player.flightState ~= 'LANDED' then
			Music.Play("music/core/fx/mapping-off",false)
		MessageBox.OK(l.FLOW_INTERRUPTED,l.OK, "TOP_LEFT", false, false)
		return true end
		if Game.time < counter then return false end
		Music.Play("music/core/fx/mapping-off",false)
		systemExplored()
		return true
	end)
end

local onEnterSystem = function (ship)
	if not ship:IsPlayer()
		or Game.system.explored
		or Game.player:CountEquip(Eq.misc.advanced_radar_mapper) < 1
	then return end
	local bodies = Space.GetBodies(function (body)
		return body.superType == "GAS_GIANT"
			or (body.superType == "ROCKY_PLANET" and body.type ~= "PLANET_ASTEROID")
	end)
	local dist, msg, xplanet
	if #bodies > 0 then
		for i = 1, #bodies do
			if bodies[i].superType == "ROCKY_PLANET" then
				xplanet = bodies[i]
				break
			end
		end
		if xplanet and Engine.rand:Integer(1) > 0
			and Game.player:DistanceTo(xplanet) > 150e9*500
		then
			for i = 1, #bodies do
				if bodies[i].superType == "ROCKY_PLANET"
					and bodies[i].path:GetSystemBody().mass > xplanet.path:GetSystemBody().mass
				then
					xplanet = bodies[i]
				end
			end
		end
	end
 	if xplanet then dist = Format.Distance(Game.player:DistanceTo(xplanet))
		msg = l.UNEXPLORED_SYSTEM_DETECTED:interp({dist=dist})
		MessageBox.OK(msg, l.OK, "TOP_LEFT", false, false)
		Game.player:SetNavTarget(xplanet)
	elseif (#bodies > 0 and bodies[1].superType == "GAS_GIANT")
		or Game.player:FindNearestTo("STAR") then
		msg = l.NO_ROCKY_PLANETS
		MessageBox.OK(msg, l.OK, "TOP_LEFT", false, false)
		Timer:CallAt(Game.time + 4, function () systemExplored() end)
	end
end

local onGameStart = function ()
	if type(loaded_data) == "table" then
		_G.explored_systems = loaded_data.explored_systems or {}
		_G.explored_count = loaded_data.explored_count or 0
	else
		_G.explored_systems = {}
		_G.explored_count = 0
	end
	loaded_data = nil
end

local serialize = function ()
	return {explored_systems = explored_systems,
					explored_count   = explored_count}
end

local unserialize = function (data)
	loaded_data = data
end

local onGameEnd = function ()
	_G.explored_systems = nil
	_G.explored_count   = nil
end


Event.Register("onShipLanded", exploreSystem)
Event.Register("onGameStart", onGameStart)
Event.Register("onEnterSystem", onEnterSystem)
Event.Register("onGameEnd", onGameEnd)

Serializer:Register("explore", serialize, unserialize)
