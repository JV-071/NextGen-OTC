local function read(path)
  local file = assert(io.open(path, 'rb'))
  local contents = file:read('*a')
  file:close()
  return contents:gsub('^\239\187\191', '')
end

local dataOptionsChunk = assert(loadstring(read('modules/client_options/data_options.lua'),
  '@modules/client_options/data_options.lua'))
local options = dataOptionsChunk()
assert(type(options.showAnimatedMouseCursor) == 'table', 'animated cursor option is missing')
assert(options.showAnimatedMouseCursor.value == true, 'animated cursor should default to enabled')
assert(options.showAnimatedMouseCursor.deferAction == true, 'cursor changes must follow Apply/Cancel semantics')
assert(type(options.hdGraphics) == 'table', 'xBRZ option is missing')
assert(options.hdGraphics.value == false, 'xBRZ should remain opt-in')
assert(options.hdGraphics.deferAction == true, 'xBRZ changes must follow Apply/Cancel semantics')

local spriteScale
g_sprites = {
  setScaleFactor = function(value) spriteScale = value end,
}
options.hdGraphics.action(true, options, nil, nil)
assert(spriteScale == 2, 'enabling xBRZ must request 2x sprite textures')
options.hdGraphics.action(false, options, nil, nil)
assert(spriteScale == 1, 'disabling xBRZ must restore native sprite textures')
g_sprites = nil

local cursorAnimations
options.showAnimatedMouseCursor.action(false, options, nil, {
  gameMapPanel = {
    setCursorAnimations = function(_, value) cursorAnimations = value end,
  },
})
assert(cursorAnimations == false, 'animated cursor action did not reach the map view')

assert(loadstring(read('modules/client_options/options.lua'), '@modules/client_options/options.lua'),
  'options.lua has invalid Lua 5.1 syntax')

local interface = read('modules/client_options/styles/interface/interface.otui')
local animatedBlock = assert(interface:match('id: showAnimatedMouseCursor(.-)id: animatedMouseCursorHelp'),
  'animated cursor widget is missing')
assert(not animatedBlock:match('enabled:%s*false'), 'animated cursor widget is still disabled')

local config = read('config.ini')
for _, key in ipairs({ 'widget', 'static%-text', 'animated%-text', 'creature%-text', 'item%-count' }) do
  assert(config:match('\n%s*' .. key .. '%s*='), 'active font setting is missing: ' .. key)
end

local oldVersionDirectory = io.open('data/things/1530/assets.json.sha256', 'rb')
assert(not oldVersionDirectory, 'version-specific asset identifier should not be shipped')
local sharedIdentifier = assert(io.open('data/things/assets.json.sha256', 'rb'),
  'shared asset identifier is missing')
sharedIdentifier:close()

local cyclopedia = read('modules/game_cyclopedia/game_cyclopedia.lua')
local eagerUi = cyclopedia:find('controllerCyclopedia:setUI("game_cyclopedia")', 1, true)
local onInit = cyclopedia:find('function controllerCyclopedia:onInit()', 1, true)
assert(eagerUi and onInit and eagerUi > onInit,
  'Cyclopedia window path must be registered after the eager Controller init phase')
assert(cyclopedia:find('not ensureCyclopediaWindow()', 1, true),
  'Cyclopedia window is not loaded on first use')
assert(cyclopedia:find('Window loaded on demand in %d ms%s', 1, true),
  'Cyclopedia lazy window load is not measurable')

print('Options and packaging contract checks passed')
