-- Explored.lua for Pioneer Scout+ (c)2012-2016 by walterar <walterar2@gmail.com>
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt
-- Work in progress.

local Lang      = import("Lang")
local Engine    = import("Engine")
local Game      = import("Game")
local Format    = import("Format")
local Character = import("Character")
local Space     = import("Space")
local Music     = import("Music")
local Eq        = import("Equipment")

local SmallLabeledButton = import("ui/SmallLabeledButton")
local SmartTable         = import("ui/SmartTable")
local InfoFace           = import("ui/InfoFace")

local ui = Engine.ui

local l = Lang.GetResource("module-explore") or Lang.GetResource("module-explore","en")

local chief_of_reports = Character.New({title  = l.CHIEF_OF_REPORTS, armour = true})

-- we keep ExploredList to remember players preferences
-- (now it is column he wants to sort by)
local ExploredList
local explored = function (tabGroup)

	-- This explored screen
	local ExploredScreen = ui:Expand()

	if #explored_systems == 0 then
		return ExploredScreen:SetInnerWidget( ui:Label(l.NO_EXPLORED_SYSTEMS) )
	end

	local rowspec = {10,10,3,10,5,10} -- columns
	if ExploredList then
		ExploredList:Clear()
	else
		ExploredList = SmartTable.New(rowspec)
	end

	-- setup headers
	local headers =
	{
		l.SYSTEM2,
		l.SECTOR2,
		l.BODIES2,
--		l.BASES2,
		l.EXPLORED,
		l.DISTANCE,
--		l.REPORTED,
--		"",
		""
	}
	ExploredList:SetHeaders(headers)

	local sortExplored = function (misList)
		local col = misList.sortCol
		local cmpExplored = function (a,b)
			return a.data[col] <= b.data[col]
		end
		local comparators =
		{ -- by column num
			[4] = cmpExplored,
		}
		misList:defaultSortFunction(comparators[col])
	end
	ExploredList:SetSortFunction(sortExplored)

	for ref,explored in pairs(explored_systems) do

		local dist = Game.system and Game.system:DistanceTo(explored.system:GetStarSystem()) or 0
		local distLabel = Game.system and string.format("%.2f", dist).." "..l.LY or "??? "..l.LY

		local system_name = explored.system:GetStarSystem().name
		local reportButton = SmallLabeledButton.New(l.REPORT)
		local dateLabel = Format.Date(explored.date)

		reportButton.button.onClick:Connect(function ()
			if not Game.system
				or not Game.player:GetDockedWith()
			then return end
			local credits = Game.player:GetDockedWith():
							GetEquipmentPrice(Eq.cargo.hydrogen)*100*explored.bodies
			Music.Play("music/core/fx/Ok", false)
--			explored.reported = true
			table.remove (_G.explored_systems, ref)--XXX
			Game.player:AddMoney(credits)
			local creditsLabel = showCurrency(credits)

			return
				ExploredScreen:SetInnerWidget(
					ui:Grid({68,32},1)
						:SetColumn(0,{
--						ui:VBox():PackEnd({ui:Label(rep)}),
--						ui:Margin(5),
							ui:VBox(10)
								:PackEnd({
									ui:Label(l.TITLE):SetFont("HEADING_LARGE"):SetColor({ r = 0.0, g = 1.0, b = 0.0 }),
									ui:Margin(10),
									ui:MultiLineText((l.TEXTO1):interp({
										name     = chief_of_reports.name,
										starport = Game.player:GetDockedWith().label,
										system   = Game.system.name,
										faction  = Game.system.faction.name})
										),
							ui:Margin(10),
							ui:Grid(2,1)
								:SetColumn(0, {ui:VBox():PackEnd({ui:Label(l.NEW_SYSTEM)})})
								:SetColumn(1, {ui:VBox():PackEnd({ui:Label(system_name)})}),
							ui:Grid(2,1)
								:SetColumn(0, {ui:VBox():PackEnd({ui:Label(l.SECTOR_LABEL)})})
								:SetColumn(1, {ui:VBox():PackEnd({ui:MultiLineText(
									" ( "..explored.system.sectorX
									..","..explored.system.sectorY
									..","..explored.system.sectorZ
									.." )")})
								}),
							ui:Grid(2,1)
								:SetColumn(0, {ui:VBox():PackEnd({ui:Label(l.BODIES_LABEL)})})
								:SetColumn(1, {ui:VBox():PackEnd({ui:Label(explored.bodies)})
								}),
--							ui:Grid(2,1)
--								:SetColumn(0, {ui:VBox():PackEnd({ui:Label(BASES_LABEL)})})
--								:SetColumn(1, {ui:VBox():PackEnd({ui:Label(explored.bodies)})
--								}),
							ui:Grid(2,1)
								:SetColumn(0, {ui:VBox():PackEnd({ui:Label(l.DISTANCE_LABEL)})})
								:SetColumn(1, {ui:VBox():PackEnd({ui:Label(distLabel)})
								}),
							ui:Margin(10),
							ui:Grid(2,1)
								:SetColumn(0, {ui:VBox():PackEnd({ui:Label(l.REWARD_LABEL)})})
								:SetColumn(1, {ui:VBox():PackEnd({ui:Label(creditsLabel)})
								})
							})})
						:SetColumn(1, {
							ui:VBox(10):PackEnd(InfoFace.New(chief_of_reports))
				}))
		end)

--		local report = explored.reported
--		local xwidget = reportButton.widget
--		if report then
--			report = l.YES
--			xwidget=l.REPORTED
--		else
--			report = l.NO
--		end

		local dateBox = ui:VBox(1):PackEnd(dateLabel)
		local distBox = ui:VBox(1):PackEnd(distLabel)

		local row =
		{ {data = system_name},
			{data = "< "..explored.system.sectorX..","..
										explored.system.sectorY..","..
										explored.system.sectorZ.." >"},
			{data = explored.bodies},
			{data = explored.date,widget = dateBox},
			{data = dist,widget = distBox},
--			{data = report},
			{widget = reportButton.widget}-- xwidget}
		}
		ExploredList:AddRow(row)
	end

	ExploredScreen:SetInnerWidget(ExploredList)

	return ExploredScreen
end

return explored
