-- Adapted from Pioneer GSM system 2013 by Gernot.
-- Licensed under the terms of CC-BY-SA 3.0. See licenses/CC-BY-SA-3.0.txt
-- Balanced for Pioneer Scout+ by walterar <walterar2@gmail.com>

define_ship {
	name='Sidewinder',
	ship_class='light_scout',
	manufacturer='p66',
	model='sidie_m',
	forward_thrust = 5e6,
	reverse_thrust = 25e5,
	up_thrust = 15e5,
	down_thrust = 15e5,
	left_thrust = 15e5,
	right_thrust = 15e5,
	angular_thrust = 2e7,

	gun_mounts = {
		{ v(0,0,-16), v(0,0,-1),9, 'HORIZONTAL' },
		{ v(0,0,15), v(0,0,1),9, 'HORIZONTAL' },
	},

	slots = {
		cargo = 30,
		atmo_shield = 1,
		cabin = 1,
		laser_front = 1,
		laser_rear = 0,
		missile = 1,
		scoop = 1,
		cargo_life_support = 0,
		hull_autorepair = 0,
	},

	min_crew = 1,
	max_crew = 2,

	capacity = 30,
	hull_mass = 10,
	fuel_tank_mass = 10,

	thruster_fuel_use = 0.0001,

	hyperdrive_class = 2,

	price = 34000,
}
