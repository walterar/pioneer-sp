-- Copyright © 2008-2014 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of CC-BY-SA 3.0. See licenses/CC-BY-SA-3.0.txt
-- Balanced for Pioneer Scout+ by walterar

define_ship {
	name = 'DS Miner',
	ship_class='medium_freighter',
	manufacturer='haber',
	model = 'dsminer',

	forward_thrust = 90e6,
	reverse_thrust = 50e6,
	up_thrust = 50e6,
	down_thrust = 50e6,
	left_thrust = 50e6,
	right_thrust = 50e6,
	angular_thrust = 80e6,

	max_cargo = 500,
	max_laser = 1,
	max_missile = 2,
	max_cargoscoop = 1,
	max_fuelscoop = 1,
	min_crew = 1,
	max_crew = 8,

	capacity = 500,
	hull_mass = 300,
	fuel_tank_mass = 150,
	thruster_fuel_use = 0.0001,
	price = 500000,
	hyperdrive_class = 6,
}
