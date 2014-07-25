-- Copyright © 2008-2014 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of CC-BY-SA 3.0. See licenses/CC-BY-SA-3.0.txt

define_ship {
	name='Sinonatrix',
	model='sinonatrix',
	ship_class='light_courier',
	manufacturer='opli',

	forward_thrust = 55e5,
	reverse_thrust = 12e5,
	up_thrust = 15e5,
	down_thrust = 1e6,
	left_thrust = 1e6,
	right_thrust = 1e6,
	angular_thrust = 25e6,

	slots = {
		cargo = 35,
		atmo_shield = 1,
		cabin = 2,
		laser_front = 1,
		laser_rear = 0,
		missile = 2,
		cargo_scoop = 1,
		fuel_scoop = 1,
		cargo_life_support = 0,
		hull_autorepair = 0,
	},

	min_crew = 1,
	max_crew = 1,

	capacity = 35,
	hull_mass = 20,
	fuel_tank_mass = 30,

	-- Exhaust velocity Vc [m/s] is equivalent of engine efficiency and depend on used technology. Higher Vc means lower fuel consumption.
	-- Smaller ships built for speed often mount engines with higher Vc. Another way to make faster ship is to increase fuel_tank_mass.
	effective_exhaust_velocity = 95e6,

	hyperdrive_class = 3,

	price = 31000,
}
