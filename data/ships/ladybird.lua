-- Copyright © 2008-2013 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of CC-BY-SA 3.0. See licenses/CC-BY-SA-3.0.txt

local thrust = function(grav,mass)
	return math.floor(grav * 9806.65 * mass)
end

local radius = 30
local tara = 50
local main = thrust(18,tara)
local reverse = thrust(10,tara)
local lateral = thrust(5,tara)
local angular = lateral * radius

define_ship {
	name='Ladybird Starfighter',
	ship_class='medium_courier',
	manufacturer='TMM',
	model='ladybird',
	forward_thrust = main,
	reverse_thrust = reverse,
	up_thrust = lateral,
	down_thrust = lateral,
	left_thrust = lateral,
	right_thrust = lateral,
	angular_thrust = angular,

	hull_mass = 30,
	fuel_tank_mass = 20,
	capacity = 40,

	slots = {
		cargo = 40,
		missile = 4,
		laser_front = 1,
		laser_rear = 1,
		scoop = 0,
		engine = 1,
		cabin = 3,
		--shield = 5,
	},

	min_crew = 1,
	max_crew = 2,

--	effective_exhaust_velocity = 5e6,
	thruster_fuel_use = 0.0001,

	hyperdrive_class = 2,

	price = 48000,
}
