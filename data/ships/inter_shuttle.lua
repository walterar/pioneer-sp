-- Copyright © 2008-2013 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of CC-BY-SA 3.0. See licenses/CC-BY-SA-3.0.txt
-- Balanced for Pioneer Scout + by walterar

define_ship {
	name='Inter Shuttle',
	ship_class='light_scout',
	manufacturer='p66',
	model='inter_shuttle',

	forward_thrust = 8e5,
	reverse_thrust = 5e5,
	up_thrust = 5e5,
	down_thrust = 5e5,
	left_thrust = 5e5,
	right_thrust = 5e5,
	angular_thrust = 5e6,

	slots = {
		cargo = 20,
		atmo_shield = 0,
		cabin = 4,
		laser_front = 0,
		laser_rear = 0,
		missile = 0,
		cargo_scoop = 0,
		fuel_scoop = 0,
		cargo_life_support = 0,
		hull_autorepair = 0,
		engine = 0,
	},

	min_crew = 1,
	max_crew = 1,

	capacity = 20,
	hull_mass = 13,

	fuel_tank_mass = 2,
	thruster_fuel_use = 0.0001,
	price = 20000,
	hyperdrive_class = 0,
}
