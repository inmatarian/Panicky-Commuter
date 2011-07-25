----------------------------------------
-- INNY'S DEPRESSING COMMUTER GAME
----------------------------------------

stateStack = {}
keypress = {}

xScale = math.floor(love.graphics.getWidth() / 160)
yScale = math.floor(love.graphics.getHeight() / 120)

font = nil
fontset = [=[ !"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~]=]

WHITE = { 255, 255, 255, 255 }

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

----------------------------------------

function text( x, y, color, str )
  love.graphics.setColor(color)
  for c in str:gmatch('.') do
    love.graphics.print(c, x, y)
    x = x + font:getWidth(c)
  end
end

----------------------------------------

Player = class()

function Player:init()
  self.x = 24
  self.y = 80
end

function Player:draw()
  love.graphics.setColor(255, 255, 255, 255)
  love.graphics.rectangle("fill", self.x, self.y, 16, 32)
end

function Player:update(dt)
  if keypress["down"]==1 then
    self.y = 80
  elseif keypress["up"]==1 then
    self.y = 48
  end
end

function Player:detectCollision( thing )
  local ax1, ax2, ay1, ay2 = self.x, self.x + 16, self.y, self.y + 32
  local bx1, bx2, by1, by2 = thing.x, thing.x + 16, thing.y, thing.y + 32
  return (ax1 < bx2) and (ax2 > bx1) and (ay1 < by2) and (ay2 > by1)
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
  love.graphics.rectangle("fill", self.x, self.y, 16, 32)
end

function Obstruction:update(dt)
  self.x = self.x - (160 * dt)
  if self.x <= -16 then
    self:pickPosition()
  end
end

----------------------------------------

PlayState = class()

function PlayState:init()
  self.player = Player()
  self.thing = Obstruction()
end

function PlayState:update(dt)
  if keypress["escape"]==1 then
    table.remove(stateStack)

  elseif keypress["return"]==1 then
    self:pause()

  else
    self.player:update(dt)
    self.thing:update(dt)

    if self.player:detectCollision(self.thing) then
      table.remove(stateStack)
    end
  end
end

function PlayState:draw()
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

function love.load()
  math.randomseed( os.time() )
  love.graphics.setColorMode("modulate")
  love.graphics.setBlendMode("alpha")

  local fontimage = love.graphics.newImage("cgafont.png")
  fontimage:setFilter("nearest", "nearest")
  font = love.graphics.newImageFont(fontimage, fontset)
  font:setLineHeight( fontimage:getHeight() )
  love.graphics.setFont(font)

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

