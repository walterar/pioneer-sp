-- Hitman.lua for Pioneer Scout+ (c)2012-2016 by walterar <walterar2@gmail.com>
-- (mod of Assasination.lua Copyright © 2008-2016 Pioneer Developers. See AUTHORS.txt for details)
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

local MsgBox   = import("ui/MessageBox")
local SLButton = import("ui/SmallLabeledButton")
local InfoFace = import("ui/InfoFace")

local l   = Lang.GetResource("module-hitman") or Lang.GetResource("module-hitman","en")
local luc = Lang.GetResource("ui-core") or Lang.GetResource("ui-core","en")
local lm  = Lang.GetResource("miscellaneous") or Lang.GetResource("miscellaneous","en")

local ui = Engine.ui

local max_dist = 30

local num_titles = 25

local ads = {}
local missions = {}

local rank

local Exists = function (ship)
	local exists = false
	if ship:exists() then
		exists = true
	end
	return exists
end
local ShipExists = function (ship)
	if ship then
		ok,val = pcall(Exists, ship)
		if ok then
			return val
		else
			return false
		end
	end
end

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
			dist      = ad.dist,
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
			form:SetMessage(lm.HAVE_ENOUGH_EXPERIENCE)
			return
		end
		if Game.player:CriminalRecord() then
			form:SetMessage(lm.CRIMINAL_RECORD)
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
				date        = Game.time,
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
			if NavAssist then Game.player:SetHyperspaceTarget(mission.location:GetStarSystem().path) end
			form:SetMessage(l.EXCELLENT)
			switchEvents()
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

	if _nearbystationsRemotes
		and #_nearbystationsRemotes > 0 then
		location = _nearbystationsRemotes[Engine.rand:Integer(1,#_nearbystationsRemotes)]
	end
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
	local due = _remote_due(dist,Engine.rand:Number(0.8, 1,true))
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

	local dist_txt = _distTxt(location)

	local ad = {
		client    = client,
		org       = l["ORG_"..Engine.rand:Integer(1, 5)],
		danger    = danger,
		date      = Game.time,
		due       = due,
		faceseed  = Engine.rand:Integer(),
		location  = location,
		dist      = dist_txt,
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

local _start_launch_sequence = function (mission)
	if ShipExists(mission.ship)
		and mission.due-10 > Game.time
		and mission.ship.flightState == "DOCKED"
	then
		Timer:CallAt(mission.due-10, function ()
			if mission.status == 'TRIP_BACK'
				or not ShipExists(mission.ship)then
			return end
			Timer:CallEvery(10, function ()
				if Game.player:GetDockedWith() == mission.ship:GetDockedWith()
					and mission.ship.alertStatus ~= "NONE"
					and mission.ship:GetDockedWith().type == "STARPORT_ORBITAL" then
					return false
				end
				return mission.ship:Undock()
			end)
		end)
	end
	local launched = false
	if mission.ship.flightState ~= "DOCKED" then
		launched = true
	end
	return launched
end

local onShipDestroyed = function (ship, body)
	for ref, mission in pairs(missions) do
		if mission.shipregid == ship.label
			and (mission.status == 'ACTIVE' or mission.status == 'JUMPING')
		then
			if not body:isa("Ship")
			or not body:IsPlayer() then
				mission.status = 'FAILED'
				mission.notplayer = 'TRUE'
			else
				mission.status = 'TRIP_BACK'
				mission.location = _nearbystationsRemotes[Engine.rand:Integer(1,#_nearbystationsRemotes)]
				if (not mission.location or Engine.rand:Integer(2) > 0)
					and Game.system:DistanceTo(mission.backstation) < 30
				then
					mission.location = mission.backstation
				else
					mission.backstation = mission.location
				end
				local dist = mission.location:DistanceTo(Game.system)
				mission.due = _remote_due(dist,Engine.rand:Number(0.8, 1,true))
				if NavAssist then Game.player:SetHyperspaceTarget(mission.location:GetStarSystem().path) end
				mission.notplayer = 'FALSE'
			end
			mission.ship = nil
			return
		end
	end
end

local onShipDocked = function (ship, station)
	for ref,mission in pairs(missions) do
		if ship == Game.player then
			if mission.status == 'TRIP_BACK' and
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
	switchEvents()
end

	local escort
local onShipUndocked = function (ship, station)
	for ref,mission in pairs(missions) do
		if mission.status ~= 'ACTIVE'
			or (ship ~= mission.ship and ship ~= Game.player)
		then return end
		if ship == mission.ship then
			ship:AIEnterMediumOrbit(ship:FindNearestTo("STAR"))
		end
		local taunt = string.interp(l["TAUNT_"..Engine.rand:Integer(1, 3)], {org = mission.org})
		Timer:CallAt(Game.time+50, function ()
			if escort then escort = nil return end
			if ShipExists(mission.ship) then
				if Game.player:GetCombatTarget() == mission.ship
					and Game.player.flightState == "FLYING"
					and mission.ship.flightState == "FLYING"
				then
					if Engine.rand:Integer(0, 1) > 0 then-- XXX
						Music.Play("music/core/fx/escalating-danger",false)
						Comms.ImportantMessage(taunt)
--						Game.player:CancelAI()--XXX
						mission.ship:AIKill(Game.player)
						escort = ship_hostil(mission.danger)
						if escort then
							Comms.ImportantMessage(l.WARNING..mission.danger..l.HOSTILE_SHIPS_APPROACHING)
						end
					else
						if ShipJump(mission.ship) then
							for i,v in pairs(Character.persistent.player.hjumps) do--XXX
								if v.label == mission.ship.label then
									mission.due = v.due + (60*60*24*30)-- XXX + 30 días a v.dest_time XXX
								end
							end
							if tracingJumps then
								mission.ship = nil--"jump"
								mission.status = 'JUMPING'
							else
								mission.status = 'FAILED'
							end
						else
							mission.ship:Explode()
							mission.ship = nil
							mission:Remove()
							missions[ref] = nil
						end
						return
					end
				elseif mission.ship.flightState ~= "HYPERSPACE" then
					mission.ship:AIDockWith(station)
				end
			end
		end)
	end
end


local onEnterSystem = function (ship)
	if not ship:IsPlayer() or not switchEvents() then return end
	local syspath = Game.system.path
	for ref,mission in pairs(missions) do
		if mission.status == 'ACTIVE' or mission.status == 'JUMPING' then
			if not mission.ship then
				if mission.due > Game.time then
					if mission.location:IsSameSystem(syspath) then
						local station = Space.GetBody(mission.location.bodyIndex)
						local shiptype = ShipDef[mission.shipid]
						local default_drive = shiptype.hyperdriveClass
						local laserdefs = utils.build_array(pairs(Equipment.laser))
						table.sort(laserdefs, function (l1, l2) return l1.price < l2.price end)
						local laserdef = laserdefs[mission.danger]
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
					end
				else
					if mission.status ~= 'JUMPING' then mission.status = 'FAILED' end
				end
			end
		else
			if not ShipExists(mission.ship) then
				mission.ship = nil
				if mission.due < Game.time then
					mission.status = 'FAILED'
				end
			end
		end
	end
end

local onCreateBB = function (station)
	for i = 1,Engine.rand:Integer(Engine.rand:Integer(0,_maxAdv),_maxAdv) do
		makeAdvert(station)
	end
end

local onUpdateBB = function (station)
	local num = 0
	local timeout = 24*60*60 -- default 1 day timeout
	for ref,ad in pairs(ads) do
		if ad.station == station then
			if (Game.time - ad.date > timeout) then
				station:RemoveAdvert(ref)
				num = num + 1
			end
		end
	end
	if num > 0 then
		for i = 1,num do
			makeAdvert(station)
		end
	end
end


local onClick = function (mission)

	local dist_txt = _distTxt(mission.location)

	local setTargetButton = SLButton.New(lm.SET_TARGET, 'NORMAL')
	setTargetButton.button.onClick:Connect(function ()
		if not NavAssist then MsgBox.Message(lm.NOT_NAV_ASSIST) return end
		if Game.system.path ~= mission.location:GetStarSystem().path then--si es en otro Sistema
			Game.player:SetHyperspaceTarget(mission.location:GetStarSystem().path)--paso 1 - selecciona Sistema
		elseif mission.status =='TRIP_BACK' then-- si es en Sistema y viene de regreso.
			Game.player:SetNavTarget(Space.GetBody(mission.location.bodyIndex))
		else-- en sitio de acción, selecciona el planeta más cercano a la estación donde está el objetivo
			Game.player:SetNavTarget(Space.GetBody(mission.location.bodyIndex):FindNearestTo("PLANET"))
		end
	end)

	if mission.status == 'ACTIVE' then

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
						:SetColumn(1, {ui:VBox():PackEnd({ui:Label(dist_txt),
													"",
													setTargetButton.widget
													})
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

	elseif mission.status == 'JUMPING' then

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

	elseif mission.status =="TRIP_BACK" then
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
														dist   = dist_txt})
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
													ui:Label(dist_txt),
													"",
													setTargetButton.widget
												})
											}),
										"",
										ui:Grid(2,1)
											:SetColumn(0, {
												ui:VBox():PackEnd({
													ui:Label(l.BEFORE_THIS_DATE)
												})
											})
											:SetColumn(1, {
												ui:VBox():PackEnd({
													ui:Label(TimeLeft(mission.due))
												})
											}),
		})})
		:SetColumn(1,{ui:VBox(10):PackEnd(InfoFace.New(mission.client))})
	elseif mission.status == 'FAILED' then
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

local loaded_data
local onGameStart = function ()
	ads = {}
	missions = {}
	if type(loaded_data) == "table" then
		for k,ad in pairs(loaded_data.ads) do
			local ref = ad.station:AddAdvert({
				description = ad.desc,
				icon        = "hitman",
				onChat      = onChat,
				onDelete    = onDelete})
			ads[ref] = ad
		end
		missions = loaded_data.missions
		switchEvents()
		loaded_data = nil
		for k,mission in pairs(missions) do
			if ShipExists(mission.ship) then
				_start_launch_sequence(mission)
			end
		end
	end
end

local serialize = function ()
	return { ads = ads, missions = missions }
end

local unserialize = function (data)
	loaded_data = data
end

switchEvents = function()
	local status = false
	Event.Deregister("onShipDocked", onShipDocked)
	Event.Deregister("onShipUndocked", onShipUndocked)
	Event.Deregister("onShipDestroyed", onShipDestroyed)
	for ref,mission in pairs(missions) do
		if Game.time > mission.due
			or mission.location:IsSameSystem(Game.system.path)
			or mission.status == 'JUMPING' then
			Event.Register("onShipDocked", onShipDocked)
			Event.Register("onShipUndocked", onShipUndocked)
			Event.Register("onShipDestroyed", onShipDestroyed)
			status = true
		end
	end
	return status
end

Event.Register("onGameStart", onGameStart)
Event.Register("onCreateBB", onCreateBB)
Event.Register("onUpdateBB", onUpdateBB)
Event.Register("onEnterSystem", onEnterSystem)

Mission.RegisterType('hitman',l.hitman,onClick)

Serializer:Register("hitman", serialize, unserialize)
