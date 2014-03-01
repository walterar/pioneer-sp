-- ShipsResale.lua for Pioneer Scout+ (c)2013-2014 by walterar <walterar2@gmail.com>
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt
-- Work in progress.

local Engine     = import("Engine")
local Game       = import("Game")
local Event      = import("Event")
local Format     = import("Format")
local Serializer = import("Serializer")
local utils      = import("utils")
local ShipDef    = import("ShipDef")
local Lang       = import("Lang")

local l = Lang.GetResource("module-shipsresale") or Lang.GetResource("module-shipsresale","en")

local ads = {}
local loaded_data
local saleship = {}
local my_shipDef,my_ship_name,my_ship_id,my_ship_price,shipdefs,maxsales
local oksel = 0

local onChat = function (form, ref, option)
	my_shipDef = ShipDef[Game.player.shipId]
	my_ship_name = my_shipDef.name
	if oksel == 0 or Game.time >= (oksel + 60*60*1) then
		my_ship_price = math.ceil(my_shipDef.basePrice * Engine.rand:Number(0.7,0.90))
		shipdefs = utils.build_array(utils.filter(function (k,def)
			return
				def.tag == 'SHIP'
				and def.basePrice > 0
				and def.name ~= my_ship_name
				and def.basePrice <= (Game.player:GetMoney() + my_ship_price)
			end, pairs(ShipDef)))
		if #shipdefs == 0 then return end
		maxsales = 6
		local minsales = 4
		local shipsales
		local sales = 0
		local shipsel
		for i = 1, maxsales do
			shipsel = shipdefs[Engine.rand:Integer(1,#shipdefs)]
			if shipsales == nil then
				shipsales = shipsel.name
				sales = sales + 1
				saleship[sales] = shipsel
			else
				local repe = string.find(shipsales,shipsel.name,1,true)
				if repe == nil then
					shipsales = shipsales.." / "..shipsel.name
					sales = sales + 1
					saleship[sales] = shipsel
				end
			end
		end
		if sales <= minsales then minsales = sales end
		maxsales = Engine.rand:Integer(minsales,sales)
		oksel = Game.time
	end

	local ad = ads[ref]

	if option == 0 then
		form:Clear()

		form:SetTitle(ad.title)
--		form:SetFace({female = false, armour = false, seed = ad.faceseed})
		form:SetMessage(string.interp(l["HelloCommander"..Engine.rand:Integer(1,4)]..l["Sale"..Engine.rand:Integer(1,4)].."[ "..my_ship_name.." ] "..format_num(my_ship_price)))

		for i = 1,maxsales do
			local difer = (saleship[i].basePrice - my_ship_price)
			if difer >= 0 then
				venta = l.His_ship_more..format_num(difer)..l["in_exchange_for_a"..Engine.rand:Integer(1,4)].." [ "..saleship[i].name.." ]"
			else
				venta = l.His_ship_less..format_num(math.abs (difer))..l["in_exchange_for_a"..Engine.rand:Integer(1,4)].." [ "..saleship[i].name.." ]"
			end
			form:AddOption(venta, i)
		end
		return
	end
	if option >= 1 and option <= maxsales then
		if Game.player:GetEquipCount('CABIN','PASSENGER_CABIN') > 0 then
			form:SetMessage(l.passengers)
			return
		end
		local credit = Game.player:GetMoney()
		local difer = saleship[option].basePrice - my_ship_price
		if difer >= 0 then
			if credit < difer then
				form:SetMessage(l.Not_have_enough_credit)
				return
			else
				Game.player:AddMoney(-difer)
				Game.player:SetShipType(saleship[option].id)
				saleship[option] = my_shipDef
				oksel = 0
				form:Clear()
				form:SetMessage(l.Thanks)
				return
			end
		else
			difer = math.abs (difer)
			Game.player:AddMoney(difer)
			Game.player:SetShipType(saleship[option].id)
			saleship[option] = my_shipDef
			form:Clear()
			form:SetMessage(l.Thanks)
			return
		end
	end
	form:Close()
end

local onShipTypeChanged = function (ship)
	if not ship:IsPlayer() then return end
	my_shipDef = ShipDef[Game.player.shipId]
	my_ship_name = my_shipDef.name
end

local onDelete = function (ref)
	ads[ref] = nil
end

local licon = "ships_resale"
local onCreateBB = function (station)
	local ad = {
		title    = l.Ships_Resale,
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

Event.Register("onShipTypeChanged", onShipTypeChanged)
Event.Register("onCreateBB", onCreateBB)
Event.Register("onGameStart", onGameStart)

Serializer:Register("ShipsResale", serialize, unserialize)
