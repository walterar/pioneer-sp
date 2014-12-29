-- Copyright © 2008-2014 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of CC-BY-SA 3.0. See licenses/CC-BY-SA-3.0.txt
-- Balanced for Pioneer Scout+ by walterar <walterar2@gmail.com>

define_ship {
	name='Deneb',
	ship_class='medium_freighter',
	manufacturer='albr',
	model='deneb',

	forward_thrust = 15e6,
	reverse_thrust = 5e6,
	up_thrust = 10e6,
	down_thrust = 4e6,
	left_thrust = 4e6,
	right_thrust = 4e6,
	angular_thrust = 50e6,

	slots = {
		cargo = 235,
		atmo_shield = 1,
		cabin = 10,
		laser_front = 1,
		laser_rear = 0,
		missile = 0,
		scoop = 2,
		cargo_life_support = 1,
		hull_autorepair = 1,
	},

	min_crew = 1,
	max_crew = 3,

	capacity = 235,
	hull_mass = 100,
	fuel_tank_mass = 100,

	--thruster_fuel_use = 0.0001,
	effective_exhaust_velocity = 51784e3,
	price = 250000,
	hyperdrive_class = 3,
}
