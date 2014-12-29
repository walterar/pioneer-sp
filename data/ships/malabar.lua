-- Copyright © 2008-2014 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of CC-BY-SA 3.0. See licenses/CC-BY-SA-3.0.txt
-- Balanced for Pioneer Scout+ by walterar <walterar2@gmail.com>

define_ship {
	name='Malabar',
	ship_class='medium_passenger_transport',
	manufacturer='mandarava_csepel',
	model='malabar',

	forward_thrust = 140e6,
	reverse_thrust = 50e6,
	up_thrust = 50e6,
	down_thrust = 50e6,
	left_thrust = 50e6,
	right_thrust = 50e6,
	angular_thrust = 120e6,

	slots = {
		cargo = 500,
		atmo_shield = 1,
		cabin = 10,
		laser_front = 1,
		laser_rear = 0,
		missile = 8,
		scoop = 2,
		cargo_life_support = 1,
		hull_autorepair = 1,
	},

	min_crew = 1,
	max_crew = 4,

	capacity = 500,
	hull_mass = 350,
	fuel_tank_mass = 320,
	thruster_fuel_use = 0.0001,

	hyperdrive_class = 7,

	price = 600000,
}
