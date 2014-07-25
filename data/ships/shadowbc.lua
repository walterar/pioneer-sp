-- Copyright © 2008-2013 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of CC-BY-SA 3.0. See licenses/CC-BY-SA-3.0.txt

--Ships not available for purchase (ambient ships)
define_static_ship {
	name='Shadow battle crab',
	ship_class='medium_freighter',
	manufacturer='albr',
	model='shadowbc',
	forward_thrust = 3200e5,
	reverse_thrust = 800e5,
	up_thrust = 800e5,
	down_thrust = 800e5,
	left_thrust = 800e5,
	right_thrust = 800e5,
	angular_thrust = 25000e5,

	slots = {
		cargo = 16000,
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

	capacity = 16000,
	hull_mass = 4000,
	fuel_tank_mass = 6000,
	effective_exhaust_velocity = 55123e3,

	hyperdrive_class = 0,

	price = 0,
}
