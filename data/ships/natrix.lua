-- Copyright © 2008-2014 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of CC-BY-SA 3.0. See licenses/CC-BY-SA-3.0.txt

define_ship {
	name='Natrix',
	ship_class='light_freighter',
	manufacturer='opli',
	model='natrix',
	forward_thrust = 124e5,
	reverse_thrust = 21e5,
	up_thrust = 21e5,
	down_thrust = 21e5,
	left_thrust = 21e5,
	right_thrust = 21e5,
	angular_thrust = 195e5,

	slots = {
		cargo = 40,
		atmo_shield = 1,
		cabin = 4,
		laser_front = 1,
		laser_rear = 0,
		missile = 2,
		cargo_scoop = 0,
		fuel_scoop = 0,
		cargo_life_support = 0,
		hull_autorepair = 0,
	},

	min_crew = 1,
	max_crew = 1,

	capacity = 40,
	hull_mass = 20,
	fuel_tank_mass = 20,
	effective_exhaust_velocity = 62143e3,

	hyperdrive_class = 2,

	price = 50000,
}
