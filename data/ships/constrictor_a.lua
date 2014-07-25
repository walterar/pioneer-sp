-- Adapted from Pioneer GSM system 2013 by Gernot.
-- Licensed under the terms of CC-BY-SA 3.0. See licenses/CC-BY-SA-3.0.txt
-- Balanced for Pioneer Scout+ by walterar <walterar2@gmail.com>

define_ship {
	name = 'Constrictor',
	ship_class='heavy_scout',
	manufacturer='p66',
	model='constrictor_a',
	forward_thrust = 259e5,
	reverse_thrust = 118e5,
	up_thrust = 1e7,
	down_thrust = 6e6,
	left_thrust = 6e6,
	right_thrust = 6e6,
	angular_thrust = 12e7,
	camera_offset = v(0,1.7,-6.7),
	gun_mounts =
	{
		{ v(0,-2,-26), v(0,0,-1), 0.5, 'HORIZONTAL' },
		{ v(0,-2,19), v(0,0,1), 0.5, 'HORIZONTAL' },
	},

	slots = {
		cargo = 90,
		cabin = 10,
		missile = 2,
		laser_front = 1,
		laser_rear = 0,
		cargo_scoop = 1,
		cargo_life_support = 1,
		fuel_scoop = 1,
	},

	min_crew = 1,
	max_crew = 3,
	capacity = 90,
	hull_mass = 60,
	fuel_tank_mass = 30,
	thruster_fuel_use = 0.00015,
	price = 143000,
	hyperdrive_class = 3,
}
