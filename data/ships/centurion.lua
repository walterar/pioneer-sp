-- Copyright © 2008-2014 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of CC-BY-SA 3.0. See licenses/CC-BY-SA-3.0.txt

define_ship {
	name='Centurion',
	ship_class='light_fighter',
	manufacturer='mandarava_csepel',
	model='centurion',

	forward_thrust = 38e5,
	reverse_thrust = 19e5,
	up_thrust = 9e5,
	down_thrust = 9e5,
	left_thrust = 9e5,
	right_thrust = 9e5,
	angular_thrust = 64e5,

	slots = {
		cargo = 20,
		laser_front = 1,
		missile = 2,
		cabin = 1,
		scoop = 2,
		cargo_life_support = 0,
	},

	min_crew = 1,
	max_crew = 1,
	capacity = 20,
	hull_mass = 10,
	fuel_tank_mass = 5,
	thruster_fuel_use = 0.0001,
--	effective_exhaust_velocity = xxex,
	price = 38000,
	hyperdrive_class = 2,
}
