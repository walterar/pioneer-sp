-- Copyright © 2008-2014 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of CC-BY-SA 3.0. See licenses/CC-BY-SA-3.0.txt

local thrust = function(grav,mass)
	return math.floor(grav * 9806.65 * mass)
end

local radius = 15
local tara = 22
local main = thrust(25,tara)
local reverse = thrust(15,tara)
local lateral = thrust(5,tara)
local angular = lateral * radius

define_ship {
	name='Manta',
	ship_class='light_fighter',
	manufacturer='p66',
	model='manta',
	forward_thrust = main,
	reverse_thrust = reverse,
	up_thrust = lateral,
	down_thrust = lateral,
	left_thrust = lateral,
	right_thrust = lateral,
	angular_thrust = angular,

	hull_mass = 16,
	fuel_tank_mass = 6,
	capacity = 22,

	slots = {
		cargo=22,
		--engine=1,
		--laser_front=1,
		laser_rear=0,
		missile=4,
		--ecm=1,
		--scanner=1,
		--radar=1,
		--hypercloud=1,
		hull_autorepair=0,
		--energy_booster=1,
		--atmo_shield=1,
		cabin=0,
		shield=2,
		fuel_scoop=0,
		cargo_scoop=0,
		--laser_cooler=1,
		cargo_life_support=0,
		--autopilot=1,
	},

	min_crew = 1,
	max_crew = 1,

--	effective_exhaust_velocity = 10e6,
	thruster_fuel_use = 0.0001,
	price = 27e3,
	hyperdrive_class = 1,
}
