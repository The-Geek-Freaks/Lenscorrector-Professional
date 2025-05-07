--[[
    Lenscorrector Professional
    Advanced Lens Correction Filter for OBS
    Author: TheGeekFreaks Copyright (c) 2025
]]

-- Required OBS modules
local obs = obslua
local bit = require("bit")

-- Debug utilities
local DEBUG = true
local function log_debug(msg)
    if DEBUG then
        obs.script_log(obs.LOG_INFO, "[LensCorrector] " .. tostring(msg))
    end
end

-- Cross-API time helper (seconds)
local function get_time_s()
    if obs.os_gettime_s then
        return obs.os_gettime_s()
    elseif obs.os_gettime_ns then
        return obs.os_gettime_ns() / 1e9
    else
        return os.clock()
    end
end

-- Translations
local translations = {
    ["de-DE"] = {
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
    ["en-US"] = {
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

-- Current language auto-detected; can be overridden by settings
local current_lang = obs.obs_get_locale() or "en-US"

-- Translation helper
local function L(key)
    if not translations[current_lang] then
        current_lang = "en-US"
    end
    return translations[current_lang][key] or key
end

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
local SETTING_PERFORMANCE_MODE = "performance_mode" -- Performance-Modus für Frame-Skipping
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

-- Profile management
local camera_profiles = {}
local profiles_path = script_path() .. "/profiles"

-- Detect operating system (path separator check)
local IS_WINDOWS = package.config:sub(1,1) == "\\"

-- Ensure profiles directory exists (cross-platform)
local function ensure_profiles_directory()
    if IS_WINDOWS then
        os.execute(string.format('if not exist "%s" mkdir "%s"', profiles_path, profiles_path))
    else
        os.execute(string.format('mkdir -p "%s"', profiles_path))
    end
    return true
end

-- Get list of available profile files (cross-platform)
local function get_profile_list()
    local profiles = {}
    local cmd = IS_WINDOWS and string.format('dir "%s" /b', profiles_path)
                              or  string.format('ls -1 "%s"', profiles_path)
    local handle = io.popen(cmd)
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
source_def.id = 'lenscorrector_filter'
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
    filter.invalid = false
    source_ref = source
    
    -- Initialisiere Standardwerte
    filter.fish_power = 0.0
    filter.fine_tuning = 0.0
    filter.center_x = 50.0
    filter.center_y = 50.0
    filter.split_screen = false
    filter.split_position = 50.0
    filter.performance_mode = false
    filter.show_grid = false
    filter.grid_type = 1
    filter.grid_opacity = 0.5
    filter.grid_color = 0xFFFFFFFF
    filter.grid_size = 10.0
    filter.width = 1920  -- Standardgröße, wird in set_render_size aktualisiert
    filter.height = 1080 -- Standardgröße, wird in set_render_size aktualisiert
    
    set_render_size(filter)
    
    -- Shader Initialisierung mit pcall für Sicherheit
    local success, err = pcall(function()
        obs.obs_enter_graphics()
        filter.effect = obs.gs_effect_create(shader_text, nil, nil)
        if filter.effect ~= nil then
            filter.params = {}
            -- Shader-Parameter abrufen
            filter.params.fish_power       = obs.gs_effect_get_param_by_name(filter.effect, 'fish_power')
            filter.params.center_x         = obs.gs_effect_get_param_by_name(filter.effect, 'center_x')
            filter.params.center_y         = obs.gs_effect_get_param_by_name(filter.effect, 'center_y')
            filter.params.texture_width    = obs.gs_effect_get_param_by_name(filter.effect, 'texture_width')
            filter.params.texture_height   = obs.gs_effect_get_param_by_name(filter.effect, 'texture_height')
            filter.params.split_screen     = obs.gs_effect_get_param_by_name(filter.effect, 'split_screen')
            filter.params.split_position    = obs.gs_effect_get_param_by_name(filter.effect, 'split_position')
            filter.params.image            = obs.gs_effect_get_param_by_name(filter.effect, 'image')
            filter.params.performance_mode = obs.gs_effect_get_param_by_name(filter.effect, 'performance_mode')
            filter.params.show_grid        = obs.gs_effect_get_param_by_name(filter.effect, 'show_grid')
            filter.params.grid_type        = obs.gs_effect_get_param_by_name(filter.effect, 'grid_type')
            filter.params.grid_opacity     = obs.gs_effect_get_param_by_name(filter.effect, 'grid_opacity')
            filter.params.grid_color       = obs.gs_effect_get_param_by_name(filter.effect, 'grid_color')
            filter.params.grid_size        = obs.gs_effect_get_param_by_name(filter.effect, 'grid_size')
            
            -- Debug-Log für Parameter
            if DEBUG then
                log_debug("Shader-Parameter initialisiert")
            end
        end
        obs.obs_leave_graphics()
    end)

    if not success or filter.effect == nil then
        log_debug("Shader initialisation failed: " .. tostring(err))
        filter.invalid = true
    end

    if filter.invalid then
        source_def.destroy(filter)
        return nil
    end
    
    source_def.update(filter, settings)
    return filter
end

source_def.destroy = function(filter)
    if not filter then return end
    
    -- Safe shader destruction with enhanced error handling
    local success, err = pcall(function()
        obs.obs_enter_graphics()
        
        -- Destroy effect if it exists
        if filter.effect ~= nil then
            obs.gs_effect_destroy(filter.effect)
            filter.effect = nil
        end
        
        -- Clear parameter references
        if filter.params then
            filter.params = nil
        end
        
        obs.obs_leave_graphics()
    end)
    
    if not success then
        log_debug("Shader destroy failed: " .. tostring(err))
    end
end

source_def.get_width = function(filter)
    return filter.width
end

source_def.get_height = function(filter)
    return filter.height
end

source_def.update = function(filter, settings)
    if not filter then return end
    
    -- Versuche Werte aus den Einstellungen zu lesen mit Fehlerbehandlung
    local success, err = pcall(function()
        -- Wichtig: Wir setzen keine Standardwerte hier, da sie bereits in create gesetzt wurden
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
        
        -- Basis-Parameter auslesen
        filter.fine_tuning = obs.obs_data_get_double(settings, SETTING_FINE_TUNING)
        filter.center_x = obs.obs_data_get_double(settings, SETTING_CENTER_X)
        filter.center_y = obs.obs_data_get_double(settings, SETTING_CENTER_Y)
        
        -- Performance- und Split-Parameter
        filter.split_screen = obs.obs_data_get_bool(settings, SETTING_SPLIT_SCREEN)
        filter.split_position = obs.obs_data_get_double(settings, SETTING_SPLIT_POSITION)
        filter.performance_mode = obs.obs_data_get_bool(settings, SETTING_PERFORMANCE_MODE)
        
        -- Grid-Parameter
        filter.show_grid = obs.obs_data_get_bool(settings, SETTING_SHOW_GRID)
        filter.grid_type = obs.obs_data_get_int(settings, SETTING_GRID_TYPE)
        filter.grid_opacity = obs.obs_data_get_double(settings, SETTING_GRID_OPACITY)
        filter.grid_color = obs.obs_data_get_int(settings, SETTING_GRID_COLOR)
        
        if DEBUG then
            log_debug("Geladene Grid-Farbe: " .. string.format("0x%08X", filter.grid_color))
        end
        
        filter.grid_size = obs.obs_data_get_double(settings, SETTING_GRID_SIZE)
    end)
    
    if not success then
        log_debug("Fehler beim Aktualisieren der Filter-Parameter: " .. tostring(err))
    end
    
    local new_lang = obs.obs_data_get_string(settings, SETTING_LANGUAGE)
    if new_lang and new_lang ~= "" and new_lang ~= current_lang then
        current_lang = new_lang
    end
    
    set_render_size(filter)
end

source_def.video_render = function(filter, effect)
    -- Validate filter data
    if not filter or filter.invalid or not filter.effect then
        if filter and filter.context then
            obs.obs_source_skip_video_filter(filter.context)
        end
        return
    end
    
    -- Performance-Modus verwendet simplere Shader-Berechnungen anstatt Frame-Skipping
    -- Das wird in apply_shader_params berücksichtigt

    -- Ensure current render size
    local target = obs.obs_filter_get_target(filter.context)
    local width, height = 0, 0
    if target ~= nil then
        width  = obs.obs_source_get_base_width(target)
        height = obs.obs_source_get_base_height(target)
    end
    if width == 0 or height == 0 then
        obs.obs_source_skip_video_filter(filter.context)
        return
    end
    filter.width  = width
    filter.height = height

    -- Begin processing the input texture with optimierter Pufferung
    if not obs.obs_source_process_filter_begin(filter.context, obs.GS_RGBA, obs.OBS_NO_DIRECT_RENDERING) then
        return
    end

    -- Update uniforms with error handling
    local success, err = pcall(function()
        apply_shader_params(filter)
        
        -- Render with shader
        local technique = obs.gs_effect_get_technique(filter.effect, 'Draw')
        if technique then
            obs.gs_technique_begin(technique)
            obs.gs_technique_begin_pass(technique, 0)
            obs.obs_source_process_filter_end(filter.context, filter.effect, width, height)
            obs.gs_technique_end_pass(technique)
            obs.gs_technique_end(technique)
        else
            log_debug('Technique not found')
            obs.obs_source_process_filter_end(filter.context, nil, width, height)
        end
    end)
    
    if not success then
        log_debug('Render error: ' .. tostring(err))
        obs.obs_source_process_filter_end(filter.context, nil, width, height)
    end
end

source_def.video_render_preview = function(filter)
    if not filter or not filter.effect or filter.invalid then
        return
    end

    local success, err = pcall(function()
        -- Ensure size is up to date
        set_render_size(filter)

        -- Create preview texture if necessary
        if not filter.preview_texture then
            local width  = filter.width  or 200
            local height = filter.height or 200
            obs.obs_enter_graphics()
            filter.preview_texture = obs.gs_texture_create(width, height, obs.GS_RGBA, 1, nil, obs.GS_TEXTURE_2D)
            obs.obs_leave_graphics()
        end

        -- Update shader uniforms
        apply_shader_params(filter)

        -- Bind preview texture to shader if sampler is available
        if filter.params.image and filter.preview_texture then
            obs.gs_effect_set_texture(filter.params.image, filter.preview_texture)
        end

        local technique = obs.gs_effect_get_technique(filter.effect, 'Draw')
        if not technique then return end

        obs.gs_reset_blend_state()
        obs.gs_technique_begin(technique)
        obs.gs_technique_begin_pass(technique, 0)

        obs.gs_draw_sprite(nil, 0, filter.width, filter.height)

        obs.gs_technique_end_pass(technique)
        obs.gs_technique_end(technique)
    end)

    if not success then
        log_debug('Preview render failed: ' .. tostring(err))
    end
end

source_def.get_properties = function(data)
    log_debug('get_properties called with data: ' .. tostring(data))
    local props = obs.obs_properties_create()
    
    -- Teste die OBS Farbinterpretation (Debug)
    if DEBUG then
        local test_color = 0xFF0000  -- Reines Rot im Format 0xBBGGRR
        log_debug("Test Farbwert (Rot): " .. string.format("0x%08X", test_color))
    end
    
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
    obs.obs_property_list_add_string(p, "Deutsch", "de-DE")
    obs.obs_property_list_add_string(p, "English", "en-US")
    
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

    source_def.description = [[
{{ Lenscorrector Professional - Erweiterte Objektivkorrektur für OBS }}

{{ Anleitung: }}
1. Fügen Sie den Filter "Lenscorrector Professional" zu Ihrer Videoquelle hinzu
2. Wählen Sie die Brennweite Ihres Objektivs aus der Liste
3. Passen Sie bei Bedarf die Korrekturstärke an
4. Speichern Sie Ihre Einstellungen als Profil

{{ Hinweis: }} Die Sprache des Filters wird aktualisiert, wenn Sie den "Zurücksetzen" Knopf in den Filtereinstellungen drücken.

{{ Lenscorrector Professional - Advanced Lens Correction for OBS }}

{{ Instructions: }}
1. Add the "Lenscorrector Professional" filter to your video source
2. Select your lens focal length from the list
3. Adjust the correction strength if needed
4. Save your settings as a profile

{{ Note: }} The filter language will update when you press the "Reset" button in the filter settings.
]]

    -- Add profile group to main properties
    obs.obs_properties_add_group(props, "profile_management", L("camera_profile"), obs.OBS_GROUP_NORMAL, profile_group)
    
    return props
end

source_def.get_defaults = function(settings)
    obs.obs_data_set_default_double(settings, SETTING_FISH_POWER, 0.0)
    obs.obs_data_set_default_double(settings, SETTING_FINE_TUNING, 0.0)
    obs.obs_data_set_default_double(settings, SETTING_CENTER_X, 50.0)
    obs.obs_data_set_default_double(settings, SETTING_CENTER_Y, 50.0)
    obs.obs_data_set_default_bool(settings, SETTING_SPLIT_SCREEN, false)
    obs.obs_data_set_default_double(settings, SETTING_SPLIT_POSITION, 50.0)
    obs.obs_data_set_default_bool(settings, SETTING_PERFORMANCE_MODE, false)
    obs.obs_data_set_default_bool(settings, SETTING_SHOW_GRID, false)
    obs.obs_data_set_default_int(settings, SETTING_GRID_TYPE, 1)
    obs.obs_data_set_default_double(settings, SETTING_GRID_OPACITY, 0.7)
    obs.obs_data_set_default_int(settings, SETTING_GRID_COLOR, 0xFF0000)
    obs.obs_data_set_default_double(settings, SETTING_GRID_SIZE, 10.0)
    obs.obs_data_set_default_string(settings, SETTING_LANGUAGE, "de-DE")
    obs.obs_data_set_default_bool(settings, SETTING_SPLIT_SCREEN, false)
    obs.obs_data_set_default_double(settings, SETTING_SPLIT_POSITION, 50.0)
    obs.obs_data_set_default_string(settings, SETTING_CAMERA_PROFILE, "")
    obs.obs_data_set_default_string(settings, SETTING_PROFILE_NAME, "")
end

source_def.video_tick = function(filter, seconds)
    set_render_size(filter)
end

function script_description()
    return [[
{{ Lenscorrector Professional - Erweiterte Objektivkorrektur für OBS }}

{{ Anleitung: }}
1. Fügen Sie den Filter "Lenscorrector Professional" zu Ihrer Videoquelle hinzu
2. Wählen Sie die Brennweite Ihres Objektivs aus der Liste
3. Passen Sie bei Bedarf die Korrekturstärke an
4. Speichern Sie Ihre Einstellungen als Profil

{{ Hinweis: }} Die Sprache des Filters wird aktualisiert, wenn Sie den "Zurücksetzen" Knopf in den Filtereinstellungen drücken.

{{ Lenscorrector Professional - Advanced Lens Correction for OBS }}

{{ Instructions: }}
1. Add the "Lenscorrector Professional" filter to your video source
2. Select your lens focal length from the list
3. Adjust the correction strength if needed
4. Save your settings as a profile

{{ Note: }} The filter language will update when you press the "Reset" button in the filter settings.
]]
end

function script_load(settings)
    log_debug('Registering Lenscorrector filter')
    obs.obs_register_source(source_def)
    log_debug('Lenscorrector filter registered')
end

-- Helper to apply all shader uniforms consistently (used by normal and preview rendering)
-- Hilfsfunktion zum Vergleichen von Tabellen
local function table_equals(t1, t2)
    if t1 == nil or t2 == nil then return false end
    for k, v in pairs(t1) do
        if t2[k] ~= v then return false end
    end
    for k, v in pairs(t2) do
        if t1[k] ~= v then return false end
    end
    return true
end

function apply_shader_params(filter)
    if not filter or not filter.params then return end
    
    -- Parameter für die Änderungserkennung sammeln
    local current_values = {
        fish_power = filter.fish_power,
        center_x = filter.center_x,
        center_y = filter.center_y,
        width = filter.width,
        height = filter.height,
        split_screen = filter.split_screen,
        split_position = filter.split_position,
        show_grid = filter.show_grid,
        performance_mode = filter.performance_mode
    }
    
    -- Feinabstimmung hinzufügen, wenn vorhanden
    if filter.fine_tuning then
        current_values.fine_tuning = filter.fine_tuning
    end
    
    -- Grid-Parameter hinzufügen
    if filter.show_grid then
        current_values.grid_type = filter.grid_type
        current_values.grid_opacity = filter.grid_opacity
        current_values.grid_color = filter.grid_color
        current_values.grid_size = filter.grid_size
    end
    
    -- Prüfen ob sich Parameter geändert haben
    if filter.last_values == nil or not table_equals(current_values, filter.last_values) then
        -- Essenzielle Parameter für die Linsenkorrektur mit Null-Prüfung
        local total_power = filter.fish_power or 0.0
        if filter.fine_tuning then
            total_power = total_power + ((filter.fine_tuning or 0.0) * 0.01)
        end
        
        -- Im Performance-Modus benutzen wir vereinfachten Algorithmus
        if filter.params.performance_mode then
            obs.gs_effect_set_bool(filter.params.performance_mode, filter.performance_mode or false)
        end
        
        if filter.params.fish_power then
            obs.gs_effect_set_float(filter.params.fish_power, total_power)
        end
        
        if filter.params.center_x then
            obs.gs_effect_set_float(filter.params.center_x, (filter.center_x or 50.0) / 100.0)
        end
        
        if filter.params.center_y then
            obs.gs_effect_set_float(filter.params.center_y, (filter.center_y or 50.0) / 100.0)
        end
        
        if filter.params.texture_width and filter.width then
            obs.gs_effect_set_float(filter.params.texture_width, filter.width)
        end
        
        if filter.params.texture_height and filter.height then
            obs.gs_effect_set_float(filter.params.texture_height, filter.height)
        end
        
        -- Split-Screen-Parameter
        if filter.params.split_screen then
            obs.gs_effect_set_bool(filter.params.split_screen, filter.split_screen or false)
        end
        
        if filter.params.split_position then
            obs.gs_effect_set_float(filter.params.split_position, (filter.split_position or 50.0) / 100.0)
        end
        
        -- Grid-Parameter
        if filter.params.show_grid then
            obs.gs_effect_set_bool(filter.params.show_grid, filter.show_grid or false)
        end
        
        if filter.params.grid_type then
            obs.gs_effect_set_int(filter.params.grid_type, (filter.show_grid and filter.grid_type) or 1)
        end
        
        if filter.params.grid_opacity then
            obs.gs_effect_set_float(filter.params.grid_opacity, (filter.show_grid and filter.grid_opacity) or 0.5)
        end
        
        if filter.params.grid_color then
            -- OBS Color-Picker gibt 0xBBGGRR im Format zurück (ohne Alpha)
            -- Wir müssen es in 0xAARRGGBB für den Shader umwandeln
            local input_color = (filter.show_grid and filter.grid_color) or 0xFFFFFFFF
            
            -- Extrahiere Komponenten aus der Eingabefarbe (0xBBGGRR Format)
            local color_b = bit.band(bit.rshift(input_color, 16), 0xFF)
            local color_g = bit.band(bit.rshift(input_color, 8), 0xFF)
            local color_r = bit.band(input_color, 0xFF)
            local color_a = 255  -- Immer voll undurchsichtig
            
            -- Konvertiere in einen 32-bit Integer im ABGR-Format für den Shader
            local shader_color = bit.bor(
                bit.lshift(color_a, 24),
                bit.lshift(color_b, 16),
                bit.lshift(color_g, 8),
                color_r
            )
            
            if DEBUG then
                log_debug("OBS Grid-Farbe: " .. string.format("0x%08X", input_color))
                log_debug("Shader-Farbe: " .. string.format("0x%08X", shader_color))
                log_debug("RGB-Werte: R=" .. color_r .. ", G=" .. color_g .. ", B=" .. color_b .. ", A=" .. color_a)
            end
            
            -- Sende aufbereitete Farbe an den Shader
            obs.gs_effect_set_int(filter.params.grid_color, shader_color)
        end
        
        if filter.params.grid_size then
            obs.gs_effect_set_float(filter.params.grid_size, (filter.show_grid and filter.grid_size) or 10.0)
        end
        
        -- Aktuelle Werte für späteren Vergleich speichern
        filter.last_values = current_values
        
        -- Debug-Ausgang, wenn Parameter aktualisiert wurden
        if DEBUG then
            log_debug("Shader-Parameter aktualisiert")
        end
    end
end

-- Shader code
shader_text = [[
uniform float4x4 ViewProj;
uniform texture2d image;

uniform float fish_power;
uniform float center_x;
uniform float center_y;
uniform float texture_width;
uniform float texture_height;
uniform bool split_screen;
uniform float split_position;
uniform bool performance_mode;

// Grid parameters
uniform bool show_grid;
uniform int grid_type;
uniform float grid_opacity;
uniform int grid_color;
uniform float grid_size;

sampler_state def_sampler {
    Filter    = Linear;
    AddressU  = Clamp;
    AddressV  = Clamp;
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

// Fast approximate lens correction for performance mode
float2 ApplyFastLensCorrection(float2 uv, float2 center_pos, float power)
{
    float2 dir = uv - center_pos;
    float dist = length(dir);
    
    float correction_factor = 1.0 + (power * dist * 2.0);
    return center_pos + dir * correction_factor;
}

// High quality lens correction
float2 ApplyLensCorrection(float2 uv, float2 center_pos, float power)
{
    float2 dir = uv - center_pos;
    float dist = length(dir);
    
    float correction_factor = 1.0;
    if (power > 0.0) {
        correction_factor = 1.0 + (power * dist * 2.0);
    } else if (power < 0.0) {
        correction_factor = 1.0 / (1.0 + (-power * dist * 2.0));
    }
    
    return center_pos + dir * correction_factor;
}

// Grid rendering function mit adaptiver Dicke
float4 ApplyGrid(float2 uv, float4 original_color)
{
    if (!show_grid) return original_color;
    
    // Aspect-Ratio berechnen
    float aspect = texture_width / texture_height;
    float2 grid_uv = uv;
    grid_uv.y *= aspect;
    
    // Grid-Schritt berechnen basierend auf Grid-Größe
    float grid_step = 1.0 / grid_size;
    
    // Adaptive Liniendicke basierend auf Auflösung
    float base_thickness = 0.003;
    float res_factor = max(texture_width, texture_height) / 1000.0;
    float grid_thickness = base_thickness / res_factor;
    
    // Mindestdicke sicherstellen
    grid_thickness = max(grid_thickness, 0.001);
    
    bool is_grid_line = false;
    
    // Standard grid
    if (grid_type == 1) {
        float x_mod = fmod(grid_uv.x, grid_step);
        float y_mod = fmod(grid_uv.y, grid_step);
        is_grid_line = x_mod < grid_thickness || y_mod < grid_thickness ||
                      x_mod > (grid_step - grid_thickness) || y_mod > (grid_step - grid_thickness);
    }
    // Perspective grid (lines toward center)
    else if (grid_type == 2) {
        float2 dir = grid_uv - float2(0.5, 0.5 * aspect);
        float angle = atan2(dir.y, dir.x);
        float angle_step = 3.14159265 / 8.0;
        float angle_mod = fmod(abs(angle), angle_step);
        float dist_mod = fmod(length(dir), grid_step);
        is_grid_line = angle_mod < grid_thickness || 
                     angle_mod > (angle_step - grid_thickness) || 
                     dist_mod < grid_thickness || 
                     dist_mod > (grid_step - grid_thickness);
    }
    // Diagonal grid
    else if (grid_type == 3) {
        float diag1 = fmod(abs(grid_uv.x + grid_uv.y), grid_step);
        float diag2 = fmod(abs(grid_uv.x - grid_uv.y), grid_step);
        is_grid_line = diag1 < grid_thickness || diag1 > (grid_step - grid_thickness) ||
                      diag2 < grid_thickness || diag2 > (grid_step - grid_thickness);
    }
    // Golden ratio grid
    else if (grid_type == 4) {
        float golden = 0.618;
        float thick = grid_thickness * 1.5; // Etwas dickere Linien für den goldenen Schnitt
        is_grid_line = abs(grid_uv.x - golden) < thick ||
                      abs(grid_uv.x - (1.0 - golden)) < thick ||
                      abs(grid_uv.y / aspect - golden) < thick ||
                      abs(grid_uv.y / aspect - (1.0 - golden)) < thick;
    }
    
    if (is_grid_line) {
        // Im Shader haben wir das Format 0xAABBGGRR (ABGR)
        float a = ((grid_color >> 24) & 0xFF) / 255.0;
        float b = ((grid_color >> 16) & 0xFF) / 255.0;
        float g = ((grid_color >> 8) & 0xFF) / 255.0;
        float r = (grid_color & 0xFF) / 255.0;
        
        // Falls Alpha 0 ist, setze es auf 1.0 (voll undurchsichtig)
        if (a == 0.0) a = 1.0;
        
        // HLSL erwartet RGBA-Format für float4
        float4 grid_color_rgba = float4(r, g, b, a);
        
        // Mischen mit dem Originalbild unter Berücksichtigung der Opazität
        return lerp(original_color, grid_color_rgba, grid_opacity);
    }
    
    return original_color;
}

float4 PSDefault(VertData v_in) : TARGET
{
    float2 uv = v_in.uv;
    float2 center_pos = float2(center_x, center_y);
    float power = fish_power;
    
    // Split screen logic
    bool apply_correction = true;
    if (split_screen) {
        apply_correction = uv.x > split_position;
    }
    
    if (apply_correction) {
        // Use simpler algorithm in performance mode
        if (performance_mode) {
            uv = ApplyFastLensCorrection(uv, center_pos, power);
        } else {
            uv = ApplyLensCorrection(uv, center_pos, power);
        }
    }
    
    // Clamp UV coordinates to valid range to avoid artifacts
    uv = clamp(uv, 0.001, 0.999);
    
    float4 color = image.Sample(def_sampler, uv);
    
    // Apply grid if enabled
    color = ApplyGrid(v_in.uv, color);
    
    // Draw split screen line
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
        pixel_shader  = PSDefault(v_in);
    }
}
]]