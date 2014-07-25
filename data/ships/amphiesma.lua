-- Copyright © 2008-2014 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of CC-BY-SA 3.0. See licenses/CC-BY-SA-3.0.txt
-- Balanced for Scout + by walterar <walterar2@gmail.com> (Work in Progress)

define_ship {
	name='Amphiesma',
	ship_class='medium_courier',
	manufacturer='opli',
	model='amphiesma',
	forward_thrust = 8e6,
	reverse_thrust = 2e6,
	up_thrust = 1e6,
	down_thrust = 5e5,
	left_thrust = 5e5,
	right_thrust = 5e5,
	angular_thrust = 4e6,

	slots = {
		cargo = 38,
		cabin = 2,
		missile = 4,
		laser_front = 1,
		laser_rear = 0,
		cargo_scoop = 1,
		cargo_life_support = 1,
		fuel_scoop = 1,
	},

	min_crew = 1,
	max_crew = 2,
	capacity = 38,
	hull_mass = 18,
	fuel_tank_mass = 10,
	-- Exhaust velocity Vc [m/s] is equivalent of engine efficiency and depend on used technology. Higher Vc means lower fuel consumption.
	-- Smaller ships built for speed often mount engines with higher Vc. Another way to make faster ship is to increase fuel_tank_mass.
--	effective_exhaust_velocity = 68e5,
	thruster_fuel_use = 0.00015,
	price = 38200,
	hyperdrive_class = 1,
}
