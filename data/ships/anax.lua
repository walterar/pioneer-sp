-- Model by Leech, published in SpaceSimCentral.com
-- Balanced to Pioneer Scout+ by walterar <walterar2@gmail.com>

define_ship {
	name = "Anax",
	ship_class='medium_scout',
	manufacturer='kaluri',
	model = "anax",
	camera_offset = v(0,0,-30),
	forward_thrust = 30e6,
	reverse_thrust = 15e6,
	up_thrust = 12e6,
	down_thrust = 12e6,
	left_thrust = 12e6,
	right_thrust = 12e6,
	angular_thrust = 25e6,
	gun_mounts =
	{
		{ v(0,0,0), v(0,0,-1), 5, 'HORIZONTAL' },
	},
	max_cargo = 100,
	max_laser = 1,
	max_missile = 4,
	max_cabin = 10,
	min_crew = 1,
	max_crew = 2,
	capacity = 100,
	hull_mass = 60,
	fuel_tank_mass = 90,
	thruster_fuel_use = 0.00015,
	price = 110000,
	hyperdrive_class = 3,
}
