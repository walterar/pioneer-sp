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

	slots = {
		cargo = 100,
		cabin = 10,
		missile = 4,
		laser_front = 1,
		laser_rear = 0,
		cargo_scoop = 1,
		cargo_life_support = 1,
		fuel_scoop = 1,
	},

	min_crew = 1,
	max_crew = 2,
	capacity = 100,
	hull_mass = 60,
	fuel_tank_mass = 90,
	thruster_fuel_use = 0.00015,
	price = 110000,
	hyperdrive_class = 3,
}
