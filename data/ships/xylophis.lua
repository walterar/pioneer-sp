-- Copyright © 2008-2014 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of CC-BY-SA 3.0. See licenses/CC-BY-SA-3.0.txt

define_ship {
	name='Xylophis',
	ship_class='light_cargo_shuttle',
	manufacturer='opli',
	model='xylophis',
	forward_thrust = 27e5,
	reverse_thrust = 9e5,
	up_thrust = 9e5,
	down_thrust = 9e5,
	left_thrust = 9e5,
	right_thrust = 9e5,
	angular_thrust = 45e5,

	slots = {
		cargo = 12,
		atmo_shield = 1,
		cabin = 0,
		laser_front = 1,
		laser_rear = 0,
		missile = 0,
		cargo_scoop = 0,
		fuel_scoop = 0,
		cargo_life_support = 0,
		hull_autorepair = 0,
	},

	min_crew = 1,
	max_crew = 1,

	capacity = 12,
	hull_mass = 5,
	fuel_tank_mass = 5,
	thruster_fuel_use = 0.0001,

	hyperdrive_class = 1,

	price = 18000,
}
