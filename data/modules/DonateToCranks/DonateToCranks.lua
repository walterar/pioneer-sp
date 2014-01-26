-- Copyright © 2008-2014 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt
-- modified for Pioneer Scout+ (c)2013 by walterar <walterar2@gmail.com>

local Lang       = import("Lang")
local Engine     = import("Engine")
local Game       = import("Game")
local Comms      = import("Comms")
local Event      = import("Event")
local Serializer = import("Serializer")

local l = Lang.GetResource("module-donatetocranks") or Lang.GetResource("module-donatetocranks","en")
local myl = Lang.GetResource("module-myl") or Lang.GetResource("module-myl","en")

local crank_flavours = {}
for i = 0,5 do
	table.insert(crank_flavours, {
		title     = l["FLAVOUR_" .. i .. "_TITLE"],
		message   = l["FLAVOUR_" .. i .. "_MESSAGE"],
	})
end

local ads = {}

local onChat = function (form, ref, option)
	local ad = ads[ref]

	if option == 0 then
		form:Clear()

		form:SetTitle(ad.title)
		form:SetFace({ seed = ad.faceseed })
		form:SetMessage(ad.message)

		form:AddOption("$1", 1)
		form:AddOption("$10", 10)
		form:AddOption("$100", 100)
		form:AddOption("$1000", 1000)
		form:AddOption("$10000", 10000)
		form:AddOption("$100000", 100000)

		return
	end

	if option == -1 then
		form:Close()
		return
	end

	if Game.player:GetMoney() < option then
		Comms.Message(l.YOU_DO_NOT_HAVE_ENOUGH_MONEY)
	elseif option == 1000 and DangerLevel > 0 then _G.DangerLevel = DangerLevel - 1
			Comms.Message(l.WOW_THAT_WAS_VERY_GENEROUS)
	elseif option == 10000 then Game.player:SetInvulnerable(1)
			Comms.Message(myl.YOU_DESERVE_TO_BE_IMMORTAL)
	else
		Comms.Message(l.THANK_YOU_ALL_DONATIONS_ARE_WELCOME)
		Game.player:AddMoney(-option)
	end
end

local onDelete = function (ref)
	ads[ref] = nil
end

local onCreateBB = function (station)
	local n = Engine.rand:Integer(1, #crank_flavours)

	local ad = {
		title    = crank_flavours[n].title,
		message  = crank_flavours[n].message,
		station  = station,
		faceseed = Engine.rand:Integer()
	}

	local ref = station:AddAdvert({
		description = ad.title,
		icon        = "donate_to_cranks",
		onChat      = onChat,
		onDelete    = onDelete})
	ads[ref] = ad
end

local loaded_data

local onGameStart = function ()
	ads = {}
	if loaded_data then
		for k,ad in pairs(loaded_data.ads) do
			ads[ad.station:AddAdvert({
				description = ad.title,
				icon        = "donate_to_cranks",
				onChat      = onChat,
				onDelete    = onDelete})] = ad
		end
		loaded_data = nil
	end
end

local serialize = function ()
	return { ads = ads }
end

local unserialize = function (data)
	loaded_data = data
end

Event.Register("onCreateBB", onCreateBB)
Event.Register("onGameStart", onGameStart)

Serializer:Register("DonateToCranks", serialize, unserialize)
