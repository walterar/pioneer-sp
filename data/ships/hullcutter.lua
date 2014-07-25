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

	slots = {
		cargo = 30,
		atmo_shield = 1,
		cabin = 1,
		laser_front = 1,
		laser_rear = 0,
		missile = 4,
		cargo_scoop = 0,
		fuel_scoop = 0,
		cargo_life_support = 0,
		hull_autorepair = 0,
	},

		min_crew = 1,
		max_crew = 2,

		capacity = 30,
		hull_mass = 10,
		fuel_tank_mass = 10,

		thruster_fuel_use = 0.0001,
		price = 48000,
		hyperdrive_class = 2,
	}
