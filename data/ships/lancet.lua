-- Copyright © 2008-2012 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of CC-BY-SA 3.0. See licenses/CC-BY-SA-3.0.txt

define_ship {
	name='Lancet',
	ship_class='light_scout',
	manufacturer='p66',
	model='lancet',
	forward_thrust = 7e6,
	reverse_thrust = 7e6,
	up_thrust = 4e6,
	down_thrust = 25e5,
	left_thrust = 25e5,
	right_thrust = 25e5,
	angular_thrust = 14e6,
	camera_offset = v(0,1.5,-3),
	gun_mounts =
	{
		{ v(0,0,-10), v(0,0,-1), 7, 'HORIZONTAL' },
		{ v(0,0,10), v(0,0,1), 7, 'HORIZONTAL' },
	},
	max_cargo = 21,
	max_laser = 2,
	max_missile = 0,
	max_fuelscoop = 0,
	max_cargoscoop = 0,
	max_cargolifesupport = 0,
	max_cabin = 2,
	capacity = 21,
	hull_mass = 20,
	fuel_tank_mass = 5,
	thruster_fuel_use = 0.0001,
	price = 40000,
	hyperdrive_class = 1,
}
