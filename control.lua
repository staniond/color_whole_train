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

function on_train_changed_state(event)
    if event.old_state ~= defines.train_state.wait_station then
        return -- handle only train_left_station events
    end

    color_train_if_set(event.train)
end

script.on_event(defines.events.on_train_changed_state, on_train_changed_state)
