-- Model by potsmoke66 (Gernot)
-- Balanced for Pioneer Scout+ by walterar <walterar2@gmail.com>
-- Licensed under the terms of CC-BY-SA 3.0. See licenses/CC-BY-SA-3.0.txt

define_ship {
		name='Hullcutter',
		ship_class='light_scout',
		manufacturer='p66',
		model='hullcutter',
		forward_thrust = 5e6,
		reverse_thrust = 25e5,
		up_thrust = 2e6,
		down_thrust = 2e6,
		left_thrust = 2e6,
		right_thrust = 2e6,
		angular_thrust = 2e7,
		gun_mounts =
		{
		{ v(0,0,-9), v(0,0,-1), 5, 'HORIZONTAL' },
		{ v(0,0,0), v(0,0,1), 5, 'HORIZONTAL' },
		},
		max_cargo = 30,
		max_laser = 1,
		max_missile = 4,
		max_hullautorepair = 0,
		max_cargolifesupport = 0,
		max_cargoscoop = 0,
		max_cabin = 1,
		min_crew = 1,
		max_crew = 2,
		capacity = 30,
		hull_mass = 10,
		price = 48000,
		fuel_tank_mass = 10,
		thruster_fuel_use = 0.0001,
		hyperdrive_class = 2,
	}
