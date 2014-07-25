-- Copyright © 2008-2014 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of CC-BY-SA 3.0. See licenses/CC-BY-SA-3.0.txt
-- Modified and balanced for Pioneer Scout+ by walterar

define_ship {
	name='Kanara Scout',
	ship_class='medium_courier',
	manufacturer='opli',
	model='kanarascout',
	forward_thrust = 38e5,
	reverse_thrust = 19e5,
	up_thrust = 9e5,
	down_thrust = 9e5,
	left_thrust = 9e5,
	right_thrust = 9e5,
	angular_thrust = 64e5,

	camera_offset = v(0,4.5,-12.5),

	gun_mounts = {
		{ v(0,-2,-46), v(0,0,-1), 5, 'HORIZONTAL' },
		{ v(0,0,0), v(0,0,1), 5, 'HORIZONTAL' },
	},

	slots = {
		cargo = 20,
		atmo_shield = 0,
		cabin = 1,
		laser_front = 1,
		laser_rear = 0,
		missile = 2,
		cargo_scoop = 0,
		fuel_scoop = 0,
		cargo_life_support = 0,
		hull_autorepair = 0,
	},

	min_crew = 1,
	max_crew = 2,

	capacity = 20,
	hull_mass = 10,

	fuel_tank_mass = 5,
	thruster_fuel_use = 0.0001,
	price = 38000,
	hyperdrive_class = 2,
}
