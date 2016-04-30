-- Copyright © 2008-2016 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt
-- Modified for Pioneer Scout Plus by Walter Arnolfo

local Engine     = import("Engine")
local Lang       = import("Lang")
local Game       = import("Game")
local Space      = import("Space")
local Comms      = import("Comms")
local Event      = import("Event")
local Mission    = import("Mission")
local Format     = import("Format")
local Serializer = import("Serializer")
local Character  = import("Character")
local Equipment  = import("Equipment")
local ShipDef    = import("ShipDef")
local Ship       = import("Ship")
local utils      = import("utils")
local Timer      = import("Timer")

local MsgBox   = import("ui/MessageBox")
local InfoFace = import("ui/InfoFace")
local SLButton = import("ui/SmallLabeledButton")

local l  = Lang.GetResource("module-cargorun") or Lang.GetResource("module-cargorun","en")
local lm = Lang.GetResource("miscellaneous") or Lang.GetResource("miscellaneous","en")

local ui = Engine.ui
local max_delivery_dist = 30
local typical_travel_time = (2.5 * max_delivery_dist + 8) * 24 * 60 * 60
local typical_reward = 75 * max_delivery_dist
local typical_reward_local = 450
local max_cargo = 10
local max_cargo_wholesaler = 100
local pickup_factor = 2
local max_price = 300

local aluminium_tubes = Equipment.EquipType.New({
	l10n_key = 'ALUMINIUM_TUBES', slots="cargo", price=50,
	capabilities={mass=1},
	purchasable=false, icon_name="Default",
	l10n_resource="module-cargorun"
})
local art_objects = Equipment.EquipType.New({
	l10n_key = 'ART_OBJECTS', slots="cargo", price=200,
	capabilities={mass=1},
	purchasable=false, icon_name="Default",
	l10n_resource="module-cargorun"
})
local clus = Equipment.EquipType.New({
	l10n_key = 'CLUS', slots="cargo", price=20,
	capabilities={mass=1},
	purchasable=false, icon_name="Default",
	l10n_resource="module-cargorun"
})
local diamonds = Equipment.EquipType.New({
	l10n_key = 'DIAMONDS', slots="cargo", price=300,
	capabilities={mass=1},
	purchasable=false, icon_name="Default",
	l10n_resource="module-cargorun"
})
local digesters = Equipment.EquipType.New({
	l10n_key = 'DIGESTERS', slots="cargo", price=10,
	capabilities={mass=1},
	purchasable=false, icon_name="Default",
	l10n_resource="module-cargorun"
})
local electrical_appliances = Equipment.EquipType.New({
	l10n_key = 'ELECTRICAL_APPLIANCES', slots="cargo", price=150,
	capabilities={mass=1},
	purchasable=false, icon_name="Default",
	l10n_resource="module-cargorun"
})
local explosives = Equipment.EquipType.New({
	l10n_key = 'EXPLOSIVES', slots="cargo", price=50,
	capabilities={mass=1},
	purchasable=false, icon_name="Default",
	l10n_resource="module-cargorun"
})
local furniture = Equipment.EquipType.New({
	l10n_key = 'FURNITURE', slots="cargo", price=15,
	capabilities={mass=1},
	purchasable=false, icon_name="Default",
	l10n_resource="module-cargorun"
})
local greenhouses = Equipment.EquipType.New({
	l10n_key = 'GREENHOUSES', slots="cargo", price=20,
	capabilities={mass=1},
	purchasable=false, icon_name="Default",
	l10n_resource="module-cargorun"
})
local hazardous_substances = Equipment.EquipType.New({
	l10n_key = 'HAZARDOUS_SUBSTANCES', slots="cargo", price=100,
	capabilities={mass=1},
	purchasable=false, icon_name="Default",
	l10n_resource="module-cargorun"
})
local machine_tools = Equipment.EquipType.New({
	l10n_key = 'MACHINE_TOOLS', slots="cargo", price=10,
	capabilities={mass=1},
	purchasable=false, icon_name="Default",
	l10n_resource="module-cargorun"
})
local neptunium = Equipment.EquipType.New({
	l10n_key = 'NEPTUNIUM', slots="cargo", price=200,
	capabilities={mass=1},
	purchasable=false, icon_name="Default",
	l10n_resource="module-cargorun"
})
local plutonium = Equipment.EquipType.New({
	l10n_key = 'PLUTONIUM', slots="cargo", price=200,
	capabilities={mass=1},
	purchasable=false, icon_name="Default",
	l10n_resource="module-cargorun"
})
local semi_finished_products = Equipment.EquipType.New({
	l10n_key = 'SEMI_FINISHED_PRODUCTS', slots="cargo", price=10,
	capabilities={mass=1},
	purchasable=false, icon_name="Default",
	l10n_resource="module-cargorun"
})
local spaceship_parts = Equipment.EquipType.New({
	l10n_key = 'SPACESHIP_PARTS', slots="cargo", price=250,
	capabilities={mass=1},
	purchasable=false, icon_name="Default",
	l10n_resource="module-cargorun"
})
local titanium = Equipment.EquipType.New({
	l10n_key = 'TITANIUM', slots="cargo", price=150,
	capabilities={mass=1},
	purchasable=false, icon_name="Default",
	l10n_resource="module-cargorun"
})
local tungsten = Equipment.EquipType.New({
	l10n_key = 'TUNGSTEN', slots="cargo", price=125,
	capabilities={mass=1},
	purchasable=false, icon_name="Default",
	l10n_resource="module-cargorun"
})
local uranium = Equipment.EquipType.New({
	l10n_key = 'URANIUM', slots="cargo", price=175,
	capabilities={mass=1},
	purchasable=false, icon_name="Default",
	l10n_resource="module-cargorun"
})
local quibbles = Equipment.EquipType.New({
	l10n_key = 'QUIBBLES', slots="cargo", price=1,
	capabilities={mass=1},
	purchasable=false, icon_name="Default",
	l10n_resource="module-cargorun"
})
local wedding_dresses = Equipment.EquipType.New({
	l10n_key = 'WEDDING_DRESSES', slots="cargo", price=15,
	capabilities={mass=1},
	purchasable=false, icon_name="Default",
	l10n_resource="module-cargorun"
})

local chemical = {
	digesters,
	hazardous_substances
}

local mining = {
	clus,
	explosives
}

local hardware = {
	aluminium_tubes,
	diamonds,
	hazardous_substances,
	machine_tools,
	neptunium,
	plutonium,
	semi_finished_products,
	spaceship_parts,
	titanium,
	tungsten,
	uranium
}

local infrastructure = {
	clus,
	explosives,
	greenhouses
}

local consumer_goods = {
	electrical_appliances,
	furniture,
	spaceship_parts
}

local expensive = { -- price >= 175
	art_objects,
	diamonds,
	neptunium,
	plutonium,
	spaceship_parts,
	uranium
}

local fluffy = {
	quibbles
}

local wedding = {
	wedding_dresses
}

local art = {
	art_objects
}

local gems = {
	diamonds
}

local radioactive = {
	neptunium,
	plutonium,
	uranium
}

local centrifuges = {
	aluminium_tubes
}

local custom_cargo = {
	{ bkey = "CHEMICAL"      , goods = chemical, weight = 0 },
	{ bkey = "MINING"        , goods = mining, weight = 0 },
	{ bkey = "HARDWARE"      , goods = hardware, weight = 0 },
	{ bkey = "INFRASTRUCTURE", goods = infrastructure, weight = 0 },
	{ bkey = "CONSUMER_GOODS", goods = consumer_goods, weight = 0 },
	{ bkey = "EXPENSIVE"     , goods = expensive, weight = 0 },
	{ bkey = "FLUFFY"        , goods = fluffy, weight = 0 },
	{ bkey = "WEDDING"       , goods = wedding, weight = 0 },
	{ bkey = "ART"           , goods = art, weight = 0 },
	{ bkey = "GEMS"          , goods = gems, weight = 0 },
	{ bkey = "RADIOACTIVE"   , goods = radioactive, weight = 0 },
	{ bkey = "CENTRIFUGES"   , goods = centrifuges, weight = 0 }
}

-- Each branch should have a probability weight proportional to its size
local custom_cargo_weight_sum = 0
for branch,branch_array in pairs(custom_cargo) do
	custom_cargo[branch].weight = #branch_array.goods
	custom_cargo_weight_sum = custom_cargo_weight_sum + #branch_array.goods
end

local ads = {}
local missions = {}

-- This function returns the number of flavours of the given string str
-- It is assumed that the first flavour has suffix '_1'
local getNumberOfFlavours = function (str)
	local num = 1

	while l[str .. "_" .. num] do
		num = num + 1
	end
	return num - 1
end

local onChat = function (form, ref, option)
	local ad = ads[ref]

	form:Clear()

	if option == -1 then
		form:Close()
		return
	end

	form:SetFace(ad.client)

	if option == 0 then
		local introtext = string.interp(ad.introtext, {
			name         = ad.client.name,
			cash         = showCurrency(ad.reward),
			cargoname    = ad.cargotype:GetName(),
			starport     = ad.location:GetSystemBody().name,
			system       = ad.location:GetStarSystem().name,
			sectorx      = ad.location.sectorX,
			sectory      = ad.location.sectorY,
			sectorz      = ad.location.sectorZ,
			dom_starport = ad.domicile:GetSystemBody().name,
			dom_system   = ad.domicile:GetStarSystem().name,
			dom_sectorx  = ad.domicile.sectorX,
			dom_sectory  = ad.domicile.sectorY,
			dom_sectorz  = ad.domicile.sectorZ,
			dist         = ad.dist
		})
		form:SetMessage(introtext)

	elseif option == 1 then
		local n = getNumberOfFlavours("WHYSOMUCH_" .. ad.branch)
		if n >= 1 then
			form:SetMessage(string.interp(l["WHYSOMUCH_" .. ad.branch .. "_" .. Engine.rand:Integer(1, n)], { cargoname = ad.cargotype:GetName() }))
		elseif ad.urgency >= 0.8 then
			form:SetMessage(string.interp(l["WHYSOMUCH_URGENT_" .. Engine.rand:Integer( 1, getNumberOfFlavours("WHYSOMUCH_URGENT"))], { cargoname = ad.cargotype:GetName() }))
		else
			form:SetMessage(string.interp(l["WHYSOMUCH_" .. Engine.rand:Integer( 1, getNumberOfFlavours("WHYSOMUCH"))], { cargoname = ad.cargotype:GetName() }))
		end

	elseif option == 2 then
		local howmuch
		if ad.wholesaler then
			howmuch = string.interp(l["HOWMUCH_WHOLESALER_" .. Engine.rand:Integer(1, getNumberOfFlavours("HOWMUCH_WHOLESALER"))], {
				amount    = ad.amount,
				cargoname = ad.cargotype:GetName(),
			})
		else
			if ad.amount > 1 then
				howmuch = string.interp(l["HOWMUCH_" .. Engine.rand:Integer(1,getNumberOfFlavours("HOWMUCH"))],
					{amount = ad.amount})
			else
				howmuch = string.interp(l["HOWMUCH_SINGULAR_" .. Engine.rand:Integer(1,getNumberOfFlavours("HOWMUCH_SINGULAR"))],
					{amount = ad.amount})
			end
		end
		form:SetMessage(howmuch)

	elseif option == 3 then
		if (Game.player.freeCapacity < ad.amount and not ad.pickup)
			or ShipDef[Game.player.shipId].capacity < ad.amount
		then
			form:SetMessage(l.YOU_DO_NOT_HAVE_ENOUGH_CARGO_SPACE_ON_YOUR_SHIP)
			return
		end

		if (MissionsSuccesses - MissionsFailures < 5) and ad.risk > 0 then
			form:SetMessage(l["DENY_" .. Engine.rand:Integer(1, getNumberOfFlavours("DENY"))])
			return
		end

		if Game.player:CriminalRecord() and ad.cargotype.price >= 150 then
			form:SetMessage(lm.CRIMINAL_RECORD)
			return
		end

		local cargo_picked_up
		if not ad.pickup then
			Game.player:AddEquip(ad.cargotype, ad.amount, "cargo")
			cargo_picked_up = true
		else
			cargo_picked_up = false
		end

		form:RemoveAdvertOnClose()

		ads[ref] = nil
		local mission = {
			type            = "CargoRun",
			domicile        = ad.domicile,
			client          = ad.client,
			location        = ad.location,
			localdelivery   = ad.localdelivery,
			wholesaler      = ad.wholesaler,
			pickup          = ad.pickup,
			cargo_picked_up = cargo_picked_up,
			introtext       = ad.introtext,
			risk            = ad.risk,
			reward          = ad.reward,
			due             = ad.due,
			amount          = ad.amount,
			branch          = ad.branch,
			cargotype       = ad.cargotype,
			way_trip        = ad.location,
			return_trip     = ad.domicile,
		}

		table.insert(missions,Mission.New(mission))

		if ad.pickup then
			form:SetMessage(l["ACCEPTED_PICKUP_" .. Engine.rand:Integer(1, getNumberOfFlavours("ACCEPTED_PICKUP"))])
		else
			form:SetMessage(l["ACCEPTED_" .. Engine.rand:Integer(1, getNumberOfFlavours("ACCEPTED"))])
		end
		if NavAssist and Game.system.path ~= mission.location:GetStarSystem().path then
			Game.player:SetHyperspaceTarget(mission.location:GetStarSystem().path)
		end
		switchEvents()
		return

	elseif option == 4 then
		form:SetMessage(string.interp(l["URGENCY_" .. ad.branch .. "_" .. math.floor(ad.urgency * (getNumberOfFlavours("URGENCY_" .. ad.branch) - 1)) + 1]
			or l["URGENCY_" .. math.floor(ad.urgency * (getNumberOfFlavours("URGENCY") - 1)) + 1], { date = Format.Date(ad.due) }))

	elseif option == 5 then
		if ad.localdelivery then -- very low risk -> no specific text to give no confusing answer
			form:SetMessage(l.RISK_1)
		else
			local branch
			if ad.wholesaler then branch = "WHOLESALER" else branch = ad.branch end
			form:SetMessage(l["RISK_" .. branch .. "_" .. ad.risk + 1] or l["RISK_" .. ad.risk + 1])
		end
	end

	form:AddOption(l.WHY_SO_MUCH_MONEY, 1)
	form:AddOption(l.HOW_MUCH_MASS, 2)
	form:AddOption(l.HOW_SOON_MUST_IT_BE_DELIVERED, 4)
	form:AddOption(l.WILL_I_BE_IN_ANY_DANGER, 5)
	form:AddOption(l.COULD_YOU_REPEAT_THE_ORIGINAL_REQUEST, 0)
	form:AddOption(l.OK_AGREED, 3)
end

local onDelete = function (ref)
	ads[ref] = nil
end


local randomCargo = function()
	local accumulator = 0
	local r = Engine.rand:Integer(0,custom_cargo_weight_sum)

	for k,b in pairs(custom_cargo) do
		accumulator = b.weight + accumulator
		if r <= accumulator then
			return
				custom_cargo[k].bkey,
				custom_cargo[k].goods[Engine.rand:Integer(1, #custom_cargo[k].goods)]
		end
	end
	error("Oh, dear! This should not happen.")
end


local makeAdvert = function (station)
	local reward, due, location, way_trip, return_trip, dist, amount
	local risk, wholesaler, pickup, branch, cargotype, missiontype
	local client = Character.New()
	local urgency = Engine.rand:Number(1)
	local localdelivery = Engine.rand:Number(0, 1) > 0.5 and true or false

	branch, cargotype = randomCargo()
	if localdelivery then
		if _nearbystationsLocals and #_nearbystationsLocals > 0 then
			location = _nearbystationsLocals[Engine.rand:Integer(1,#_nearbystationsLocals)]
		end
		if not location or location == station.path then return end

--		dist = station:DistanceTo(Space.GetBody(location.bodyIndex))
--		if dist < 1000 then return end

		amount = Engine.rand:Integer(1, max_cargo)
		risk = 0 -- no risk for local delivery
		wholesaler = false -- no local wholesaler delivery
		pickup = Engine.rand:Number(0, 1) > 0.75 and true or false

		local AU = 149597870700
		local dist = station:DistanceTo(Space.GetBody(location.bodyIndex))/AU
		local reward_base = 350

		missiontype = "LOCAL"
		if pickup then missiontype = "PICKUP_LOCAL" end

		due    = _local_due(station,location,urgency,pickup)
		reward = reward_base+(reward_base*(1+math.sqrt(dist))*(1+urgency)*(1+Game.system.lawlessness))

	else
		if _nearbystationsRemotes and #_nearbystationsRemotes > 0 then
			location = _nearbystationsRemotes[Engine.rand:Integer(1,#_nearbystationsRemotes)]
		end
		if location == nil then return end
		dist = location:DistanceTo(Game.system)
		wholesaler = Engine.rand:Number(0, 1) > 0.75 and true or false
		if wholesaler then
			amount = Engine.rand:Integer(max_cargo, max_cargo_wholesaler)
			missiontype = "WHOLESALER"
			pickup = false
		else
			amount = Engine.rand:Integer(1, max_cargo)
			pickup = Engine.rand:Number(0, 1) > 0.75 and true or false
			if pickup then
				missiontype = "PICKUP"
			else
				missiontype = branch
			end
		end

		risk = 0.75 * cargotype.price / max_price + Engine.rand:Number(0, 0.25) -- goods with price max_price have a risk of 0 to 3
		local riskmargin = Engine.rand:Number(-0.3,0.3) -- Add some random luck
		if     risk >= (1.0 + riskmargin) then  risk = 3--pirates = 3
		elseif risk >= (0.7 + riskmargin) then  risk = 2--pirates = 2
		elseif risk >= (0.5 + riskmargin) then  risk = 1--pirates = 1
		else   risk = 0
		end

		reward = 1000+(tariff(dist,risk,urgency,location)*(1+amount/max_cargo_wholesaler))
		due    = _remote_due(dist,urgency,pickup)

	end

	local n = getNumberOfFlavours("INTROTEXT_" .. missiontype)
	local introtext
	if n >= 1 then
		introtext = l["INTROTEXT_" .. missiontype .. "_" .. Engine.rand:Integer(1, n)]
	else
		introtext = l["INTROTEXT_" .. Engine.rand:Integer(1, getNumberOfFlavours("INTROTEXT"))]
	end

	local dist_txt = _distTxt(location)--,localdelivery)

	local ad = {
		station       = station,
		domicile      = station.path,
		client        = client,
		location      = location,
		localdelivery = localdelivery,
		wholesaler    = wholesaler,
		pickup        = pickup,
		introtext     = introtext,
		dist          = dist_txt,
		due           = due,
		amount        = amount,
		branch        = branch,
		cargotype     = cargotype,
		risk          = risk,
		urgency       = urgency,
		reward        = reward,
		faceseed      = Engine.rand:Integer(),
		way_trip      = location,
		return_trip   = domicile,
	}

	n = getNumberOfFlavours("ADTEXT_" .. missiontype)
	local adtext
	if n >= 1 then
		adtext = l["ADTEXT_" .. missiontype .. "_" .. Engine.rand:Integer(1, n)]
	else
		adtext = l["ADTEXT_" .. Engine.rand:Integer(1, getNumberOfFlavours("ADTEXT"))]
	end
	ad.desc = string.interp(adtext, {
			system   = ad.location:GetStarSystem().name,
			cash     = showCurrency(ad.reward),
			starport = ad.location:GetSystemBody().name,
	})

	local ref = station:AddAdvert({
		description = ad.desc,
		icon        = ad.risk > 0 and "cargorun_danger" or "cargorun",
		onChat      = onChat,
		onDelete    = onDelete })
	ads[ref] = ad

	return ad
end

local onCreateBB = function (station)
	local num = math.ceil(Game.system.population)
	num = Engine.rand:Integer(0,num and num < 3 or 3)
	if num > 0 then
		for i = 1,num do
			makeAdvert(station)
		end
	end
end

local onUpdateBB = function (station)
	for ref,ad in pairs(ads) do
		if ad.localdelivery then
			if ad.due < Game.time + 24*60*60 then -- 1 day timeout for locals
				ad.station:RemoveAdvert(ref)
			end
		else
			if ad.due < Game.time + 2*24*60*60 then -- 2 day timeout for inter-system
				ad.station:RemoveAdvert(ref)
			end
		end
	end
	if Engine.rand:Integer(50) < 1 then makeAdvert(station) end
end

	local hostilactive = false
local onFrameChanged = function (body)
----print("CargoRun onFrameChanged body="..body.label)
	if hostilactive then return end
	if body:isa("Ship") and body:IsPlayer() and body.frameBody ~= nil then
		for ref,mission in pairs(missions) do
			if mission.risk < 1 then return end
			if mission.location:IsSameSystem(Game.system.path) then
				if mission.status == "ACTIVE" then
					if mission.pickup then
						if mission.cargo_picked_up then
							target_distance_from_entry = body:DistanceTo(Space.GetBody(mission.return_trip.bodyIndex))
						else return end
					else
						target_distance_from_entry = body:DistanceTo(Space.GetBody(mission.way_trip.bodyIndex))
					end
					if target_distance_from_entry > 500000e3 then return end
					local risk = mission.risk
					local ship
					local target_trip
					if mission.pickup then
						target_trip = mission.return_trip.bodyIndex
					else
						target_trip = mission.way_trip.bodyIndex
					end
					local locationx
					if mission.pickup then
						locationx = mission.return_trip:GetSystemBody().name
					else
						locationx = mission.return_trip:GetSystemBody().name
					end
					local pirate_greeting
					Timer:CallEvery(1, function ()
						if hostilactive then return true end
						if body:DistanceTo(Space.GetBody(target_trip)) > 100000e3 then return false end
						ship = ship_hostil(risk)
						if ship then
							hostilactive = true
							pirate_greeting = string.interp(l['PIRATE_TAUNTS_'..Engine.rand:Integer(1,7)],
								{client   = mission.client.name,
								location  = locationx,
								cargoname = mission.cargotype:GetName()
								})
							Comms.ImportantMessage(pirate_greeting, ship.label)
							return true
						end
					end)
					if Game.time > mission.due then mission.status = 'FAILED' end
				end
			end
		end
	end
end


local onShipDocked = function (player, station)
	if not player:IsPlayer() then return end
	hostilactive = false
	for ref,mission in pairs(missions) do
		if (mission.location == station.path and not mission.pickup)
		or (mission.domicile == station.path and mission.pickup and mission.cargo_picked_up)
		then
			if Game.time <= mission.due then-- dentro de fecha
				_G.MissionsSuccesses = MissionsSuccesses + 1
				local n = getNumberOfFlavours("SUCCESSMSG_" .. mission.branch)
				if n >= 1 then
					Comms.ImportantMessage(l["SUCCESSMSG_" .. mission.branch .. "_" .. Engine.rand:Integer(1, n)], mission.client.name)
				else
					Comms.ImportantMessage(l["SUCCESSMSG_" .. Engine.rand:Integer(1, getNumberOfFlavours("SUCCESSMSG"))], mission.client.name)
				end
				player:AddMoney(mission.reward)
			else-- fuera de fecha
				_G.MissionsFailures = MissionsFailures + 1
				local n = getNumberOfFlavours("FAILUREMSG_" .. mission.branch)
				if n >= 1 then
					Comms.ImportantMessage(l["FAILUREMSG_" .. mission.branch .. "_" .. Engine.rand:Integer(1, n)], mission.client.name)
				else
					Comms.ImportantMessage(l["FAILUREMSG_" .. Engine.rand:Integer(1, getNumberOfFlavours("FAILUREMSG"))], mission.client.name)
				end
			end
			local amount = Game.player:RemoveEquip(mission.cargotype, mission.amount, "cargo")
			if amount < mission.amount then
				_G.MissionsSuccesses = MissionsSuccesses - 1
				if player:GetMoney() < (amount - mission.amount) * mission.cargotype.price then
					_G.MissionsFailures = MissionsFailures + 1
				end
				Comms.ImportantMessage(l.WHAT_IS_THIS, mission.client.name)
				player:AddMoney((amount - mission.amount) * mission.cargotype.price) -- pay for the missing
				Comms.ImportantMessage(l.I_HAVE_DEBITED_YOUR_ACCOUNT, mission.client.name)
			end
			mission:Remove()
			missions[ref] = nil
		elseif mission.location == station.path and mission.pickup and not mission.cargo_picked_up then
			if Game.player.freeCapacity < mission.amount then
				Comms.ImportantMessage(l.YOU_DO_NOT_HAVE_ENOUGH_EMPTY_CARGO_SPACE, mission.client.name)
			else
				Game.player:AddEquip(mission.cargotype, mission.amount, "cargo")
				mission.cargo_picked_up = true
				Comms.ImportantMessage(l.WE_HAVE_LOADED_UP_THE_CARGO_ON_YOUR_SHIP, mission.client.name)
				mission.location = mission.domicile
				if NavAssist and Game.system.path ~= mission.location:GetStarSystem().path then
					Game.player:SetHyperspaceTarget(mission.location:GetStarSystem().path)
				end
			end
		elseif mission.status == "ACTIVE" and Game.time > mission.due then
			mission.status = 'FAILED'
		end

		if check_crime(mission,"FRAUD") then--XXX
			Comms.ImportantMessage(l.WHAT_IS_THIS, mission.client.name)
			local amount = Game.player:RemoveEquip(mission.cargotype, mission.amount, "cargo")
			if amount < mission.amount then
				player:AddMoney((amount - mission.amount) * mission.cargotype.price * 10) -- pay x10 the missing
				Comms.ImportantMessage(l.I_HAVE_DEBITED_YOUR_ACCOUNT, mission.client.name)
			end
			mission:Remove()
			missions[ref] = nil
		end
	end
	switchEvents()
end


	local loaded_data
local onGameStart = function ()
	if loaded_data then
		ads = {}
		missions = {}
		custom_cargo = {}
		custom_cargo_weight_sum = 0

		for k,ad in pairs(loaded_data.ads) do
			local ref = ad.station:AddAdvert({
				description = ad.desc,
				icon        = ad.risk > 0 and "cargorun_danger" or "cargorun",
				onChat      = onChat,
				onDelete    = onDelete,
				isEnabled   = isEnabled })
			ads[ref] = ad
		end
		missions                = loaded_data.missions
		custom_cargo            = loaded_data.custom_cargo
		custom_cargo_weight_sum = loaded_data.custom_cargo_weight_sum
		hostilactive            = loaded_data.hostilactive or false
		way_trip                = loaded_data.way_trip
		return_trip             = loaded_data.return_trip
		switchEvents()
		loaded_data = nil
	end
end


local onClick = function (mission)

	local dist_txt = _distTxt(mission.location)

	local setTargetButton = SLButton.New(lm.SET_TARGET, 'NORMAL')
	setTargetButton.button.onClick:Connect(function ()
		if not NavAssist then MsgBox.Message(lm.NOT_NAV_ASSIST) return end
		if Game.system.path ~= mission.location:GetStarSystem().path then
			Game.player:SetHyperspaceTarget(mission.location:GetStarSystem().path)
		else
			Game.player:SetNavTarget(Space.GetBody(mission.location.bodyIndex))
		end
	end)

	local danger

	if mission.localdelivery then
		danger = l.RISK_1
	else
		local branch
		if mission.wholesaler then branch = "WHOLESALER" else branch = mission.branch end
		danger = (l["RISK_" .. branch .. "_" .. mission.risk + 1])
			or (l["RISK_" .. mission.risk + 1])
	end

	if not mission.pickup then
		return
							ui:Grid({68,32},1)
							:SetColumn(0,{ui:VBox(10)
							:PackEnd({ui:MultiLineText((mission.introtext)
										:interp({name = mission.client.name,
											cargoname = mission.cargotype:GetName(),
											starport  = mission.location:GetSystemBody().name,
											system    = mission.location:GetStarSystem().name,
											sectorx   = mission.location.sectorX,
											sectory   = mission.location.sectorY,
											sectorz   = mission.location.sectorZ,
											cash      = showCurrency(mission.reward),
											dist      = dist_txt
											})
										),
										ui:Margin(5),
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
													ui:Label(l.CARGO)
												})
											})
											:SetColumn(1, {
												ui:VBox():PackEnd({
													ui:Label(mission.cargotype:GetName())
												})
											}),
										ui:Grid(2,1)
											:SetColumn(0, {
												ui:VBox():PackEnd({
													ui:Label(l.AMOUNT)
												})
											})
											:SetColumn(1, {
												ui:VBox():PackEnd({
													ui:Label(mission.amount.."t")
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
		})})
		:SetColumn(1, {
			ui:VBox(10):PackEnd(InfoFace.New(mission.client))
		})
	else-- mission.pickup

		if mission.cargo_picked_up then
			pickLabel=ui:Label(l.PICKED_UP_IN):SetColor({ r = 1.0, g = 1.0, b = 0.2 }) -- yellow
		else
			pickLabel=ui:Label(l.PICKUP_FROM):SetColor({ r = 0.0, g = 1.0, b = 0.2 }) -- green
		end

		return
							ui:Grid({68,32},1)
								:SetColumn(0,{ui:VBox(10)
								:PackEnd({ui:MultiLineText((mission.introtext)
								:interp({name = mission.client.name,

									cargoname = mission.cargotype:GetName(),
									starport  = mission.way_trip:GetSystemBody().name,
									system    = mission.way_trip:GetStarSystem().name,
									sectorx   = mission.way_trip.sectorX,
									sectory   = mission.way_trip.sectorY,
									sectorz   = mission.way_trip.sectorZ,

									dom_starport = mission.return_trip:GetSystemBody().name,
									dom_system   = mission.return_trip:GetStarSystem().name,
									dom_sectorx  = mission.return_trip.sectorX,
									dom_sectory  = mission.return_trip.sectorY,
									dom_sectorz  = mission.return_trip.sectorZ,
									cash         = showCurrency(mission.reward),
									dist         = dist_txt})
										),
										ui:Margin(10),
										ui:Grid(1,1)
											:SetColumn(0, {
												ui:VBox():PackEnd({
													pickLabel
												})
											}),
										ui:Grid(2,1)
											:SetColumn(0, {
												ui:VBox():PackEnd({
													ui:Label(l.SPACEPORT)
												})
											})
											:SetColumn(1, {
												ui:VBox():PackEnd({
													ui:MultiLineText(mission.way_trip:GetSystemBody().name)
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
													ui:MultiLineText(mission.way_trip:GetStarSystem().name
														.." ("..mission.way_trip.sectorX
														..","..mission.way_trip.sectorY
														..","..mission.way_trip.sectorZ..")")
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
													_distTxt(mission.way_trip)
												})
											}),
										ui:Grid(1,1)
											:SetColumn(0, {
												ui:VBox():PackEnd({
												ui:Label(l.DELIVER_TO):SetColor({ r = 0.0, g = 1.0, b = 0.2 }) -- green
												})
											}),
										ui:Grid(2,1)
											:SetColumn(0, {
												ui:VBox():PackEnd({
													ui:Label(l.SPACEPORT)
												})
											})
											:SetColumn(1, {
												ui:VBox():PackEnd({
													ui:MultiLineText(mission.return_trip:GetSystemBody().name)
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
													ui:MultiLineText(mission.return_trip:GetStarSystem().name
														.." ("..mission.return_trip.sectorX
														..","..mission.return_trip.sectorY
														..","..mission.return_trip.sectorZ..")")
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
													_distTxt(mission.return_trip),
													"",
													setTargetButton.widget
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
													ui:Label(l.CARGO)
												})
											})
											:SetColumn(1, {
												ui:VBox():PackEnd({
													ui:Label(mission.cargotype:GetName())
												})
											}),
										ui:Grid(2,1)
											:SetColumn(0, {
												ui:VBox():PackEnd({
													ui:Label(l.AMOUNT)
												})
											})
											:SetColumn(1, {
												ui:VBox():PackEnd({
													ui:Label(mission.amount.." t")
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
		})})
		:SetColumn(1, {
			ui:VBox(10):PackEnd(InfoFace.New(mission.client))
		})
	end
end

local onEnterSystem = function (ship)
	if not ship:IsPlayer() or not switchEvents() then return end
end

local serialize = function ()
	return {
					ads                     = ads,
					missions                = missions,
					custom_cargo            = custom_cargo,
					custom_cargo_weight_sum = custom_cargo_weight_sum,
					hostilactive            = hostilactive
				}
end

local unserialize = function (data)
	loaded_data = data
end

switchEvents = function()
	local status = false
--print("CargoRun Events deactivated")
	Event.Deregister("onFrameChanged", onFrameChanged)
	Event.Deregister("onShipDocked", onShipDocked)
--	Event.Deregister("onShipLanded", onShipLanded)
	for ref,mission in pairs(missions) do
		if mission.location:IsSameSystem(Game.system.path) then
--print("CargoRun Events activate")
			Event.Register("onFrameChanged", onFrameChanged)
			Event.Register("onShipDocked", onShipDocked)
--			Event.Register("onShipLanded", onShipLanded)
			status = true
		end
	end
	return status
end

Event.Register("onCreateBB", onCreateBB)
Event.Register("onUpdateBB", onUpdateBB)
Event.Register("onEnterSystem", onEnterSystem)
Event.Register("onGameStart", onGameStart)

Mission.RegisterType('CargoRun',l.CARGORUN,onClick)

Serializer:Register("CargoRun", serialize, unserialize)
