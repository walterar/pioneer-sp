-- Copyright © 2008-2015 Pioneer Developers. See AUTHORS.txt for details
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
local l   = Lang.GetResource("ui-core") or Lang.GetResource("ui-core","en");
local myl = Lang.GetResource("module-myl") or Lang.GetResource("module-myl","en");

local personalInfo = function ()

	local CurrentPosition
	local CurrentFaction
	local StationName

	local CurrentDanger
	if DangerLevel == 0 then
		CurrentDanger = ui:Label(myl.Risk_Area)
											:SetFont("HEADING_LARGE")
											:SetColor({ r = 0.0, g = 1.0, b = 0.0 }) -- green
	elseif DangerLevel == 1 then
		CurrentDanger = ui:Label(myl.Risk_Area.." *")
											:SetFont("HEADING_LARGE")
											:SetColor({ r = 1.0, g = 1.0, b = 0.0 }) -- yellow
	elseif DangerLevel == 2 then
		CurrentDanger = ui:Label(myl.Risk_Area.." **")
											:SetFont("HEADING_LARGE")
											:SetColor({ r = 1.0, g = 0.0, b = 0.0 }) -- red
	end

	if Game.system == nil then
		CurrentPosition = myl.Hyperspace
		CurrentFaction  = myl.Hyperspace
	else
		if Game.player.flightState == "DOCKED" then
			StationName = Game.player:GetDockedWith().label..", "
		else
			if Game.player.flightState == "LANDED" then
				StationName = myl.Landed_in..Game.player.frameBody.label..", "
			else
				StationName = myl.In_space_of
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
					ui:Label(myl.Experience):SetFont("HEADING_NORMAL"):SetColor({ r = 0.8, g = 1.0, b = 0.4 }),
					ui:Table():SetColumnSpacing(10):AddRows({
						{ myl.Successful_Missions, (MissionsSuccesses or 0)},
						{ myl.Failed_Missions, (MissionsFailures or 0)},
					"",
						{ l.RATING, player:GetCombatRating() },
						{ myl.Shots_successful, (ShotsSuccessful or 0)},
						{ myl.Shots_received, (ShotsReceived or 0)},
						{ l.KILLS,  string.format('%d',player.killcount) },
					}),
					"",
					ui:Label(l.MILITARY):SetFont("HEADING_NORMAL"):SetColor({ r = 0.8, g = 1.0, b = 0.4 }),
					ui:Table():SetColumnSpacing(10):AddRows({
						{ myl.Origin, OriginFaction },
						{ l.ALLEGIANCE, ShipFaction },
						{ myl.Registration, Game.player.label },
					}),
					"",
					ui:Label(l.NAVIGATION):SetFont("HEADING_NORMAL"):SetColor({ r = 0.8, g = 1.0, b = 0.4 }),
					ui:Table():SetColumnSpacing(10):AddRows({
						{ myl.Previous_Position, PrevPos },
						{ myl.Previous_Faction, PrevFac },
						{ myl.Current_Position, CurrentPosition},
						{ myl.Current_Faction, CurrentFaction },
					}),
					"",
					ui:Label(myl.Damage_Report):SetFont("HEADING_NORMAL"):SetColor({ r = 0.8, g = 1.0, b = 0.4 }),
					ui:Table():SetColumnSpacing(10):AddRows({
						{ l.HULL_INTEGRITY..": ", showCurrency(Game.player.hullPercent,decimal, "%",neg_prefix) },
					"",
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
