-- Copyright © 2008-2016 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt

local Player     = import_core("Player")
local Serializer = import("Serializer")
local Event      = import("Event")
local Game       = import("Game")
local Faction    = import("Faction")
local utils      = import("utils")

--local Format     = import("Format")

-- TODO: save load with serializer.
Player.record = {}

--
-- Method: AddCrime
--
-- Add a crime to the player's criminal record
--
-- > Game.player:AddCrime(crime, fine, faction)
--
-- Parameters:
--
--   crime - a string constant describing the crime
--
--   fine - an amount to add to the player's fine
--
--   faction - optional argument, defaults to the system the player is in
--
--
-- Availability:
--
--   2014 December
--
-- Status:
--
--   experimental
--
function Player:AddCrime (crime, addFine, faction)
	local forFaction = (faction and faction.id) or Game.system.faction.id

	-- first time for this faction
	if not self.record[forFaction] then
		self.record[forFaction] = {}
		self.record[forFaction].listcrimes = {}
		self.record[forFaction].totalfine = 0
	end

	-- if first time for this crime type
	if not self.record[forFaction].listcrimes[crime] then
		self.record[forFaction].listcrimes[crime] = {}

--		self.record[forFaction].listcrimes[crime].date = 0--XXX

		self.record[forFaction].listcrimes[crime].fine = 0
		self.record[forFaction].listcrimes[crime].count = 0
	end

--	self.record[forFaction].listcrimes[crime].date = Game.time --XXX

	self.record[forFaction].listcrimes[crime].fine =
		self.record[forFaction].listcrimes[crime].fine + addFine
	self.record[forFaction].listcrimes[crime].count =
		self.record[forFaction].listcrimes[crime].count +1
	self.record[forFaction].totalfine =
		self.record[forFaction].totalfine + addFine

	-- todo: could have systemPath as faction for independent?
end

--
-- Method: GetCrime
--
-- Get criminal record and total fine for player for faction
--
-- > criminalrecord, totalFine = Game.player:GetCrime(faction)
--
-- Parameters:
--
--   faction - optional argument, defaults to the system the player is in
--
-- Return:
--
--   criminalRecord - a table with count and fine for each crime committed
--
--   totalFine - the total fine of the player in faction
--
--
-- Availability:
--
--   2015 September
--
-- Status:
--
--   experimental
--
function Player:GetCrime (faction)
	local forFaction = (faction and faction.id) or Game.system.faction.id

	-- return crime record and total fine for faction
	local listOfCrime, totalFine

	if Game.player.flightState == "HYPERSPACE" then
		-- no crime in hyperspace
		listOfCrime = {}
		totalFine = 0
	elseif not self.record[forFaction] then
		-- first time for this faction, clean record
		listOfCrime = {}
		totalFine = 0
	else
		listOfCrime = self.record[forFaction].listcrimes
		totalFine = self.record[forFaction].totalfine
	end

	return listOfCrime, totalFine
end


function Player:CriminalRecord (faction)
	local forFaction = (faction and faction.id) or Game.system.faction.id
	local crimes, fine = Game.player:GetCrime()
	local result = false
	if #utils.build_array(pairs(crimes)) > 0 then
		result = true
	end
	return result
end


function Player:ClearCriminalRecord (faction)
	local forFaction = (faction and faction.id) or Game.system.faction.id

	if self.record[forFaction] then
		self.record[forFaction] = {}
		self.record[forFaction].listcrimes = {}
		self.record[forFaction].totalfine = 0
	end

	-- TODO
end

function Player:PayCrimeFine (faction)
	local forFaction = (faction and faction.id) or Game.system.faction.id

	if self.record[forFaction] then
		self.record[forFaction].totalfine = 0
	end

	-- TODO
end


--
-- Method: GetMoney
--
-- Get the player's current money
--
-- > money = player:GetMoney()
--
-- Return:
--
--   money - the player's money, in dollars
--
-- Availability:
--
--   alpha 10
--
-- Status:
--
--   experimental
--
function Player:GetMoney ()
	return self.cash
end

--
-- Method: SetMoney
--
-- Set the player's money
--
-- > player:SetMoney(money)
--
-- Parameters:
--
--   money - the new amount of money, in dollars
--
-- Availability:
--
--   alpha 10
--
-- Status:
--
--   experimental
--
function Player:SetMoney (m)
	self:setprop("cash", m)
end

--
-- Method: AddMoney
--
-- Add an amount to the player's money
--
-- > money = player:AddMoney(change)
--
-- Parameters:
--
--   change - the amount of money to add to the player's money, in dollars
--
-- Return:
--
--   money - the player's new money, in dollars
--
-- Availability:
--
--   alpha 10
--
-- Status:
--
--   experimental
--
function Player:AddMoney (m)
	self:setprop("cash", self.cash + m)
end


local loaded_data

local onGameStart = function ()
	if (loaded_data) then
		Game.player:setprop("cash", loaded_data.cash)
		--		Player.record = loaded_data.record
		for faction, crimes in pairs(loaded_data.record) do
			-- NOTE: if not indexing on faction.name or faction.id -> Player tried to serialize unsoported 'Faction' userdata value
			Player.record = {}
			Player.record[faction] = {}
			Player.record[faction].totalfine = crimes.totalfine
			Player.record[faction].listcrimes = {}
			for crime, prop in pairs(crimes.listcrimes) do
				Player.record[faction].listcrimes[crime] = {}

--				Player.record[faction].listcrimes[crime].date = prop.date--XXX
				Player.record[faction].listcrimes[crime].fine = prop.fine

				Player.record[faction].listcrimes[crime].count = prop.count
			end
		end
		loaded_data = nil
	end
end

local serialize = function ()

	local data = {
		cash = Game.player.cash,
		record = {}
		-- record = Game.player.record  -- diff with Player.record and Game.player.record?
		-- also, when do we explicitly need to copy every element manually, and when not?
	}
	for factionkey,userdata in pairs(Player.record) do
		data.record[factionkey] = {}
		data.record[factionkey].totalfine = userdata.totalfine
		data.record[factionkey].listcrimes = {}
		for crimekey,crimes in pairs(userdata.listcrimes) do
			data.record[factionkey].listcrimes[crimekey] = {}
--			data.record[factionkey].listcrimes[crimekey].date = crimes.date--XXX
			data.record[factionkey].listcrimes[crimekey].fine = crimes.fine
			data.record[factionkey].listcrimes[crimekey].count = crimes.count
		end
	end

	return data
end


local unserialize = function (data)
	loaded_data = data
	Player.cash = data.cash

	for factionkey,userdata in pairs(data.record) do
		Player.record[factionkey] = {}
		Player.record[factionkey].totalfine = userdata.totalfine
		Player.record[factionkey].listcrimes = {}
		for crimekey,crimes in pairs(userdata.listcrimes) do
			Player.record[factionkey].listcrimes[crimekey] = {}
--			Player.record[factionkey].listcrimes[crimekey].date = crimes.date--XXX
			Player.record[factionkey].listcrimes[crimekey].fine = crimes.fine
			Player.record[factionkey].listcrimes[crimekey].count = crimes.count
		end
	end
end

local onGameEnd = function ()
	-- clean up for next game:
	Player.record = {}
end

Event.Register("onGameEnd", onGameEnd)
Event.Register("onGameStart", onGameStart)
Serializer:Register("Player", serialize, unserialize)

return Player
