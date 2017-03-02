--[[
    ___                      
   / __| __ _ _  _ _ _  __ _ 
   \__ \/ _` | || | ' \/ _` |
   |___/\__,_|\_,_|_|\_\__,_|

An exercise in copypaste and cargo cult programming.
Thanks to kaeza from #ve-servers and authors of ~/.minetest/mods/**.lua

srjskam 2017

--]]

local ambient_temperature = 24

------------------------------------------------------ generic
function string.starts(String,Start)
   return string.sub(String,1,string.len(Start))==Start
end
function string.ends(String,End)
   return End=='' or string.sub(String,-string.len(End))==End
end

------------------------------------------------------ common stuff of stoves

function water_thrown(itemstack, user, pos, node)

	local meta = minetest.get_meta(pos)
	local temp = meta:get_float("sauna:temp") or 0
	local feel = meta:get_float("sauna:feel") or 0

	local feelboost = temp/500.0 * 0.6
	meta:set_float("sauna:temp", 0.9 * temp + 0.1 * 0)
	meta:set_float("sauna:feel", (1.0-feelboost) * feel + feelboost * 100)

	local timer = minetest.get_node_timer(pos)
	if timer:get_timeout() == 0 then
		timer:start(1)
	end

	minetest.sound_play("sauna_throwing_water", {
		pos=pos,
		gain = temp/500,
	})
	minetest.add_particlespawner({
		amount = 45 * temp/500,
		time = 2,
		minpos = vector.add(pos,{x=-.3, y=0, z=-.3}),
		maxpos = vector.add(pos,{x= .3, y=0, z= .3}),
		minvel = {x=-.1, y=.1, z=-.1},
		maxvel = {x= .1, y=2 , z= .1},
		minacc = {x=-.5, y=0 , z=-.5},
		maxacc = {x= .5, y=1 , z= .5},
		minexptime = 1,
		maxexptime = 2,
		minsize = 1,
		maxsize = 10,
		collisiondetection = true,
		vertical = false,
		texture = "sauna_steam.png",
		--playername = "singleplayer"
	})
end

function stove_cooling(pos, elapsed)
	local meta = minetest.get_meta(pos)
	local temp = meta:get_float("sauna:temp") or ambient_temperature
	local feel = meta:get_float("sauna:feel") or 0

	local tempstring = "cold"
	if temp > 100  then tempstring = "warm." end
	if temp > 200 then tempstring = "hot enough." end
	if temp > 450 then tempstring = "as hot as it gets." end
	
	local feelstring = "cool"
	if feel > 20  then feelstring = "warm" end
	if feel > 30  then feelstring = "hot" end
	if feel > 50 then feelstring = "hot!" end
	if feel > 70 then feelstring = "HOT!!" end
	if feel > 80  then feelstring = "scalding!" end

	meta:set_string("infotext", "Stove is "..tempstring..--" "..temp..
								"\nAir feels "..feelstring)--.." "..feel )
	meta:set_float("sauna:temp", 0.95 * temp + 0.05 * ambient_temperature)
	meta:set_float("sauna:feel", 0.95 * feel + 0.05 * 0)
 
	if temp < ambient_temperature+10 and feel < 10 
		and meta:get_int("sauna:on")==0
	then
		meta:set_string("infotext","")
		return false
	end
	return true
end

------------------------------------------------------ health effects
function good(feel)-- used for vasta too
	return feel > 30 and feel < 60
end

if minetest.setting_getbool("enable_damage") then
	minetest.register_abm({
		nodenames = { "sauna:stove_wood"    , "sauna:stove_wood_active",
					  "sauna:stove_electric", "sauna:stove_electric_active"},
		interval = 6,
		chance = 1,
		action = function(pos, node, active_object_count, active_object_count_wider)
			for _, obj in pairs(minetest.get_objects_inside_radius(pos,10)) do
				if obj:is_player() then

					local meta = minetest.get_meta(pos)
					local feel = meta:get_float("sauna:feel") or 0	
					local hp = obj:get_hp()
					local dist = vector.distance(pos, obj:getpos())
					if good(feel) then
						obj:set_hp(hp + math.ceil(2/dist) )
					elseif feel > 80 then
						obj:set_hp(hp - math.ceil(2/dist))
					elseif feel > 90 then
						obj:set_hp(hp - math.ceil(4/dist))
					end
				end
			end
		end,
	})
end

------------------------------------------------------ sauna stove wood

local formspec =
	"invsize[8,9;]"..
	"label[0,0;Sauna Stove]"..
	"list[current_name;fuel;3,1;1,1;]"..
	"image[4,1;1,1;default_furnace_fire_bg.png]"..
	"list[current_player;main;0,5;8,4;]"..
	"listring[]"
function formspec_burning(percent)
	return 
	"invsize[8, 9]"..
	"label[0, 0;Sauna Stove]"..
	"list[current_name;fuel;3, 1;1, 1;]"..
	"image[4, 1;1, 1;default_furnace_fire_bg.png^[lowpart:"..
	(percent)..":default_furnace_fire_fg.png]"..
	"list[current_player;main;0, 5;8, 4;]"..
	"listring[]"
end
for _,active in ipairs({true, false}) do
	minetest.register_node("sauna:stove_wood"..(active and "_active" or ""), {
		description = "Sauna Stove",
		drawtype="mesh",
		mesh="sauna_stove.obj",
		tiles = {"sauna_stove_wood"..(active and "_active" or "")..".png"},
		groups = {snappy=3,choppy=3,oddly_breakable_by_hand=3,flammable=0,
					sauna_stove=1,
					not_in_creative_inventory = active and 1 or 0,
		},
		paramtype="light",
		light_source = active and 5 or 0,
		paramtype2 = "facedir",
		legacy_facedir_simple = true,
		on_construct = function(pos)-----------------on_construct
			local meta = minetest.get_meta(pos)
			local inv = meta:get_inventory()
			inv:set_size("fuel", 1)
			meta:set_int("sauna:fuel_total", 0) 
			meta:set_int("sauna:fuel_left", 0) 
			meta:set_string("formspec", formspec)

			meta:set_float("sauna:temp", ambient_temperature) 
			meta:set_float("sauna:feel", 0) 
			meta:set_int("sauna:on", 0) 
		end,
		on_metadata_inventory_put = function(pos)-----------------on_metadata_inventory_put
			local timer = minetest.get_node_timer(pos)
			if timer:get_timeout() == 0 then
				timer:start(1)
			end
		end,
		on_timer = function(pos, elapsed)-------------------------on_timer
			local node = minetest.get_node(pos)
			local meta = minetest.get_meta(pos)
			local inv = meta:get_inventory()
			local fuel_total= meta:get_int("sauna:fuel_total") 
			local fuel_left= meta:get_int("sauna:fuel_left") 
			local retval = false
			if fuel_left > 0 then
				fuel_left = fuel_left -1
				meta:set_float("sauna:temp",  0.8 * meta:get_float("sauna:temp")
											+ 0.2 * 600 )
				retval = true
			else
				fuellist = inv:get_list("fuel")
				fuel, afterfuel = minetest.get_craft_result({
									method = "fuel", width = 1, 
									items= fuellist})
				if not fuel or fuel.time == 0 then
					fuel_total = 0
					meta:set_string("formspec", formspec)
					minetest.swap_node(pos, {
						name = "sauna:stove_wood",
						param2=node.param2})
					retval = false
				else
					minetest.swap_node(pos, {
						name = "sauna:stove_wood_active",
						param2=node.param2})
					inv:set_stack("fuel", 1, afterfuel.items[1])
					fuel_total = fuel.time
					fuel_left = fuel.time
					retval = true
				end
			end

			meta:set_string("formspec", formspec_burning(100.0*fuel_left/fuel_total))
			meta:set_int("sauna:fuel_total", fuel_total) 
			meta:set_int("sauna:fuel_left", fuel_left) 
			return stove_cooling(pos,elapsed) or retval

		end,
		water_thrown=water_thrown,
	})
end
minetest.register_craft({
	output = 'sauna:stove_wood',
	recipe = {
		{'', 'default:cobble', ''},
		{'technic:cast_iron_ingot', 'default:cobble', 'technic:cast_iron_ingot'},
		{'technic:cast_iron_ingot', 'technic:cast_iron_ingot', 'technic:cast_iron_ingot'},
	}
})

------------------------------------------------------ sauna stove electric

local stove_electric_demand = 1500
for foo,active in ipairs({true, false}) do
	minetest.register_node("sauna:stove_electric"..(active and "_active" or ""), {
		description = "Electric Sauna Stove",
		drawtype="mesh",
		mesh="sauna_stove.obj",
		tiles = {"sauna_stove_electric"..(active and "_active" or "")..".png"},
		groups = {snappy=3,choppy=3,oddly_breakable_by_hand=3,flammable=0,
				sauna_stove=1,
				technic_mv=1,technic_machine = 1,
				not_in_creative_inventory = active and 1 or 0,
		},
		paramtype="light",
		light_source = active and 1 or 0,
		paramtype2 = "facedir",
		legacy_facedir_simple = true,
		on_construct = function(pos)--------------------on_construct
			local meta = minetest.get_meta(pos)
			meta:set_float("sauna:temp", ambient_temperature) 
			meta:set_float("sauna:feel", 0) 
			meta:set_int("sauna:on", 0) 
			meta:set_int("HV_EU_input", 0)
			meta:set_int("MV_EU_demand", 0 )
			meta:set_int("sauna:waitforfirsttechniccycle", 1)
		end,
		on_timer = stove_cooling,
		on_rightclick = function(pos, node, player, itemstack, pointed_thing)-----on_rightclick
			local meta = minetest.get_meta(pos)
			if active then
				meta:set_int("MV_EU_demand",  0 )
				meta:set_int("sauna:on", 0) 
				minetest.swap_node(pos, {
					name = "sauna:stove_electric",
					param2=node.param2})
			else	
				-- start timer to follow temperature
				local timer = minetest.get_node_timer(pos)
				if timer:get_timeout() == 0 then
					timer:start(1)
				end
				meta:set_int("sauna:on", 1) 
				meta:set_int("MV_EU_demand",  stove_electric_demand )
				meta:set_int("sauna:waitforfirsttechniccycle", 1)	
				minetest.swap_node(pos, {
					name = "sauna:stove_electric_active", 
					param2 = node.param2})
			end
		end,
		water_thrown=water_thrown,
		technic_run = function(pos, node)--------------------technic_run
			local meta = minetest.get_meta(pos)

			-- check for power
			if  active 
				-- wait for one cycle to let technic update EI_input
				and meta:get_int("sauna:waitforfirsttechniccycle") ==0
				-- throw dice so all saunas in the net won't shut down at once
				and math.random(4) == 1 
				and meta:get_int("MV_EU_input") < meta:get_int("MV_EU_demand")
			then
				meta:set_int("sauna:on", 0)
				meta:set_int("MV_EU_demand",  0 )
 				minetest.swap_node(pos, {name = "sauna:stove_electric", 
										 param2=node.param2})
			end

			-- increase stove temperature
			if active then
				meta:set_float("sauna:temp",  0.8 * meta:get_float("sauna:temp")
											+ 0.2 * 600 ) -- 600°C ≃ red hot
			end
			meta:set_int("sauna:waitforfirsttechniccycle", 0)
		end,
		connects_to = {"technic:MV_cable","group:technic_MV", "group:technic_all_tiers"},
		connect_sides = {"bottom", "back", "left", "right"},
  		technic_disabled_machine_name = "sauna:stove_electric",
		technic_on_disable = function (pos, node)
			meta:set_int("MV_EU_demand",  0 )
			meta:set_int("sauna:on", 0) 
			technic.swap_node(pos, "sauna:stove_electric")
		end,

	})
technic.register_machine("MV", "sauna:stove_electric"..(active and "_active" or ""), technic.receiver)
end

minetest.register_craft({
	output = 'sauna:stove_electric',
	recipe = {
		{'', 'default:cobble', ''},
		{'technic:stainless_steel_ingot', 'homedecor:heating_element', 'technic:stainless_steel_ingot'},
		{'technic:stainless_steel_ingot', 'technic:mv_transformer', 'technic:stainless_steel_ingot'},
	}
})

------------------------------------------------------ scoop

minetest.register_tool("sauna:scoop", {
    description = "Sauna Scoop",
    inventory_image = "sauna_scoop.png",
	liquids_pointable = true,
	on_use = function(itemstack, user, pointed_thing)
		if pointed_thing.type == "node" then
			local node = minetest.get_node(pointed_thing.under)
			if node.name == "default:water_source" then
				return ItemStack("sauna:scoop_water")
			end
		end
		return itemstack
	end,
})
minetest.register_tool("sauna:scoop_water", {
    description = "Sauna Scoop with Water",
    inventory_image = "sauna_scoop_water.png",
	liquids_pointable = true,
	on_use = function(itemstack, user, pointed_thing)
		if pointed_thing.type == "node" then
			local node = minetest.get_node(pointed_thing.under)
			if string.starts(node.name, "sauna:stove") then
				minetest.registered_nodes[node.name].water_thrown(
							itemstack, user, pointed_thing.under, node)
				return ItemStack("sauna:scoop ")
			end
		end
		return itemstack
	end,
})

minetest.register_craft({
	output = 'sauna:scoop',
	recipe = {
		{'', '', 'default:copper_ingot'},
		{'', 'default:steel_ingot', ''},
		{'default:stick', '', ''},
	}
})
------------------------------------------------------ vasta
minetest.register_tool("sauna:vasta", {
    description = "Vasta",
    inventory_image = "sauna_vasta.png",
	liquids_pointable = true,
	on_use = function(itemstack, user, pointed_thing)
		minetest.sound_play("sauna_vasta")
		local maybepos = minetest.find_node_near(user:getpos(), 10, {"group:sauna_stove"})
		if maybepos and math.random(4)==1 then
			local meta = minetest.get_meta(maybepos)
			local feel = meta:get_float("sauna:feel") or 0	
			local hp = user:get_hp()
			if good(feel) then
				user:set_hp(hp+1)
			end
		end
		return itemstack
	end,
})


minetest.register_craft({
	output = 'sauna:vasta',
	recipe = {
		{'', 'default:aspen_leaves', 'default:aspen_leaves'},
		{'', 'default:aspen_leaves', 'default:aspen_leaves'},
		{'farming:cotton', '', ''},
	}
})

if minetest.get_modpath("moretrees") then
	minetest.register_craft({
		output = 'sauna:vasta',
		recipe = {
			{'', 'moretrees:birch_leaves', 'moretrees:birch_leaves'},
			{'', 'moretrees:birch_leaves', 'moretrees:birch_leaves'},
			{'farming:cotton', '', ''},
		}
	})
end


