-- Copyright © 2008-2014 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of CC-BY-SA 3.0. See licenses/CC-BY-SA-3.0.txt

define_ship {
	name='Lunar Shuttle',
	ship_class='light_passenger_shuttle',
	manufacturer='haber',
	model='lunarshuttle',
	forward_thrust = 52e5,
	reverse_thrust = 16e5,
	up_thrust = 28e5,
	down_thrust = 6e5,
	left_thrust = 6e5,
	right_thrust = 6e5,
	angular_thrust = 86e5,

	camera_offset = v(0,4,-22),

	gun_mounts = {
		{ v(0,0,-26), v(0,0,-1), 5, 'HORIZONTAL' },
		{ v(0,-2,9), v(0,0,1), 5, 'HORIZONTAL' },
	},

	slots = {
		cargo = 30,
		cabin = 2,
		missile = 0,
		laser_front = 1,
		laser_rear = 0,
		cargoscoop = 0,
		cargolifesupport = 0,
		hullautorepair = 0,
		fuelscoop = 0,
		engine = 0
	},

	min_crew = 1,
	max_crew = 2,

	capacity = 30,
	hull_mass = 20,
	fuel_tank_mass = 10,

	effective_exhaust_velocity = 80000e3,

	hyperdrive_class = 0,

	price = 40000,
}
