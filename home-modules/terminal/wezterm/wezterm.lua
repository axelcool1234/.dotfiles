-- Pull in the wezterm API
local wezterm = require 'wezterm'
local io = require 'io';
local os = require 'os';
local act = wezterm.action

-- Custom Actions
-- Track if our helper pane is open
local helper_pane_created = false
local helper_pane_open = false

wezterm.on('minimize-toggle', function(window, pane)
    if helper_pane_open then
      -- Minimize the helper pane
      window:perform_action(
        wezterm.action.ActivatePaneDirection 'Up',
        pane
      )
      window:perform_action(
        wezterm.action.TogglePaneZoomState,
        pane
      )
      helper_pane_open = false
    else
      -- Open a new pane at the bottom
      if helper_pane_created then
          window:perform_action(
            wezterm.action.TogglePaneZoomState,
            pane
          )
      else
          pane:split {
            direction = 'Bottom',
            size = 0.3,  -- Takes 30% of the window height
          }
          helper_pane_created = true
      end
      -- Focus the new pane
      window:perform_action(
        wezterm.action.ActivatePaneDirection 'Down',
        pane
      )
      helper_pane_open = true
    end
end)


wezterm.on("trigger-editor-with-scrollback", function(window, pane)
  -- Retrieve the current viewport's text.
  -- Pass an optional number of lines (eg: 2000) to retrieve
  -- that number of lines starting from the bottom of the viewport
  local scrollback = pane:get_lines_as_text();

  -- Create a temporary file to pass to vim
  local name = os.tmpname();
  local f = io.open(name, "w+");
  f:write(scrollback);
  f:flush();
  f:close();

  -- Use $EDITOR or default to 'vim' if $EDITOR is not set
  -- FIXME: Should be dynamic, but it seems to open in Nano despite EDITOR being set to something else.
  -- local editor = os.getenv("EDITOR") or "vim"
  local editor = "nvim"


  -- Open a new tab running vim and tell it to open the file
  window:perform_action(wezterm.action{SpawnCommandInNewTab={
    args={editor, name}}
  }, pane)

  -- wait "enough" time for editor to read the file before we remove it.
  -- The window creation and process spawn are asynchronous
  -- wrt. running this script and are not awaitable, so we just pick
  -- a number.
  wezterm.sleep_ms(1000);
  os.remove(name);
end)

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

    -- Toggle minimized pane
    { key = "t", mods = "CTRL", action = wezterm.action.EmitEvent "minimize-toggle" },

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

    -- Editor Mode
    { key = "E", mods = "CTRL|SHIFT",    action=wezterm.action{EmitEvent="trigger-editor-with-scrollback"}},
  },
}
