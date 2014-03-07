-- ChangeOfPropellant.lua for Pioneer Scout+ (c)2012-2014 by walterar <walterar2@gmail.com>
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt
-- Work in progress.
--
local Lang       = import("Lang")
local Engine     = import("Engine")
local Game       = import("Game")
local Comms      = import("Comms")
local Event      = import("Event")
local Format     = import("Format")
local Rand       = import("Rand")
local Serializer = import("Serializer")

local l = Lang.GetResource("module-changeofpropellant") or Lang.GetResource("module-changeofpropellant","en")

local ads = {}
local loaded_data

local onChat = function (form, ref, option)
	local ad = ads[ref]

	local price = tariff(10,1,1,Game.system.path)

	if option == 0 then
		form:Clear()
		form:SetTitle(l.formtittle)
		form:SetFace({seed = ad.faceseed+2})
		form:SetMessage(l.formmessage..showCurrency(price).."\n*\n*\n*\n")--, 2, "$", "-"
		form:AddOption(l.convert, 1)
		return
	end

	if option == 1 then
		if FuelHydrogen == true then return end
		form:Clear()
		if Game.player:GetMoney() < price then
			form:SetMessage("\n"..l.Not_have_enough_credit, ad.title)
		else
			Game.player:AddMoney(-price)
			form:SetMessage(l.convertok)
			_G.FuelHydrogen = true
		end
		return
	end
	form:Close()
end

local onDelete = function (ref)
	ads[ref] = nil
end

local licon = "mechanics_service"
local onCreateBB = function (station)
	local ad = {
		title    = l.adtittle,
		station  = station,
		faceseed = station.seed
		}
	ads[station:AddAdvert({
		description = ad.title,
		icon        = licon,
		onChat      = onChat,
		onDelete    = onDelete})] = ad
end

local onGameStart = function ()
	ads = {}
	if loaded_data then
		for k,ad in pairs(loaded_data.ads) do
			ads[ad.station:AddAdvert({
			description = ad.title,
			icon        = licon,
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

Serializer:Register("ChangeOfPropellant", serialize, unserialize)
