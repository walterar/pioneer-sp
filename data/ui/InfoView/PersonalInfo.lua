-- Copyright © 2008-2016 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt
-- modified for Pioneer Scout+ (c)2012-2015 by walterar <walterar2@gmail.com>
-- Work in progress.

local Lang               = import("Lang")
local Engine             = import("Engine")
local Character          = import("Character")
local Game               = import("Game")
local InfoFace           = import("ui/InfoFace")
local SmallLabeledButton = import("ui/SmallLabeledButton")

local ui = Engine.ui
local l  = Lang.GetResource("ui-core") or Lang.GetResource("ui-core","en")
local le = Lang.GetResource("module-explore") or Lang.GetResource("module-explore","en")
local ls = Lang.GetResource("miscellaneous") or Lang.GetResource("miscellaneous","en")

local personalInfo = function ()

	local CurrentPosition
	local CurrentFaction
	local StationName

	local CurrentDanger
	if DangerLevel == 0 then
		CurrentDanger = ui:Label(ls.RISK_AREA)
											:SetFont("HEADING_LARGE")
											:SetColor({ r = 0.0, g = 1.0, b = 0.0 }) -- green
	elseif DangerLevel == 1 then
		CurrentDanger = ui:Label(ls.RISK_AREA.." *")
											:SetFont("HEADING_LARGE")
											:SetColor({ r = 1.0, g = 1.0, b = 0.0 }) -- yellow
	elseif DangerLevel == 2 then
		CurrentDanger = ui:Label(ls.RISK_AREA.." **")
											:SetFont("HEADING_LARGE")
											:SetColor({ r = 1.0, g = 0.0, b = 0.0 }) -- red
	end

	if Game.system == nil then
		CurrentPosition = ls.HYPERSPACE
		CurrentFaction  = ls.HYPERSPACE
	else
		if Game.player.flightState == "DOCKED" then
			StationName = Game.player:GetDockedWith().label..", "
		else
			if Game.player.flightState == "LANDED" then
				StationName = ls.LANDED_IN..Game.player.frameBody.label..", "
			else
				StationName = ls.IN_SPACE_OF
			end
		end
		CurrentPosition = StationName
							..Game.system.name.." ("
							..Game.system.path.sectorX..","
							..Game.system.path.sectorY..","
							..Game.system.path.sectorZ..")"
		CurrentFaction = Game.system.faction.name
	end

	local player = Character.persistent.player
	local faceFlags = { player.female and "FEMALE" or "MALE" }

	-- for updating the caption
	local faceWidget = InfoFace.New(player)
	-- for updating the entire face
	local faceWidgetContainer = ui:Margin(0, "ALL", faceWidget)

	local nameEntry = ui:TextEntry(player.name):SetFont("HEADING_LARGE")
	nameEntry.onChange:Connect(function (newName)
		player.name = newName
		faceWidget:UpdateInfo(player)
	end )

	local genderToggle = SmallLabeledButton.New(l.TOGGLE_MALE_FEMALE)
	genderToggle.button.onClick:Connect(function ()
		player.female = not player.female
		faceWidget = InfoFace.New(player)
		faceWidgetContainer:SetInnerWidget(faceWidget.widget)
	end)

	local generateFaceButton = SmallLabeledButton.New(l.MAKE_NEW_FACE)
	generateFaceButton.button.onClick:Connect(function ()
		player.seed = Engine.rand:Integer()
		faceWidget = InfoFace.New(player)
		faceWidgetContainer:SetInnerWidget(faceWidget.widget)
	end)

	return
		ui:Grid({48,4,48},1)
			:SetColumn(0, {
				ui:Table():AddRows({
					ui:Label(ls.EXPERIENCE):SetFont("HEADING_NORMAL"):SetColor({ r = 0.8, g = 1.0, b = 0.4 }),
					ui:Table():SetColumnSpacing(10):AddRows({
						{ le.EXPLORED_SYSTEMS, (explored_count)},
						{ ls.SUCCESSFUL_MISSIONS, (MissionsSuccesses or 0)},
						{ ls.FAILED_MISSIONS, (MissionsFailures or 0)},
					"",
						{ l.RATING, player:GetCombatRating() },
						{ ls.SHOTS_SUCCESSFUL, (ShotsSuccessful or 0)},
						{ ls.SHOTS_RECEIVED, (ShotsReceived or 0)},
						{ l.KILLS,  string.format('%d',player.killcount) },
					}),
					"",
					ui:Label(l.MILITARY):SetFont("HEADING_NORMAL"):SetColor({ r = 0.8, g = 1.0, b = 0.4 }),
					ui:Table():SetColumnSpacing(10):AddRows({
						{ ls.ORIGIN, OriginFaction },
						{ l.ALLEGIANCE, ShipFaction },
						{ ls.REGISTRATION, Game.player.label },
					}),
					"",
					ui:Label(l.NAVIGATION):SetFont("HEADING_NORMAL"):SetColor({ r = 0.8, g = 1.0, b = 0.4 }),
					ui:Table():SetColumnSpacing(10):AddRows({
						{ ls.PREVIOUS_POSITION, PrevPos },
						{ ls.PREVIOUS_FACTION, PrevFac },
						{ ls.CURRENT_POSITION, CurrentPosition},
						{ ls.CURRENT_FACTION, CurrentFaction },
					}),
					"",
					ui:Label(ls.DAMAGE_REPORT):SetFont("HEADING_NORMAL"):SetColor({ r = 0.8, g = 1.0, b = 0.4 }),
					ui:Table():SetColumnSpacing(10):AddRows({--return string.format("%.f %%", z);
						{ l.HULL_INTEGRITY..": "..string.format("%.1f %%",Game.player.hullPercent) },
					damageControl,
					CurrentDanger,
					})
				})
			})
			:SetColumn(2, {
				ui:VBox(10)
					:PackEnd(ui:HBox(10):PackEnd({
						ui:VBox(5):PackEnd({
							ui:Expand("HORIZONTAL", nameEntry),
						}),
						ui:VBox(5):PackEnd({
							genderToggle,
							generateFaceButton,
						})
					}))
					:PackEnd(ui:Expand("BOTH", faceWidgetContainer))
			})
end

return personalInfo
