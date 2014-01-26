-- Copyright © 2008-2012 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of CC-BY-SA 3.0. See licenses/CC-BY-SA-3.0.txt

define_ship {
	name='Cobra Mk1',
	ship_class='medium_scout',
	manufacturer='p66',
	model='cobra_mk1_a',
	forward_thrust = 12e6,
	reverse_thrust = 4e6,
	up_thrust = 4e6,
	down_thrust = 4e6,
	left_thrust = 4e6,
	right_thrust = 4e6,
	angular_thrust = 6e7,
	camera_offset = v(0,2.75,-10.25),
	gun_mounts =
	{
		{ v(0,0,-19), v(0,0,-1), 4.75, 'HORIZONTAL' },
		{ v(0,0,0), v(0,0,1), 0, 'HORIZONTAL' }
	},
	max_cargo = 60,
	max_laser = 1,
	max_missile = 2,
	max_hullautorepair = 0,
	max_cabin = 2,
	min_crew = 1,
	max_crew = 2,
	capacity = 60,
	hull_mass = 40,
	fuel_tank_mass = 20,
	thruster_fuel_use = 0.0002,
	price = 97000,
	hyperdrive_class = 2,
}
