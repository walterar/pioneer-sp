-- Copyright © 2008-2015 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt
-- modified for Pioneer Scout+ (c)2012-2015 by walterar <walterar2@gmail.com>
-- Work in progress.

local Character    = import("Character")
local Engine       = import("Engine")
local Lang         = import("Lang")
local Game         = import("Game")
local ShipDef      = import("ShipDef")
local Format       = import("Format")
local Rand         = import("Rand")

local InfoGauge    = import("ui/InfoGauge")
local InfoFace     = import("ui/InfoFace")
local ModelSpinner = import("UI.Game.ModelSpinner")


local Music        = import("Music")
local Timer        = import("Timer")

local l = Lang.GetResource("ui-core")
local ui = Engine.ui

local getRepairCost = function (percent, shipDef)
	-- repairing 1% hull damage costs 0.1% of ship price
	shipDef = shipDef or ShipDef[Game.player.shipId]
	return math.ceil(shipDef.basePrice * (percent * 0.1)) * 0.015--XXX
end

local getRepairMessage = function (damage, price)
	return string.interp(
		l.REPAIR_X_HULL_DAMAGE_FOR_X, {
			damage = string.format('%.1f', damage),
			price = showCurrency(price)
		})
end

local shipRepairs = function (args)
	local messageLabel   = ui:Label('')
	local feedbackLabel  = ui:Label('')
	local repairButtons  = ui:VBox(5)
	local repair1Label   = ui:Label('')
	local repairAllLabel = ui:Label('')
	local repair1Btn     = ui:Button(ui:Expand('HORIZONTAL', repair1Label))
	local repairAllBtn   = ui:Button(ui:Expand('HORIZONTAL', repairAllLabel))

	local integrityGauge = ui:Gauge()
	integrityGauge:Bind("valuePercent", Game.player, "hullPercent")

	local damageAll, damage1, costRepairAll, costRepair1

	local update = function (feedbackText)
		local shipDef     = ShipDef[Game.player.shipId]
		local hullPercent = Game.player.hullPercent

		if hullPercent > 99.9 then
			messageLabel:SetText(l.SHIP_IS_ALREADY_FULLY_REPAIRED)
			feedbackLabel:SetText(feedbackText)
			repairButtons:Clear()
		else
			damageAll = 100 - hullPercent
			damage1 = math.min(damageAll, 1)
			costRepair1 = getRepairCost(damage1, shipDef)
			costRepairAll = getRepairCost(damageAll, shipDef)

			messageLabel:SetText(string.interp(l.YOUR_HULL_IS_AT_X_INTEGRITY,
				{value = string.format('%.1f', hullPercent)}))
			feedbackLabel:SetText(feedbackText)

			repair1Label:SetText(getRepairMessage(damage1, costRepair1))
			repairAllLabel:SetText(getRepairMessage(damageAll, costRepairAll))

			repairButtons:Clear()
			repairButtons:PackEnd(repair1Btn)
			if damageAll > damage1 then
				repairButtons:PackEnd(repairAllBtn)
			end
		end
	end

		local in_progress_repair = false
	local tryRepair = function (damage, price)
		if in_progress_repair or Game.paused then return end
		if Game.player:GetMoney() >= price then
			in_progress_repair = true
			local song
			if Music.IsPlaying then song = Music.GetSongName() end
			Music.Play("music/core/fx/repair", false)
			Timer:CallAt(Game.time + 10, function ()
				Music.Stop()
				if song then Music.Play(song, false) end
				in_progress_repair = false
				Game.player:AddMoney(-price)
				update('')
			end)
			local x = damage/10
			local i = 10
			local h
			Timer:CallEvery(1, function ()
				h = Game.player.hullPercent + x
				if h > 100 then h = 100 end
				Game.player:SetHullPercent(h)
				i=i-1
				if i < 1 then
					update('')
					return true
				end
			end)
		else
			update(l.YOU_DONT_HAVE_ENOUGH_MONEY_FOR_THAT_OPTION)
		end
	end

	repair1Btn.onClick:Connect(function () tryRepair(damage1, costRepair1); end)
	repairAllBtn.onClick:Connect(function () tryRepair(damageAll, costRepairAll); end)

	-- initialise UI state
	update('')

	-- XXX need a better way of seeding this
	local station = Game.player:GetDockedWith()
	local rand = Rand.New(util.hash_random(station.seed .. '-repair-guy', 2^31-1) - 1)
	local face = InfoFace.New(Character.New({ title = l.CHIEF_MECHANIC }, rand))

	return
		ui:Grid({48,4,48},1)
			:SetColumn(0, {
				ui:VBox(5):PackEnd({
					messageLabel,
					repairButtons,
					feedbackLabel,
					ui:Expand("VERTICAL"),
					ui:HBox(5):PackEnd({
						ui:Label(l.HULL_INTEGRITY),
						integrityGauge,
					})
				})
			})
			:SetColumn(2, {
				face
			})

end

return shipRepairs
