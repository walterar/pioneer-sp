-- Copyright © 2008-2015 Pioneer Developers. Author: Karl F (https://github.com/impaktor)
-- Modified by Walter Arnolfo <walterar2@gmail.com> for Pioneer Scout Plus
-- Licensed under the terms of the GPL v3. See http://en.wikipedia.org/wiki/GNU_General_Public_License


local Lang = import("Lang")

local l   = Lang.GetResource("ui-core") or Lang.GetResource("ui-core","en")
local myl = Lang.GetResource("module-myl") or Lang.GetResource("module-myl","en")

--
-- Namespace: Laws
--
--
-- Laws: CrimeType
--
-- Different types of crimes and law offences
--
-- DUMPING - jettison of hazardous rubble/waste too close to station
-- MURDER - destruction of ship too close to station
-- PIRACY - fired or crash on ship too close to station
-- TRADING_ILLEGAL_GOODS - attempted to sell illegal goods
-- UNLAWFUL_WEAPONS_DISCHARGE - shooting weapons too close to station without being attacked
-- ENVIRONMENTAL_DAMAGE - jettison of radioactive products in space inhabited systems
-- ABDUCTION - do not carrying passengers to the station agreed
-- FRAUD - do not deliver package or message to the station agreed
-- ESPIONAGE - carry data to another faction
-- ESCAPE - manual take-off to evade fines
-- ILLEGAL_JUMP - jump into hyperspace less than 5Km from the station
--
-- Availability:
--
--   2015 Feb
--
-- Status:
--
--   experimental
--

local Laws = {}
Laws.CrimeType = {}

Laws.CrimeType["MURDER"]                     = {basefine = 10000, name =   l.MURDER}
Laws.CrimeType["ENVIRONMENTAL_DAMAGE"]       = {basefine =  8500, name = myl.ENVIRONMENTAL_DAMAGE}
Laws.CrimeType["ESPIONAGE"]                  = {basefine =  8000, name = myl.ESPIONAGE}
Laws.CrimeType["ABDUCTION"]                  = {basefine =  5000, name = myl.ABDUCTION}
Laws.CrimeType["FRAUD"]                      = {basefine =  3500, name = myl.FRAUD}
Laws.CrimeType["TRADING_ILLEGAL_GOODS"]      = {basefine =  3000, name =   l.TRADING_ILLEGAL_GOODS}
Laws.CrimeType["ESCAPE"]                     = {basefine =  2800, name = myl.ESCAPE}
Laws.CrimeType["PIRACY"]                     = {basefine =  2500, name =   l.PIRACY}
Laws.CrimeType["ILLEGAL_JUMP"]               = {basefine =  2200, name = myl.ILLEGAL_JUMP}
Laws.CrimeType["DUMPING"]                    = {basefine =  1000, name =   l.DUMPING}
Laws.CrimeType["UNLAWFUL_WEAPONS_DISCHARGE"] = {basefine =   200, name =   l.UNLAWFUL_WEAPONS_DISCHARGE}


return Laws
