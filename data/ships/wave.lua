-- Copyright © 2008-2014 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of CC-BY-SA 3.0. See licenses/CC-BY-SA-3.0.txt

define_ship {
	name='Wave',
	ship_class='medium_fighter',
	manufacturer='auronox',
	model='wave',
	forward_thrust = 68e5,
	reverse_thrust = 14e5,
	up_thrust = 8e5,
	down_thrust = 8e5,
	left_thrust = 8e5,
	right_thrust = 8e5,
	angular_thrust = 70e5,

	slots = {
		cargo = 30,
		atmo_shield = 1,
		cabin = 1,
		laser_front = 1,
		laser_rear = 0,
		missile = 4,
		cargo_scoop = 0,
		fuel_scoop = 0,
		cargo_life_support = 0,
		hull_autorepair = 0,
	},

	min_crew = 1,
	max_crew = 1,

	capacity = 30,
	hull_mass = 13,
	fuel_tank_mass = 22,

	effective_exhaust_velocity = 169e5,

	hyperdrive_class = 2,

	price = 269e3,
}
