-- Copyright © 2008-2016 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt
-- modified for Pioneer Scout+ (c)2012-2015 by walterar <walterar2@gmail.com>
-- Work in progress.

local Lang       = import("Lang")
local Engine     = import("Engine")
local Game       = import("Game")
local Space      = import("Space")
local StarSystem = import("StarSystem")
local Comms      = import("Comms")
local Event      = import("Event")
local Mission    = import("Mission")
local Music      = import("Music")
local Format     = import("Format")
local Serializer = import("Serializer")
local Character  = import("Character")
local Timer      = import("Timer")

local MsgBox   = import("ui/MessageBox")
local InfoFace = import("ui/InfoFace")
local SLButton = import("ui/SmallLabeledButton")

local l  = Lang.GetResource("module-deliverpackage") or Lang.GetResource("module-deliverpackage","en")
local lm = Lang.GetResource("miscellaneous") or Lang.GetResource("miscellaneous","en")

-- Get the UI class
local ui = Engine.ui

local num_pirate_taunts = 10

-- minimum $150 reward in local missions
local local_reward = 150

local flavours = {
	{
		urgency       = 0,-- 0
		risk          = 0,
		localdelivery = false,
	}, {
		urgency       = 0.1,-- 1
		risk          = 2,
		localdelivery = false,
	}, {
		urgency       = 0.6,-- 2
		risk          = 1,
		localdelivery = false,
	}, {
		urgency       = 0.4,-- 3
		risk          = 3,
		localdelivery = false,
	}, {
		urgency       = 0.1,-- 4
		risk          = 0,
		localdelivery = false,
	}, {
		urgency       = 0.1,-- 5
		risk          = 0,
		localdelivery = true,
	}, {
		urgency       = 0.2,-- 6
		risk          = 0,
		localdelivery = true,
	}, {
		urgency       = 0.4,-- 7
		risk          = 0,
		localdelivery = true,
	}, {
		urgency       = 0.6,-- 8
		risk          = 0,
		localdelivery = true,
	}, {
		urgency       = 0.8,-- 9
		risk          = 0,
		localdelivery = true,
	}
}

-- add strings to flavours
for i = 1,#flavours do
	local f = flavours[i]
	f.adtext        = l["FLAVOUR_" .. i-1 .. "_ADTEXT"]
	f.introtext     = l["FLAVOUR_" .. i-1 .. "_INTROTEXT"].."\n*\n*"
	f.whysomuchtext = l["FLAVOUR_" .. i-1 .. "_WHYSOMUCHTEXT"].."\n*\n*"
	f.successmsg    = l["FLAVOUR_" .. i-1 .. "_SUCCESSMSG"]
	f.failuremsg    = l["FLAVOUR_" .. i-1 .. "_FAILUREMSG"]
end

local ads = {}
local missions = {}

local onChat = function (form, ref, option)
	local ad = ads[ref]

	form:Clear()

	if option == -1 then
		form:Close()
		return
	end

	if option == 0 then
		form:SetFace(ad.client)

		local introtext = string.interp(flavours[ad.flavour].introtext, {
			name     = ad.client.name,
			cash     = showCurrency(ad.reward),
			starport = ad.location:GetSystemBody().name,
			system   = ad.location:GetStarSystem().name,
			sectorx  = ad.location.sectorX,
			sectory  = ad.location.sectorY,
			sectorz  = ad.location.sectorZ,
			dist     = ad.dist
		})

		form:SetMessage(introtext)

	elseif option == 1 then
		form:SetMessage(flavours[ad.flavour].whysomuchtext)

	elseif option == 2 then
		form:SetMessage(l.IT_MUST_BE_DELIVERED_BY..Format.Date(ad.due).."\n*\n*")

	elseif option == 4 then

		if ad.risk == 0 and Engine.rand:Integer(1) == 0 then
			form:SetMessage(l.I_HIGHLY_DOUBT_IT.."\n*\n*")
		elseif ad.risk == 0 then
			form:SetMessage(l.NOT_ANY_MORE_THAN_USUAL.."\n*\n*")
		end
		if ad.risk == 1 then
			form:SetMessage(l.THIS_IS_A_VALUABLE_PACKAGE_YOU_SHOULD_KEEP_YOUR_EYES_OPEN.."\n*\n*")
		elseif ad.risk == 2 then
			form:SetMessage(l.IT_COULD_BE_DANGEROUS_YOU_SHOULD_MAKE_SURE_YOURE_ADEQUATELY_PREPARED.."\n*\n*")
		elseif ad.risk == 3 then
			form:SetMessage(l.THIS_IS_VERY_RISKY_YOU_WILL_ALMOST_CERTAINLY_RUN_INTO_RESISTANCE.."\n*\n*")
		end

	elseif option == 3 then
		if (MissionsSuccesses - MissionsFailures < 5) and ad.risk > 0 then
			form:SetMessage(lm.HAVE_ENOUGH_EXPERIENCE)
			return
		end
		form:RemoveAdvertOnClose()

		ads[ref] = nil

		local mission = {
			type     = "Delivery",
			client   = ad.client,
			location = ad.location,
			risk     = ad.risk,
			reward   = ad.reward,
			due      = ad.due,
			flavour  = ad.flavour
		}

		table.insert(missions,Mission.New(mission))

		if NavAssist and Game.system.path ~= mission.location:GetStarSystem().path then
			Game.player:SetHyperspaceTarget(mission.location:GetStarSystem().path)
		end
		form:SetMessage(l.EXCELLENT_I_WILL_LET_THE_RECIPIENT_KNOW_YOU_ARE_ON_YOUR_WAY)
		switchEvents()
		return
	end

	form:AddOption(l.WHY_SO_MUCH_MONEY, 1)
	form:AddOption(l.HOW_SOON_MUST_IT_BE_DELIVERED, 2)
	form:AddOption(l.WILL_I_BE_IN_ANY_DANGER, 4)
	form:AddOption(l.COULD_YOU_REPEAT_THE_ORIGINAL_REQUEST, 0)
	form:AddOption(l.OK_AGREED, 3)
end

local onDelete = function (ref)
	ads[ref] = nil
end

local makeAdvert = function (station)

	local reward, due, location, dist
	local flavour = Engine.rand:Integer(1,#flavours)
	local urgency = flavours[flavour].urgency
	local risk = flavours[flavour].risk

	if flavours[flavour].localdelivery == true then
		if _nearbystationsLocals and #_nearbystationsLocals > 0 then
			location = _nearbystationsLocals[Engine.rand:Integer(1,#_nearbystationsLocals)]
		end
		if not location or location == station.path then return end

		local AU = 149597870700
		local dist = station:DistanceTo(Space.GetBody(location.bodyIndex))/AU
		due = _local_due(station,location,urgency,false)

		local reward_base = 250
		reward = reward_base+(reward_base*(dist/3)*(1+urgency)*(1+Game.system.lawlessness))
	else
		if _nearbystationsRemotes and #_nearbystationsRemotes > 0 then
			location = _nearbystationsRemotes[Engine.rand:Integer(1,#_nearbystationsRemotes)]
		end
		if location == nil then return end
		dist = Game.system:DistanceTo(location)
		reward = tariff(dist,risk,urgency,location)
		due    = _remote_due(dist,urgency,false)
	end

	local dist_txt = _distTxt(location)--,flavours[flavour].localdelivery)

	local client = Character.New()

	local ad = {
		station  = station,
		flavour  = flavour,
		client   = client,
		location = location,
		dist     = dist_txt,
		due      = due,
		risk     = risk,
		urgency  = urgency,
		reward   = reward,
		faceseed = Engine.rand:Integer()
	}

	ad.desc = string.interp(flavours[flavour].adtext, {
		starport = ad.location:GetSystemBody().name,
		system   = ad.location:GetStarSystem().name,
		cash     = showCurrency(ad.reward),
	})
	ads[station:AddAdvert({
		description = ad.desc,
		icon        = ad.risk > 0 and "delivery_danger" or "delivery",
		onChat      = onChat,
		onDelete    = onDelete})] = ad
end

local onCreateBB = function (station)
	local num = math.ceil(Game.system.population)
	if num > 3 then num = 3 end
	if num > 0 then
		for i = 1,num do
			makeAdvert(station)
		end
	end
end

local onUpdateBB = function (station)
	for ref,ad in pairs(ads) do
		if flavours[ad.flavour].localdelivery then
			if ad.due < Game.time + 24*60*60 then -- 1 day timeout for locals
				ad.station:RemoveAdvert(ref)
			end
		else
			if ad.due < Game.time + 2*24*60*60 then -- 2 day timeout for inter-system
				ad.station:RemoveAdvert(ref)
			end
		end
	end
	if Engine.rand:Integer(50) < 1 then
		makeAdvert(station)
	end
end

	local hostilactive = false
local onFrameChanged = function (body)
--print("DeliverPackage onFrameChanged body="..body.label)
	if hostilactive then return end
	if body:isa("Ship") and body:IsPlayer() and body.frameBody ~= nil then
		for ref,mission in pairs(missions) do
			local risk = flavours[mission.flavour].risk
			if risk < 1 then return end
			if mission.status == "ACTIVE" and mission.location:IsSameSystem(Game.system.path) then
				local target_distance_from_entry = body:DistanceTo(Space.GetBody(mission.location.bodyIndex))
				if target_distance_from_entry > 500000e3 then return end
				Timer:CallEvery(1, function ()
					if hostilactive then return true end
					if body:DistanceTo(Space.GetBody(mission.location.bodyIndex)) > 100000e3 then return false end
					ship = ship_hostil(risk)
					if ship then
						hostilactive = true
						local hostile_greeting = string.interp(
									l["PIRATE_TAUNTS_"..Engine.rand:Integer(1,num_pirate_taunts)-1],
										{
										client = mission.client.name,
										location = mission.location:GetSystemBody().name
										})
						Comms.ImportantMessage(hostile_greeting, ship.label)
						return true
					end
				end)
			end
			if mission.status == "ACTIVE" and Game.time > mission.due then
				mission.status = 'FAILED'
			end
		end
	end
end

local onShipDocked = function (player, station)
--print("DeliverPackage onFrameChanged player="..player.label)
	if not player:IsPlayer() then return end
	hostilactive = false
	for ref,mission in pairs(missions) do
		if check_crime(mission,"FRAUD") then
			mission:Remove()
			missions[ref] = nil
--			return
		end
		if mission and mission.location == station.path then
			if Game.time > mission.due then
				Comms.ImportantMessage(flavours[mission.flavour].failuremsg, mission.client.name)
				_G.MissionsFailures = MissionsFailures + 1
			else
				Comms.ImportantMessage(flavours[mission.flavour].successmsg, mission.client.name)
				_G.MissionsSuccesses = MissionsSuccesses + 1
				player:AddMoney(mission.reward)
			end
			mission:Remove()
			missions[ref] = nil
		end
	end
	switchEvents()
end

local onShipLanded = function (player, body)
	if not player:IsPlayer() then return end
	hostilactive = false
	for ref,mission in pairs(missions) do
		if check_crime(mission,"FRAUD") then
			mission:Remove()
			missions[ref] = nil
--			return
		end
		if mission and mission.location == Game.player:FindNearestTo("SPACESTATION").path then
			if Game.time > mission.due then
				Comms.ImportantMessage(flavours[mission.flavour].failuremsg, mission.client.name)
				_G.MissionsFailures = MissionsFailures + 1
			else
				Comms.ImportantMessage(flavours[mission.flavour].successmsg, mission.client.name)
				_G.MissionsSuccesses = MissionsSuccesses + 1
				player:AddMoney(mission.reward)
			end
			mission:Remove()
			missions[ref] = nil
		end
	end
	switchEvents()
end

local onEnterSystem = function (ship)
	if not ship:IsPlayer() or not switchEvents() then return end
end

local loaded_data
local onGameStart = function ()
	ads = {}
	missions = {}
	if loaded_data then
		for k,ad in pairs(loaded_data.ads) do
			ads[ad.station:AddAdvert({
				description = ad.desc,
				icon        = ad.risk > 0 and "delivery_danger" or "delivery",
				onChat      = onChat,
				onDelete    = onDelete})] = ad
		end
		missions     = loaded_data.missions
		hostilactive = loaded_data.hostilactive
		switchEvents()
		loaded_data = nil
	end
end


local onClick = function (mission)

--	local dist = Game.system and string.format("%.2f", Game.system:DistanceTo(mission.location)) or "zzz"
	local dist_txt = _distTxt(mission.location)--,flavours[mission.flavour].localdelivery)

	local setTargetButton = SLButton.New(lm.SET_TARGET, 'NORMAL')
	setTargetButton.button.onClick:Connect(function ()
		if not NavAssist then MsgBox.Message(lm.NOT_NAV_ASSIST) return end

		if Game.system.path ~= mission.location:GetStarSystem().path then
			Game.player:SetHyperspaceTarget(mission.location:GetStarSystem().path)
			Music.Play("music/core/fx/Ok", false)
		else
			Game.player:SetNavTarget(Space.GetBody(mission.location.bodyIndex))
		end
	end)

	local danger
	if mission.risk == 0 then
		if Engine.rand:Integer(1) == 0 then
			danger = (l.I_HIGHLY_DOUBT_IT)
		else
			danger = (l.NOT_ANY_MORE_THAN_USUAL)
		end
	elseif mission.risk == 1 then
		danger = (l.THIS_IS_A_VALUABLE_PACKAGE_YOU_SHOULD_KEEP_YOUR_EYES_OPEN)
	elseif mission.risk == 2 then
		danger = (l.IT_COULD_BE_DANGEROUS_YOU_SHOULD_MAKE_SURE_YOURE_ADEQUATELY_PREPARED)
	elseif mission.risk == 3 then
		danger = (l.THIS_IS_VERY_RISKY_YOU_WILL_ALMOST_CERTAINLY_RUN_INTO_RESISTANCE)
	end

	return ui:Grid({68,32},1)
		:SetColumn(0,{ui:VBox(10):PackEnd({ui:MultiLineText((flavours[mission.flavour].introtext):interp({
														name     = mission.client.name,
														starport = mission.location:GetSystemBody().name,
														system   = mission.location:GetStarSystem().name,
														sectorx  = mission.location.sectorX,
														sectory  = mission.location.sectorY,
														sectorz  = mission.location.sectorZ,
														cash     = showCurrency(mission.reward),
														dist     = dist_txt})
										),
										ui:Margin(10),
										ui:Grid(2,1)
											:SetColumn(0, {
												ui:VBox():PackEnd({
													ui:Label(l.SPACEPORT)
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
															..","..mission.location.sectorZ
															..")")
												})
											}),
										ui:Grid(2,1)
											:SetColumn(0, {
												ui:VBox():PackEnd({
													ui:Label(l.DEADLINE)
												})
											})
											:SetColumn(1, {
												ui:VBox():PackEnd({
													ui:Label(Format.Date(mission.due))
												})
											}),
										ui:Grid(2,1)
											:SetColumn(0, {
												ui:VBox():PackEnd({
													ui:Label(l.DANGER)
												})
											})
											:SetColumn(1, {
												ui:VBox():PackEnd({
													ui:MultiLineText(danger)
												})
											}),
										ui:Margin(5),
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
		})})
		:SetColumn(1, {
			ui:VBox(10):PackEnd(InfoFace.New(mission.client))
		})
end

local serialize = function ()
	return
		{
		ads          = ads,
		missions     = missions,
		hostilactive = hostilactive
		}
end

local unserialize = function (data)
	loaded_data = data
end

switchEvents = function()
	local status = false
--print("DeliverPackage Events deactivated")
	Event.Deregister("onFrameChanged", onFrameChanged)
	Event.Deregister("onShipDocked", onShipDocked)
	Event.Deregister("onShipLanded", onShipLanded)
	for ref,mission in pairs(missions) do
		if mission.location:IsSameSystem(Game.system.path) then
--print("DeliverPackage Events activate")
			Event.Register("onFrameChanged", onFrameChanged)
			Event.Register("onShipDocked", onShipDocked)
			Event.Register("onShipLanded", onShipLanded)
			status = true
		end
	end
	return status
end

Event.Register("onCreateBB", onCreateBB)
Event.Register("onUpdateBB", onUpdateBB)
Event.Register("onEnterSystem", onEnterSystem)
Event.Register("onGameStart", onGameStart)

Mission.RegisterType('Delivery',l.DELIVERY,onClick)

Serializer:Register("DeliverPackage", serialize, unserialize)
