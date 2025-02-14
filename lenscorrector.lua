--[[
    Lenscorrector Professional
    Advanced Lens Correction Filter for OBS
    Author: TheGeekFreaks Copyright (c) 2025
]]

-- Required OBS modules
local obs = obslua
local bit = require("bit")

-- Translations
local translations = {
    DE = {
        -- Haupteinstellungen
        filter_name = "Objektivkorrektur Pro",
        strength = "Stärke",
        center_x = "Zentrum X",
        center_y = "Zentrum Y",
        
        -- Erweiterte Einstellungen
        advanced_settings = "Erweiterte Einstellungen",
        fine_tune = "Feinabstimmung",
        quality = "Qualität",
        quality_low = "Niedrig",
        quality_medium = "Mittel",
        quality_high = "Hoch",
        performance_mode = "Performance-Modus",
        
        -- Visuelle Hilfen
        visual_aids = "Visuelle Hilfen",
        show_grid = "Gitter anzeigen",
        grid_type = "Gittertyp",
        grid_standard = "Standard",
        grid_perspective = "Perspektive",
        grid_diagonal = "Diagonal",
        grid_golden = "Goldener Schnitt",
        grid_opacity = "Gitter Transparenz",
        grid_color = "Gitterfarbe",
        grid_size = "Gittergröße",
        split_screen = "Geteilter Bildschirm",
        split_position = "Teilungsposition",
        language = "Sprache",
        
        -- Brennweiten
        focal_length = "Brennweite",
        focal_length_custom = "Benutzerdefiniert",
        
        -- Kameraprofil
        camera_profile = "Kameraprofil",
        profile_name = "Profilname",
        save_profile = "Profil speichern",
        load_profile = "Profil laden",
        profile_saved = "Profil erfolgreich gespeichert",
        profile_loaded = "Profil erfolgreich geladen",
        profile_save_failed = "Fehler beim Speichern des Profils",
        profile_load_failed = "Fehler beim Laden des Profils"
    },
    EN = {
        -- Main Settings
        filter_name = "Lens Correction Pro",
        strength = "Strength",
        center_x = "Center X",
        center_y = "Center Y",
        
        -- Advanced Settings
        advanced_settings = "Advanced Settings",
        fine_tune = "Fine Tuning",
        quality = "Quality",
        quality_low = "Low",
        quality_medium = "Medium",
        quality_high = "High",
        performance_mode = "Performance Mode",
        
        -- Visual Aids
        visual_aids = "Visual Aids",
        show_grid = "Show Grid",
        grid_type = "Grid Type",
        grid_standard = "Standard",
        grid_perspective = "Perspective",
        grid_diagonal = "Diagonal",
        grid_golden = "Golden Ratio",
        grid_opacity = "Grid Opacity",
        grid_color = "Grid Color",
        grid_size = "Grid Size",
        split_screen = "Split Screen",
        split_position = "Split Position",
        language = "Language",
        
        -- Focal Length
        focal_length = "Focal Length",
        focal_length_custom = "Custom",
        
        -- Camera Profile
        camera_profile = "Camera Profile",
        profile_name = "Profile Name",
        save_profile = "Save Profile",
        load_profile = "Load Profile",
        profile_saved = "Profile saved successfully",
        profile_loaded = "Profile loaded successfully",
        profile_save_failed = "Failed to save profile",
        profile_load_failed = "Failed to load profile"
    }
}

-- Lens focal length presets
local FOCAL_LENGTH_PRESETS = {
    { focal_length = 8,   power = -0.45, name = "8mm",  note = "Extremes Fisheye (zirkular)" },
    { focal_length = 10,  power = -0.40, name = "10mm", note = "Sehr starke Verzerrung" },
    { focal_length = 12,  power = -0.35, name = "12mm", note = "Starkes Fisheye" },
    { focal_length = 14,  power = -0.30, name = "14mm", note = "Deutliches Fisheye" },
    { focal_length = 16,  power = -0.25, name = "16mm", note = "Typisches diagonales Fisheye" },
    { focal_length = 18,  power = -0.20, name = "18mm", note = "Weitwinkel mit Fisheye" },
    { focal_length = 20,  power = -0.17, name = "20mm", note = "Weitwinkel" },
    { focal_length = 24,  power = -0.14, name = "24mm", note = "Starker Weitwinkel" },
    { focal_length = 28,  power = -0.11, name = "28mm", note = "Moderater Weitwinkel" },
    { focal_length = 35,  power = -0.08, name = "35mm", note = "Klassisches Reportage-Weitwinkel" },
    { focal_length = 40,  power = -0.06, name = "40mm", note = "Leichter Weitwinkel" },
    { focal_length = 50,  power = -0.03, name = "50mm", note = "Normalobjektiv" },
    { focal_length = 70,  power = -0.01, name = "70mm", note = "Leichtes Tele" },
    { focal_length = 100, power = 0.00,  name = "100mm", note = "Tele" }
}

-- Constants for settings
local SETTING_FOCAL_LENGTH = "focal_length"
local SETTING_FISH_POWER = "fish_power"
local SETTING_FINE_TUNING = "fine_tuning"
local SETTING_CENTER_X = "center_x"
local SETTING_CENTER_Y = "center_y"
local SETTING_QUALITY = "quality"
local SETTING_PERFORMANCE_MODE = "performance_mode"
local SETTING_SHOW_GRID = "show_grid"
local SETTING_GRID_TYPE = "grid_type"
local SETTING_GRID_OPACITY = "grid_opacity"
local SETTING_GRID_COLOR = "grid_color"
local SETTING_GRID_SIZE = "grid_size"
local SETTING_SPLIT_SCREEN = "split_screen"
local SETTING_SPLIT_POSITION = "split_position"
local SETTING_LANGUAGE = "language"
local SETTING_CAMERA_PROFILE = "camera_profile"
local SETTING_PROFILE_NAME = "profile_name"

-- Quality levels
local QUALITY_LOW = 1
local QUALITY_MEDIUM = 2
local QUALITY_HIGH = 3

-- Grid types
local GRID_STANDARD = 1
local GRID_PERSPECTIVE = 2
local GRID_DIAGONAL = 3
local GRID_GOLDEN = 4

-- Optimized local references
local obs_data_get_double = obs.obs_data_get_double
local obs_data_get_bool = obs.obs_data_get_bool
local obs_data_get_int = obs.obs_data_get_int
local obs_data_get_string = obs.obs_data_get_string

-- Current language
local current_lang = "DE"

-- Translation function
local function L(key)
    if not translations[current_lang] then
        current_lang = "EN"
    end
    return translations[current_lang][key] or key
end

-- Profile management
local camera_profiles = {}
local profiles_path = script_path() .. "profiles"

-- Ensure profiles directory exists
local function ensure_profiles_directory()
    local success = os.execute('if not exist "' .. profiles_path .. '" mkdir "' .. profiles_path .. '"')
    return success
end

-- Get list of available profiles
local function get_profile_list()
    local profiles = {}
    local handle = io.popen('dir "' .. profiles_path .. '" /b')
    if handle then
        for file in handle:lines() do
            if file:match("%.json$") then
                profiles[#profiles + 1] = file:gsub("%.json$", "")
            end
        end
        handle:close()
    end
    return profiles
end

-- Save current settings as profile
local function save_profile(settings, profile_name)
    if not ensure_profiles_directory() then
        return false
    end
    
    -- Create a table with all settings
    local data = obs.obs_data_create()
    
    -- Save all settings
    obs.obs_data_set_string(data, "focal_length", obs.obs_data_get_string(settings, SETTING_FOCAL_LENGTH))
    obs.obs_data_set_double(data, "fish_power", obs.obs_data_get_double(settings, SETTING_FISH_POWER))
    obs.obs_data_set_double(data, "center_x", obs.obs_data_get_double(settings, SETTING_CENTER_X))
    obs.obs_data_set_double(data, "center_y", obs.obs_data_get_double(settings, SETTING_CENTER_Y))
    obs.obs_data_set_double(data, "fine_tune", obs.obs_data_get_double(settings, SETTING_FINE_TUNING))
    obs.obs_data_set_string(data, "quality", obs.obs_data_get_string(settings, SETTING_QUALITY))
    obs.obs_data_set_bool(data, "performance_mode", obs.obs_data_get_bool(settings, SETTING_PERFORMANCE_MODE))
    obs.obs_data_set_bool(data, "grid", obs.obs_data_get_bool(settings, SETTING_SHOW_GRID))
    obs.obs_data_set_string(data, "grid_type", obs.obs_data_get_string(settings, SETTING_GRID_TYPE))
    obs.obs_data_set_double(data, "grid_opacity", obs.obs_data_get_double(settings, SETTING_GRID_OPACITY))
    obs.obs_data_set_string(data, "grid_color", obs.obs_data_get_string(settings, SETTING_GRID_COLOR))
    obs.obs_data_set_double(data, "grid_size", obs.obs_data_get_double(settings, SETTING_GRID_SIZE))
    obs.obs_data_set_bool(data, "split_screen", obs.obs_data_get_bool(settings, SETTING_SPLIT_SCREEN))
    obs.obs_data_set_double(data, "split_position", obs.obs_data_get_double(settings, SETTING_SPLIT_POSITION))
    
    -- Get JSON string
    local json_str = obs.obs_data_get_json(data)
    obs.obs_data_release(data)
    
    -- Save to file
    local file = io.open(profiles_path .. "/" .. profile_name .. ".json", "w")
    if file then
        file:write(json_str)
        file:close()
        obs.script_log(obs.LOG_INFO, "Profile saved to: " .. profiles_path .. "/" .. profile_name .. ".json")
        return true
    end
    
    obs.script_log(obs.LOG_WARNING, "Failed to open file for writing: " .. profiles_path .. "/" .. profile_name .. ".json")
    return false
end

-- Load profile
local function load_profile(settings, profile_name)
    local file = io.open(profiles_path .. "/" .. profile_name .. ".json", "r")
    if file then
        local content = file:read("*all")
        file:close()
        
        local data = obs.obs_data_create_from_json(content)
        if data then
            obs.obs_data_set_string(settings, SETTING_FOCAL_LENGTH, obs.obs_data_get_string(data, "focal_length"))
            obs.obs_data_set_double(settings, SETTING_FISH_POWER, obs.obs_data_get_double(data, "fish_power"))
            obs.obs_data_set_double(settings, SETTING_CENTER_X, obs.obs_data_get_double(data, "center_x"))
            obs.obs_data_set_double(settings, SETTING_CENTER_Y, obs.obs_data_get_double(data, "center_y"))
            obs.obs_data_set_double(settings, SETTING_FINE_TUNING, obs.obs_data_get_double(data, "fine_tune"))
            obs.obs_data_set_string(settings, SETTING_QUALITY, obs.obs_data_get_string(data, "quality"))
            obs.obs_data_set_bool(settings, SETTING_PERFORMANCE_MODE, obs.obs_data_get_bool(data, "performance_mode"))
            obs.obs_data_set_bool(settings, SETTING_SHOW_GRID, obs.obs_data_get_bool(data, "grid"))
            obs.obs_data_set_string(settings, SETTING_GRID_TYPE, obs.obs_data_get_string(data, "grid_type"))
            obs.obs_data_set_double(settings, SETTING_GRID_OPACITY, obs.obs_data_get_double(data, "grid_opacity"))
            obs.obs_data_set_string(settings, SETTING_GRID_COLOR, obs.obs_data_get_string(data, "grid_color"))
            obs.obs_data_set_double(settings, SETTING_GRID_SIZE, obs.obs_data_get_double(data, "grid_size"))
            obs.obs_data_set_bool(settings, SETTING_SPLIT_SCREEN, obs.obs_data_get_bool(data, "split_screen"))
            obs.obs_data_set_double(settings, SETTING_SPLIT_POSITION, obs.obs_data_get_double(data, "split_position"))
            
            obs.obs_data_release(data)
            return true
        end
    end
    return false
end

-- Source definition
local source_def = {}
source_def.id = 'filter-lens-correct-pro'
source_def.type = obs.OBS_SOURCE_TYPE_FILTER
source_def.output_flags = bit.bor(
    obs.OBS_SOURCE_VIDEO,
    obs.OBS_SOURCE_CUSTOM_DRAW
)

local source_ref = nil

local function set_render_size(filter)
    local target = obs.obs_filter_get_target(filter.context)
    local width, height
    
    if target == nil then
        width, height = 0, 0
    else
        width = obs.obs_source_get_base_width(target)
        height = obs.obs_source_get_base_height(target)
    end
    
    filter.width = width
    filter.height = height
end

source_def.get_name = function()
    return L("filter_name")
end

source_def.create = function(settings, source)
    local filter = {}
    filter.context = source
    source_ref = source
    
    set_render_size(filter)
    
    obs.obs_enter_graphics()
    filter.effect = obs.gs_effect_create(shader_text, nil, nil)
    
    if filter.effect ~= nil then
        filter.params = {}
        filter.params.fish_power = obs.gs_effect_get_param_by_name(filter.effect, 'fish_power')
        filter.params.fine_tuning = obs.gs_effect_get_param_by_name(filter.effect, 'fine_tuning')
        filter.params.center_x = obs.gs_effect_get_param_by_name(filter.effect, 'center_x')
        filter.params.center_y = obs.gs_effect_get_param_by_name(filter.effect, 'center_y')
        filter.params.texture_width = obs.gs_effect_get_param_by_name(filter.effect, 'texture_width')
        filter.params.texture_height = obs.gs_effect_get_param_by_name(filter.effect, 'texture_height')
        filter.params.show_grid = obs.gs_effect_get_param_by_name(filter.effect, 'show_grid')
        filter.params.grid_type = obs.gs_effect_get_param_by_name(filter.effect, 'grid_type')
        filter.params.grid_opacity = obs.gs_effect_get_param_by_name(filter.effect, 'grid_opacity')
        filter.params.grid_color = obs.gs_effect_get_param_by_name(filter.effect, 'grid_color')
        filter.params.grid_size = obs.gs_effect_get_param_by_name(filter.effect, 'grid_size')
        filter.params.split_screen = obs.gs_effect_get_param_by_name(filter.effect, 'split_screen')
        filter.params.split_position = obs.gs_effect_get_param_by_name(filter.effect, 'split_position')
        filter.params.quality = obs.gs_effect_get_param_by_name(filter.effect, 'quality')
    end
    obs.obs_leave_graphics()
    
    if filter.effect == nil then
        source_def.destroy(filter)
        return nil
    end
    
    source_def.update(filter, settings)
    return filter
end

source_def.destroy = function(filter)
    if filter.effect ~= nil then
        obs.obs_enter_graphics()
        obs.gs_effect_destroy(filter.effect)
        obs.obs_leave_graphics()
    end
end

source_def.get_width = function(filter)
    return filter.width
end

source_def.get_height = function(filter)
    return filter.height
end

source_def.update = function(filter, settings)
    local focal_length = obs.obs_data_get_string(settings, SETTING_FOCAL_LENGTH)
    if focal_length ~= "custom" then
        local focal_num = tonumber(focal_length)
        for _, preset in ipairs(FOCAL_LENGTH_PRESETS) do
            if preset.focal_length == focal_num then
                filter.fish_power = preset.power
                break
            end
        end
    else
        filter.fish_power = obs.obs_data_get_double(settings, SETTING_FISH_POWER)
    end
    
    filter.fine_tuning = obs_data_get_double(settings, SETTING_FINE_TUNING)
    filter.center_x = obs_data_get_double(settings, SETTING_CENTER_X)
    filter.center_y = obs_data_get_double(settings, SETTING_CENTER_Y)
    
    -- Performance-Modus Logik
    filter.performance_mode = obs.obs_data_get_bool(settings, SETTING_PERFORMANCE_MODE)
    local quality = obs.obs_data_get_int(settings, SETTING_QUALITY)
    if filter.performance_mode and quality > 2 then
        quality = 2  -- Beschränke Qualität auf Mittel im Performance-Modus
    end
    filter.quality = quality
    
    filter.show_grid = obs.obs_data_get_bool(settings, SETTING_SHOW_GRID)
    filter.grid_type = obs.obs_data_get_int(settings, SETTING_GRID_TYPE)
    filter.grid_opacity = obs_data_get_double(settings, SETTING_GRID_OPACITY)
    filter.grid_color = obs.obs_data_get_int(settings, SETTING_GRID_COLOR)
    filter.grid_size = obs_data_get_double(settings, SETTING_GRID_SIZE)
    filter.split_screen = obs.obs_data_get_bool(settings, SETTING_SPLIT_SCREEN)
    filter.split_position = obs_data_get_double(settings, SETTING_SPLIT_POSITION)
    
    local new_lang = obs_data_get_string(settings, SETTING_LANGUAGE)
    if new_lang and new_lang ~= current_lang then
        current_lang = new_lang
    end
    
    set_render_size(filter)
end

source_def.video_render = function(filter, effect)
    if not obs.obs_source_process_filter_begin(filter.context, obs.GS_RGBA, obs.OBS_NO_DIRECT_RENDERING) then
        return
    end
    
    local total_power = filter.fish_power + (filter.fine_tuning * 0.01)
    
    obs.gs_effect_set_float(filter.params.fish_power, total_power)
    obs.gs_effect_set_float(filter.params.center_x, filter.center_x / 100.0)
    obs.gs_effect_set_float(filter.params.center_y, filter.center_y / 100.0)
    obs.gs_effect_set_float(filter.params.texture_width, filter.width)
    obs.gs_effect_set_float(filter.params.texture_height, filter.height)
    obs.gs_effect_set_bool(filter.params.show_grid, filter.show_grid)
    obs.gs_effect_set_int(filter.params.grid_type, filter.grid_type)
    obs.gs_effect_set_float(filter.params.grid_opacity, filter.grid_opacity)
    
    -- Convert hex color to vec4 (BGR to RGB)
    local color_vec = obs.vec4()
    color_vec.x = bit.band(filter.grid_color, 0xFF) / 255.0                  -- B -> R
    color_vec.y = bit.band(bit.rshift(filter.grid_color, 8), 0xFF) / 255.0   -- G -> G
    color_vec.z = bit.band(bit.rshift(filter.grid_color, 16), 0xFF) / 255.0  -- R -> B
    color_vec.w = 1.0
    obs.gs_effect_set_vec4(filter.params.grid_color, color_vec)
    
    local actual_grid_size = math.max(0.01, math.min(1.0, filter.grid_size / 100.0))
    obs.gs_effect_set_float(filter.params.grid_size, actual_grid_size)
    
    obs.gs_effect_set_bool(filter.params.split_screen, filter.split_screen)
    obs.gs_effect_set_float(filter.params.split_position, filter.split_position / 100.0)
    obs.gs_effect_set_int(filter.params.quality, filter.quality)
    
    obs.obs_source_process_filter_end(filter.context, filter.effect, filter.width, filter.height)
end

source_def.get_properties = function()
    local props = obs.obs_properties_create()
    
    -- Profile management
    local profile_group = obs.obs_properties_create()
    
    -- Profile selection
    local profile_list = obs.obs_properties_add_list(profile_group, SETTING_CAMERA_PROFILE,
        L("camera_profile"), obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
    
    -- Add profiles to list
    local profiles = get_profile_list()
    for _, profile_name in ipairs(profiles) do
        obs.obs_property_list_add_string(profile_list, profile_name, profile_name)
    end
    
    -- Profile name input and save/load buttons
    obs.obs_properties_add_text(profile_group, SETTING_PROFILE_NAME, L("profile_name"), obs.OBS_TEXT_DEFAULT)
    
    obs.obs_properties_add_button(profile_group, "save_profile", L("save_profile"),
        function(props, prop)
            local settings = obs.obs_source_get_settings(source_ref)
            if not settings then
                obs.script_log(obs.LOG_WARNING, "Could not get source settings")
                return true
            end
            
            local profile_name = obs.obs_data_get_string(settings, SETTING_PROFILE_NAME)
            if not profile_name or profile_name == "" then
                obs.script_log(obs.LOG_WARNING, "No profile name specified")
                obs.obs_data_release(settings)
                return true
            end
            
            obs.script_log(obs.LOG_INFO, "Attempting to save profile: " .. profile_name)
            
            if save_profile(settings, profile_name) then
                obs.script_log(obs.LOG_INFO, L("profile_saved"))
                
                -- Refresh profile list
                local list_prop = obs.obs_properties_get(profile_group, SETTING_CAMERA_PROFILE)
                if list_prop then
                    obs.obs_property_list_clear(list_prop)
                    local profiles = get_profile_list()
                    for _, name in ipairs(profiles) do
                        obs.obs_property_list_add_string(list_prop, name, name)
                    end
                end
                
                -- Update the settings
                obs.obs_data_set_string(settings, SETTING_CAMERA_PROFILE, profile_name)
            else
                obs.script_log(obs.LOG_WARNING, L("profile_save_failed"))
            end
            
            obs.obs_data_release(settings)
            return true
        end)
    
    obs.obs_properties_add_button(profile_group, "load_profile", L("load_profile"),
        function(props, prop)
            local settings = obs.obs_source_get_settings(source_ref)
            local profile_name = obs.obs_data_get_string(settings, SETTING_CAMERA_PROFILE)
            
            if profile_name and profile_name ~= "" then
                if load_profile(settings, profile_name) then
                    obs.script_log(obs.LOG_INFO, L("profile_loaded"))
                else
                    obs.script_log(obs.LOG_WARNING, L("profile_load_failed"))
                end
            end
            
            obs.obs_data_release(settings)
            return true
        end)
    
    obs.obs_properties_add_group(props, "profile_management", L("camera_profile"), obs.OBS_GROUP_NORMAL, profile_group)
    
    -- Language selection
    local p = obs.obs_properties_add_list(props, SETTING_LANGUAGE, L("language"),
        obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
    obs.obs_property_list_add_string(p, "Deutsch", "DE")
    obs.obs_property_list_add_string(p, "English", "EN")
    
    -- Haupteinstellungen
    local main_group = obs.obs_properties_create()
    
    -- Brennweiten-Voreinstellungen
    local focal_list = obs.obs_properties_add_list(main_group, SETTING_FOCAL_LENGTH, L("focal_length"),
        obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
    obs.obs_property_list_add_string(focal_list, L("focal_length_custom"), "custom")
    
    -- Füge alle Brennweiten mit Notizen hinzu
    for _, preset in ipairs(FOCAL_LENGTH_PRESETS) do
        local display_name = string.format("%s - %s", preset.name, preset.note)
        obs.obs_property_list_add_string(focal_list, display_name, tostring(preset.focal_length))
    end
    
    -- Callback für Brennweiten-Änderungen
    obs.obs_property_set_modified_callback(focal_list, function(props, property, settings)
        local focal_length = obs.obs_data_get_string(settings, SETTING_FOCAL_LENGTH)
        
        -- Finde das passende Preset
        if focal_length ~= "custom" then
            local focal_num = tonumber(focal_length)
            for _, preset in ipairs(FOCAL_LENGTH_PRESETS) do
                if preset.focal_length == focal_num then
                    obs.obs_data_set_double(settings, SETTING_FISH_POWER, preset.power)
                    break
                end
            end
        end
        
        return true
    end)
    
    obs.obs_properties_add_float_slider(main_group, SETTING_FISH_POWER, L("strength"), -0.5, 0.5, 0.01)
    obs.obs_properties_add_float_slider(main_group, SETTING_CENTER_X, L("center_x"), 0.0, 100.0, 0.01)
    obs.obs_properties_add_float_slider(main_group, SETTING_CENTER_Y, L("center_y"), 0.0, 100.0, 0.01)
    obs.obs_properties_add_group(props, "main_settings", L("filter_name"), obs.OBS_GROUP_NORMAL, main_group)

    -- Erweiterte Einstellungen
    local advanced_group = obs.obs_properties_create()
    obs.obs_properties_add_float_slider(advanced_group, SETTING_FINE_TUNING, L("fine_tune"), -100.0, 100.0, 0.1)
    
    local quality_list = obs.obs_properties_add_list(advanced_group, SETTING_QUALITY, L("quality"), 
        obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_INT)
    obs.obs_property_list_add_int(quality_list, L("quality_low"), QUALITY_LOW)
    obs.obs_property_list_add_int(quality_list, L("quality_medium"), QUALITY_MEDIUM)
    obs.obs_property_list_add_int(quality_list, L("quality_high"), QUALITY_HIGH)
    
    obs.obs_properties_add_bool(advanced_group, SETTING_PERFORMANCE_MODE, L("performance_mode"))
    obs.obs_properties_add_group(props, "advanced_settings", L("advanced_settings"), obs.OBS_GROUP_NORMAL, advanced_group)

    -- Visuelle Hilfen
    local visual_group = obs.obs_properties_create()
    obs.obs_properties_add_bool(visual_group, SETTING_SHOW_GRID, L("show_grid"))
    
    local grid_type_list = obs.obs_properties_add_list(visual_group, SETTING_GRID_TYPE, L("grid_type"),
        obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_INT)
    obs.obs_property_list_add_int(grid_type_list, L("grid_standard"), GRID_STANDARD)
    obs.obs_property_list_add_int(grid_type_list, L("grid_perspective"), GRID_PERSPECTIVE)
    obs.obs_property_list_add_int(grid_type_list, L("grid_diagonal"), GRID_DIAGONAL)
    obs.obs_property_list_add_int(grid_type_list, L("grid_golden"), GRID_GOLDEN)
    
    obs.obs_properties_add_float_slider(visual_group, SETTING_GRID_OPACITY, L("grid_opacity"), 0.0, 1.0, 0.01)
    obs.obs_properties_add_color(visual_group, SETTING_GRID_COLOR, L("grid_color"))
    obs.obs_properties_add_float_slider(visual_group, SETTING_GRID_SIZE, L("grid_size"), 1.0, 100.0, 1.0)
    obs.obs_properties_add_bool(visual_group, SETTING_SPLIT_SCREEN, L("split_screen"))
    obs.obs_properties_add_float_slider(visual_group, SETTING_SPLIT_POSITION, L("split_position"), 0.0, 100.0, 0.1)
    obs.obs_properties_add_group(props, "visual_aids", L("visual_aids"), obs.OBS_GROUP_NORMAL, visual_group)

    return props
end

source_def.get_defaults = function(settings)
    obs.obs_data_set_default_string(settings, SETTING_FOCAL_LENGTH, "custom")
    obs.obs_data_set_default_double(settings, SETTING_FISH_POWER, 0.0)
    obs.obs_data_set_default_double(settings, SETTING_FINE_TUNING, 0.0)
    obs.obs_data_set_default_double(settings, SETTING_CENTER_X, 50.0)
    obs.obs_data_set_default_double(settings, SETTING_CENTER_Y, 50.0)
    obs.obs_data_set_default_int(settings, SETTING_QUALITY, 2)
    obs.obs_data_set_default_bool(settings, SETTING_PERFORMANCE_MODE, false)
    obs.obs_data_set_default_bool(settings, SETTING_SHOW_GRID, false)
    obs.obs_data_set_default_int(settings, SETTING_GRID_TYPE, 1)
    obs.obs_data_set_default_double(settings, SETTING_GRID_OPACITY, 0.7)
    obs.obs_data_set_default_int(settings, SETTING_GRID_COLOR, 0xFF0000)
    obs.obs_data_set_default_double(settings, SETTING_GRID_SIZE, 10.0)
    obs.obs_data_set_default_string(settings, SETTING_LANGUAGE, "DE")
    obs.obs_data_set_default_bool(settings, SETTING_SPLIT_SCREEN, false)
    obs.obs_data_set_default_double(settings, SETTING_SPLIT_POSITION, 50.0)
    obs.obs_data_set_default_string(settings, SETTING_CAMERA_PROFILE, "")
    obs.obs_data_set_default_string(settings, SETTING_PROFILE_NAME, "")
end

source_def.video_tick = function(filter, seconds)
    set_render_size(filter)
end

function script_description()
    return "Adds a professional lens correction filter with advanced features"
end

function script_load(settings)
    obs.obs_register_source(source_def)
end

-- Shader code
shader_text = [[
uniform float4x4 ViewProj;
uniform texture2d image;

uniform float fish_power;
uniform float fine_tuning;
uniform float center_x;
uniform float center_y;
uniform float texture_width;
uniform float texture_height;
uniform bool show_grid;
uniform int grid_type;
uniform float grid_opacity;
uniform float4 grid_color;
uniform float grid_size;
uniform bool split_screen;
uniform float split_position;
uniform int quality;

sampler_state def_sampler {
    Filter   = Linear;
    AddressU = Clamp;
    AddressV = Clamp;
};

struct VertData {
    float4 pos : POSITION;
    float2 uv  : TEXCOORD0;
};

VertData VSDefault(VertData v_in)
{
    VertData vert_out;
    vert_out.pos = mul(float4(v_in.pos.xyz, 1.0), ViewProj);
    vert_out.uv  = v_in.uv;
    return vert_out;
}

float2 ApplyLensCorrection(float2 uv, float2 center_pos, float power)
{
    float2 dir = uv - center_pos;
    float dist = length(dir);
    
    // Progressive correction based on distance from center
    float correction_factor = 1.0;
    if (power >= 0.0001) {
        // Pincushion correction (positive values)
        correction_factor = 1.0 + (power * dist * 2.0);
    } else if (power <= -0.0001) {
        // Barrel correction (negative values)
        correction_factor = 1.0 / (1.0 + (-power * dist * 2.0));
    }
    
    return center_pos + dir * correction_factor;
}

float4 DrawGrid(float2 uv)
{
    float2 center_pos = float2(center_x, center_y);
    float power = fish_power;
    
    // Apply lens correction to grid UV if not in split screen or on right side
    if (!split_screen || uv.x > split_position) {
        uv = ApplyLensCorrection(uv, center_pos, power);
    }
    
    float2 grid_scale = float2(grid_size, grid_size);
    float2 grid_pos = fmod(uv, grid_scale);
    float line_width = 0.002;
    float grid = 0.0;
    
    // Standard grid
    if (grid_type == 1) {
        if (grid_pos.x < line_width || grid_pos.y < line_width ||
            abs(grid_pos.x - grid_scale.x) < line_width || 
            abs(grid_pos.y - grid_scale.y) < line_width)
            grid = 1.0;
    }
    // Perspective grid
    else if (grid_type == 2) {
        float2 center = float2(0.5, 0.5);
        float2 dir = normalize(uv - center);
        float dist = distance(uv, center);
        float angle = atan2(dir.y, dir.x);
        
        float radial = fmod(abs(angle), grid_scale.x);
        if (radial < line_width || abs(radial - grid_scale.x) < line_width)
            grid = 1.0;
            
        float circular = fmod(dist, grid_scale.y);
        if (circular < line_width || abs(circular - grid_scale.y) < line_width)
            grid = 1.0;
    }
    // Diagonal grid
    else if (grid_type == 3) {
        float2 diagonal_uv = float2(uv.x + uv.y, uv.x - uv.y) * 0.707;
        float2 diagonal_pos = fmod(diagonal_uv, grid_scale);
        if (diagonal_pos.x < line_width || diagonal_pos.y < line_width ||
            abs(diagonal_pos.x - grid_scale.x) < line_width || 
            abs(diagonal_pos.y - grid_scale.y) < line_width)
            grid = 1.0;
    }
    // Golden ratio grid
    else if (grid_type == 4) {
        float golden = 1.618033988749895;
        float2 golden_pos = fmod(uv * golden, grid_scale);
        if (golden_pos.x < line_width || golden_pos.y < line_width ||
            abs(golden_pos.x - grid_scale.x) < line_width || 
            abs(golden_pos.y - grid_scale.y) < line_width)
            grid = 1.0;
            
        float2 spiral_center = float2(0.382, 0.382);
        float spiral_dist = distance(uv, spiral_center);
        if (spiral_dist < line_width * 2.0)
            grid = 1.0;
    }
    
    return float4(grid_color.rgb, grid * grid_opacity);
}

float4 PSDrawBare(VertData v_in) : TARGET
{
    float2 center_pos = float2(center_x, center_y);
    float2 uv = v_in.uv;
    float power = fish_power;
    
    // Split screen logic
    bool apply_correction = true;
    if (split_screen) {
        apply_correction = v_in.uv.x > split_position;
    }
    
    if (apply_correction) {
        float2 sample_uv = uv;
        if (quality == 1) {
            sample_uv = floor(uv * 256.0) / 256.0;
        }
        else if (quality == 3) {
            float2 pixel_size = float2(1.0/texture_width, 1.0/texture_height);
            sample_uv = uv + pixel_size * 0.5;
        }
        
        uv = ApplyLensCorrection(sample_uv, center_pos, power);
    }
    
    float4 color = image.Sample(def_sampler, uv);
    
    if (show_grid) {
        float4 grid = DrawGrid(v_in.uv);
        color = lerp(color, grid_color, grid.a);
    }
    
    if (split_screen) {
        float line_width = 0.002;
        if (abs(v_in.uv.x - split_position) < line_width) {
            return float4(1.0, 1.0, 1.0, 1.0);
        }
    }
    
    return color;
}

technique Draw
{
    pass
    {
        vertex_shader = VSDefault(v_in);
        pixel_shader  = PSDrawBare(v_in);
    }
}
]]