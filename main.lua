
stateStack = {}
keypress = {}

----------------------------------------

function new(class)
  local inst = {}
  inst.__index = class
  return setmetatable(inst, inst)
end

----------------------------------------

Player = {}
function Player.new()
  local self = new(Player)
  self.x = 24
  self.y = 80
  return self
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

Obstruction = {}
function Obstruction.new()
  local self = new(Obstruction)
  self:pickPosition()
  return self
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

PlayState = {}
function PlayState.new()
  local self = new(PlayState)
  self.player = Player.new()
  self.thing = Obstruction.new()
  return self
end

function PlayState:update(dt)
  if keypress["escape"]==1 then
    table.remove(stateStack)
    return
  end

  self.player:update(dt)
  self.thing:update(dt)

  if self.player:detectCollision(self.thing) then
    table.remove(stateStack)
  end
end

function PlayState:draw()
  self.player:draw()
  self.thing:draw()
end

----------------------------------------

TitleState = {}
function TitleState.new()
  local self = new(TitleState)
  return self
end

function TitleState:update(dt)
  if keypress["escape"]==1 then
    table.remove(stateStack)
    return
  elseif keypress["return"]==1 then
    table.insert(stateStack, PlayState.new())
  end
end

function TitleState:draw()
  love.graphics.setColor(0, 128, 255, 255)
  love.graphics.rectangle("fill", 8, 8, 144, 32)
end
----------------------------------------

function love.load()
  table.insert( stateStack, TitleState.new() )
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
    stateStack[n]:draw()
  end
end

function love.keypressed(key, unicode)
  keypress[key] = 0
end

function love.keyreleased(key, unicode)
  keypress[key] = nil
end

