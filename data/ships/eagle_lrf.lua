-- Adapted from Pioneer GSM system 2013 by Gernot.
-- Licensed under the terms of CC-BY-SA 3.0. See licenses/CC-BY-SA-3.0.txt
-- Balanced for Pioneer Scout+ by walterar <walterar2@gmail.com>

define_ship {
	name='Eagle LRF',
	ship_class='light_scout',
	manufacturer='p66',
	model = 'eagle_lrf',

	forward_thrust = 38e5,
	reverse_thrust = 19e5,
	up_thrust = 9e5,
	down_thrust = 9e5,
	left_thrust = 9e5,
	right_thrust = 9e5,
	angular_thrust = 64e5,

	camera_offset = v(0,1,-12.8),
	gun_mounts = {
		{ v(0,-.7,-25), v(0,0,-1), 5, 'HORIZONTAL' },
		{ v(0,-.7,25), v(0,0,1), 5, 'HORIZONTAL' },
	},

	slots = {
		cargo = 20,
		atmo_shield = 1,
		cabin = 0,
		laser_front = 1,
		laser_rear = 0,
		missile = 2,
		scoop = 0,
		cargo_life_support = 0,
		hull_autorepair = 0,
	},

	min_crew = 1,
	max_crew = 1,

	capacity = 20,
	hull_mass = 10,
	fuel_tank_mass = 5,
	thruster_fuel_use = 0.0001,

	hyperdrive_class = 1,

	price = 28000,
}
