-- Model by potsmoke66 (Gernot)
-- Configured for Pioneer Scout+ by walterar <walterar2@gmail.com>
-- Licensed under the terms of CC-BY-SA 3.0. See licenses/CC-BY-SA-3.0.txt

define_ship {
	name='MCU-1',
	ship_class='medium_cargo_shuttle',
	manufacturer='p66',
	model='mcu1',
	forward_thrust = 2e6,
	reverse_thrust = 2e6,
	up_thrust = 2e6,
	down_thrust = 2e6,
	left_thrust = 2e6,
	right_thrust = 2e6,
	angular_thrust = 2e7,

	slots = {
		cargo = 40,
		atmo_shield = 1,
		cabin = 5,
		laser_front = 0,
		laser_rear = 0,
		missile = 0,
		scoop = 0,
		cargo_life_support = 0,
		hull_autorepair = 0,
		engine = 0,
	},

	min_crew = 1,
	max_crew = 1,

	capacity = 40,
	hull_mass = 20,
	fuel_tank_mass = 10,
	effective_exhaust_velocity = 5e7,

	hyperdrive_class = 0,

	price = 30000,
}
