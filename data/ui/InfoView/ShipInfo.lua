-- Copyright © 2008-2016 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt
-- modified for Pioneer Scout+ (c)2012-2015 by walterar <walterar2@gmail.com>
-- Work in progress.

local Engine    = import("Engine")
local Lang      = import("Lang")
local Game      = import("Game")
local Equip     = import("Equipment")
local ShipDef   = import("ShipDef")

local ModelSpinner = import("UI.Game.ModelSpinner")

local ui = Engine.ui

local l  = Lang.GetResource("ui-core");
local lc = Lang.GetResource("equipment-core") or Lang.GetResource("equipment-core","en");
local ls = Lang.GetResource("miscellaneous") or Lang.GetResource("miscellaneous","en")

local yes_no = function (binary)
	if binary == 1 then
		return l.YES
	elseif binary == 0 then
		return l.NO
	else error("argument to yes_no not 0 or 1")
	end
end

local shipInfo = function (args)

	local player = Game.player

	local shipDef = ShipDef[player.shipId]

	local hyperdrive  = table.unpack(player:GetEquip("engine"))
	local frontWeapon = table.unpack(player:GetEquip("laser_front"))
	local rearWeapon  = table.unpack(player:GetEquip("laser_rear"))

	hyperdrive  = hyperdrive  or nil
	frontWeapon = frontWeapon or nil
	rearWeapon  = rearWeapon  or nil

	local shipNameEntry = ui:TextEntry(player.shipName):SetFont("HEADING_NORMAL")
	shipNameEntry.onChange:Connect(function (newName)
		player:SetShipName(newName)
	end )

	local mass_with_fuel = player.staticMass + player.fuelMassLeft
	local mass_with_fuel_kg = 1000 * mass_with_fuel

	-- ship stats mass is in tonnes; scale by 1000 to convert to kg
	local fwd_acc = -shipDef.linearThrust.FORWARD / mass_with_fuel_kg
	local bwd_acc = shipDef.linearThrust.REVERSE / mass_with_fuel_kg
	local up_acc = shipDef.linearThrust.UP / mass_with_fuel_kg

	-- delta-v calculation according to http://en.wikipedia.org/wiki/Tsiolkovsky_rocket_equation
	local deltav = shipDef.effectiveExhaustVelocity * math.log((player.staticMass + player.fuelMassLeft) / player.staticMass)

	local equipItems = {}
	local equips = {Equip.cargo, Equip.misc, Equip.hyperspace, Equip.laser}
	for _,t in pairs(equips) do
		for k,et in pairs(t) do
			local slot = et:GetDefaultSlot(player)
			if (slot ~= "cargo" and slot ~= "missile" and slot ~= "engine" and slot ~= "laser_front" and slot ~= "laser_rear") then
				local count = player:CountEquip(et)
				if count > 0 then
					if count > 1 then
						if et == Equip.misc.cabin_occupied then
							table.insert(equipItems, ui:Label(string.interp(l.N_OCCUPIED_PASSENGER_CABINS,
								{ quantity = string.format("%d", count) })))
						elseif et == Equip.misc.cabin then
							table.insert(equipItems, ui:Label(string.interp(l.N_UNOCCUPIED_PASSENGER_CABINS,
								{ quantity = string.format("%d", count) })))
						elseif et == Equip.misc.shield_generator then
							table.insert(equipItems, ui:Label(string.interp(l.N_SHIELD_GENERATORS,
								{ quantity = string.format("%d", count) })))
						else
							table.insert(equipItems, ui:Label(et:GetName()))
						end
					else
						table.insert(equipItems, ui:Label(et:GetName()))
					end
				end
			end
		end
	end

	return
		ui:Grid({48,4,48},1)
			:SetColumn(0, {
				ui:Table():AddRows({
					ui:Table():SetColumnSpacing(10):AddRows({
						ui:Label(ls.FEATURES):SetFont("HEADING_NORMAL"):SetColor({ r = 0.8, g = 1.0, b = 0.4 }),
						{ l.HYPERDRIVE..":", hyperdrive and hyperdrive:GetName() or l.NONE },
						{
							l.HYPERSPACE_RANGE..":",
							string.interp(
								l.N_LIGHT_YEARS_N_MAX, {
									range    = string.format("%.1f",player.hyperspaceRange),
									maxRange = string.format("%.1f",player.maxHyperspaceRange)
								}
							),
						},
						"",
						{ l.WEIGHT_EMPTY..":",  string.format("%dt", player.staticMass - player.usedCapacity) },
						{ l.CAPACITY_USED..":", string.format("%dt (%dt "..l.FREE..")", player.usedCapacity,  player.freeCapacity) },
						{ l.FUEL_WEIGHT..":",   string.format("%dt (%dt "..l.MAX..")", player.fuelMassLeft, shipDef.fuelTankMass ) },
						{ l.ALL_UP_WEIGHT..":", string.format("%dt", mass_with_fuel ) },
						"",
						{ l.FORWARD_ACCEL..":",  string.format("%.2f m/s² (%.1f G)", fwd_acc, fwd_acc / 9.81) },
						{ l.BACKWARD_ACCEL..":", string.format("%.2f m/s² (%.1f G)", bwd_acc, bwd_acc / 9.81) },
						{ l.UP_ACCEL..":",       string.format("%.2f m/s² (%.1f G)", up_acc, up_acc / 9.81) },
						{ l.DELTA_V..":",        string.format("%d km/s", deltav / 1000)},
						"",
						ui:Label(ls.CAPACITY):SetFont("HEADING_NORMAL"):SetColor({ r = 0.8, g = 1.0, b = 0.4 }),
						{  l.MISSILE_MOUNTS..":",        shipDef.equipSlotCapacity.missile},
						{ lc.ATMOSPHERIC_SHIELDING..":", yes_no(shipDef.equipSlotCapacity.atmo_shield)},
						{  l.SCOOP_MOUNTS..":",          shipDef.equipSlotCapacity.scoop},
						{ lc.UNOCCUPIED_CABIN..":",      shipDef.equipSlotCapacity.cabin},
						{ lc.AUTO_COMBAT..":",           yes_no(shipDef.equipSlotCapacity.autocombat)},
						{ lc.DEMP..":",                  yes_no(shipDef.equipSlotCapacity.demp)},
						{ lc.MATTER_CAPACITOR..":",      yes_no(shipDef.equipSlotCapacity.capacitor)},
						"",
						ui:Label(ls.CREW):SetFont("HEADING_NORMAL"):SetColor({ r = 0.8, g = 1.0, b = 0.4 }),
						{ ls.CREW_VACANCIES..":", shipDef.maxCrew-shipDef.minCrew},
						"",
						ui:Label(ls.WEAPONS):SetFont("HEADING_NORMAL"):SetColor({ r = 0.8, g = 1.0, b = 0.4 }),
						{ l.FRONT_WEAPON..":", frontWeapon and frontWeapon:GetName() or l.NONE},
						{ l.REAR_WEAPON..":",  rearWeapon and rearWeapon:GetName() or l.NONE },
						"",
						{ lc.MISSILE_UNGUIDED..":", player:CountEquip(Equip.misc.missile_unguided)},
						{ lc.MISSILE_GUIDED..":",   player:CountEquip(Equip.misc.missile_guided)},
						{ lc.MISSILE_SMART..":",    player:CountEquip(Equip.misc.missile_smart)},
						{ lc.MISSILE_NAVAL..":",    player:CountEquip(Equip.misc.missile_naval)},
					}),
					"",
						ui:Label(l.EQUIPMENT):SetFont("HEADING_NORMAL"):SetColor({ r = 0.8, g = 1.0, b = 0.4 }),
					ui:Table():AddRows(equipItems),
				})
			})
			:SetColumn(2, {
				ui:VBox(10)
					:PackEnd(ui:HBox(10):PackEnd({
						ui:VBox(5):PackEnd({
							ui:Label(shipDef.name):SetFont("HEADING_LARGE"):SetColor({ r = 0.8, g = 1.0, b = 0.4 }),
						}),
						ui:VBox(5):PackEnd({
							ui:Expand("HORIZONTAL", shipNameEntry),
						})
					}))
--					:PackEnd(ModelSpinner.New(ui, shipDef.modelName, player:GetSkin()))
					:PackEnd(ModelSpinner.New(ui, shipDef.modelName, player:GetSkin(), player.model.pattern))
			})
end

return shipInfo
