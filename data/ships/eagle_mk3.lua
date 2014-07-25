-- Adapted from Pioneer GSM system 2013 by Gernot.
-- Balanced for Pioneer Scout+ by walterar <walterar2@gmail.com>
-- Licensed under the terms of CC-BY-SA 3.0. See licenses/CC-BY-SA-3.0.txt

define_ship {
	name='Eagle MK3',
	ship_class='light_scout',
	manufacturer='p66',
	model = 'eagle_mk3',

	forward_thrust = 36e5,
	reverse_thrust = 25e5,
	up_thrust = 8e5,
	down_thrust = 8e5,
	left_thrust = 8e5,
	right_thrust = 8e5,
	angular_thrust = 64e5,

	camera_offset = v(0,1,-12.8),

	gun_mounts =
	{
		{ v(0,-.7,-40), v(0,0,-1), 5, 'HORIZONTAL' },
		{ v(0,-.7,25), v(0,0,1), 5, 'HORIZONTAL' },
	},

	slots = {
		cargo = 22,
		atmo_shield = 1,
		cabin = 0,
		laser_front = 1,
		laser_rear = 0,
		missile = 2,
		cargo_scoop = 0,
		cargo_life_support = 0,
		hull_autorepair = 0,
		fuel_scoop = 0,
	},

	min_crew = 1,
	max_crew = 1,

	capacity = 22,
	hull_mass = 10,
	fuel_tank_mass = 5,

	thruster_fuel_use = 0.00015,
	price = 33000,
	hyperdrive_class = 1,
}
