-- Copyright © 2008-2016 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt
-- modified for Pioneer Scout+ (c)2012-2015 by walterar <walterar2@gmail.com>
-- Work in progress.

local Engine     = import("Engine")
local Lang       = import("Lang")
local Game       = import("Game")
local Comms      = import("Comms")
local Event      = import("Event")
local Rand       = import("Rand")
local NameGen    = import("NameGen")
local Format     = import("Format")
local Serializer = import("Serializer")
local Eq         = import("Equipment")
local Music      = import("Music")
local Timer      = import("Timer")

local l = Lang.GetResource("module-breakdownservicing") or Lang.GetResource("module-breakdownservicing","en")

-- Default numeric values --
----------------------------
local oneyear = 31557600 -- One standard Julian year
local onemonth = 2592000 -- One standard Julian month
local alertMsg = l.MAKE_HYPERDRIVE_REPAIR_BEFORE_IT_BREAKING

-- 10, guaranteed random by D16 dice roll.
-- This is to make the BBS name different from the station welcome character.
local seedbump = 10
-- How many jumps might you get after your service_period is finished?
-- Failure is increasingly likely with each jump, this being the limit
-- where probability = 1
local max_jumps_unserviced = 20

local flavours = {
	{
		strength = 1.5,
		baseprice = 6
	}, {
		strength = 1.2, -- At least a year... hidden bonus!
		baseprice = 4
	}, {
		strength = 1.0,
		baseprice = 3
	}, {
		strength = 0.5,
		baseprice = 2
	}, {
		strength = 2.1, -- these guys are good.
		baseprice = 10
	}, {
		strength = 0.1, -- These guys are bad.
		baseprice = 1.8
	}
}

-- add strings to flavours
for i = 1,#flavours do
	local f = flavours[i]
	f.title     = l["FLAVOUR_" .. i-1 .. "_TITLE"]
	f.intro     = l["FLAVOUR_" .. i-1 .. "_INTRO"].."\n*"
	f.yesplease = l["FLAVOUR_" .. i-1 .. "_YESPLEASE"]
	f.response  = l["FLAVOUR_" .. i-1 .. "_RESPONSE"].."\n*"
end

local ads = {}
local service_history = {
	lastdate = 0, -- Default will be overwritten on game start
	company = nil, -- Name of company that did the last service
	service_period = oneyear, -- default
	jumpcount = 0, -- Number of jumps made after the service_period
}

local lastServiceMessage = function (hyperdrive)
	-- Fill in the blanks tokens on the {lasttime} string from service_history
	local message
	if hyperdrive == nil then
		message = l.YOU_DO_NOT_HAVE_A_DRIVE_TO_SERVICE.."\n*"
	elseif not service_history.company then
		message = l.YOUR_DRIVE_HAS_NOT_BEEN_SERVICED.."\n*"
	else
		message = l.YOUR_DRIVE_WAS_LAST_SERVICED_ON.."\n*"
	end
	return string.interp(message, {date = Format.Date(service_history.lastdate), company = service_history.company})
end

local onChat = function (form, ref, option)
	local ad = ads[ref]

	local hyperdrive = Game.player:GetEquip('engine',1)

	-- Tariff!  ad.baseprice is from 2 to 10
	local price
	if hyperdrive then
		price = (ad.baseprice*(2+Game.system.lawlessness))
			* (Game.player:GetDockedWith():GetEquipmentPrice(hyperdrive) / 100)
	else
		price = 0
	end

	-- Replace those tokens into ad's intro text that can change during play
	local message = string.interp(ad.intro, {
		drive = hyperdrive and hyperdrive:GetName() or "None",
		price = showCurrency(price)
	})

	if option == -1 then
		-- Hang up
		form:Close()
		return
	end

	if option == 0 then
		-- Initial proposal
		form:SetTitle(ad.title)
		form:SetFace({ female = ad.isfemale, seed = ad.faceseed, name = ad.name })
		-- Replace token with details of last service (which might have
		-- been seconds ago)
		form:SetMessage(string.interp(message, {
			lasttime = lastServiceMessage(hyperdrive)
		}))
		if not hyperdrive then-- or service_history.jumpcount < 1
			message = l.YOU_DO_NOT_HAVE_A_DRIVE_TO_SERVICE
			form:SetMessage(message)
		elseif Game.player:GetMoney() < price then
			form:AddOption(l.I_DONT_HAVE_ENOUGH_MONEY, -1)
		else
			form:AddOption(ad.yesplease, 1)
		end
		print(('DEBUG: %.2f years / %.2f price = %.2f'):format(ad.strength, ad.baseprice, ad.strength/ad.baseprice))
	end

	if option == 1 then
		if Game.player:GetMoney() < price then
			form:SetMessage("\n"..l.I_DONT_HAVE_ENOUGH_MONEY.."\n*")
		else
			Music.Play("music/core/fx/repair1", false)
--			Timer:CallAt(Game.time+10, function ()
--				Music.Stop()
				form:Clear()
				form:SetTitle(ad.title)
				form:SetFace({ female = ad.isfemale, seed = ad.faceseed, name = ad.name })
				form:SetMessage(ad.response)
				Game.player:AddMoney(-price)
				service_history.lastdate = Game.time
				service_history.service_period = ad.strength * oneyear
				service_history.company = ad.title.."\n*"
				service_history.jumpcount = 0
				if damageControl == alertMsg then _G.damageControl = "" end
--			end)
		end
	end
end

local onDelete = function (ref)
	ads[ref] = nil
end

local onShipTypeChanged = function (ship)
	if ship:IsPlayer() then
		service_history.company = nil
		service_history.lastdate = Game.time
		if Engine.rand:Integer(3) < 1 then
			service_history.service_period = onemonth
			service_history.jumpcount = 0
		end
	end
end

local onShipEquipmentChanged = function (ship, equipment)
	if ship:IsPlayer() and equipment and equipment:IsValidSlot("engine", ship) then
		service_history.company = nil
		service_history.lastdate = Game.time
		service_history.service_period = onemonth
		service_history.jumpcount = 0
	end
end

local onCreateBB = function (station)
	local rand = Rand.New(station.seed + seedbump)
	local n = rand:Integer(1,#flavours)
	local isfemale = rand:Integer(1) == 1
	local name = NameGen.FullName(isfemale,rand)

	local ad = {
		name = name,
		isfemale = isfemale,
		-- Only replace tokens which are not subject to further change
		title = string.interp(flavours[n].title, {
			name = station.label,
			proprietor = name
		}),
		intro = string.interp(flavours[n].intro, {
			name = station.label,
			proprietor = name
		}),
		yesplease = flavours[n].yesplease,
		response = flavours[n].response,
		station = station,
		faceseed = rand:Integer(),
		strength = flavours[n].strength,
		baseprice = flavours[n].baseprice *rand:Number(0.8,1.2) -- A little per-station flavouring
	}

	local ref = station:AddAdvert({
		description = ad.title,
		icon        = "mechanics_service",
		onChat      = onChat,
		onDelete    = onDelete})
	ads[ref] = ad
end

local loaded_data

local onGameStart = function ()
	ads = {}

	if type(loaded_data) == "table" then
		for k,ad in pairs(loaded_data.ads) do
			ads[ad.station:AddAdvert({
			description = ad.title,
			icon        = "mechanics_service",
			onChat      = onChat,
			onDelete    = onDelete})] = ad
		end
		service_history = loaded_data.service_history
		loaded_data = nil
	else
		service_history = {
			lastdate = 0, -- Default will be overwritten on game start
			company = nil, -- Name of company that did the last service
			service_period = onemonth, -- default
			jumpcount = 0 -- Number of jumps made after the service_period
		}
	end
end

local savedByCrew = function(ship)
	for crew in ship:EachCrewMember() do
		if crew:TestRoll('engineering') then return crew end
	end
	return false
end


local onEnterSystem = function (ship)
	if not ship:IsPlayer() then return end
	Timer:CallAt(Game.time+1, function ()
		print(('DEBUG: Jumps since warranty: %d, chance of failure (if > 0): 1/%d\nWarranty expires: %s'):format
(service_history.jumpcount,max_jumps_unserviced-service_history.jumpcount,Format.Date(service_history.lastdate + service_history.service_period)))
		if service_history.jumpcount and service_history.jumpcount > 0 then--and damageControl == "" then
			Comms.Message(alertMsg)
			_G.damageControl = alertMsg
		elseif damageControl == alertMsg then
			_G.damageControl = ""
		end
		local saved_by_this_guy = savedByCrew(ship)
		if (service_history.lastdate + service_history.service_period < Game.time)
			and not saved_by_this_guy then
			service_history.jumpcount = service_history.jumpcount + 1
			if Game.system.population > 0
				and damageControl == alertMsg
				and ((service_history.jumpcount > max_jumps_unserviced)
				or (Engine.rand:Integer(max_jumps_unserviced - service_history.jumpcount) < 1))
			then
			-- Destroy the engine
				local engine = ship:GetEquip('engine',1)
				local engine_mass = engine.capabilities.mass
				ship:RemoveEquip(engine)
				ship:AddEquip(Eq.cargo.rubbish, engine_mass)
				_G.damageControl = l.THE_SHIPS_HYPERDRIVE_HAS_BEEN_DESTROYED_BY_A_MALFUNCTION
				Comms.ImportantMessage(damageControl)
			end
		end
		if saved_by_this_guy and service_history.jumpcount > 0 then
		-- Brag to the player
			if not saved_by_this_guy.player then
				Comms.Message(l.I_FIXED_THE_HYPERDRIVE_BEFORE_IT_BROKE_DOWN,saved_by_this_guy.name)
			end
		-- Rewind the servicing countdown by a random amount based on crew member's ability
			local fixup = saved_by_this_guy.engineering - saved_by_this_guy.DiceRoll()
			if fixup > 0 then service_history.jumpcount = service_history.jumpcount - fixup end
			_G.damageControl = ""
		end
	end)
end

local serialize = function ()
	return { ads = ads, service_history = service_history }
end

local unserialize = function (data)
	loaded_data = data
end

Event.Register("onCreateBB", onCreateBB)
Event.Register("onGameStart", onGameStart)
Event.Register("onShipTypeChanged", onShipTypeChanged)
Event.Register("onShipEquipmentChanged", onShipEquipmentChanged)
Event.Register("onEnterSystem", onEnterSystem)

Serializer:Register("BreakdownServicing", serialize, unserialize)
