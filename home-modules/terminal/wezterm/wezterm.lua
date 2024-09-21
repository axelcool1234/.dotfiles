-- Pull in the wezterm API
local wezterm = require 'wezterm'
local act = wezterm.action
-- This will hold the configuration.
return {
  -- max_fps = 165, 
  enable_wayland = true;
  color_scheme = 'Tokyo Night',
  font = wezterm.font 'JetBrains Mono',
  font_size = 10.0,
  leader = { key = 'b', mods = 'CTRL'},
   -- disable_default_key_bindings = true,
  keys = {
    { key = "b", mods = "LEADER|CTRL", action=wezterm.action{SendString="\x01"}},

    -- Toggle Pane Fullscreen
    { key = "b", mods = "LEADER",      action="TogglePaneZoomState" },

    -- New Panes
    { key = "h", mods = "CTRL",        action = wezterm.action.SplitPane { direction = "Left", size = { Percent = 50 } } },
    { key = "j", mods = "CTRL",        action = wezterm.action.SplitPane { direction = "Down", size = { Percent = 50 } } },
    { key = "k", mods = "CTRL",        action = wezterm.action.SplitPane { direction = "Up", size = { Percent = 50 } } },
    { key = "l", mods = "CTRL",        action = wezterm.action.SplitPane { direction = "Right", size = { Percent = 50 } } },

    -- Switch Panes
    { key = "h", mods = "SUPER|SHIFT", action=wezterm.action{ActivatePaneDirection="Left"}},
    { key = "j", mods = "SUPER|SHIFT", action=wezterm.action{ActivatePaneDirection="Down"}},
    { key = "k", mods = "SUPER|SHIFT", action=wezterm.action{ActivatePaneDirection="Up"}},
    { key = "l", mods = "SUPER|SHIFT", action=wezterm.action{ActivatePaneDirection="Right"}},

    -- Alter Pane Sizes
    { key = "H", mods = "CTRL|SHIFT",  action=wezterm.action{AdjustPaneSize={"Left", 5}}},
    { key = "J", mods = "CTRL|SHIFT",  action=wezterm.action{AdjustPaneSize={"Down", 5}}},
    { key = "K", mods = "CTRL|SHIFT",  action=wezterm.action{AdjustPaneSize={"Up", 5}}},
    { key = "L", mods = "CTRL|SHIFT",  action=wezterm.action{AdjustPaneSize={"Right", 5}}},

    -- Switching tabs
    { key = "1", mods = "LEADER",      action=wezterm.action{ActivateTab=0}},
    { key = "2", mods = "LEADER",      action=wezterm.action{ActivateTab=1}},
    { key = "3", mods = "LEADER",      action=wezterm.action{ActivateTab=2}},
    { key = "4", mods = "LEADER",      action=wezterm.action{ActivateTab=3}},
    { key = "5", mods = "LEADER",      action=wezterm.action{ActivateTab=4}},
    { key = "6", mods = "LEADER",      action=wezterm.action{ActivateTab=5}},
    { key = "7", mods = "LEADER",      action=wezterm.action{ActivateTab=6}},
    { key = "8", mods = "LEADER",      action=wezterm.action{ActivateTab=7}},
    { key = "9", mods = "LEADER",      action=wezterm.action{ActivateTab=8}},

    -- Previous terminal commands
    { key = ";", mods = "CTRL",        action=act.SendKey{key="UpArrow"}},
    { key = "'", mods = "CTRL",        action=act.SendKey{key="DownArrow"}},
  },
}
