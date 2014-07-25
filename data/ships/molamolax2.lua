-- Copyright © 2008-2014 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of CC-BY-SA 3.0. See licenses/CC-BY-SA-3.0.txt
-- Balanced for Pioneer Scout+ by walterar <walterar2@gmail.com>

define_ship {
	name='Mola-Mola X2',
	ship_class='medium_scout',
	manufacturer='kaluri',
	model='molamola',
	forward_thrust = 259e5,
	reverse_thrust = 118e5,
	up_thrust = 1e7,
	down_thrust = 6e6,
	left_thrust = 6e6,
	right_thrust = 6e6,
	angular_thrust = 12e7,

	slots = {
		cargo = 90,
		atmo_shield = 1,
		cabin = 10,
		laser_front = 1,
		laser_rear = 0,
		missile = 2,
		cargo_scoop = 1,
		fuel_scoop = 1,
		cargo_life_support = 0,
		hull_autorepair = 0,
	},

	min_crew = 1,
	max_crew = 3,

	capacity = 90,
	hull_mass = 60,
	fuel_tank_mass = 30,

	thruster_fuel_use = 0.00015,

	hyperdrive_class = 3,

	price = 125000,
}
