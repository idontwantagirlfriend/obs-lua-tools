-- Author: idontwantagirlfriend
-- Obs adaptor functions

local obs = {}

function obs.set_text_source(source_name, text)
    local source = obslua.obs_get_source_by_name(source_name)
    local settings = obslua.obs_data_create()
    obslua.obs_data_set_string(settings, "text", text)
    obslua.obs_source_update(source, settings)
    obslua.obs_data_release(settings)
    obslua.obs_source_release(source)
end

function obs.get_text_source_names()
    local sources = obslua.obs_enum_sources()
    local source_names = {}

    if sources ~= nil then
        for _, source in ipairs(sources) do
            local source_id = obslua.obs_source_get_unversioned_id(source)
            if source_id == "text_gdiplus" or source_id == "text_ft2_source" then
                table.insert(source_names, obslua.obs_source_get_name(source))
            end
        end
        obslua.source_list_release(sources)
    end
    return source_names
end

function obs.get_scene_names()
    local scenes = obslua.obs_frontend_get_scenes()
    local scene_names = {}
    if scenes ~= nil then
        for _, scene in ipairs(scenes) do
            local name = obslua.obs_source_get_name(scene)
            table.insert(scene_names, name)
        end
    end
    return scene_names
end

function obs.switch_to_scene(scene_name)
    local scenes = obslua.obs_frontend_get_scenes()
    for _, scene in ipairs(scenes) do
        local name = obslua.obs_source_get_name(scene)
        if name == scene_name then
            obslua.obs_frontend_set_current_scene(scene)
            break
        end
    end
end

function obs.create_props()
    local props = obslua.obs_properties_create()
    return props
end

function obs.add_str_property(props, params)
    local name, label, desc = params.name or "", params.label or "", params.desc or ""
    local item = obslua.obs_properties_add_text(props, name, label, obslua.OBS_TEXT_DEFAULT)
    obslua.obs_property_set_long_description(item, desc)
    return item
end

function obs.add_int_property(props, params)
    local name, label, min, max, step, desc = params.name or "", params.label or "", params.min or 0, params.max or 100,
        params.step or 1, params.desc or ""
    local item = obslua.obs_properties_add_int(props, name, label, min, max, step)
    obslua.obs_property_set_long_description(item, desc)
    return item
end

function obs.add_bool_property(props, params)
    local name, label, desc = params.name or "", params.label or "", params.desc or ""
    local item = obslua.obs_properties_add_bool(props, name, label)
    obslua.obs_property_set_long_description(item, desc)
    return item
end

function obs.add_list_property(props, params)
    local name, label, desc, elements = params.name or "", params.label or "", params.desc or "", params.elements or {}
    local list = obslua.obs_properties_add_list(props, name, label, obslua.OBS_COMBO_TYPE_EDITABLE, obslua
        .OBS_COMBO_FORMAT_STRING)
    obslua.obs_property_set_long_description(list, desc)

    for _, element in ipairs(elements) do
        obslua.obs_property_list_add_string(list, element, element)
    end
    return list
end

function obs.add_button_property(props, params)
    local name, label, desc, callback = params.name or "", params.label or "", params.desc or "", params.callback
    local item = obslua.obs_properties_add_button(props, name, label, callback)
    obslua.obs_property_set_long_description(item, desc)
    return item
end

function obs.validate(value, expected_type_str_code)
    assert(type(value) == expected_type_str_code, "Expected " .. expected_type_str_code .. " got " .. type(value))
end

function obs.create_settings()
    local settings = obslua.obs_data_create()
    return settings
end

function obs.get_str_setting(settings, name)
    local value = obslua.obs_data_get_string(settings, name)
    return value
end

function obs.get_int_setting(settings, name)
    local value = obslua.obs_data_get_int(settings, name)
    return value
end

function obs.get_bool_setting(settings, name)
    local value = obslua.obs_data_get_bool(settings, name)
    return value
end

function obs.set_str_setting(settings, name, value, expected_type)
    obs.validate(value, expected_type)
    obslua.obs_data_set_string(settings, name, value)
end

function obs.set_int_setting(settings, name, value, expected_type)
    obs.validate(value, expected_type)
    obslua.obs_data_set_int(settings, name, value)
end

function obs.set_bool_setting(settings, name, value, expected_type)
    obs.validate(value, expected_type)
    obslua.obs_data_set_bool(settings, name, value)
end

obs.timer = {
    add = function(func, interval)
        obslua.timer_add(func, interval)
        return func
    end,
    remove = function(timer)
        obslua.timer_remove(timer)
    end
}

-- A Singleton that stores settings for countdown functions

State = {}
State.__index = State

function State._new()
    local state = setmetatable({}, State)
    return state
end

function State.get_instance()
    if State._instance == nil then
        State._instance = State._new()
    end
    return State._instance
end

-- Time format helper methods

local template = {}
function template.create_template(format_config)
    local format_parts = {}
    if format_config.hours_visible then
        table.insert(format_parts, "%H")
    end
    if format_config.mins_visible then
        table.insert(format_parts, "%M")
    end
    if format_config.secs_visible then
        table.insert(format_parts, "%S")
    end

    return table.concat(format_parts, ":")
end

function template.fit_to_template(seconds, template_str, is_local)
    if is_local == false then
        return os.date("!" .. template_str, seconds)
    end
    return os.date(template_str, seconds)
end

function template.extract_config_from(settings)
    return {
        hours_visible = obs.get_bool_setting(settings, "hours_visible"),
        mins_visible = obs.get_bool_setting(settings, "mins_visible"),
        secs_visible = obs.get_bool_setting(settings, "secs_visible")
    }
end

-- Calculator functions used in timer

local function calc_timespan(timespan_info)
    local start_hour, start_min, end_hour, end_min = timespan_info.start_hour, timespan_info.start_min,
        timespan_info.end_hour, timespan_info.end_min
    local timespan = ((end_hour - start_hour) * 3600 + (end_min - start_min) * 60) % 86400
    return timespan
end

local function extract_timespan_info_from(settings)
    return {
        start_hour = obs.get_int_setting(settings, "start_hour"),
        start_min = obs.get_int_setting(settings, "start_min"),
        end_hour = obs.get_int_setting(settings, "end_hour"),
        end_min = obs.get_int_setting(settings, "end_min")
    }
end

-- Main workflow functions

local function is_selected(source_name)
    return source_name and source_name ~= "[No source selected]" and source_name ~= ""
end

local function format_clock(settings, local_timestamp)
    local format_config = template.extract_config_from(settings)
    local template_str = template.create_template(format_config)
    local formatted_clock = template.fit_to_template(local_timestamp, template_str, true)
    return formatted_clock
end
local function set_clock_text(clock_text, settings)
    local clock_source_name = obs.get_str_setting(settings, "clock_source")
    if is_selected(clock_source_name) then
        obs.set_text_source(clock_source_name, clock_text)
    end
end

--
local function calc_countdown(settings, timestamp_now)
    local timespan_info = extract_timespan_info_from(settings)
    local time_now = os.date("*t", timestamp_now)
    local now_hour, now_min, now_sec = time_now.hour, time_now.min, time_now.sec
    local end_hour, end_min = timespan_info.end_hour, timespan_info.end_min

    local countdown = (end_hour - now_hour) * 3600 + (end_min - now_min) * 60 - now_sec
    local force_next_day = obs.get_bool_setting(settings, "force_next_day")
    if countdown < 0 and force_next_day then
        countdown = countdown + 86400
    end
    return countdown
end

local function format_countdown(countdown, settings)
    if countdown > 0 then
        local timespan_info = extract_timespan_info_from(settings)
        local format_config = template.extract_config_from(settings)
        local template_str = template.create_template(format_config)
        return template.fit_to_template(math.min(countdown, calc_timespan(timespan_info)), template_str, false)
    end
    return obs.get_str_setting(settings, "timeout_text")
end


local function set_countdown_text(settings, countdown_text)
    local countdown_source = obs.get_str_setting(settings, "countdown_source")
    if is_selected(countdown_source) then
        obs.set_text_source(countdown_source, countdown_text)
    end
end

local function stopwatch_tick(settings_state)
    local settings = settings_state.settings
    local timestamp_now = os.time()

    local clock_text = format_clock(settings, timestamp_now)
    set_clock_text(clock_text, settings)

    local countdown = calc_countdown(settings, timestamp_now)
    local countdown_text = format_countdown(countdown, settings)
    set_countdown_text(settings, countdown_text)

    local scene_name = obs.get_str_setting(settings, "timeout_scene")
    if countdown == 0 and scene_name ~= "[No scene selected]" and scene_name ~= "" then
        obs.switch_to_scene(scene_name)
    end
end

local function reset_stopwatch(props, prop)
    local state = State.get_instance()
    if state.activate_timer ~= nil then
        obs.timer.remove(state.activate_timer)
    end
    local activate_timer = function()
        stopwatch_tick(state.settings_state)
    end
    state.activate_timer = obs.timer.add(activate_timer, 500)
end

local function stop_stopwatch(props, prop)
    local state = State.get_instance()
    if state.activate_timer ~= nil then
        obs.timer.remove(state.activate_timer)
    end
end

-- Obs standard interface functions

function script_description()
    return "Load the current time and a countdown to the specified text sources."
end

function script_defaults(settings)
    local state = State.get_instance()
    state.settings_state = {}

    obs.set_bool_setting(settings, "live_update", true, "boolean")
    obs.set_bool_setting(settings, "hours_visible", true, "boolean")
    obs.set_bool_setting(settings, "mins_visible", true, "boolean")
    obs.set_bool_setting(settings, "secs_visible", true, "boolean")
    obs.set_bool_setting(settings, "force_next_day", false, "boolean")
    obs.set_int_setting(settings, "start_hour", 0, "number")
    obs.set_int_setting(settings, "start_min", 0, "number")
    obs.set_int_setting(settings, "end_hour", 1, "number")
    obs.set_int_setting(settings, "end_min", 0, "number")
    obs.set_str_setting(settings, "timeout_text", "Final Run!", "string")

    reset_stopwatch(nil, nil)

    state.settings_state.settings = settings
end

function script_properties()
    local props = obs.create_props()
    obs.add_bool_property(props, {
        name = "live_update",
        label = "Live update",
        desc = "Any change on settings immediately gets updated.",
    })
    local source_names = obs.get_text_source_names()
    obs.add_list_property(props, {
        name = "clock_source",
        label = "Clock source",
        desc = "The text source to display the current time.",
        elements = { "[No source selected]", unpack(source_names) }
    })
    -- unpack is deprecated in lua54, but obs-studio uses lua53
    obs.add_list_property(props, {
        name = "countdown_source",
        label = "Countdown source",
        desc = "The text source to display the remaining time.",
        elements = { "[No source selected]", unpack(source_names) }
    })
    obs.add_int_property(props, {
        name = "start_hour",
        label = "Start hour",
        min = 0,
        max = 23,
        step = 1
    })
    obs.add_int_property(props, {
        name = "start_min",
        label = "Start minute",
        min = 0,
        max = 59,
        step = 1
    })
    obs.add_int_property(props, {
        name = "end_hour",
        label = "End hour",
        min = 0,
        max = 23,
        step = 1
    })
    obs.add_int_property(props, {
        name = "end_min",
        label = "End minute",
        min = 0,
        max = 59,
        step = 1
    })
    obs.add_str_property(props, {
        name = "timeout_text",
        label = "Timeout text",
        desc = "The text to display when time runs out.",
    })
    obs.add_bool_property(props, {
        name = "force_next_day",
        label = "Force next day",
        desc =
        "Whether the end hour is considered to be on the following day. Especially useful when the countdown goes overnight.",
    })

    obs.add_bool_property(props, {
        name = "hours_visible",
        label = "Display hours"
    })
    obs.add_bool_property(props, {
        name = "mins_visible",
        label = "Display minutes"
    })
    obs.add_bool_property(props, {
        name = "secs_visible",
        label = "Display seconds"
    })

    local scene_names = obs.get_scene_names()
    obs.add_list_property(props, {
        name = "timeout_scene",
        label = "Timeout scene",
        entries = { "[No scene selected]", unpack(scene_names) },
        desc = "The scene to switch to when the countdown terminates.",
    })

    obs.add_button_property(props, {
        name = "restart_button",
        label = "Restart countdown",
        callback = reset_stopwatch
    })

    obs.add_button_property(props, {
        name = "stop_button",
        label = "Stop countdown",
        callback = stop_stopwatch
    })

    return props
end

function script_update(settings)
    local state = State.get_instance()
    if not obs.get_bool_setting(state.settings_state.settings, "live_update") then
        state.settings_state = {}
    end
    state.settings_state.settings = settings
end

return {
    script_description = script_description,
    script_defaults = script_defaults,
    script_properties = script_properties,
    script_update = script_update,
}
