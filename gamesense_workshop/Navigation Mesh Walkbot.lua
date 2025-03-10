--local variables for API. Automatically generated by https://github.com/simpleavaster/gslua/blob/master/authors/sapphyrus/generate_api.lua
local client_get_cvar, client_camera_position, client_create_interface, client_random_int, client_latency, client_set_clan_tag, client_find_signature, client_log, client_timestamp, client_delay_call = client.get_cvar, client.camera_position, client.create_interface, client.random_int, client.latency, client.set_clan_tag, client.find_signature, client.log, client.timestamp, client.delay_call 
local client_draw_indicator, client_trace_line, client_draw_circle, client_draw_line, client_draw_text, client_register_esp_flag, client_get_model_name, client_system_time, client_visible, client_exec = client.draw_indicator, client.trace_line, client.draw_circle, client.draw_line, client.draw_text, client.register_esp_flag, client.get_model_name, client.system_time, client.visible, client.exec 
local client_key_state, client_set_cvar, client_unix_time, client_error_log, client_draw_debug_text, client_update_player_list, client_camera_angles, client_eye_position, client_draw_hitboxes, client_random_float = client.key_state, client.set_cvar, client.unix_time, client.error_log, client.draw_debug_text, client.update_player_list, client.camera_angles, client.eye_position, client.draw_hitboxes, client.random_float 
local entity_get_local_player, entity_is_enemy, entity_get_bounding_box, entity_get_all, entity_set_prop, entity_is_alive, entity_get_steam64, entity_get_classname, entity_get_player_resource, entity_get_esp_data, entity_is_dormant = entity.get_local_player, entity.is_enemy, entity.get_bounding_box, entity.get_all, entity.set_prop, entity.is_alive, entity.get_steam64, entity.get_classname, entity.get_player_resource, entity.get_esp_data, entity.is_dormant 
local entity_get_player_name, entity_get_game_rules, entity_get_origin, entity_hitbox_position, entity_get_player_weapon, entity_get_players, entity_get_prop = entity.get_player_name, entity.get_game_rules, entity.get_origin, entity.hitbox_position, entity.get_player_weapon, entity.get_players, entity.get_prop 
local globals_realtime, globals_absoluteframetime, globals_chokedcommands, globals_oldcommandack, globals_tickcount, globals_commandack, globals_lastoutgoingcommand, globals_curtime = globals.realtime, globals.absoluteframetime, globals.chokedcommands, globals.oldcommandack, globals.tickcount, globals.commandack, globals.lastoutgoingcommand, globals.curtime 
local globals_mapname, globals_tickinterval, globals_framecount, globals_frametime, globals_maxplayers = globals.mapname, globals.tickinterval, globals.framecount, globals.frametime, globals.maxplayers 
local ui_new_slider, ui_new_combobox, ui_reference, ui_set_visible, ui_new_textbox, ui_new_color_picker, ui_new_checkbox, ui_mouse_position, ui_new_listbox, ui_new_multiselect, ui_is_menu_open, ui_new_hotkey = ui.new_slider, ui.new_combobox, ui.reference, ui.set_visible, ui.new_textbox, ui.new_color_picker, ui.new_checkbox, ui.mouse_position, ui.new_listbox, ui.new_multiselect, ui.is_menu_open, ui.new_hotkey 
local ui_set, ui_menu_size, ui_name, ui_menu_position, ui_set_callback, ui_new_button, ui_new_label, ui_new_string, ui_get = ui.set, ui.menu_size, ui.name, ui.menu_position, ui.set_callback, ui.new_button, ui.new_label, ui.new_string, ui.get 
local client_world_to_screen, client_draw_rectangle, client_draw_circle_outline, client_userid_to_entindex, client_draw_gradient, client_set_event_callback, client_screen_size, client_trace_bullet, client_unset_event_callback, client_color_log, client_reload_active_scripts, client_scale_damage = client.world_to_screen, client.draw_rectangle, client.draw_circle_outline, client.userid_to_entindex, client.draw_gradient, client.set_event_callback, client.screen_size, client.trace_bullet, client.unset_event_callback, client.color_log, client.reload_active_scripts, client.scale_damage

local sourcenav = require "gamesense/sourcenav"
local navmesh_raw = nil
local navmesh = nil
local graph = {}
local ignoreConnection = {}
local forbiddenWaypoint = {}
local path = {}
local waypoint = {nil}
local follow_target = nil
local lastStuckHandleTick = 999999999999
local lastPointRemoved = nil
local stuckAttempts = 0
local currMap = globals_mapname()

-- menu
local m_enable = ui_new_checkbox("Misc", "Movement", "Enable walkbot")
local m_target_type = ui_new_combobox("Misc", "Movement", "Walkbot target", "Waypoint", "Closest enemy", "Teammate")
local m_option_type = ui_new_multiselect("Misc", "Movement", "Walkbot options", "Lock view angle", "Rand waypt if no enemy")
local m_end_waypoint = ui_new_hotkey("Misc", "Movement", "Set end waypoint")
local m_calculate_path = ui_new_hotkey("Misc", "Movement", "Calculate path")
local m_remove_point = ui_new_hotkey("Misc", "Movement", "Remove point")
local m_follow_target = ui_new_textbox("Misc", "Movement", "Target")

local ref_enable_aa = ui_reference("AA", "Anti-aimbot angles", "Enabled")
local ref_easy_strafe = ui_reference("Misc", "Movement", "Easy strafe")

local nav_area_attributes = {
    CROUCH = 0x1, --must crouch to use this node/area
    JUMP = 0x2, --must jump to traverse this area (only used during generation)
    PRECISE = 0x4,	--do not adjust for obstacles, just move along area
    NO_JUMP = 0x8,	--inhibit discontinuity jumping
    STOP = 0x10, --must stop when entering this area
    RUN = 0x20,	--must run to traverse this area
    WALK = 0x40, --must walk to traverse this area
    AVOID = 0x80, --avoid this area unless alternatives are too dangerous
    TRANSIENT = 0x100, --area may become blocked, and should be periodically checked
    DONT_HIDE = 0x200, --area should not be considered for hiding spot generation
    STAND = 0x400, --bots hiding in this area should stand
    NO_HOSTAGES = 0x800, --hostages shouldn't use this area
    STAIRS = 0x1000, --this area represents stairs, do not attempt to climb or jump them - just walk up
    NO_MERGE = 0x2000, --don't merge this area with adjacent areas
    OBSTACLE_TOP = 0x4000, --this nav area is the climb point on the tip of an obstacle
    CLIFF = 0x8000, --this nav area is adjacent to a drop of at least CliffHeight

    FIRST_CUSTOM = 0x10000, --apps may define custom app-specific bits starting with this value
    LAST_CUSTOM = 0x4000000, --apps must not define custom app-specific bits higher than with this value
    FUNC_COST = 0x20000000, --area has designer specified cost controlled by func_nav_cost entities

    HAS_ELEVATOR = 0x40000000, --area is in an elevator's path
    NAV_BLOCKER = 0x80000000, --area is blocked by nav blocker ( Alas, needed to hijack a bit in the attributes to get within a cache line [7/24/2008 tom])
}
-- credits to sapphyrus for this
local buttons = {
    IDLE = 0x0, 
    IN_ATTACK = 0x1,
    IN_JUMP = 0x2,
    IN_DUCK = 0x4, 
    IN_FORWARD = 0x8,
    IN_BACK = 0x10,
    IN_USE = 0x20,
    IN_CANCEL = 0x40,
    IN_LEFT = 0x80,
    IN_RIGHT = 0x100,
    IN_MOVELEFT = 0x200,
    IN_MOVERIGHT = 0x400,
    IN_ATTACK2 = 0x800,
    IN_RUN = 0x1000,
    IN_RELOAD = 0x2000,
    IN_ALT1 = 0x4000,
    IN_ALT2 = 0x8000,
    IN_SCORE = 0x10000,
    IN_WALK =  0x20000
}

--[[ TODO: 

    -- break vents and glass,
    -- plant bomb
    -- defuse bomb
    -- recalculate when stuck
    -- avoid molly

    maybe??
    -- listen to bot says 

]]

local INF = 1/0
local cachedPaths = nil

local function dist_between_node(nodeA, nodeB)
    return math.sqrt(math.pow(nodeB.x - nodeA.x, 2) + math.pow(nodeB.y - nodeA.y, 2) + math.pow(nodeB.z - nodeA.z, 2 ))
end

local function heuristic_cost_estimate(nodeA, nodeB)
    local cost = dist_between_node(nodeA, nodeB) - (5 * nodeA.encounter_paths_count)
    if cost < 0 then cost = 0 end
    return cost
end

local function is_valid_node(node,neighbor)
    return true
end

local function lowest_f_score(set, f_score)

    local lowest, bestNode = INF, nil
    for _, node in ipairs(set) do
        local score = f_score[node]
        if score < lowest then
            lowest, bestNode = score, node
        end
    end
    return bestNode
end

local function neighbor_nodes(selectedNode, nodes)

    local neighbors = {}
    for _, node in ipairs(nodes) do
        if selectedNode ~= node and is_valid_node(selectedNode, node) then
            table.insert(neighbors, node)
        end
    end
    return neighbors
end

local function not_in(set,selectedNode)

    for _, node in ipairs(set) do
        if node == selectedNode then return false end
    end
    return true
end

local function remove_node(set, selectedNode)

    for i, node in ipairs(set) do
        if node == selectedNode then 
            set[i] = set[#set]
            set[#set] = nil
            break
        end
    end 
end

local function unwind_path( flat_path, map, current_node )

    if map[current_node] then
        table.insert(flat_path, 1, map[current_node]) 
        return unwind_path(flat_path, map, map [current_node])
    else
        return flat_path
    end
end


local function a_star(start, goal, nodes, valid_node_func)

    local closedset = {}
    local openset = {start}
    local came_from = {}

    if valid_node_func then is_valid_node = valid_node_func end

    local g_score, f_score = {}, {}
    g_score [start] = 0
    f_score [start] = g_score[start] + heuristic_cost_estimate(start, goal)

    while #openset > 0 do
    
        local current = lowest_f_score(openset, f_score)
        if current == goal then
            local path = unwind_path({}, came_from, goal)
            table.insert(path, goal)
            return path
        end

        remove_node(openset, current)	   
        table.insert(closedset, current)
        
        local neighbors = neighbor_nodes(current, nodes)
        for _, neighbor in ipairs(neighbors) do 
            if not_in (closedset, neighbor) then
                local tentative_g_score = g_score[current] + dist_between_node(current, neighbor)
                 
                if not_in (openset, neighbor) or tentative_g_score < g_score[neighbor] then 
                    came_from[neighbor] = current
                    g_score[neighbor] = tentative_g_score
                    f_score[neighbor] = g_score [neighbor] + heuristic_cost_estimate(neighbor, goal)
                    if not_in(openset, neighbor) then
                        table.insert(openset, neighbor)
                    end
                end
            end
        end
    end
    return nil -- no valid path
end

local function clear_cached_paths ()
    cachedPaths = nil
end

local function a_star_path(start, goal, nodes, ignore_cache, valid_node_func)

    if not cachedPaths then cachedPaths = {} end
    if not cachedPaths[start] then
        cachedPaths[start ] = {}
    elseif cachedPaths[start][goal] and not ignore_cache then
        return cachedPaths[start][goal]
    end

      local resPath = a_star(start, goal, nodes, valid_node_func)
      if not cachedPaths[start][goal] and not ignore_cache then
            cachedPaths[start][goal] = resPath
      end

    return resPath
end

------------------------------------------------------------------------------------------------

local function get_mid_pt(init, final)
    return (init + final) / 2
end

local function distance1D (x1, x2)  
    return math.sqrt(math.pow(x2 - x1, 2 ))
end

local function distance2D (x1, y1, x2, y2)  
    return math.sqrt(math.pow(x2 - x1, 2) + math.pow(y2 - y1, 2))
end

local function distance3D (x1, y1, z1, x2, y2, z2)
    return math.sqrt(math.pow(x2 - x1, 2) + math.pow(y2 - y1, 2) + math.pow(z2 - z1, 2))
end

local function time_to_ticks(time)
    return math.floor(time / globals_tickinterval() + .5)
end

local function point_in_area(p, x_min, y_min, x_max, y_max)
    return (p[1] <= x_max and p[1] >= x_min) and (p[2] <= y_max and p[2] >= y_min)
end

local function rotate_3d(distance, location_x, location_y, yaw)
    local locationXAngle = location_x + math.cos(math.rad(yaw)) * distance
    local locationYAngle = location_y + math.sin(math.rad(yaw)) * distance

    return locationXAngle, locationYAngle
end

local function normaliseAngle(y)
    while y < 0 do
        y = y + 360
    end
    while y > 360 or y == 360 do
        y = y - 360
    end
    return y
end

local function reset_variables()
    graph = {}
    path = nil
    waypoint = {nil}
    ignoreConnection = {}
    forbiddenWaypoint = {}
end

local function vector_angles(x1, y1, z1, x2, y2, z2)
    --https://github.com/ValveSoftware/source-sdk-2013/blob/master/sp/src/mathlib/mathlib_base.cpp#L535-L563
    local origin_x, origin_y, origin_z
    local target_x, target_y, target_z
    if x2 == nil then
        target_x, target_y, target_z = x1, y1, z1
        origin_x, origin_y, origin_z = client_eye_position()
        if origin_x == nil then
            return
        end
    else
        origin_x, origin_y, origin_z = x1, y1, z1
        target_x, target_y, target_z = x2, y2, z2
    end

    --calculate delta of vectors
    local delta_x, delta_y, delta_z = target_x-origin_x, target_y-origin_y, target_z-origin_z

    if delta_x == 0 and delta_y == 0 then
        return (delta_z > 0 and 270 or 90), 0
    else
        --calculate yaw
        local yaw = math.deg(math.atan2(delta_y, delta_x))

        --calculate pitch
        local hyp = math.sqrt(math.pow(delta_x,2) + math.pow(delta_y,2))
        local pitch = math.deg(math.atan2(-delta_z, hyp))

        return pitch, yaw
    end
end

local function draw_circle(c, x, y, r, g, b, a, radius)
    client_draw_circle(c, x, y, 0, 0, 0, 150, radius+1, 0, 1.0) 
    client_draw_circle(c, x, y, r, g, b, a, radius, 0, 1.0)
end

local function get_local_origin()
    local localPlayer = entity_get_local_player()
    if localPlayer == nil then 
        return nil
    end

    local lx, ly, lz = entity_get_origin(localPlayer)
    if lx == nil then 
        return nil
    end

    return lx, ly, lz
end

local function save_to_graph()
    if navmesh_raw ~= nil then
        for i, areas in ipairs(navmesh.areas) do
            local midX, midY, midZ = get_mid_pt(areas.north_west.x,areas.south_east.x),get_mid_pt(areas.north_west.y,areas.south_east.y), get_mid_pt(areas.north_east_z, areas.south_west_z)	
            graph[i] = areas
            graph[i].x = midX
            graph[i].y = midY
            graph[i].z = midZ   
        end
    end
end

local function load_nav_mesh()
    if entity_get_local_player() == nil then 
        return
    end
      reset_variables()
    if sourcenav == nil then
        client_error_log("please subscribe to https://gamesense.pub/forums/viewtopic.php?id=18492")
        return
    end
    currMap = globals_mapname()
    navmesh_raw = nil
    navmesh_raw = readfile("csgo/maps/" .. currMap .. ".nav")
    if navmesh_raw  ~= nil then
        navmesh = sourcenav.parse(navmesh_raw)
        save_to_graph() 
    else 
        client_error_log("navigation mesh not found, please run 'nav_generate' in console")
    end
end

local function draw_flags(node)
    local wX1, wY1 = client_world_to_screen(c, node.x, node.y, node.z)
    
    if wX1 ~= nil then  
        local text = ""
        -- really ghetto ik
        if (bit.band(node.flags, nav_area_attributes.JUMP) == nav_area_attributes.JUMP) then
            text = text .. "JUMP:"
        end
        if (bit.band(node.flags, nav_area_attributes.WALK) == nav_area_attributes.WALK) then
            text = text .. "WALK:"
        end
        if (bit.band(node.flags, nav_area_attributes.CROUCH) == nav_area_attributes.CROUCH) then
            text = text .. "CROUCH:"
        end
        if (bit.band(node.flags, nav_area_attributes.PRECISE) == nav_area_attributes.PRECISE)   then
            text = text .. "PRECISE:"
        end
        if (bit.band(node.flags, nav_area_attributes.NO_JUMP) == nav_area_attributes.NO_JUMP)   then
            text = text .. "NO_JUMP:"
        end
        if (bit.band(node.flags, nav_area_attributes.AVOID) == nav_area_attributes.AVOID)   then
            text = text .. "AVOID:"
        end
        if (bit.band(node.flags, nav_area_attributes.TRANSIENT) == nav_area_attributes.TRANSIENT)   then
            text = text .. "TRANSIENT:"
        end
        if (bit.band(node.flags, nav_area_attributes.OBSTACLE_TOP) == nav_area_attributes.OBSTACLE_TOP) then
            text = text .. "OBSTACLE_TOP:"
        end
        if (bit.band(node.flags, nav_area_attributes.CLIFF) == nav_area_attributes.CLIFF)   then
            text = text .. "CLIFF:"
        end
        if (bit.band(node.flags, nav_area_attributes.STAIRS) == nav_area_attributes.STAIRS) then
            text = text .. "STAIRS:"
        end
        if (bit.band(node.flags, nav_area_attributes.NO_MERGE) == nav_area_attributes.NO_MERGE) then
            text = text .. "NO_MERGE:"
        end
        if (bit.band(node.flags, nav_area_attributes.FIRST_CUSTOM) == nav_area_attributes.FIRST_CUSTOM) then
            text = text .. "FIRST_CUSTOM:"
        end
        if (bit.band(node.flags, nav_area_attributes.LAST_CUSTOM) == nav_area_attributes.LAST_CUSTOM)   then
            text = text .. "LAST_CUSTOM:"
        end
        if (bit.band(node.flags, nav_area_attributes.FUNC_COST) == nav_area_attributes.FUNC_COST)   then
            text = text .. "FUNC_COST:"
        end
        if (bit.band(node.flags, nav_area_attributes.HAS_ELEVATOR) == nav_area_attributes.HAS_ELEVATOR) then
            text = text .. "HAS_ELEVATOR:"
        end
        if (bit.band(node.flags, nav_area_attributes.NAV_BLOCKER) == nav_area_attributes.NAV_BLOCKER)   then
            text = text .. "NAV_BLOCKER:"
        end
        client_draw_text(c, wX1, wY1, 255, 255, 255, 255, "c", 0, text)
    end
end

local valid_node_func = function ( node, neighbor ) 

    for i, con in ipairs(ignoreConnection) do
        if con.id == neighbor.id then
            return false
        end
    end

    if (bit.band(neighbor.flags, nav_area_attributes.OBSTACLE_TOP) == nav_area_attributes.OBSTACLE_TOP) then
        return false
    end

    -- loop through all the connections from curr node
    for i, connDir in ipairs(node.connections) do
        for k, target in ipairs(connDir.connections) do
            if target == neighbor.id then




                return true
            end
        end
    end

    return false
end
local function get_inc_from_area_id(id)
    for i, node in ipairs(graph) do
        if node.id == id then
            return i
        end
    end
    return 1
end
local function draw_mesh(node)

    local lx, ly, lz = get_local_origin()
    if lx == nil then
        return
    end

    -- only draw when in vicinity 
    if distance3D(node.x, node.y, node.z,lx, ly, lz) > 500 then
        return
    end

    local wX1, wY1 = client_world_to_screen(c, node.x, node.y, node.z)
    --client_draw_text(c, wX1, wY1, 255, 255, 255, 255, "c", 0, node.id .. ":" .. node.encounter_paths_count)
    draw_flags(node)
    
    -- draw the cross
    local NW_wX, NW_wY = client_world_to_screen(c, node.north_west.x, node.north_west.y, node.north_west.z)
    local SE_wX, SE_wY = client_world_to_screen(c, node.south_east.x, node.south_east.y, node.south_east.z)
    local NE_wX, NE_wY = client_world_to_screen(c, node.south_east.x, node.north_west.y, node.north_east_z)
    local SW_wX, SW_wY = client_world_to_screen(c, node.north_west.x, node.south_east.y, node.south_west_z)
    
    client_draw_line(c, NW_wX, NW_wY, NE_wX, NE_wY, 0, 0, 0, 255)
    client_draw_line(c, SW_wX, SW_wY, SE_wX, SE_wY, 0, 0, 0, 255)
    client_draw_line(c, NW_wX, NW_wY, SW_wX, SW_wY, 0, 0, 0, 255)
    client_draw_line(c, NE_wX, NE_wY, SE_wX, SE_wY, 0, 0, 0, 255)
end

local function get_closest_area(x1,y1,z1)
    local closestNode = graph[1]
    for i, node in ipairs(graph) do
        
        if distance3D(closestNode.x, closestNode.y, closestNode.z, x1, y1, z1) > distance3D(node.x, node.y, node.z, x1, y1, z1) then
            closestNode = node
        end	 
    end
    return closestNode
end

local function draw_path()
    if path ~= nil then
        local prevNode = nil
        for i, node in ipairs (path) do
            local wX1, wY1 = client_world_to_screen(c, node.x, node.y, node.z)
            local pwX1, pwY1 = nil
            if prevNode ~= nil then
                pwX1, pwY1 = client_world_to_screen(c, prevNode.x, prevNode.y, prevNode.z)
            end
        
            if wX1 ~= nil then

                draw_circle(c, wX1, wY1, 72, 133, 237, 255, 2)
                if pwX1 ~= nil then
                    client_draw_line(c, wX1, wY1, pwX1, pwY1, 72, 133, 237, 255)
                end
            --  client_draw_text(c, wX1, wY1, 255, 255, 255, 255, "c", 0, i)	
            end
            
            prevNode = node
        end 
    end

    if waypoint[1] ~= nil then
        local closestNode = get_closest_area( waypoint[1], waypoint[2], waypoint[3])
        local height = 15
        local width = 5
        local wX1, wY1 = client_world_to_screen(c, closestNode.x, closestNode.y, closestNode.z)
        if wX1 ~= nil then
            -- draw border
            local border = 1
            renderer.triangle(wX1 - width - border, wY1 - height - border, wX1 + width + border ,wY1 - height - border, wX1, wY1 + border, 0,0,0,250)
            renderer.triangle(wX1 - width, wY1 - height, wX1 + width ,wY1 - height, wX1, wY1, 219,50,54,255)


            draw_circle(c, wX1, wY1 - height, 219, 50, 54, 255, width)
            draw_circle(c, wX1, wY1 - height, 100, 50, 54, 255, 1)
        end
    end
end

local function calculate_path(x1, y1, z1, x2, y2, z2)
    if x1 == nil or x2 == nil then
        path = nil
    else
        local closestNodeLocal = get_closest_area(x1, y1, z1)
        local closestNodeWaypoint = get_closest_area(x2, y2, z2)
        local closestNodeLocalInc = get_inc_from_area_id(closestNodeLocal.id)
        local closestNodeWaypointInc = get_inc_from_area_id(closestNodeWaypoint.id)

        -- prevent fps drops when no path is found
        for i, node in ipairs(forbiddenWaypoint) do
            if node.id == closestNodeWaypoint.id then
                path = nil
                return
            end
        end

        if closestNodeLocalInc ~= -1 and closestNodeWaypointInc ~= -1 then
            path = a_star_path(graph[closestNodeLocalInc], graph[closestNodeWaypointInc], graph, false, valid_node_func )
            if path == nil then
                table.insert(forbiddenWaypoint, closestNodeWaypoint)
            end
        end
    end
end

local function remove_next_point()
    lastPointRemoved = path[1]
    table.remove(path, 1)
    --remove the waypoint when finished
    lastStuckHandleTick = globals_tickcount()
    if #path <= 0 then
        waypoint = {nil}
    end
end

local function get_closest_enemy()
    local lx, ly, lz = get_local_origin()
    if lx == nil then 
        return
    end

    local closestEnemy = nil
    for i = 1, 64 do -- for dormant players too
        if entity_get_classname(i) == "CCSPlayer" then 
            if entity_is_enemy(i) then
                if entity_is_alive(i) and entity_get_origin(i) ~= nil then
                    if closestEnemy == nil then
                        closestEnemy = i
                    else
                        local ex, ey, ez = entity_get_origin(i)
                        local cx, cy, cz = entity_get_origin(closestEnemy)
                
                        if distance3D(lx, ly, lz, cx, cy, cz) > distance3D(lx, ly, lz, ex, ey, ez) then
                            closestEnemy = i
                        end
                    end
                end
            end
        end
    end

    return closestEnemy
end

local function get_predict_node(yaw)
    local lx, ly, lz = get_local_origin()
    if lx == nil then
        return
    end
    lx, ly = rotate_3d(20, lx, ly, yaw)
 
    for i, node in ipairs(graph) do
        if point_in_area({lx, ly}, node.north_west.x, node.north_west.y, node.south_east.x, node.south_east.y) then
            return node
        end
    end
end

local function handle_movement(cmd)
    local lx, ly, lz = get_local_origin()
    if lx == nil then 
        return
    end

    if path ~= nil and #path > 0 then 
        -- needs to be on for inorder for IN_FORWARD to work
        if ui_get(ref_easy_strafe) == false then
            ui_set(ref_easy_strafe, true)
        end

        local _, yaw = vector_angles(lx, ly, lz, path[1].x, path[1].y, path[1].z)
        yaw = normaliseAngle(yaw)
        cmd.move_yaw = yaw

        local option_type = ui_get(m_option_type)
        for i = 1, #option_type do
            local name = option_type[i]
            if name == "Lock view angle" then
                cmd.yaw = yaw
                ui_set(ref_enable_aa, true)
            end
        end

        cmd.buttons = bit.bor(cmd.buttons, buttons.IN_FORWARD)

        if distance3D(lx, ly, lz ,path[1].x, path[1].y, path[1].z) < 50 then
            if bit.band(graph[get_inc_from_area_id(path[1].id)].flags, nav_area_attributes.JUMP) == nav_area_attributes.JUMP then
                cmd.buttons = bit.bor(cmd.buttons, buttons.IN_JUMP, buttons.IN_DUCK)
            elseif bit.band(graph[get_inc_from_area_id(path[1].id)].flags, nav_area_attributes.CROUCH) == nav_area_attributes.CROUCH then
                cmd.buttons = bit.bor(cmd.buttons, buttons.IN_DUCK)
            end
        end

        -- helps with crouching
        local preNode = get_predict_node(yaw)
        if preNode ~= nil then
            if bit.band(graph[get_inc_from_area_id(preNode.id)].flags, nav_area_attributes.CROUCH) == nav_area_attributes.CROUCH then
                cmd.buttons = bit.bor(cmd.buttons, buttons.IN_DUCK)
            end
        end

        -- kidda ghetto but who the fuck cares
        local CDynamicProp = entity_get_all("CDynamicProp")
        for i, ent in ipairs(CDynamicProp) do
            local ox, oy, oz = entity_get_origin(ent)
            if distance3D(ox, oy, oz,lx, ly, lz) < 50 then
                cmd.yaw = yaw
                cmd.buttons = bit.bor(cmd.buttons, buttons.IN_ATTACK)
            end 
        end

        -- do the door opening shit
        local ent = entity_get_all("CPropDoorRotating")
        for i, door in ipairs(ent) do
            local orig = {entity_get_origin(door)}
            orig[3] = orig[3] + 50
            -- check that im in the vicinity
            if distance3D(lx, ly, lz + 50, orig[1], orig[2], orig[3]) < 50 then
                local infrontX, infrontY, infrontZ = rotate_3d(50, lx, ly, yaw)
                local trace = client_trace_line(entity_get_local_player(), lx, ly, lz + 50, infrontX, infrontY, lz + 50)

                -- door should be shut
                if trace < 0.9 then
                    cmd.buttons = bit.bor(cmd.buttons, buttons.IN_USE)
                end
            end
        end
    end
end

local function set_waypoint_origin()
    local lx, ly, lz = get_local_origin()
    if lx == nil then 
        return
    end

    waypoint = {lx, ly, lz} 
end

local function set_waypoint_teammate()
    if follow_target ~= nil then
        if entity_is_alive(follow_target) then
            local px, py, pz = entity_get_origin(follow_target)
            waypoint = {px, py, pz} 
        end
    end
end

local function update_follow_target()
    for i, player in ipairs(entity_get_players()) do
        local currName = entity_get_player_name(player)
        if currName == ui_get(m_follow_target) then 
            follow_target = player
        end
    end
end

local function set_waypoint_enemy()
    local lx, ly, lz = get_local_origin()
    if lx == nil then 
        return
    end

    local closestEnemy = get_closest_enemy()
    if closestEnemy ~= nil then
        local cx, cy, cz = entity_get_origin(closestEnemy)
        waypoint = {cx, cy, cz}
    end

    return closestEnemy
end

local function set_pathway()
    local lx, ly, lz = get_local_origin()
    if lx == nil then 
        return
    end 
    calculate_path(lx, ly, lz, waypoint[1], waypoint[2], waypoint[3])
end

local function set_waypoint_rand()
    local lx, ly, lz = get_local_origin()
    if lx == nil then 
        return
    end

    if graph ~= nil and #graph > 0 then
        local randNode = graph[client_random_int(1, #graph)]
        waypoint = {randNode.x,randNode.y,randNode.z}
    end
end

local function handle_closest_enemy()
    -- reset the ignore connections
    ignoreConnection = {}

    local closestEnemy = set_waypoint_enemy()
    if closestEnemy == nil then
        local option_type = ui_get(m_option_type)
        for i = 1, #option_type do
            local name = option_type[i]
            if name == "Rand waypt if no enemy" then
                set_waypoint_rand()
            end
        end
    end

    set_pathway()
end

load_nav_mesh()

local function on_paint(c)
    if not ui_get(m_enable) then
        return
    end

    if navmesh_raw == nil then
        return
    end

    draw_path()

--	for i, node in ipairs(graph) do
--		draw_mesh(node)
--	end
end

local function handle_stuck(cmd)
    if stuckAttempts == 0 then
        cmd.buttons = bit.bor(cmd.buttons, buttons.IN_JUMP)
        stuckAttempts = stuckAttempts + 1
    else
        table.insert(ignoreConnection, path[1])
        set_pathway()
        stuckAttempts = 0
    end
    lastStuckHandleTick = globals_tickcount()
end

local function on_setup_command(cmd)
    if not ui_get(m_enable) then
        return
    end

    -- pretty shit but fixes some issue on map change
    if not currMap == globals_mapname() then
        load_nav_mesh()
        return
    end

    if navmesh_raw == nil then
        return
    end

--  local m_bIsScoped = entity_get_prop(entity_get_local_player(), "m_bIsScoped")   
--  if m_bIsScoped == 0 then 
    --  cmd.buttons = bit.bor(cmd.buttons, buttons.IN_ATTACK2)
--  end

    local targetType = ui_get(m_target_type)
    if targetType == "Waypoint" then
        if ui_get(m_end_waypoint) then
            set_waypoint_origin()
        end
        if ui_get(m_calculate_path) then
            set_pathway()
        end
    elseif targetType == "Closest enemy" then
        if path == nil or #path <= 0 then
            handle_closest_enemy()  
        end 
    elseif targetType == "Teammate" then
        if path == nil or #path <= 0 then
            set_waypoint_teammate()
            set_pathway()
            if ui_is_menu_open() then
                update_follow_target()
            end
        end
    end

    handle_movement(cmd)

    if path ~= nil and #path > 0 then
        local lx, ly, lz = get_local_origin()
        if lx == nil then
            return
        end

        if distance3D(lx, ly, lz, path[1].x, path[1].y, path[1].z) < 50 or ui_get(m_remove_point) then  
            remove_next_point()
        end

        -- check if stuck
        if lastStuckHandleTick + time_to_ticks(4) < globals_tickcount() then
            handle_stuck(cmd)
        end
    end
end

local function on_player_spawn(e)
    if not ui_get(m_enable) then
        return
    end
    if navmesh_raw == nil then
        return
    end
    if client_userid_to_entindex(e.userid) == entity_get_local_player() then
        if ui_get(m_target_type) == "Closest enemy" then
            handle_closest_enemy()
        end
    end
end

local function on_player_connect_full(e)
    if not ui_get(m_enable) then
        return
    end
    if client_userid_to_entindex(e.userid) == entity_get_local_player() then
        clear_cached_paths()
        load_nav_mesh()
    end
end

local function on_round_prestart(e)
    if not ui_get(m_enable) then
        return
    end
    if navmesh_raw == nil then
        return
    end

    local targetType = ui_get(m_target_type)
    if targetType == "Closest enemy" then   
        set_waypoint_enemy()
    elseif targetType == "Teammate" then
        set_waypoint_teammate()
    end

    client_delay_call(0.5, set_pathway)
end

local function on_player_death(e)
    if not ui_get(m_enable) then
        return
    end
    if navmesh_raw == nil then
        return
    end
    if ui_get(m_target_type) == "Closest enemy" and client_userid_to_entindex(e.attacker) == entity_get_local_player() or client_userid_to_entindex(e.assister) == entity_get_local_player() then
        client_delay_call(0.1, handle_closest_enemy)
    end
end

local function handle_menu()
    if ui_get(m_enable) then
        path = nil
        waypoint = {nil}
        ui_set_visible(m_target_type, true)
        ui_set_visible(m_option_type, true)
        local targetType = ui_get(m_target_type)
        if targetType == "Waypoint" then
            ui_set_visible(m_calculate_path, true)
            ui_set_visible(m_remove_point, true)
            ui_set_visible(m_end_waypoint, true)
            ui_set_visible(m_follow_target, false)
        elseif targetType == "Closest enemy" then
            ui_set_visible(m_calculate_path, false)
            ui_set_visible(m_remove_point, false)
            ui_set_visible(m_end_waypoint, false)
            ui_set_visible(m_follow_target, false)
        elseif targetType == "Teammate" then
            ui_set_visible(m_calculate_path, false)
            ui_set_visible(m_remove_point, false)
            ui_set_visible(m_end_waypoint, false)
            ui_set_visible(m_follow_target, true)
        end
    else
        ui_set_visible(m_target_type, false)
        ui_set_visible(m_calculate_path, false)
        ui_set_visible(m_remove_point, false)
        ui_set_visible(m_end_waypoint, false)
        ui_set_visible(m_follow_target, false)
        ui_set_visible(m_option_type, false)
    end
end

ui_set_callback(m_enable, handle_menu)
ui_set_callback(m_target_type, handle_menu)
handle_menu()

client_set_event_callback("paint", on_paint)
client_set_event_callback("setup_command", on_setup_command)
client_set_event_callback("player_spawn", on_player_spawn)
client_set_event_callback("player_connect_full", on_player_connect_full)
client_set_event_callback("round_prestart", on_round_prestart)
client_set_event_callback("player_death", on_player_death)