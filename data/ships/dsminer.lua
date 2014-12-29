-- Copyright © 2008-2012 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of CC-BY-SA 3.0. See licenses/CC-BY-SA-3.0.txt

define_ship {
	name = 'Deep Space Miner',
	ship_class='medium_freighter',
	manufacturer='haber',
	model = 'dsminer',
	forward_thrust = 70e6,
	reverse_thrust = 28e6,
	up_thrust = 28e6,
	down_thrust = 28e6,
	left_thrust = 28e6,
	right_thrust = 28e6,
	angular_thrust = 80e6,

	slots = {
		cargo = 4600,
		atmo_shield = 0,
		cabin = 0,
		laser_front = 1,
		laser_rear = 0,
		missile = 2,
		scoop = 2,
		cargo_life_support = 1,
		hull_autorepair = 1,
	},

	min_crew = 5,
	max_crew = 8,

	capacity = 4700,
	hull_mass = 1200,
	fuel_tank_mass = 1200,

	-- Exhaust velocity Vc [m/s] is equivalent of engine efficiency and depend on used technology. Higher Vc means lower fuel consumption.
	-- Smaller ships built for speed often mount engines with higher Vc. Another way to make faster ship is to increase fuel_tank_mass.
	effective_exhaust_velocity = 166e5,
	price = 37739e2,
	hyperdrive_class = 8,
}
