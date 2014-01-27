define_surface_station {
	model = 'ground_station',
    num_docking_ports = 14,
	-- define groups of bays, in this case 1 group with 1 bay.
	-- params are = {minSize, maxSize, {list,of,bay,numbers}}
	bay_groups = {
		{0, 15, {1}},
		{30, 500, {2}},
		{30, 500, {3}},
		{30, 500, {4}},
		{30, 500, {5}},
		{30, 500, {6}},
		{0, 30, {7}},
		{0, 30, {8}},
		{0, 30, {9}},
		{0, 30, {10}},
		{0, 30, {11}},
		{0, 30, {12}},
		{0, 30, {13}},
		{0, 30, {14}},
	},
    parking_distance = 5000.0,
    parking_gap_size = 2000.0,
    ship_launch_stage = 0,
    dock_anim_stage_duration = { 300, 4.0},
    undock_anim_stage_duration = { 0 },
}
