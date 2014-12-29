-- Adapted from Pioneer GSM system 2013 by Gernot.
-- Licensed under the terms of CC-BY-SA 3.0. See licenses/CC-BY-SA-3.0.txt
-- Balanced for Pioneer Scout+ by walterar <walterar2@gmail.com>

define_ship {
	name='Lancet',
	ship_class='light_scout',
	manufacturer='p66',
	model='lancet',

	forward_thrust = 7e6,
	reverse_thrust = 7e6,
	up_thrust = 4e6,
	down_thrust = 25e5,
	left_thrust = 25e5,
	right_thrust = 25e5,
	angular_thrust = 14e6,

	camera_offset = v(0,1.5,-3),
	gun_mounts = {
		{ v(0,0,-10), v(0,0,-1), 7, 'HORIZONTAL' },
		{ v(0,0,10), v(0,0,1), 7, 'HORIZONTAL' },
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

	price = 31000,
}
