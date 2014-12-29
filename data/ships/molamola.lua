-- Copyright © 2008-2014 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of CC-BY-SA 3.0. See licenses/CC-BY-SA-3.0.txt
-- Balanced for Pioneer Scout+ by walterar <walterar2@gmail.com>

define_ship {
	name='Mola Mola',
	ship_class='light_freighter',
	manufacturer='kaluri',
	model='molamola',

	forward_thrust = 5e6,
	reverse_thrust = 22e5,
	up_thrust = 19e5,
	down_thrust = 6e5,
	left_thrust = 6e5,
	right_thrust = 6e5,
	angular_thrust = 20e5,

	slots = {
		cargo = 80,
		atmo_shield = 1,
		cabin = 8,
		laser_front = 1,
		laser_rear = 0,
		missile = 2,
		scoop = 2,
		cargo_life_support = 0,
		hull_autorepair = 0,
	},

	min_crew = 1,
	max_crew = 3,

	capacity = 80,
	hull_mass = 35,

	fuel_tank_mass = 20,
	effective_exhaust_velocity = 65e6,

	hyperdrive_class = 2,

	price = 90000,
}
