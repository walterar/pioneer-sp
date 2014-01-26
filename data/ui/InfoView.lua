-- Copyright © 2008-2013 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt

local Engine = import("Engine")
local Event  = import("Event")
local Lang   = import("Lang")

local TabGroup = import("ui/TabGroup")

local shipInfo        = import("InfoView/ShipInfo")
local personalInfo    = import("InfoView/PersonalInfo")
local econTrade       = import("InfoView/EconTrade")
local missions        = import("InfoView/Missions")
local crewRoster      = import("InfoView/CrewRoster")
local orbitalAnalysis = import("InfoView/OrbitalAnalysis")

local ui = Engine.ui
local l = Lang.GetResource("ui-core");

local tabGroup
ui.templates.InfoView = function (args)
	if tabGroup then
		tabGroup:SwitchFirst()
		return tabGroup.widget
	end

	tabGroup = TabGroup.New()

	tabGroup:AddTab({ id = "missions",        title = l.MISSIONS,             icon = "Eye",        template = missions,        })
	tabGroup:AddTab({ id = "econTrade",       title = l.ECONOMY_TRADE,        icon = "CreditCard", template = econTrade,       })
	tabGroup:AddTab({ id = "shipInfo",        title = l.SHIP_INFORMATION,     icon = "Info",       template = shipInfo         })
	tabGroup:AddTab({ id = "personalInfo",    title = l.PERSONAL_INFORMATION, icon = "User",       template = personalInfo     })
	tabGroup:AddTab({ id = "crew",            title = l.CREW_ROSTER,          icon = "Agenda",     template = crewRoster,      })
	tabGroup:AddTab({ id = "orbitalAnalysis", title = l.ORBITAL_ANALYSIS,     icon = "Planet",     template = orbitalAnalysis, })

	return tabGroup.widget
end

Event.Register("onGameEnd", function ()
	tabGroup = nil
end)
