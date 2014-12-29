-- Copyright © 2008-2014 Pioneer Developers. See AUTHORS.txt for details
-- Modified by Walter Arnolfo <walterar2@gmail.com> for Pioneer Scout Plus
-- Licensed under the terms of the GPL v3. See http://en.wikipedia.org/wiki/GNU_General_Public_License


local Lang = import("Lang")
local    l = Lang.GetResource("ui-core") or Lang.GetResource("ui-core.en")
local  myl = Lang.GetResource("module-myl") or Lang.GetResource("module-myl.en")

--
-- Namespace: Constants
--
--
-- Constants: CrimeType
--
-- Different types of crimes and law offences
--
-- DUMPING - jettison of hazardous rubble/waste
-- MURDER - destruction of ship
-- PIRACY - fired or crash on ship
-- TRADING_ILLEGAL_GOODS - attempted to sell illegal goods
-- UNLAWFUL_WEAPONS_DISCHARGE - weapons discharged too close to station
-- ENVIRONMENTAL_DAMAGE
-- ABDUCTION -
-- FRAUD -
-- ESPIONAGE -
-- ESCAPE -
-- ILLEGAL_JUMP -
--
-- Availability:
--
--   2014 May
--
-- Status:
--
--   experimental
--

local Constant = {}
Constant.CrimeType = {}

Constant.CrimeType["MURDER"]                     = {basefine = 10000, name =   l.MURDER}
Constant.CrimeType["PIRACY"]                     = {basefine =  9500, name =   l.PIRACY}
Constant.CrimeType["ENVIRONMENTAL_DAMAGE"]       = {basefine =  8500, name = myl.ENVIRONMENTAL_DAMAGE}
Constant.CrimeType["ESPIONAGE"]                  = {basefine =  8000, name = myl.ESPIONAGE}
Constant.CrimeType["ABDUCTION"]                  = {basefine =  5000, name = myl.ABDUCTION}
Constant.CrimeType["FRAUD"]                      = {basefine =  3500, name = myl.FRAUD}
Constant.CrimeType["TRADING_ILLEGAL_GOODS"]      = {basefine =  3000, name =   l.TRADING_ILLEGAL_GOODS}
Constant.CrimeType["ESCAPE"]                     = {basefine =  2800, name = myl.ESCAPE}
Constant.CrimeType["ILLEGAL_JUMP"]               = {basefine =  2200, name = myl.ILLEGAL_JUMP}
Constant.CrimeType["UNLAWFUL_WEAPONS_DISCHARGE"] = {basefine =  1900, name =   l.UNLAWFUL_WEAPONS_DISCHARGE}
Constant.CrimeType["DUMPING"]                    = {basefine =  1000, name =   l.DUMPING}


return Constant
