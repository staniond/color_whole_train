-- cybersyn train statuses
-- copied from cybersyn constants file
STATUS_D = 0
STATUS_TO_P = 1
STATUS_P = 2
STATUS_TO_R = 3
STATUS_R = 4
STATUS_TO_D = 5
STATUS_TO_D_BYPASS = 6
STATUS_TO_F = 7
STATUS_F = 8

--------------------General train function-----------------------

---@param train LuaTrain
---@param color Color
function color_train(train, color)
	for _, carriage in ipairs(train.carriages) do
		carriage.color = color
	end
end

--- Return true if at least one locomotive has the
--- copy_color_from_train_stop option set
---@param train LuaTrain
---@return boolean
function train_has_color_by_destination_set(train)
	for _, locomotive in ipairs(train.locomotives.front_movers) do
		if locomotive.copy_color_from_train_stop then
            return true
		end
	end
	for _, locomotive in ipairs(train.locomotives.back_movers) do
		if locomotive.copy_color_from_train_stop then
            return true
		end
	end
    return false
end

---@param train LuaTrain
---@param color Color
function color_train_if_set(train, color)
    if train_has_color_by_destination_set(train) then
        color_train(train, color)
    end
end

--------------------cybersyn trains handling-----------------------

function cybersyn_train_status_changed(event)
    local train = remote.call("cybersyn", "get_train", event.train_id)

    local next_station = nil
    if event.new_status == STATUS_TO_P then
        next_station = remote.call("cybersyn", "get_station", train.p_station_id).entity_stop
    elseif event.new_status == STATUS_TO_R then
        next_station = remote.call("cybersyn", "get_station", train.r_station_id).entity_stop
    elseif event.new_status == STATUS_TO_D or event.new_status == STATUS_TO_D_BYPASS then
        next_station = remote.call("cybersyn", "get_depot", train.depot_id).entity_stop
    elseif event.new_status == STATUS_TO_F then
        next_station = remote.call("cybersyn", "get_refueler", train.refueler_id).entity_stop
    else
        --other events we are not interested in
        return
    end

    if next_station then
        color_train_if_set(train.entity, next_station.color)
    end
end

--- @param train_id uint
--- @return boolean
function is_cybersyn_train(train_id)
    local cybersyn_train = remote.call("cybersyn", "get_train", train_id)
    return cybersyn_train ~= nil
end

function register_cybersyn_on_train_status_changed()
    local on_cybersyn_train_status_changed_event = remote.call("cybersyn", "get_on_train_status_changed")
    script.on_event(on_cybersyn_train_status_changed_event, cybersyn_train_status_changed)
end


--------------------vanilla trains handling-----------------------

--- @param surface LuaSurface
--- @param station_name string
--- @return LuaEntity?
--- Returns the first station found with the given name on the given surface.
--- Nil if none found.
function find_station_by_name(surface, station_name)
    -- TODO this is expensive, precompute a table with all station's colors on_load/on_init
    -- and just do a lookup here + catch on_entity_color_changed + on_built_entity + on_robot_built_entity
    for _,train_station in pairs(surface.find_entities_filtered {name="train-stop"}) do
        if train_station.backer_name == station_name then
            return train_station
        end
    end
    return nil
end

function on_train_changed_state(event)
    ---@type LuaTrain
    local train = event.train

    if event.old_state ~= defines.train_state.wait_station then
        return -- handle only train_left_station events
    end

    if script.active_mods["cybersyn"] and is_cybersyn_train(train.id) then
        return -- let cybersyn code handle cybersyn trains
    end

    local next_station_name = train.schedule.records[train.schedule.current].station
    if not next_station_name then
        return -- station name nil, cannot color (probably a temporary stop)
    end

    local train_surface = train.carriages[1].surface -- assume train has at least 1 carriage
    local next_station = find_station_by_name(train_surface, next_station_name)
    if not next_station then
        return -- no station with name from train schedule found, should never happen
    end
    color_train_if_set(train, next_station.color)
end

--------------------event handler registering-----------------------

if script.active_mods["cybersyn"] then
    script.on_init(register_cybersyn_on_train_status_changed)
    script.on_load(register_cybersyn_on_train_status_changed)
end
script.on_event(defines.events.on_train_changed_state, on_train_changed_state)
