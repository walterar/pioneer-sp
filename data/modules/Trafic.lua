-- Copyright © 2012-2014 Pioneer Scout+ by walterar <walterar2@gmail.com>
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt
-- Work in progress.--
--
local Engine     = import("Engine")
local Game       = import("Game")
local Space      = import("Space")
local utils      = import("utils")
local ShipDef    = import("ShipDef")
local Ship       = import("Ship")
local Timer      = import("Timer")
local Event      = import("Event")

local trafiship = {}
local ships_count = 0
local returning = 0
local destino_final = false
local active = false
local target

local trafic_docked = function (station)
	returning = 0--XXX
	for i=1, ships_count do
		local sbody = station.path:GetSystemBody()
		local objetivo = Space.GetBody(sbody.parent.index)
		local xtime = Game.time+Engine.rand:Integer(20,60*5)
		Timer:CallAt(xtime, function ()
			if not pcall(function ()
				if nil ~= objetivo then
					trafiship[i]:AIEnterLowOrbit(objetivo)
				end
				end) then
			end
		end)
	end
end

_G.trafic = function (mission)
	if active == true then return end
	trafiship = {}
	local destination
	if not mission then
		if Game.time < 10 then
			destination = Game.player:GetDockedWith().label
		else
			if destino_final == true then
				destino_final = false
				destination = target.label
			else return
			end
		end
	else
		destination = mission.location:GetSystemBody().name
	end
	local stations = Space.GetBodies(function (body)
		return
		body:isa("SpaceStation")
	end)
	if #stations > 0 then
		for i=1, #stations do
			local station = stations[i]
			if station.label == destination then
				active = true
				if Engine.rand:Integer(2) > 0 then--XXX
					local police = Space.SpawnShipDocked("police", station)
					if police ~= nil then
						police:SetLabel("POLICE")
					end
				end
				if Engine.rand:Integer(1,4) < 5 then--XXX
					local ships_trafic = utils.build_array(utils.filter(function (k,def)
						return def.tag      == 'SHIP'
							and def.capacity >= 20
							and def.capacity <= 400
							and def.defaultHyperdrive ~= "NONE"
							and def.id ~= ('amphiesma')
							and def.id ~= ('constrictor_a')
							and def.id ~= ('constrictor_b')
							and def.id ~= ('cobra_mk1_a')
							and def.id ~= ('cobra_mk1_b')
							and def.id ~= ('cobra_mk1_c')
							and def.id ~= ('molamola')
							and def.id ~= ('wave')
					end, pairs(ShipDef)))
					if station.numDocks == 4 then
						ships_count = Engine.rand:Integer(1,2)
					elseif station.numDocks == 6 then
						ships_count = Engine.rand:Integer(1,4)
					else
						if station.numDocks == 14 and Game.player.totalMass < 25 then
							ships_count = Engine.rand:Integer(1,12)
						else
							ships_count = Engine.rand:Integer(1,4)
						end
					end
					if #ships_trafic > 0 and ships_count > 0 then
						for i = 1, ships_count do
							trafiship[i] = ships_trafic[Engine.rand:Integer(1,#ships_trafic)]
							if trafiship[i] ~= nil then
								local default_drive = trafiship[i].defaultHyperdrive
								trafiship[i] = Space.SpawnShipDocked(trafiship[i].id, station)
								if nil ~= trafiship[i] then
									trafiship[i]:AddEquip(default_drive)
								else return
								end
								if Engine.rand:Integer(1,2) > 1 then
									trafiship[i]:SetLabel(Ship.MakeRandomLabel(Game.system.faction.name))
								else
									trafiship[i]:SetLabel(Ship.MakeRandomLabel())
								end
							else
								return
							end
						end
						if Game.player:GetDockedWith() then trafic_docked(station) end
					end
				end
			end
		end
	end
end

local onShipDocked = function (ship, station)
	if ship:IsPlayer() then
		active = false
		trafic_docked(station)
	else
		for i=1, ships_count do
			if trafiship[i] == ship then
				local xtime = Game.time+(60*30)
				Timer:CallAt(xtime, function ()
					trafic_docked(station)
				end)
			end
		end
	end
end


local onAICompleted = function (ship, ai_error)
	if ai_error == 'NONE' then
		if ship:IsPlayer() then
			if destino_final == true then
				trafic()
			end
		return
		end
		for i=1, ships_count do
			if ship == trafiship[i] then
				local docked = Game.player:GetDockedWith()
				if docked then
					if docked == ship:GetDockedWith() then return end
					local station = docked
					if returning < ships_count then
						returning = returning + 1
					else
						return
					end
					ship:AIDockWith(station)
				else
					for i=1,ships_count do
					trafiship[i]:Explode()
					trafiship[i] = nil
					end
					active=0
					returning=0
					ships_count=0
					trafiship={}
				end
			end
		end
	else
		print(ai_error)
	end
end

local onFrameChanged = function (body)
	if body:isa("Ship") and body:IsPlayer() then
		if body.frameBody == nil then return end
		target = Game.player:GetNavTarget()
		if target == nil then return end
		if target.type == 'STARPORT_ORBITAL'
			or target.type == 'STARPORT_SURFACE' then
			destino_final = true
			return
		else
			destino_final = false
		end
	end
end

local onShipCollided = function (ship, other)
	for i=1, ships_count do
		if ship == trafiship[i] then
			ship:Explode()
			trafiship[i] = nil
		end
	end
end

local onShipDestroyed = function (ship, attacker)
	for i=1, ships_count do
		if ship == trafiship[i] then
			trafiship[i] = nil
		end
	end
end

local onGameStart = function ()
	active = false
	trafic()
end

Event.Register("onShipDocked", onShipDocked)
Event.Register("onAICompleted", onAICompleted)
Event.Register("onFrameChanged", onFrameChanged)
Event.Register("onShipCollided", onShipCollided)
Event.Register("onShipDestroyed", onShipDestroyed)
Event.Register("onGameStart", onGameStart)
