-- Copyright © 2008-2014 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of CC-BY-SA 3.0. See licenses/CC-BY-SA-3.0.txt

define_ship {
	name='MechanicCop',
	ship_class='light_fighter',
	manufacturer='haber',
	model='police',
	forward_thrust = 38e5,
	reverse_thrust = 19e5,
	up_thrust = 9e5,
	down_thrust = 9e5,
	left_thrust = 9e5,
	right_thrust = 9e5,
	angular_thrust = 64e5,

	hull_mass = 10,
	fuel_tank_mass = 5,
	capacity = 15,
	max_cargo = 15,
	max_laser = 1,
	max_missile = 6,
	max_cargoscoop = 0,
	max_fuelscoop = 0,
	min_crew = 1,
	max_crew = 1,
	-- Exhaust velocity Vc [m/s] is equivalent of engine efficiency and depend on used technology. Higher Vc means lower fuel consumption.
	-- Smaller ships built for speed often mount engines with higher Vc. Another way to make faster ship is to increase fuel_tank_mass.
	thruster_fuel_use = 0.0001,
--	effective_exhaust_velocity = 89e5,
	price = 0,
	hyperdrive_class = 0,
}
