-- Copyright © 2008-2014 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of CC-BY-SA 3.0. See licenses/CC-BY-SA-3.0.txt

define_ship {
	name='Venturestar',
	model='venturestar',
	ship_class='medium_freighter',
	manufacturer='albr',
	forward_thrust = 35e6,
	reverse_thrust = 10e6,
	up_thrust = 15e6,
	down_thrust = 8e6,
	left_thrust = 8e6,
	right_thrust = 8e6,
	angular_thrust = 50e6,

	slots = {
		cargo = 500,
		atmo_shield = 1,
		cabin = 10,
		laser_front = 1,
		laser_rear = 0,
		missile = 12,
		cargo_scoop = 1,
		fuel_scoop = 1,
		cargo_life_support = 1,
		hull_autorepair = 1,
	},

	min_crew = 1,
	max_crew = 5,

	capacity = 500,
	hull_mass = 200,
	fuel_tank_mass = 200,
	effective_exhaust_velocity = 51784e3,

	hyperdrive_class = 4,

	price = 630000,
}
