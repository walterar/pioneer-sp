-- SPA.lua for Pioneer Scout+ (c)2013-2014 by walterar <walterar2@gmail.com>
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt
-- Work in progress.

local Lang       = import("Lang")
local Engine     = import("Engine")
local Game       = import("Game")
local Comms      = import("Comms")
local Event      = import("Event")
local Format     = import("Format")
local Serializer = import("Serializer")
--local Character  = import("Character")

local l  = Lang.GetResource("module-spa") or Lang.GetResource("module-spa","en")
local ls = Lang.GetResource("module-system") or Lang.GetResource("module-system","en")


-- Default numeric values --
----------------------------
local oneyear = 31557600-- One standard Julian year--2592000 un mes
local ads = {}
local memberships = {
-- some_club = {
--	joined = 0,
--	expiry = oneyear,
--  milrads = 0, -- counter for military fuel / radioactives balance
-- }
}

-- 1 / probability that you'll see one in a BBS
-- local chance_of_availability = 1

local flavours = {
	{
		clubname        = l.FLAVOUR_CLUBNAME_0,
		welcome         = l.FLAVOUR_WELCOME_0,
		nonmember_intro = l.FLAVOUR_NONMEMBER_INTRO_0,
		member_intro    = l.FLAVOUR_MEMBER_INTRO_0,
		annual_fee      = 2600,
	}
}

local loaded_data

local onDelete = function (ref)
	ads[ref] = nil
end

local onChat
onChat = function (form, ref, option)
	local ad = ads[ref]

	local setMessage = function (message)
		form:SetMessage(message:interp({
			hydrogen      = l.HYDROGEN,
			military_fuel = l.MILITARY_FUEL,
			radioactives  = l.RADIOACTIVES,
			metal_alloys  = l.METAL_ALLOYS,
			clubname      = ad.flavour.clubname,
		}))
	end

	form:Clear()
	form:SetTitle(ad.flavour.clubname)
	local membership = memberships[ad.flavour.clubname]

	if membership and (membership.joined + membership.expiry > Game.time) then
		Game.player:SetFuelPercent()

		setMessage(ad.flavour.member_intro)

		form:AddGoodsTrader({
			canTrade = function (ref, commodity)
				return ({
					['HYDROGEN']      = true,
					['MILITARY_FUEL'] = true,
					['RADIOACTIVES']  = true,
					['METAL_ALLOYS']  = true,
				})[commodity]
			end,
			getStock = function (ref, commodity)
				ad.stock[commodity] = ({
					['HYDROGEN']      = ad.stock.HYDROGEN or (Engine.rand:Integer(2,50) + Engine.rand:Integer(3,25)),
					['MILITARY_FUEL'] = ad.stock.MILITARY_FUEL or (Engine.rand:Integer(2,25) + Engine.rand:Integer(3,25)),
					['METAL_ALLOYS']  = ad.stock.METAL_ALLOYS or (Engine.rand:Integer(2,25) + Engine.rand:Integer(3,25)),
					['RADIOACTIVES']  = 0,
				})[commodity]
				return ad.stock[commodity]
			end,
			getBuyPrice = function (ref, commodity)
				return ad.station:GetEquipmentPrice(commodity) * ({
					['HYDROGEN']      = 0.5, -- half price Hydrogen
					['MILITARY_FUEL'] = 0.6, -- 40% off Milfuel
					['METAL_ALLOYS']  = 0.6, -- 40% off Metal_Alloys
					['RADIOACTIVES']  = 0, -- Radioactives go free
				})[commodity]
			end,
			onClickBuy = function (ref, commodity)
				return membership.joined + membership.expiry > Game.time
			end,
			getSellPrice = function (ref, commodity)
				return ad.station:GetEquipmentPrice(commodity) * ({
					['HYDROGEN']      = 0.45,
					['MILITARY_FUEL'] = 0.55,
					['METAL_ALLOYS']  = 0.55,
					['RADIOACTIVES']  = 0,
				})[commodity]
			end,
			onClickSell = function (ref, commodity)
				if (commodity == 'RADIOACTIVES' and membership.milrads < 1) then
					Comms.Message(l.YOU_MUST_BUY:interp({
						military_fuel = l.MILITARY_FUEL,
						radioactives  = l.RADIOACTIVES,
						metal_alloys  = l.METAL_ALLOYS,
					}))
					return false
				end
				return	membership.joined + membership.expiry > Game.time
			end,
			bought = function (ref, commodity)
				ad.stock[commodity] = ad.stock[commodity] + 1
				if commodity == 'MILITARY_FUEL' or commodity == 'RADIOACTIVES' then
					membership.milrads = membership.milrads -1
				end
			end,
			sold = function (ref, commodity)
				ad.stock[commodity] = ad.stock[commodity] - 1
				if commodity == 'MILITARY_FUEL' or commodity == 'RADIOACTIVES' then
					membership.milrads = membership.milrads +1
				end
			end,
		})

	elseif option == -1 then
		form:Close()

	elseif option == 1 then
		setMessage(l.WE_WILL_ONLY_DISPOSE_OF)
		form:AddOption(l.APPLY_FOR_MEMBERSHIP,2)
		form:AddOption(l.GO_BACK,0)

	elseif option == 2 then
		if Game.player:GetMoney() > 2600 then
			memberships[ad.flavour.clubname] = {
				joined  = Game.time,
				expiry  = oneyear,
				milrads = 0,
			}
			_G.SpaMember = 1
			Game.player:AddMoney(0 - ad.flavour.annual_fee)
			setMessage(l.YOU_ARE_NOW_A_MEMBER:interp({
				expiry_date = Format.Date(memberships[ad.flavour.clubname].joined + memberships[ad.flavour.clubname].expiry)
			}))
			form:AddOption(l.BEGIN_TRADE,0)

		else
			setMessage(l.YOUR_MEMBERSHIP_APPLICATION_HAS_BEEN_DECLINED)
		end

	else
		setMessage(ad.flavour.nonmember_intro:interp({
			membership_fee = format_num(ad.flavour.annual_fee, 2, "$", "-")
		}))
		form:AddOption(l.WHAT_CONDITIONS_APPLY:interp({radioactives = l.RADIOACTIVES}),1)
		form:AddOption(l.APPLY_FOR_MEMBERSHIP,2)
	end
end

local licon = "spa"
local onCreateBB = function (station)
	local ad = {
			station = station,
			stock   = {},
			price   = {}
		}
	ad.flavour = flavours[1]
	ads[station:AddAdvert({
		description = ad.flavour.clubname,
		icon        = licon,
		onChat      = onChat,
		onDelete    = onDelete})] = ad
end

local onShipFuelChanged = function (ship, state)
	if ship:IsPlayer() and (state == "WARNING" or state == "EMPTY") then
		if SpaMember > 0 then
--			Comms.Message(t('The propellent cell has been recharged.'))
			Game.player:SetFuelPercent(50)
		elseif state == "WARNING" then
			Comms.ImportantMessage(ls.YOUR_FUEL_TANK_IS_ALMOST_EMPTY)
		elseif state == "EMPTY" then
			Comms.ImportantMessage(ls.YOUR_FUEL_TANK_IS_EMPTY)
		end
	end
end

local onShipDocked = function (ship, station)
	if ship:IsPlayer() then
		local membership = memberships[flavours[1].clubname]
		if membership and (membership.joined + membership.expiry > Game.time) then
			_G.SpaMember = 1
		else
			_G.SpaMember = 0
		end
	end
end

local onGameStart = function ()
	if loaded_data then
		for k,ad in pairs(loaded_data.ads) do
			ads[ad.station:AddAdvert({
			description = ad.flavour.clubname,
			icon        = licon,
			onChat      = onChat,
			onDelete    = onDelete})] = ad
		end
		memberships = loaded_data.memberships
		loaded_data = nil
	else
		memberships = {}
	end
end

local serialize = function ()
	return { ads = ads, memberships = memberships }
end

local unserialize = function (data)
	loaded_data = data
end

Event.Register("onGameStart", onGameStart)
Event.Register("onCreateBB", onCreateBB)
Event.Register("onShipFuelChanged", onShipFuelChanged)
Event.Register("onShipDocked", onShipDocked)

Serializer:Register("SPA", serialize, unserialize)
