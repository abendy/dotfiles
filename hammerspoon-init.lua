local presets = {
  portrait = {
    width = 0.75,
    height = 0.70,
    key = "p",
  },
  landscape = {
    width = 0.80,
    height = 0.50,
    key = "l",
  },
}

hs.window.animationDuration = 0

local function apply_preset(name)
  local preset = presets[name]
  if not preset then
    hs.alert.show("Unknown preset: " .. name)
    return
  end

  local window = hs.window.focusedWindow()
  if not window then
    hs.alert.show("No focused window")
    return
  end

  local screen_frame = window:screen():frame()
  local width = math.floor(screen_frame.w * preset.width)
  local height = math.floor(screen_frame.h * preset.height)
  local x = math.floor(screen_frame.x + ((screen_frame.w - width) / 2))
  local y = math.floor(screen_frame.y + ((screen_frame.h - height) / 2))

  window:setFrame({
    x = x,
    y = y,
    w = width,
    h = height,
  })
end

local function move_window_to_screen(direction)
  local window = hs.window.focusedWindow()
  if not window then
    hs.alert.show("No focused window")
    return
  end

  local screen = window:screen()
  local target_screen

  if direction == "north" then
    target_screen = screen:toNorth(window:frame(), true)
  elseif direction == "south" then
    target_screen = screen:toSouth(window:frame(), true)
  end

  if not target_screen then
    hs.alert.show("No screen " .. direction)
    return
  end

  window:moveToScreen(target_screen)
end

local function sorted_secondary_screens()
  local primary_screen = hs.screen.primaryScreen()
  local secondary_screens = {}

  for _, screen in ipairs(hs.screen.allScreens()) do
    if screen:id() ~= primary_screen:id() then
      local x, y = screen:position()
      table.insert(secondary_screens, {
        screen = screen,
        x = x,
        y = y,
        distance = math.abs(x) + math.abs(y),
      })
    end
  end

  table.sort(secondary_screens, function(a, b)
    if a.distance ~= b.distance then
      return a.distance < b.distance
    end

    if a.y ~= b.y then
      return a.y < b.y
    end

    return a.x < b.x
  end)

  return secondary_screens
end

local function move_window_to_named_screen(name)
  local window = hs.window.focusedWindow()
  if not window then
    hs.alert.show("No focused window")
    return
  end

  local target_screen

  if name == "primary" then
    target_screen = hs.screen.primaryScreen()
  elseif name == "secondary" then
    local secondary_screens = sorted_secondary_screens()
    if #secondary_screens > 0 then
      target_screen = secondary_screens[1].screen
    end
  end

  if not target_screen then
    hs.alert.show("No " .. name .. " screen")
    return
  end

  window:moveToScreen(target_screen)
end

local action_by_key = {}

for name, preset in pairs(presets) do
  action_by_key[hs.keycodes.map[preset.key]] = function()
    apply_preset(name)
  end
end

action_by_key[hs.keycodes.map["1"]] = function()
  move_window_to_named_screen("primary")
end

action_by_key[hs.keycodes.map["2"]] = function()
  move_window_to_named_screen("secondary")
end

action_by_key[hs.keycodes.map.up] = function()
  move_window_to_screen("north")
end

action_by_key[hs.keycodes.map.down] = function()
  move_window_to_screen("south")
end

local preset_watcher = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
  local flags = event:getFlags()
  if not flags:containExactly({ "ctrl", "fn" }) then
    return false
  end

  local action = action_by_key[event:getKeyCode()]
  if not action then
    return false
  end

  action()
  return true
end)

preset_watcher:start()

hs.hotkey.bind({ "ctrl", "alt", "cmd" }, "r", function()
  hs.reload()
end)

hs.alert.show("Hammerspoon config loaded")
