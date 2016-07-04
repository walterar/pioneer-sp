-- ChangeOfEnrolls.lua for Pioneer Scout+ (c)2012-2015 by walterar <walterar2@gmail.com>
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

local l = Lang.GetResource("module-changeofenrolls") or Lang.GetResource("module-changeofenrolls","en")

local ads = {}
local loaded_data
local amount

local onChat = function (form, ref, option)
	local ad = ads[ref]
	local crime,fine = Game.player:GetCrime()

	if option == 0 then
		form:Clear()
		form:SetTitle(l.You_are_owner_of_the_registration..Game.player.label.."\n")
		form:SetFace({seed = ad.faceseed+1})

		if fine > 0 then
				form:SetMessage(l.cannot_change_your_registration..showCurrency(fine).."\n \n*\n*")
		return end

		if Game.player:CriminalRecord() then
			amount = 5000 * (1+Game.system.lawlessness)
			form:SetMessage(l.Change_your_registration_and_clean_criminal_record..showCurrency(amount).."\n \n*\n*")
			form:AddOption(l.Register_in .. Game.system.faction.name, 1)
		else
			amount = 100 * (1+Game.system.lawlessness)
			form:SetMessage(l.Work_we_do..showCurrency(amount).."\n \n*\n*")
			form:AddOption(l.Register_in .. Game.system.faction.name, 1)
		end
		return
	end

	if option == 1 then
		form:Clear()
		if Game.player:GetMoney() < amount then
			form:SetMessage("\n"..l.Not_have_enough_credit)
		else
			local ship_prefix = string.upper(string.sub(Game.system.faction.name,1,2))
			local shiplabel = string.format("%02s-%04d", ship_prefix, Engine.rand:Integer(0,9999))
			Game.player:SetLabel(shiplabel)
			_G.ShipFaction = Game.system.faction.name
			local prefix = string.sub(Game.player.label, 1 , 2)
			Game.player:ClearCriminalRecord()
			Game.player:AddMoney(-amount)
			form:SetMessage("\n"..l.Change_of_enrolls_His_new_register_is..Game.player.label, ad.title)
		end
		return
	end
	form:Close()
end

local onDelete = function (ref)
	ads[ref] = nil
end

local licon = "change_of_enrolls"
local onCreateBB = function (station)
	local ad = {
		title    = l.Change_of_enrolls,
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
	if type(loaded_data) == "table" then
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

Serializer:Register("ChangeOfEnrolls", serialize, unserialize)
