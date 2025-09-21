-- Pull in the wezterm API
local wezterm = require("wezterm")

-- This will hold the configuration.
local config = wezterm.config_builder()

config.initial_cols = 80
config.initial_rows = 28

config.font_size = 14
config.color_scheme = "BlulocoDark"
config.font = wezterm.font_with_fallback({
	"JetBrainsMono Nerd Font",
	"JetBrainsMono Nerd Font Mono",
	"FiraCode Nerd Font",
})
config.enable_tab_bar = false

-- Finally, return the configuration to wezterm:
return config
