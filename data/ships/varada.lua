-- Copyright © 2008-2014 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of CC-BY-SA 3.0. See licenses/CC-BY-SA-3.0.txt

define_ship {
	name='Varada',
	ship_class='light_courier',
	manufacturer='mandarava_csepel',
	model='varada',
	forward_thrust = 600e3,
	reverse_thrust = 200e3,
	up_thrust = 120e3,
	down_thrust = 120e3,
	left_thrust = 240e3,
	right_thrust = 240e3,
	angular_thrust = 45e5,

	slots = {
		cargo = 5,
		atmo_shield = 0,
		cabin = 0,
		laser_front = 0,
		laser_rear = 0,
		missile = 0,
		cargo_scoop = 0,
		fuel_scoop = 0,
		cargo_life_support = 0,
		hull_autorepair = 0,
	},

	capacity = 5,
	hull_mass = 2,
	fuel_tank_mass = 3,

	min_crew = 1,
	max_crew = 1,
	effective_exhaust_velocity = 140e5,

	hyperdrive_class = 0,

	price = 123e3,
}
