----------------------------------------
-- INNY'S DEPRESSING COMMUTER GAME
----------------------------------------

function classcall(class, ...)
  local inst = {}
  setmetatable(inst, inst)
  inst.__index = class
  if inst.init then inst:init(...) end
  return inst
end

function class( superclass )
  local t = {}
  t.__index = superclass
  t.__call = classcall
  return setmetatable(t, t)
end

strict_mt = {}
strict_mt.__newindex = function( t, k, v ) error("attempt to update a read-only table", 2) end
strict_mt.__index = function( t, k ) error("attempt to read key "..k, 2) end

function strict( table )
  return setmetatable( table, strict_mt )
end

----------------------------------------

stateStack = {}
keypress = {}

xScale = math.floor(love.graphics.getWidth() / 160)
yScale = math.floor(love.graphics.getHeight() / 120)

WHITE = strict { 255, 255, 255, 255 }

----------------------------------------

function text( x, y, color, str )
  love.graphics.setColor(color)
  for c in str:gmatch('.') do
    love.graphics.print(c, x, y)
    x = x + font:getWidth(c)
  end
end

----------------------------------------

Animator = class()

function Animator:init( frames )
  self.frames = frames or {}
  self.index = 1
  self.clock = 0
end

function Animator:add( name, length )
  table.insert(self.frames, {name=name, length=length})
end

function Animator:update(dt)
  self.clock = self.clock + dt
  while self.clock >= self.frames[self.index].length do
    self.clock = self.clock - self.frames[self.index].length
    self.index = self.index + 1
    if self.index > #self.frames then
      self.index = 1
    end
  end
end

function Animator:current()
  return self.frames[self.index].name
end

----------------------------------------

Player = class()

function Player:init()
  self.x = 24
  self.y = 80
  local rate = 1/10
  self.anim = Animator()
  self.anim:add( "playerRunningOne", rate )
  self.anim:add( "playerRunningTwo", rate )
end

function Player:draw()
  love.graphics.drawq( tilesetImage, spriteQuads[self.anim:current()], self.x, self.y )
end

function Player:update(dt)
  if keypress["down"]==1 then
    self.y = 80
  elseif keypress["up"]==1 then
    self.y = 48
  end
  self.anim:update(dt)
end

function Player:detectCollision( thing )
  local ax1, ax2, ay1, ay2 = self.x, self.x + 16, self.y, self.y + 32
  local bx1, bx2, by1, by2 = thing.x, thing.x + 16, thing.y, thing.y + 32
  return (ax1 < bx2) and (ax2 > bx1) and (ay1 < by2) and (ay2 > by1)
end

----------------------------------------

Sitter = class()

function Sitter:init( name )
  self.x = 160
  self.y = 0
  self.name = name
end

function Sitter:draw()
  love.graphics.drawq( tilesetImage, spriteQuads[self.name], self.x, self.y )
end

function Sitter:update(dt)
  self.x = self.x - (160 * dt)
end

----------------------------------------

Obstruction = class()

function Obstruction:init()
  self:pickPosition()
end

function Obstruction:pickPosition()
  self.x = 160
  self.y = (math.random(0, 1) * 32) + 48
end

function Obstruction:draw()
  love.graphics.setColor(255, 0, 0, 255)
  love.graphics.rectangle("fill", math.floor(self.x), self.y, 16, 32)
end

function Obstruction:update(dt)
  self.x = self.x - (160 * dt)
  if self.x <= -16 then
    self:pickPosition()
  end
end

----------------------------------------

MAP = strict { 1,2, 3,4, 1,2, 1,2, 1,2, 3,4, 1,2, 1,2, 1,2, 3,4, 1,2, 5,6 }

MAPTRANS = strict {
  { "leftDarkWindow", "rightDarkWindow", "leftTopDarkDoor",
    "rightTopDarkDoor", "leftTopArtCorner", "rightTopArtCorner" };
  { "leftSeats", "rightSeats", "leftBottomDoor",
    "rightBottomDoor", "leftSeatsCorner", "rightSeatsCorner" };
  { "leftHorizFloor", "rightHorizFloor", "leftVertFloor",
    "rightVertFloor", "leftFloorCorner", "rightFloorCorner" }
}

Background = class()

function Background:init()
  self.offset = 1
end

function Background:update(dt)
  self.offset = self.offset + (160 * dt)
  if self.offset > #MAP*12 then self.offset = self.offset - #MAP*12 end
end

function Background:draw()
  local y = 32
  local sx = math.floor(self.offset / 12)
  local ox = self.offset - ( sx * 12 )
  for x = 0, 14 do
    local t = x + 1 + sx
    while t > #MAP do t = t - #MAP end
    t = MAP[t]
    local a, b, c = MAPTRANS[1][t], MAPTRANS[2][t], MAPTRANS[3][t]
    love.graphics.drawq( tilesetImage, tileQuads[a], x*12-ox, y )
    love.graphics.drawq( tilesetImage, tileQuads[b], x*12-ox, y+14 )
    love.graphics.drawq( tilesetImage, tileQuads[c], x*12-ox, y+14+12 )
  end

--[[
  local x, i, y = 0, math.floor(self.offset), 32
  local MAP, MAPTRANS = MAP, MAPTRANS
  while x < 160 do
    local t = MAP[i]
    x, i = x + 12, i + 1
    if i > #MAP then i = 1 end
  end
]]
end

----------------------------------------

PlayState = class()

function PlayState:init()
  self.player = Player()
  self.thing = Obstruction()
  self.background = Background()
end

function PlayState:update(dt)
  if keypress["escape"]==1 then
    table.remove(stateStack)

  elseif keypress["return"]==1 then
    self:pause()

  else
    self.background:update(dt)
    self.player:update(dt)
    self.thing:update(dt)

    if self.player:detectCollision(self.thing) then
      table.remove(stateStack)
    end
  end
end

function PlayState:draw()
  love.graphics.setColor(255, 255, 255, 255)
  self.background:draw()
  self.player:draw()
  self.thing:draw()
end

function PlayState:pause()
  table.insert(stateStack, PausedState())
end

----------------------------------------

MenuState = class()

function MenuState:init()
  self.mode = 1
end

function MenuState:update(dt)
  if keypress["down"]==1 then
    self.mode = (self.mode + 1) % 3
  elseif keypress["up"]==1 then
    self.mode = (self.mode - 1) % 3
  elseif keypress["escape"]==1 then
    table.remove(stateStack)
  elseif keypress["return"]==1 then
    table.insert( stateStack, PlayState() )
  end
end

function MenuState:draw()
  love.graphics.setColor(0, 255, 128, 255)
  love.graphics.rectangle("fill", 8, 8, 144, 32)
  text( 16, 16, WHITE, "DIFFICULTY" )
  text( 32, 64, WHITE, "QUEENS" )
  text( 32, 80, WHITE, "BROOKLYN" )
  text( 32, 96, WHITE, "MANHATTAN" )
  love.graphics.rectangle("fill", 16, 64 + (self.mode * 16), 7, 7)
end

----------------------------------------

TitleState = class()

function TitleState:init()
  -- nop
end

function TitleState:update(dt)
  if keypress["escape"]==1 then
    table.remove(stateStack)
    return
  elseif keypress["return"]==1 then
    table.insert( stateStack, MenuState() )
  end
end

function TitleState:draw()
  love.graphics.setColor(0, 128, 255, 255)
  love.graphics.rectangle("fill", 8, 8, 144, 32)
  text( 16, 16, WHITE, "PANICKY COMMUTER" )
  text( 4, 108, WHITE, "(X) 2993 INMATARIAN" )
end

----------------------------------------

PausedState = class()

function PausedState:update(dt)
  if keypress["escape"]==1 or keypress["return"]==1 then
    table.remove(stateStack)
  end
end

function PausedState:draw()
  local n = #stateStack
  stateStack[n-1]:draw()
  love.graphics.setColor(0, 0, 0, 128)
  love.graphics.rectangle("fill", 0, 0, 160, 120)
  text( 16, 16, WHITE, "PAUSED" )
end

----------------------------------------

tileBounds = strict {
  leftDarkWindow = { 2, 2, 12, 14 },
  rightDarkWindow = { 15, 2, 12, 14 },
  leftLightWindow = { 2, 17, 12, 14 },
  rightLightWindow = { 15, 17, 12, 14 },
  leftTopDarkDoor = { 28, 2, 12, 14 },
  rightTopDarkDoor = { 41, 2, 12, 14 },
  leftTopLightDoor = { 28, 17, 12, 14 },
  rightTopLightDoor = { 41, 17, 12, 14 },
  leftTopArtCorner = { 54, 17, 12, 14 },
  rightTopArtCorner = { 67, 17, 12, 14 },
  leftSeats = { 2, 32, 12, 12 },
  rightSeats = { 15, 32, 12, 12 },
  leftBottomDoor = { 28, 32, 12, 12 },
  rightBottomDoor = { 41, 32, 12, 12 },
  leftSeatsCorner = { 54, 32, 12, 12 },
  rightSeatsCorner = { 67, 32, 12, 12 },
  leftHorizFloor = { 2, 45, 12, 32 },
  rightHorizFloor = { 15, 45, 12, 32 },
  leftVertFloor = { 28, 45, 12, 32 },
  rightVertFloor = { 41, 45, 12, 32 },
  leftFloorCorner = { 54, 45, 12, 32 },
  rightFloorCorner = { 67, 45, 12, 32 }
}

spriteBounds = strict {
  playerIcon = { 91, 19, 5, 6 },
  playerLeftLife = { 96, 19, 6, 6 },
  playerMiddleLife = { 103, 19, 6, 6 },
  playerRightLife = { 110, 19, 6, 6 },
  playerLeftDead = { 96, 26, 6, 6 },
  playerMiddleDead = { 103, 26, 6, 6 },
  playerRightDead = { 110, 26, 6, 6 },
  playerRunningOne = { 2, 80, 9, 13 },
  playerRunningTwo = { 13, 80, 9, 13 },
  playerDeadOne = { 26, 86, 11, 8 },
  playerDeadTwo = { 39, 86, 10, 8 },
  fatGuy = { 54, 80, 7, 14 },
  hoboGuy = { 64, 80, 10, 14 },
  bibleGuyOne = { 77, 80, 8, 14 },
  bibleGuyTwo = { 87, 80, 8, 14 },
  sittingOne = { 101, 80, 7, 14 },
  sittingTwo = { 110, 80, 7, 14 },
  sittingThree = { 119, 80, 7, 14 }
}

function loadTileset(name)
  tilesetImage = love.graphics.newImage(name)
  tilesetImage:setFilter("nearest", "nearest")
  local sw, sh = tilesetImage:getWidth(), tilesetImage:getHeight()

  tileQuads = {}
  for k, v in pairs( tileBounds ) do
    tileQuads[k] = love.graphics.newQuad(v[1], v[2], v[3], v[4], sw, sh)
  end

  spriteQuads = {}
  for k, v in pairs( spriteBounds ) do
    spriteQuads[k] = love.graphics.newQuad(v[1], v[2], v[3], v[4], sw, sh)
  end
end

fontset = [=[ !"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~]=]

function loadFont(name)
  local fontimage = love.graphics.newImage(name)
  fontimage:setFilter("nearest", "nearest")
  font = love.graphics.newImageFont(fontimage, fontset)
  font:setLineHeight( fontimage:getHeight() )
  love.graphics.setFont(font)
end

----------------------------------------

function love.load()
  math.randomseed( os.time() )
  love.graphics.setColorMode("modulate")
  love.graphics.setBlendMode("alpha")
  loadFont("cgafont.png")
  loadTileset("tileset.png")
  table.insert( stateStack, TitleState() )
end

function love.update(dt)
  for i, v in pairs(keypress) do
    keypress[i] = v+1
  end
  local n = #stateStack
  if n > 0 then
    stateStack[n]:update(dt)
  else
    love.event.push('q')
  end
end

function love.draw()
  local n = #stateStack
  if n > 0 then
    love.graphics.scale( xScale, yScale )
    stateStack[n]:draw()
  end
end

function love.keypressed(key, unicode)
  keypress[key] = 0
end

function love.keyreleased(key, unicode)
  keypress[key] = nil
end

function love.focus(focused)
  if not focused then
    local n = #stateStack
    if (n > 0) and (stateStack[n].pause) then
      stateStack[n]:pause()
    end
  end
end

