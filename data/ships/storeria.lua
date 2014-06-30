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
	max_cargo = 120,
	max_laser = 2,
	max_missile = 4,
	max_cargoscoop = 0,
	min_crew = 1,
	max_crew = 3,
	max_cabin = 10,
	capacity = 120,
	hull_mass = 80,
	fuel_tank_mass = 40,
	-- Exhaust velocity Vc [m/s] is equivalent of engine efficiency and depend on used technology. Higher Vc means lower fuel consumption.
	-- Smaller ships built for speed often mount engines with higher Vc. Another way to make faster ship is to increase fuel_tank_mass.
	thruster_fuel_use = 0.00015,
	price = 162000,
	hyperdrive_class = 4,
}
