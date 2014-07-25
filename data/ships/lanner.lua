-- Copyright © 2008-2014 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of CC-BY-SA 3.0. See licenses/CC-BY-SA-3.0.txt
-- Balanced for Pioneer Scout+ by walterar

define_ship {
	name='Lanner',
	ship_class='heavy_scout',
	manufacturer='p66',
	model='lanner',
	forward_thrust = 478e5,
	reverse_thrust = 159e5,
	up_thrust = 159e5,
	down_thrust = 80e5,
	left_thrust = 80e5,
	right_thrust = 80e5,
	angular_thrust = 1170e5,

	camera_offset = v(0,3,-28.5),

	gun_mounts = {
		{ v(0,-1.9,-38), v(0,0,-1), 5, 'HORIZONTAL' },
		{ v(0,1,38), v(0,0,1), 5, 'HORIZONTAL' },
	},

	slots = {
		cargo = 190,
		atmo_shield = 1,
		cabin = 10,
		laser_front = 1,
		laser_rear = 0,
		missile = 4,
		cargo_scoop = 1,
		fuel_scoop = 1,
		cargo_life_support = 1,
		hull_autorepair = 1,
	},

	min_crew = 1,
	max_crew = 2,

	capacity = 190,
	hull_mass = 95,

	fuel_tank_mass = 40,
	thruster_fuel_use = 0.00015,
	hyperdrive_class = 4,

	price = 280000,

}
