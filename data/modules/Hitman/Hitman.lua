-- Hitman.lua for Pioneer Scout+ (c)2012-2015 by walterar <walterar2@gmail.com>
-- (mod of Assasination.lua Copyright © 2008-2014 Pioneer Developers. See AUTHORS.txt for details)
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt

local Engine     = import("Engine")
local Lang       = import("Lang")
local Game       = import("Game")
local Space      = import("Space")
local Comms      = import("Comms")
local Timer      = import("Timer")
local Event      = import("Event")
local Mission    = import("Mission")
local Character  = import("Character")
local Format     = import("Format")
local Serializer = import("Serializer")
local Equipment  = import("Equipment")
local ShipDef    = import("ShipDef")
local Ship       = import("Ship")
local utils      = import("utils")
local Music      = import("Music")

local InfoFace = import("ui/InfoFace")

local l   = Lang.GetResource("module-hitman") or Lang.GetResource("module-hitman","en")
local luc = Lang.GetResource("ui-core") or Lang.GetResource("ui-core","en")
local myl = Lang.GetResource("module-myl") or Lang.GetResource("module-myl","en")

local ui = Engine.ui

local max_dist = 30

local num_titles = 25

local ads = {}
local missions = {}

local rank

local onDelete = function (ref)
	ads[ref] = nil
end

local onChat = function (form, ref, option)
	local ad = ads[ref]
	form:Clear()
	if option == -1 then
		form:Close()
		return
	end
	if option == 0 then
		local sys = ad.location:GetStarSystem()
		local introtext = string.interp(l.INTROTEXT, {
								you    = luc.COMMANDER.." "..Character.persistent.player.name,
								name   = ad.client.name,
								org    = ad.org,
								cash   = showCurrency(ad.reward),
								target = ad.target.title.." "..ad.target.name,
								reason = l["REASON_"..Engine.rand:Integer(1, 5)]
		})
		form:SetMessage(introtext.."\n \n*\n*")
	elseif option == 1 then
		local sys   = ad.location:GetStarSystem()
		local sbody = ad.location:GetSystemBody()
		form:SetMessage(string.interp(l.X_WILL_BE_LEAVING, {
			target    = ad.target.name,
			spaceport = sbody.name,
			system    = sys.name,
			sectorX   = ad.location.sectorX,
			sectorY   = ad.location.sectorY,
			sectorZ   = ad.location.sectorZ,
			dist      = string.format("%.2f", ad.dist),
			date      = Format.Date(ad.due),
			shipname  = ad.shipname,
			shipregid = ad.shipregid
		  }).."\n \n*\n*"
		)
	elseif option == 2 then
		local sbody = ad.location:GetSystemBody()
		form:SetMessage(string.interp(l.IT_MUST_BE_DONE_AFTER, {
			target    = ad.target.name,
			spaceport = sbody.name
			}).."\n \n*\n*"
		)
	elseif option == 3 then
		if MissionsSuccesses - MissionsFailures < 5 then
			form:SetMessage(myl.have_enough_experience)
			return
		end
		if Game.player:CriminalRecord() then
			form:SetMessage(l.CRIMINAL_RECORD)
		elseif ad.rank >= 15 and Character.persistent.player:GetCombatRating() < 1 then
			form:SetMessage(l.INSUFFICIENT_LEVEL_COMBAT)
		else
			local backstation = Game.player:GetDockedWith().path
			form:RemoveAdvertOnClose()
			ads[ref] = nil
			local mission = {
				type        ="hitman",
				location    = ad.location,
				backstation = backstation,
				client      = ad.client,
				org         = ad.org,
				danger      = ad.danger,
				due         = ad.due,
				reward      = ad.reward,
				target      = ad.target,
				shipid      = ad.shipid,
				shipname    = ad.shipname,
				shipregid   = ad.shipregid,
				rank        = ad.rank,
				status      = 'ACTIVE'
			}
			table.insert(missions,Mission.New(mission))
			Game.player:SetHyperspaceTarget(mission.location:GetStarSystem().path)
			form:SetMessage(l.EXCELLENT)
		end
		return
	elseif option == 4 then
		form:SetMessage(l.PAID_SITE.."\n \n*\n*")
	end
	form:AddOption(string.interp(l.WHERE_CAN_I_FIND_X, {target = ad.target.name}), 1);
	form:AddOption(l.COULD_YOU_REPEAT_THE_ORIGINAL_REQUEST, 0);
	form:AddOption(l.HOW_SOON_MUST_IT_BE_DONE, 2);
	form:AddOption(l.HOW_WILL_I_BE_PAID, 4);
	form:AddOption(l.OK_AGREED, 3);
end


local makeAdvert = function (station)
	location = _nearbystationsRemotes[Engine.rand:Integer(1,#_nearbystationsRemotes)]
	if location == nil then return end
	local client = Character.New()
	local targetIsfemale = Engine.rand:Integer(1) > 0
	rank = Engine.rand:Integer(1,num_titles)
	local target = Character.New({
						title  = l["TITLE_"..rank],
						armour = true,
						female = targetIsfemale
						})
	local dist = Game.system:DistanceTo(location)
	local due = term(dist,Engine.rand:Number(0.8, 1))
	local danger = Engine.rand:Integer(1,4)
	local reward = Engine.rand:Number(11000*(1+(rank/25)), 15000*(1+(rank/25))) * (1+(danger/4))--XXX
	local shipdefs = utils.build_array(utils.filter(function (k,def)
		return
			def.tag == 'SHIP'
			and def.hyperdriveClass > 0
			and def.equipSlotCapacity.atmo_shield > 0
			and def.capacity >= math.ceil(rank/5)*17
	end, pairs(ShipDef)))
	local shipdef  = shipdefs[Engine.rand:Integer(1,#shipdefs)]
	local shipid   = shipdef.id
	local shipname = shipdef.name
	local ad = {
		client    = client,
		org       = l["ORG_"..Engine.rand:Integer(1, 5)],
		danger    = danger,
		due       = due,
		faceseed  = Engine.rand:Integer(),
		location  = location,
		dist      = dist,
		reward    = reward,
		shipid    = shipid,
		shipname  = shipname,
		shipregid = Ship.MakeRandomLabel(),
		station   = station,
		target    = target,
		rank      = rank
	}
	ad.desc = string.interp(l.ADTEXT, {
								org = ad.org,
								you = luc.COMMANDER.." "..Character.persistent.player.name
		})
	local ref = station:AddAdvert({
		description = ad.desc,
		icon        = "hitman",
		onChat      = onChat,
		onDelete    = onDelete
	})
	ads[ref] = ad
end

local onCreateBB = function (station)
	local num = Engine.rand:Integer(math.ceil(Game.system.lawlessness*10))
	for i = 1, num do
		makeAdvert(station)
	end
end

local onShipDestroyed = function (ship, body)
	for ref, mission in pairs(missions) do
		if mission.ship  == ship and mission.status == 'ACTIVE' and mission.due < Game.time then
			if not body:isa("Ship")
			or not body:IsPlayer() then
				mission.status = 'FAILED'
				mission.notplayer = 'TRUE'
			else
				mission.status = 'COMPLETED'
				mission.location = _nearbystationsRemotes[Engine.rand:Integer(1,#_nearbystationsRemotes)]
				if Engine.rand:Integer(2) > 0 or mission.location == nil then
					mission.location = mission.backstation
				else
					mission.backstation = mission.location
				end
				local dist = mission.location:DistanceTo(Game.system)
				mission.due = term(dist,Engine.rand:Number(0.8, 1))
				Game.player:SetHyperspaceTarget(mission.location:GetStarSystem().path)
				mission.notplayer = 'FALSE'
			end
			mission.ship = nil
			return
		end
	end
end

local _start_launch_sequence = function (mission)
	if mission.ship
		and mission.ship:exists()
		and mission.due >= Game.time
		and (mission.ship.flightState == "DOCKED"
		or mission.ship.flightState == "LANDED")
	then
		Timer:CallAt(mission.due, function ()
			if mission.status == 'COMPLETED' then return end
			if mission.ship and mission.ship:exists() then
				mission.ship:Undock()
				Timer:CallEvery(10, function ()
					if mission.ship
						and mission.ship:exists()
						and mission.ship.flightState ~= "DOCKED"
						and mission.ship.flightState ~= "LANDED"
					then
						return true
					else
						mission.ship:Undock()
						return false
					end
				end)
			end
		end)
	end
end

local onEnterSystem = function (ship)
	if not ship:IsPlayer() then return end
	local syspath = Game.system.path
	for ref,mission in pairs(missions) do
		if mission.status == 'ACTIVE' then
			if not mission.ship then
				if mission.due > Game.time then
					if mission.location:IsSameSystem(syspath) then
						local station = Space.GetBody(mission.location.bodyIndex)
						local shiptype = ShipDef[mission.shipid]
						local default_drive = shiptype.hyperdriveClass
						local laserdefs = utils.build_array(pairs(Equipment.laser))
						table.sort(laserdefs, function (l1, l2) return l1.price < l2.price end)
						local laserdef = laserdefs[mission.danger+1]
						local count = default_drive ^ 2
						mission.ship = Space.SpawnShipDocked(mission.shipid, station)
						if mission.ship == nil then return end
						mission.ship:SetLabel(mission.shipregid)
						mission.ship:AddEquip(Equipment.misc.atmospheric_shielding)
						mission.ship:AddEquip(Equipment.misc.scanner)
						local engine = Equipment.hyperspace['hyperdrive_'..tostring(default_drive)]
						mission.ship:AddEquip(engine)
						mission.ship:AddEquip(laserdef)
						if mission.danger > 3 then
							mission.ship:AddEquip(Equipment.misc.laser_cooling_booster)
						end
						mission.ship:AddEquip(Equipment.cargo.hydrogen, count)
						local count_shields = math.ceil((mission.rank or 1) /5)-1
						if count_shields > 0 then
							mission.ship:AddEquip(Equipment.misc.shield_generator, count_shields)
						end
						if count_shields > 2 then
							mission.ship:AddEquip(Equipment.misc.shield_energy_booster)
						end
						_start_launch_sequence(mission)
						mission.shipstate = 'docked'
					end
				else
					mission.status = 'FAILED'
				end
			else
				if not mission.ship:exists() then
					mission.ship = nil
					if mission.due < Game.time then
						mission.status = 'FAILED'
					end
				end
			end
		end
	end
end

local onShipDocked = function (ship, station)
	for ref,mission in pairs(missions) do
		if ship == Game.player then
			if mission.status == 'COMPLETED' and
				mission.backstation == station.path then
				local text = string.interp(l.SUCCESS, {
					org    = mission.org,
					target = mission.target.name,
					cash = showCurrency(mission.reward),
				})
				Comms.ImportantMessage(text, mission.client.name)
				ship:AddMoney(mission.reward)
				_G.MissionsSuccesses = MissionsSuccesses+1
				mission:Remove()
				missions[ref] = nil
			elseif mission.status == 'FAILED' then
				local text
				if mission.notplayer == 'TRUE' then
					text = string.interp(l.FAILURE_2, {
						org    = mission.org,
						target = mission.target.name,
						cash   = showCurrency(mission.reward)
					})
				else
					text = string.interp(l.FAILURE_3, {
						org    = mission.org,
						target = mission.target.name,
						cash   = showCurrency(mission.reward)
					})
				end
				Comms.ImportantMessage(text)
				_G.MissionsFailures = MissionsFailures+1
				mission:Remove()
				missions[ref] = nil
			end
		else
			if mission.ship == ship then
				mission.status = 'FAILED'
			end
		end
	end
end

local onShipUndocked = function (ship, station)
	for ref,mission in pairs(missions) do
		if mission.status == 'ACTIVE' and ship == mission.ship then
			local target = Game.player:FindNearestTo("PLANET") or Game.player:FindNearestTo("STAR")
			mission.ship:AIEnterLowOrbit(target)
			local taunt = string.interp(l["TAUNT_"..Engine.rand:Integer(1, 3)], {org = mission.org})
			Timer:CallAt(Game.time+90, function ()
				if mission.ship and mission.ship:exists()
					and Game.player:GetCombatTarget() == mission.ship
					and Game.player.flightState == "FLYING" then
					Music.Play("music/core/fx/escalating-danger",false)
					Comms.ImportantMessage(taunt)
					mission.ship:AIKill(Game.player)
				return true end
			end)
		end
	end
end

local onAICompleted = function (ship, ai_error)
	for ref,mission in pairs(missions) do
		if ship and mission.ship == ship
		and mission.status == 'ACTIVE' then
			if Game.player:GetCombatTarget() == ship and Game.player.flightState == "FLYING" then
				ship:AIKill(Game.player)
			return end
			mission.ship:AIDockWith(mission.ship:FindNearestTo("SPACESTATION"))
--[[-- XXX TODO
			local systems = Game.system:GetNearbySystems(max_dist, function (s) return #s:GetStationPaths() > 0 end)
			if #systems == 0 then return end
			local target = systems[Engine.rand:Integer(1,#systems)]
			ship:HyperjumpTo(target.path)
--]]
		end
	end
end

local onUpdateBB = function (station)
	for ref,ad in pairs(ads) do
		if (ad.due < Game.time + 5*60*60*24) then
			ad.station:RemoveAdvert(ref)
		end
	end
	if Engine.rand:Integer(4*24*60*60) < 60*60 then
		makeAdvert(station)
	end
end

	local loaded_data
local onGameStart = function ()
	ads = {}
	missions = {}
	if not loaded_data then return end
	for k,ad in pairs(loaded_data.ads) do
		local ref = ad.station:AddAdvert({
			description = ad.desc,
			icon        = "hitman",
			onChat      = onChat,
			onDelete    = onDelete})
		ads[ref] = ad
	end
	missions = loaded_data.missions
	loaded_data = nil
end

local onClick = function (mission)
	local dist = Game.system and string.format("%.2f", Game.system:DistanceTo(mission.location)) or "???"
	if mission.status =="ACTIVE" then
		return
			ui:Grid({68,32},1)
				:SetColumn(0,{ui:VBox():PackEnd({
					ui:Margin(10),
					ui:Grid(2,1)
						:SetColumn(0, {ui:VBox():PackEnd({ui:Label(l.CONTRACTOR)})})
						:SetColumn(1, {ui:VBox():PackEnd({ui:MultiLineText(mission.org)})}),
					ui:Grid(2,1)
						:SetColumn(0, {ui:VBox():PackEnd({ui:Label(l.CONTACT)})})
						:SetColumn(1, {ui:VBox():PackEnd({ui:MultiLineText(mission.client.name)})}),
					ui:Grid(2,1)
						:SetColumn(0, {ui:VBox():PackEnd({ui:Label(l.REWARD)})})
						:SetColumn(1, {ui:VBox():PackEnd({ui:MultiLineText(showCurrency(mission.reward))})}),
					ui:Margin(10),
					ui:Grid(2,1)
						:SetColumn(0, {ui:VBox():PackEnd({ui:Label(l.TARGET_NAME)})})
						:SetColumn(1, {ui:VBox():PackEnd({ui:MultiLineText(
											mission.target.title.." "..mission.target.name)})
						}),
					ui:Grid(2,1)
						:SetColumn(0, {ui:VBox():PackEnd({ui:MultiLineText(l.TARGET_LEAVING_SPACEPORT)})})
						:SetColumn(1, {ui:VBox():PackEnd({ui:Label(Format.Date(mission.due))})
						}),
					ui:Grid(2,1)
						:SetColumn(0, {ui:VBox():PackEnd({ui:Label(l.SPACEPORT1)})})
						:SetColumn(1, {ui:VBox():PackEnd({ui:MultiLineText(mission.location:GetSystemBody().name)
							})
						}),
					ui:Grid(2,1)
						:SetColumn(0, {ui:VBox():PackEnd({ui:Label(l.SYSTEM)})})
						:SetColumn(1, {ui:VBox():PackEnd({ui:MultiLineText(
											mission.location:GetStarSystem().name
							.." ("..mission.location.sectorX
							.. ","..mission.location.sectorY
							.. ","..mission.location.sectorZ
							..")")
							})
						}),
					ui:Grid(2,1)
						:SetColumn(0, {ui:VBox():PackEnd({ui:Label(l.DISTANCE)})})
						:SetColumn(1, {ui:VBox():PackEnd({ui:Label(dist.." "..l.LY)})
						}),
							ui:Margin(5),
					ui:Grid(2,1)
						:SetColumn(0, {ui:VBox():PackEnd({ui:Label(l.SHIP)})})
						:SetColumn(1, {ui:VBox():PackEnd({ui:MultiLineText(mission.shipname)})
						}),
					ui:Grid(2,1)
						:SetColumn(0, {ui:VBox():PackEnd({ui:Label(l.SHIP_ID)})})
						:SetColumn(1, {ui:VBox():PackEnd({ui:Label(mission.shipregid)})
						}),
		})})
				:SetColumn(1, {ui:VBox():PackEnd(InfoFace.New(mission.target))})
	elseif mission.status =="COMPLETED" then
		return
			ui:Grid({68,32},1)
				:SetColumn(0,{ui:VBox(10):PackEnd({
										ui:Margin(10),
										ui:MultiLineText((l.SUCCESSMSG):interp({
														you    = luc.COMMANDER,
														name   = mission.client.name,
														target = mission.target.name,
														dead   = l["KILLED_"..Engine.rand:Integer(1, 4)],
														cash   = showCurrency(mission.reward),
														dist   = dist.." "..l.LY})
										),
										ui:Margin(10),
										ui:Grid(2,1)
											:SetColumn(0, {
												ui:VBox():PackEnd({
													ui:Label(l.SPACEPORT2)
												})
											})
											:SetColumn(1, {
												ui:VBox():PackEnd({
													ui:MultiLineText(mission.location:GetSystemBody().name)
												})
											}),
										ui:Grid(2,1)
											:SetColumn(0, {
												ui:VBox():PackEnd({
													ui:Label(l.SYSTEM)
												})
											})
											:SetColumn(1, {
												ui:VBox():PackEnd({
													ui:MultiLineText(mission.location:GetStarSystem().name
														.." ("..mission.location.sectorX
														..","..mission.location.sectorY
														..","..mission.location.sectorZ..")")
												})
											}),
										ui:Grid(2,1)
											:SetColumn(0, {
												ui:VBox():PackEnd({
													ui:Label(l.DISTANCE)
												})
											})
											:SetColumn(1, {
												ui:VBox():PackEnd({
													ui:Label(dist.." "..l.LY)
												})
											}),
										ui:Grid(2,1)
											:SetColumn(0, {
												ui:VBox():PackEnd({
													ui:Label(l.BEFORE_THIS_DATE)
												})
											})
											:SetColumn(1, {
												ui:VBox():PackEnd({
													ui:Label(Format.Date(mission.due))
												})
											}),
		})})
		:SetColumn(1,{ui:VBox(10):PackEnd(InfoFace.New(mission.client))})
	elseif mission.status =='FAILED' then
		Timer:CallAt(Game.time+2, function ()
			local current_mission = mission
			for ref,mission in pairs(missions) do
				if mission == current_mission then
					_G.MissionsFailures = MissionsFailures+1
					mission:Remove()
					missions[ref] = nil
				end
			end
		end)
		return
			ui:Grid({68,32},1)
				:SetColumn(0,{ui:VBox(10):PackEnd({
					ui:Margin(10),
					ui:MultiLineText((l.FAILURE_1):interp({
							you  = luc.COMMANDER,
							name = mission.client.name
							})),
					})})
				:SetColumn(1,{ui:VBox(10):PackEnd(InfoFace.New(mission.client))})
	end
end

local serialize = function ()
	return { ads = ads, missions = missions }
end

local unserialize = function (data)
	loaded_data = data
	for k,mission in pairs(loaded_data.missions) do
		if mission.ship and mission.ship:exists() then
			_start_launch_sequence(mission)
		end
	end
end

Event.Register("onGameStart", onGameStart)
Event.Register("onCreateBB", onCreateBB)
Event.Register("onUpdateBB", onUpdateBB)
Event.Register("onEnterSystem", onEnterSystem)
Event.Register("onShipDestroyed", onShipDestroyed)
Event.Register("onShipUndocked", onShipUndocked)
Event.Register("onAICompleted", onAICompleted)
Event.Register("onShipDocked", onShipDocked)

Mission.RegisterType('hitman',l.hitman,onClick)

Serializer:Register("hitman", serialize, unserialize)