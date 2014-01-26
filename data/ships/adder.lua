-- Adapted from Pioneer GSM system 2013 by Gernot.
-- Balanced for Pioneer Scout+ 2013-2014 by walterar <walterar2@gmail.com>
-- Licensed under the terms of CC-BY-SA 3.0. See licenses/CC-BY-SA-3.0.txt

define_ship {
	name='Adder',
	ship_class='medium_scout',
	manufacturer='p66',
	model='adder',
	forward_thrust = 11e6,
	reverse_thrust = 55e5,
	up_thrust = 35e5,
	down_thrust = 2e6,
	left_thrust = 2e6,
	right_thrust = 2e6,
	angular_thrust = 22e6,
	camera_offset = v(0,4,-22),
	gun_mounts =
	{
		{ v(0,0,-26), v(0,0,-1), 5, 'HORIZONTAL' },
		{ v(0,-2,9), v(0,0,1), 5, 'HORIZONTAL' },
	},
	max_cargo = 50,
	max_laser = 1,
	max_missile = 2,
	max_cargoscoop = 1,
	max_fuelscoop = 1,
	max_cargolifesupport = 1,
	max_cabin = 4,
	min_crew = 1,
	max_crew = 2,
	capacity = 50,
	hull_mass = 30,
	fuel_tank_mass = 10,
	thruster_fuel_use = 0.00015,
	price = 60000,
	hyperdrive_class = 3,
}