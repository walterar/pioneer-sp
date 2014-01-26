-- Copyright © 2008-2012 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of CC-BY-SA 3.0. See licenses/CC-BY-SA-3.0.txt

define_ship {
	name='Caiman',
	ship_class='medium_scout',
	manufacturer='p66',
	model='caiman',
	forward_thrust = 11e6,
	reverse_thrust = 5e6,
	up_thrust = 4e6,
	down_thrust = 4e6,
	left_thrust = 4e6,
	right_thrust = 4e6,
	angular_thrust = 8e7,
	camera_offset = v(0,3.8,-7),
	gun_mounts =
	{
		{ v(0,-1.3,-17), v(0,0,-1),5.16, 'HORIZONTAL' },
		{ v(0,0,0), v(0,0,1),5.16, 'HORIZONTAL' }
	},
	max_cargo = 60,
	max_laser = 1,
	max_missile = 4,
	max_hullautorepair = 0,
	max_cabin = 4,
	min_crew = 1,
	max_crew = 2,
	capacity = 60,
	hull_mass = 30,
	fuel_tank_mass = 10,
	thruster_fuel_use = 0.00015,
	price = 65000,
	hyperdrive_class = 2,
}