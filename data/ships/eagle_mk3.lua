-- Adapted from Pioneer GSM system 2013 by Gernot.
-- Balanced for Pioneer Scout+ by walterar <walterar2@gmail.com>
-- Licensed under the terms of CC-BY-SA 3.0. See licenses/CC-BY-SA-3.0.txt

define_ship {
	name='Eagle MK3',
	ship_class='light_scout',
	manufacturer='p66',
	model = 'eagle_mk3',
	forward_thrust = 36e5,
	reverse_thrust = 25e5,
	up_thrust = 8e5,
	down_thrust = 8e5,
	left_thrust = 8e5,
	right_thrust = 8e5,
	angular_thrust = 64e5,
	camera_offset = v(0,1,-12.8),
	gun_mounts =
	{
		{ v(0,-.7,-40), v(0,0,-1), 5, 'HORIZONTAL' },
		{ v(0,-.7,25), v(0,0,1), 5, 'HORIZONTAL' },
	},
	max_cargo = 22,
	max_missile = 2,
	max_fuelscoop = 0,
	max_cargoscoop = 0,
	max_cabin = 0,
	min_crew = 1,
	max_crew = 1,
	capacity = 22,
	hull_mass = 10,
	fuel_tank_mass = 5,
	thruster_fuel_use = 0.00015,
	price = 43000,
	hyperdrive_class = 1,
}
