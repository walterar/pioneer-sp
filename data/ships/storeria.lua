-- Copyright © 2008-2014 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of CC-BY-SA 3.0. See licenses/CC-BY-SA-3.0.txt
-- Balanced for Pioneer Scout+ by walterar

define_ship {
	name='Storeria',
	ship_class='medium_freighter',
	manufacturer='opli',
	model='storeria',
	forward_thrust = 32e6,
	reverse_thrust = 16e6,
	up_thrust = 7e6,
	down_thrust = 7e6,
	left_thrust = 7e6,
	right_thrust = 7e6,
	angular_thrust = 15e7,

	slots = {
		cargo = 120,
		atmo_shield = 1,
		cabin = 10,
		laser_front = 1,
		laser_rear = 0,
		missile = 4,
		scoop = 2,
		cargo_life_support = 1,
		hull_autorepair = 0,
	},

	min_crew = 1,
	max_crew = 3,

	capacity = 120,
	hull_mass = 80,
	fuel_tank_mass = 40,
	thruster_fuel_use = 0.00015,

	hyperdrive_class = 4,

	price = 162000,
}
