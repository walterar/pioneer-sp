-- Copyright © 2008-2014 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of CC-BY-SA 3.0. See licenses/CC-BY-SA-3.0.txt
-- Balanced for Pioneer Scout+ by walterar

define_ship {
	name='Lanner',
	ship_class='heavy_scout',
	manufacturer='p66',
	model='lanner',
	forward_thrust = 478e5,
	reverse_thrust = 159e5,
	up_thrust = 159e5,
	down_thrust = 80e5,
	left_thrust = 80e5,
	right_thrust = 80e5,
	angular_thrust = 1170e5,
	camera_offset = v(0,3,-28.5),
	gun_mounts =
	{
		{ v(0,-1.9,-38), v(0,0,-1), 5, 'HORIZONTAL' },
		{ v(0,1,38), v(0,0,1), 5, 'HORIZONTAL' },
	},
	max_cargo = 190,
	max_laser = 2,
	max_missile = 4,
	max_cargoscoop = 0,
	min_crew = 1,
	max_crew = 2,
	capacity = 190,
	hull_mass = 130,
	fuel_tank_mass = 60,
	thruster_fuel_use = 0.00015,
	price = 280000,
	hyperdrive_class = 4,
}
