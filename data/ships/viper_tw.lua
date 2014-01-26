-- Model by Coolhand, converted to Pioneer GSM system 2013 by Gernot.
-- Balanced for Pioneer Scout+ by walterar <walterar2@gmail.com>
-- Licensed under the terms of CC-BY-SA 3.0. See licenses/CC-BY-SA-3.0.txt

define_ship {
	name='Viper TW',
	ship_class='medium_scout',
	manufacturer='p66',
	model='viper_tw',
	forward_thrust = 10e6,
	reverse_thrust = 4e6,
	up_thrust = 4e6,
	down_thrust = 3e6,
	left_thrust = 3e6,
	right_thrust = 3e6,
	angular_thrust = 30e6,
	camera_offset = v(0,4.5,-12.5),
	gun_mounts =
	{
		{ v(0,-2,-46), v(0,0,-1), 5, 'HORIZONTAL' },
		{ v(0,0,0), v(0,0,1), 5, 'HORIZONTAL' },
	},
	max_cargo = 60,
	max_laser = 1,
	max_missile = 4,
	max_cargoscoop = 1,
	max_fuelscoop = 1,
	max_cabin = 6,
	min_crew = 1,
	max_crew = 2,
	capacity = 60,
	hull_mass = 30,
	fuel_tank_mass = 10,
	thruster_fuel_use = 0.0001,
	price = 70000,
	hyperdrive_class = 3,
}
