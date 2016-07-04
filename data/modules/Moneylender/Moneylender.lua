-- Moneylender.lua for Pioneer Scout+ (c)2012-2015 by walterar <walterar2@gmail.com>
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt

local Lang       = import("Lang")
local Engine     = import("Engine")
local Game       = import("Game")
local Comms      = import("Comms")
local Event      = import("Event")
local Serializer = import("Serializer")
local Format     = import("Format")
local Timer      = import("Timer")

local l = Lang.GetResource("module-moneylender") or Lang.GetResource("module-moneylender","en")

local flavours = {}
for i = 0,5 do
	table.insert(flavours, {
		title     = l["FLAVOUR_" .. i .. "_TITLE"]
	})
end

local ads    = {}
local deuda  = {}
local cuotas = 12

local onChat = function (form, ref, option)
	local ad = ads[ref]
	if option == 0 then
		form:Clear()

		form:SetTitle(l.GALACTIC_PILOTS_UNION.."\n"..l.AGENCY..Game.system.name.."\n"..l.PERSONAL_LOANS_NO_GUARANTOR.."\n*")

		form:SetFace({ seed = ad.faceseed })
		form:SetMessage(l.MESSAGE_3.."\n*")

		form:AddOption(showCurrency(5000), 5000)
		form:AddOption(showCurrency(10000), 10000)
		form:AddOption(showCurrency(50000), 50000)
		form:AddOption(showCurrency(100000), 100000)
		form:AddOption(showCurrency(500000), 500000)

		return
	end

	if option == -1 then
		form:Close()
		return
	end

	if deuda.total and deuda.total > 0 and option > 0 then
		form:Clear()

		local introtext = string.interp(l.REQUEST_DENIED,{
									deuda  = showCurrency(deuda.total),
									fecha  = Format.Date(deuda.fecha_inicio),
									cuotas = deuda.resto_cuotas,
									resto  = cuotas - deuda.resto_cuotas,
									})
		form:SetMessage(introtext)

	return end

	if option >= 5000 then
		Game.player:AddMoney(option)

		deuda = {
			total        = option*3,
			resto_cuotas = cuotas,
			valor_cuota  = (option*3)/cuotas,
			fecha_inicio = Game.time,
			fecha_p_pago = Game.time + (60*60*24*30)
			}

		_G.deuda_valor_cuota = deuda.valor_cuota
		_G.deuda_resto_cuotas = deuda.resto_cuotas
		_G.deuda_fecha_p_pago = deuda.fecha_p_pago
		_G.deuda_total = deuda.total

		form:Clear()

		local introtext = string.interp(l.TRANSFER,{
								deuda  = showCurrency(option),
								fecha  = Format.Date(deuda.fecha_inicio),
								cuotas = deuda.resto_cuotas,
								valor  = showCurrency(deuda.valor_cuota),
								})
		form:SetMessage(introtext)

	end
end

local onDelete = function (ref)
	ads[ref] = nil
end

local onCreateBB = function (station)
	local n = Engine.rand:Integer(1, #flavours)

	local ad = {
		title    = flavours[n].title,
		message  = flavours[n].message,
		station  = station,
		faceseed = Engine.rand:Integer()
		}

	local ref = station:AddAdvert({
		description = ad.title,
		icon        = "moneylender",
		onChat      = onChat,
		onDelete    = onDelete})
	ads[ref] = ad
end

local To_pay = function (cobrar_cuotas)
	local debitar = deuda.valor_cuota * cobrar_cuotas
	Game.player:AddMoney(-debitar)
	deuda.fecha_p_pago = Game.time + (60*60*24*30)
	_G.deuda_fecha_p_pago = deuda.fecha_p_pago
	deuda.resto_cuotas = deuda.resto_cuotas - cobrar_cuotas
	_G.deuda_resto_cuotas = deuda.resto_cuotas
	deuda.total = deuda.total - debitar
	_G.deuda_total = deuda.total
	if deuda.total <= 0 then
		deuda = {}
		_G.deuda_valor_cuota = nil
		_G.deuda_resto_cuotas = nil
		_G.deuda_fecha_p_pago = nil
		_G.deuda_total = nil
	end
end

local onShipDocked = function (ship, station)
	if ship == Game.player and deuda_total and Game.time >= deuda_fecha_p_pago then
		local cobrar_cuotas = math.floor((Game.time - (deuda_fecha_p_pago-(60*60*24*30))) / (60*60*24*30))
--print("cobrar_cuotas = "..cobrar_cuotas)
		if cobrar_cuotas < 1 then cobrar_cuotas = 1 end
		if (deuda.total - deuda.valor_cuota) < deuda.valor_cuota then
			cobrar_cuotas = 1
			deuda.valor_cuota = deuda.total
			deuda.fecha_p_pago = nil
		end
		Timer:CallAt(Game.time + 3, function ()-- permite cobrar la mision antes XXX
			if Game.player:GetMoney() > (deuda.valor_cuota * cobrar_cuotas) then
				To_pay(cobrar_cuotas)
			elseif math.floor(Game.player:GetMoney() / deuda.valor_cuota) > 0  then
				cobrar_cuotas = math.floor((Game.player:GetMoney() / deuda.valor_cuota))-- ojo no redondear
				repeat
					if Game.player:GetMoney() > deuda.valor_cuota then
						To_pay(1)
						cobrar_cuotas = cobrar_cuotas -1
					end
				until cobrar_cuotas < 1
			end
		end)
	end
end

	local loaded_data
local onGameStart = function ()
	ads = {}
	if type(loaded_data) == "table" then
		for k,ad in pairs(loaded_data.ads) do
			ads[ad.station:AddAdvert({
				description = ad.title,
				icon        = "moneylender",
				onChat      = onChat,
				onDelete    = onDelete})] = ad
		end
		deuda = {}
		deuda = loaded_data.deuda
		loaded_data = nil
	end
end

local serialize = function ()
	return {ads = ads, deuda = deuda}
end

local unserialize = function (data)
	loaded_data = data
end

Event.Register("onCreateBB", onCreateBB)
Event.Register("onGameStart", onGameStart)
Event.Register("onShipDocked", onShipDocked)

Serializer:Register("Moneylender", serialize, unserialize)
