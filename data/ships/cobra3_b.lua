-- Adapted from Pioneer GSM system 2013 by Gernot.
-- Balanced for Pioneer Scout+ by walterar <walterar2@gmail.com>
-- Licensed under the terms of CC-BY-SA 3.0. See licenses/CC-BY-SA-3.0.txt

--local model_scale = 1.2 model is scaled now 1.2:1

define_ship {
	name='Cobra Mk3',
	ship_class='medium_scout',
	manufacturer='p66',
	model='cobra3_b',
	forward_thrust = 17e6,
	reverse_thrust = 8e6,
	up_thrust = 6e6,
	down_thrust = 6e6,
	left_thrust = 6e6,
	right_thrust = 6e6,
	angular_thrust = 4e7,
	camera_offset = v(0,3.1,-4.1),
	gun_mounts =
	{
		{ v(0,0.4,-15), v(0,0,-1), 0.5, 'HORIZONTAL' },
		{ v(0,3.1,15), v(0,0,1), 0.5, 'HORIZONTAL' },
	},

	slots = {
		cargo = 80,
		cabin = 8,
		missile = 4,
		laser_front = 1,
		laser_rear = 0,
		scoop = 2,
		cargo_life_support = 1,
	},

	min_crew = 1,
	max_crew = 3,
	capacity = 80,
	hull_mass = 40,
	fuel_tank_mass = 20,
	thruster_fuel_use = 0.0002,
	price = 98000,
	hyperdrive_class = 3,
}
