-- Copyright © 2008-2014 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of CC-BY-SA 3.0. See licenses/CC-BY-SA-3.0.txt
-- Balanced for Pioneer Scout+ by walterar <walterar2@gmail.com>

define_ship {
	name='Pumpkinseed',
	ship_class='light_courier',
	manufacturer='kaluri',
	model='pumpkinseed',

	forward_thrust = 5e6,
	reverse_thrust = 3e6,
	up_thrust = 5e5,
	down_thrust = 34e4,
	left_thrust = 34e4,
	right_thrust = 34e4,
	angular_thrust = 160e5,

	slots = {
		cargo = 20,
		atmo_shield = 1,
		cabin = 1,
		laser_front = 1,
		laser_rear = 0,
		missile = 4,
		scoop = 0,
		cargo_life_support = 0,
		hull_autorepair = 0,
	},

	min_crew = 1,
	max_crew = 1,

	capacity = 20,
	hull_mass = 10,

	fuel_tank_mass = 7,
	effective_exhaust_velocity = 8e7,

	hyperdrive_class = 1,

	price = 28200,
}
