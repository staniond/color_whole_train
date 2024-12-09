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

--- Returns the color of the first locomotive that has the
--- 'copy_color_from_train_stop' setting set, nil if no such locomotive is on the train.
---@param train LuaTrain
---@return Color?
function get_new_color(train)
	for _, locomotive in ipairs(train.locomotives.front_movers) do
		if locomotive.copy_color_from_train_stop then
            return locomotive.color
		end
	end
	for _, locomotive in ipairs(train.locomotives.back_movers) do
		if locomotive.copy_color_from_train_stop then
            return locomotive.color
		end
	end
    return nil
end

--- Colors wagons of this train to the color of next station,
--- if at least one locomotive of this train has the
--- 'copy_color_from_train_stop' set. The color is copied from
--- such a locomotive.
---@param train LuaTrain
function color_train_if_set(train)
    local new_color = get_new_color(train)
    if not new_color then
        return
    end

	for _, wagon in ipairs(train.cargo_wagons) do
        wagon.color = new_color
	end
	for _, wagon in ipairs(train.fluid_wagons) do
        wagon.color = new_color
	end
end

--------------------cybersyn trains handling-----------------------
--- cybersyn trains need special handling as their schedule can be
--- changed dynamically and so the train color might have to be changed even
--- when they are not leaving station
--- (new order received when going to depot, refueling needed etc.)

function cybersyn_train_status_changed(event)
    local s = event.new_status
    if s ~= STATUS_TO_P and
       s ~= STATUS_TO_R and
       s ~= STATUS_TO_F and
       s ~= STATUS_TO_D and
       s ~= STATUS_TO_D_BYPASS
    then
        return -- handle only when train is leaving station
    end

    local train = remote.call("cybersyn", "get_train", event.train_id)
    color_train_if_set(train.entity)
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

function on_train_changed_state(event)
    if event.old_state ~= defines.train_state.wait_station then
        return -- handle only train_left_station events
    end

    ---@type LuaTrain
    local train = event.train

    if script.active_mods["cybersyn"] and is_cybersyn_train(train.id) then
        return -- let cybersyn code handle cybersyn trains
    end

    color_train_if_set(train)
end


if script.active_mods["cybersyn"] then
    script.on_init(register_cybersyn_on_train_status_changed)
    script.on_load(register_cybersyn_on_train_status_changed)
end
script.on_event(defines.events.on_train_changed_state, on_train_changed_state)
