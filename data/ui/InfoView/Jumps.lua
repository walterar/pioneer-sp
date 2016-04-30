-- Jumps.lua for Pioneer Scout+ (c)2012-2016 by walterar <walterar2@gmail.com>
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt
-- Work in progress.

local Lang      = import("Lang")
local Engine    = import("Engine")
local Game      = import("Game")
local Format    = import("Format")
local Character = import("Character")
local Space     = import("Space")
local Music     = import("Music")

local SmallLabeledButton = import("ui/SmallLabeledButton")
local SmartTable         = import("ui/SmartTable")

local ui = Engine.ui

local l  = Lang.GetResource("ui-core") or Lang.GetResource("ui-core","en")
local lm = Lang.GetResource("miscellaneous") or Lang.GetResource("miscellaneous","en")
local lh = Lang.GetResource("tracingjumps") or Lang.GetResource("tracingjumps","en")

local AU = 149597870700

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

-- we keep JumpsList to remember players preferences
-- (now it is column he wants to sort by)
local JumpsList
local jumps = function (tabGroup)
	-- This jump screen
	local JumpsScreen = ui:Expand()

	for i,v in pairs(Character.persistent.player.hjumps) do--< check and remove overdue
		if Game.time > v.due then
			table.remove(Character.persistent.player.hjumps,i)
		end
	end
	if #Character.persistent.player.hjumps == 0 then
		return JumpsScreen:SetInnerWidget( ui:Label(lh.NOT_JUMPS) )
	end

	local rowspec = {3,10,11,10,5,3,7} -- 7 columns
	if JumpsList then
		JumpsList:Clear()
	else
		JumpsList = SmartTable.New(rowspec)
	end

	-- setup headers
	local headers =
	{
		lh.SHIP_LABEL,
		lh.SHIP_NAME,
		lh.JUMPED_TO,
		lh.ARRIVAL_DATE,
		lh.GUNS,
		lh.SHIELDS,
	}
	JumpsList:SetHeaders(headers)

	-- we're not happy with default sort function so we specify one by ourselves
	local sortJumps = function (misList)
		local col = misList.sortCol
		local cmpByReward = function (a,b)
			return a.data[col] >= b.data[col]
		end
		local comparators =
		{ -- by column num
			[5] = cmpByReward,
		}
		misList:defaultSortFunction(comparators[col])
	end
	JumpsList:SetSortFunction(sortJumps)

	for ref,jump in pairs(Character.persistent.player.hjumps) do
		-- Format the location
		local jumpLocationName = string.format('%s\n[%d,%d,%d]',
						jump.location:GetStarSystem().name,
						jump.location.sectorX,jump.location.sectorY,jump.location.sectorZ)

		-- Format the distance or position label
		local distLabel
		local dist = Game.system and Game.system:DistanceTo(jump.location) or 0

		if Game.system then-- mi chequeo de hiperespacio favorito
			if dist == 0 then
				dist = Game.player:DistanceTo(Space.GetBody(jump.location.bodyIndex))/AU
				if dist < 0.01 then
					dist =  Game.player:DistanceTo(Space.GetBody(jump.location.bodyIndex))/1000
					distLabel = ui:Label(string.format('%.2f %s', dist, lm.KM))
					distLabel:SetColor({ r = 0.0, g = 1.0, b = 0.2 }) -- green
				else
					distLabel = ui:Label(lh.IN_SITE)
					distLabel:SetColor({ r = 1.0, g = 1.0, b = 0.2 }) -- yellow
				end
			else
				distLabel = ui:Label(string.format('%.2f %s', dist, lm.LY))
				if Game.player:GetHyperspaceDetails(jump.location) == 'OK' then
					distLabel:SetColor({ r = 0.0, g = 1.0, b = 0.2 }) -- green
				else
					distLabel:SetColor({ r = 1.0, g = 0.0, b = 0.0 }) -- red
				end
			end
		else
			distLabel = ui:Label(lm.HYPERSPACE):SetColor({ r = 1.0, g = 0.0, b = 0.0 }) -- red
		end

		-- Pack location and distance
		local locationBox = ui:VBox(2):PackEnd(ui:MultiLineText(jumpLocationName))
									:PackEnd(distLabel)

		-- Format Due info
		local dueLabel = ui:Label(Format.Date(jump.due))
		local days = math.max(0, (jump.due - Game.time) / (24*60*60))
		local daysLabel = ui:Label(string.format(l.D_DAYS_LEFT, days)):SetColor({ r = 1.0, g = 0.0, b = 1.0 }) -- purple
		local dueBox = ui:VBox(2):PackEnd(dueLabel):PackEnd(daysLabel)

		local moreButton = SmallLabeledButton.New(lh.SET_ROUTE)


		moreButton.button.onClick:Connect(function ()
			Music.Play("music/core/fx/Ok", false)
			Game.player:SetHyperspaceTarget(jump.location:GetStarSystem().path)
		end)

		local row =
		{ {data = jump.label},
			{data = jump.model},
			{data = dist, widget = locationBox},
			{data = jump.due, widget = dueBox},
			{data = jump.guns},
			{data = jump.shields},
			{widget = moreButton.widget}
		}
		JumpsList:AddRow(row)
	end

	JumpsScreen:SetInnerWidget(JumpsList)

	return JumpsScreen
end

return jumps
