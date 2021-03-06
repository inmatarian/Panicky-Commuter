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
GRAY = strict { 144, 144, 144, 255 }

globalHighScore = 0

----------------------------------------

function text( x, y, color, str )
  if x == "center" then x = 80-(str:len()*4) end
  love.graphics.setColor(color)
  for c in str:gmatch('.') do
    love.graphics.print(c, x, y)
    x = x + font:getWidth(c)
  end
end

----------------------------------------

SINETABLE = strict {
  0, 0.195, 0.382, 0.555, 0.707, 0.831, 0.923, 0.98,
  1, 0.98, 0.923, 0.831, 0.707, 0.555, 0.382, 0.195,
  -0.001, -0.196, -0.383, -0.556, -0.708, -0.832, -0.924, -0.981,
  -1, -0.981, -0.924, -0.832, -0.708, -0.556, -0.383, -0.196, 0
}

function sine( degree )
  while degree < 0 do degree = degree + 360 end
  while degree > 360 do degree = degree - 360 end
  return SINETABLE[1+(math.floor((degree/(360/(#SINETABLE-1)))+0.5))]
end

----------------------------------------

function randomPull( ... )
  local pull = math.random(0, 10000) / 10000
  for n = 1, select('#', ...) do
    local e = select(n, ...)
    if pull < e then return n end
    pull = pull - e
  end
  return nil
end

----------------------------------------

Sound = {
  bank = {};
  effectFiles = { DEATH="DEATH.wav", CHIRP="CHIRP.wav" };
  effectData = {};
}

function Sound.init()
  for name, file in pairs(Sound.effectFiles) do
    Sound.effectData[name] = love.sound.newSoundData(file)
  end
end

function Sound.playsound(name)
  local sound = love.audio.newSource(Sound.effectData[name])
  Sound.bank[sound] = sound
  love.audio.play(sound)
end

function Sound.playmod( file )
  Sound.stopmod()
  Sound.bgm = love.audio.newSource(file, "stream")
  Sound.bgm:setLooping( true )
  Sound.bgm:setVolume(0.8)
  love.audio.play(Sound.bgm)
  Sound.bgmfile = file
end

function Sound.stopmod()
  if not Sound.bgm then return end
  love.audio.stop(Sound.bgm)
  Sound.bgm = nil
  Sound.bgmfile = nil
end

function Sound.update()
  local remove = {}
  for _, src in pairs(Sound.bank) do
    if src:isStopped() then table.insert(remove, src) end
  end
  for _, src in ipairs(remove) do
    Sound.bank[src] = nil
  end
end

----------------------------------------

function updateHighScore( newScore )
  if newScore > globalHighScore then
    globalHighScore = newScore
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
  self.x = 32
  self.y = 72
  self.blink = 0
  self.lives = 3
  local rate = 1/10
  self.anim = Animator()
  self.anim:add( "playerRunningOne", rate )
  self.anim:add( "playerRunningTwo", rate )
end

function Player:draw()
  if (self.blink <= 0) or (math.floor(self.blink*10)%2 == 0) then
    drawSprite( self.anim:current(), self.x, self.y )
  end
end

function Player:update(dt)
  if self.blink > 0 then self.blink = self.blink - dt end
  if keypress["down"]==1 then
    self.y = 72
  elseif keypress["up"]==1 then
    self.y = 56
  end
  self.anim:update(dt)
end

function Player:detectCollision( thing )
  if self.blink > 0 then return false end
  local ax1, ax2, ay1, ay2 = self.x + 2, self.x + 4, self.y + 2, self.y + 6
  local bx1, bx2, by1, by2 = thing.x + 2, thing.x + 4, thing.y + 2, thing.y + 6
  return (ax1 < bx2) and (ax2 > bx1) and (ay1 < by2) and (ay2 > by1)
end

----------------------------------------

Sprite = class()

function Sprite:init( pos, speed, name )
  self.x = 160
  self.y = pos
  self.speed = speed
  self.name = name
end

function Sprite:draw()
  if self.name then
    drawSprite( self.name, self.x, self.y )
  end
end

function Sprite:update(dt)
  self.x = self.x - (self.speed * dt)
end

----------------------------------------

Sitter = class( Sprite )
Sitter.nameList = { "sittingOne", "sittingTwo", "sittingThree", "sittingFour" }

function Sitter:init( speed )
  Sprite.init( self, 45, speed, self.nameList[math.random(#self.nameList)] )
end

----------------------------------------

FatGuy = class( Sprite )
FatGuy.possibleY = { 56, 72 }

function FatGuy:init( speed )
  local y = self.possibleY[ math.random(1, 2) ]
  Sprite.init( self, y, speed, "fatGuy" )
end

----------------------------------------

HoboGuy = class( Sprite )
HoboGuy.possibleY = { 56, 72 }

function HoboGuy:init( speed, player )
  local y = self.possibleY[ math.random(1, 2) ]
  Sprite.init( self, y, speed, "hoboGuy" )
  self.player = player
  self.barrier = 72
end

function HoboGuy:update(dt)
  Sprite.update( self, dt )
  if self.x <= self.barrier then
    self.barrier = self.barrier - 64
    if math.random(1, 2) == 1 then
      self.y = self.player.y
    end
  end
end

----------------------------------------

BibleGuy = class( Sprite )
BibleGuy.possibleY = { 56, 72 }

function BibleGuy:init()
  local y = self.possibleY[ math.random(1, 2) ]
  local rate = 1/10
  Sprite.init( self, y, 0, "bibleGuyOne" )
  self.x = 0
  self.clock = 0
  self.anim = Animator()
  self.anim:add( "bibleGuyOne", rate )
  self.anim:add( "bibleGuyTwo", rate )
end

function BibleGuy:update(dt)
  self.clock = self.clock + dt
  if self.clock < 1.5 then
    local t = math.floor(self.clock * 4)
    if t % 2 == 0 then
      if not self.name then
        Sound.playsound("CHIRP")
      end
      self.name = "bibleGuyOne"
    else
      self.name = nil
    end
  else
    self.x = self.x + (45 * dt)
    self.anim:update(dt)
    self.name = self.anim:current()
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

function Background:init( speed )
  self.lastOffset = 1
  self.offset = 1
  self.speed = speed
end

function Background:update(dt)
  self.lastOffset = self.offset
  self.offset = self.offset + (self.speed * dt)
  if self.offset > #MAP*12 then self.offset = self.offset - #MAP*12 end
end

function Background:draw()
  local floor = math.floor
  local y = 32
  local sx = floor(self.offset / 12)
  local ox = self.offset - ( sx * 12 )
  for x = 0, 14 do
    local t = x + 1 + sx
    while t > #MAP do t = t - #MAP end
    t = MAP[t]
    drawTile( MAPTRANS[1][t], floor(x*12-ox), floor(y) )
    drawTile( MAPTRANS[2][t], floor(x*12-ox), floor(y+14) )
    drawTile( MAPTRANS[3][t], floor(x*12-ox), floor(y+14+12) )
  end
end

----------------------------------------

DIFFICULTY = {
  {
    speed = 100,
    blink = 2,
    fatguy = 0.1,
    hobo = 0.025,
    cooloff = 2,
    bible = 0.001,
    sitters = 0.30,
    score = 2
  }, {
    speed = 120,
    blink = 1.5,
    fatguy = 0.15,
    hobo = 0.075,
    cooloff = 0.75,
    bible = 0.0025,
    sitters = 0.50,
    score = 5
  }, {
    speed = 140,
    blink = 0.75,
    fatguy = 0.3,
    hobo = 0.15,
    cooloff = 0.25,
    bible = 0.0075,
    sitters = 0.90,
    score = 20
  }
}

----------------------------------------

PlayState = class()

function PlayState:init( mode )
  self.player = Player()
  self.things = {}
  self.background = Background( mode.speed )
  self.mode = mode
  self.score = 0
  self.cooloff = 1
  self.clock = 0
  Sound.playmod("game.s3m")
end

function PlayState:update(dt)
  if keypress["escape"]==1 then
    table.remove(stateStack)

  elseif keypress["return"]==1 then
    self:pause()

  else
    self.clock = self.clock + dt
    if self.cooloff > 0 then self.cooloff = self.cooloff - dt end
    self.background:update(dt)
    self.player:update(dt)
    self:updateThings(dt)
    self:checkCollisions()
    self:addThings()
    self:updateScore(dt)
  end
end

function PlayState:addThings()
  local offset = self.background.offset
  local mode = self.mode
  if math.floor(offset/12) == math.floor(self.background.lastOffset/12) then return end

  local column = 1 + (math.floor((offset+160)/12) % #MAP)
  local tile = MAP[column]
  if tile == 1 or tile == 2 then
    if randomPull( mode.sitters ) == 1 then
      local thing = Sitter( mode.speed )
      self.things[thing] = true
    end
  end

  if tile == 1 or tile == 3 then
    local which = randomPull( mode.fatguy, mode.hobo, mode.bible )
    local thing
    if which == 1 then
      thing = FatGuy( mode.speed )
    elseif which == 2 and self.cooloff <= 0 then
      thing = HoboGuy( mode.speed, self.player )
      self.cooloff = mode.cooloff
    elseif which == 3 and self.cooloff <= 0 then
      self.cooloff = mode.cooloff
      thing = BibleGuy()
    end
    if thing then self.things[thing] = true end
  end
end

function PlayState:updateThings(dt)
  removal = {}
  for thing, _ in pairs(self.things) do
    thing:update(dt)
    if (thing.x < -16) or (thing.x > 180) then
      table.insert( removal, thing )
    end
  end
  for thing, _ in pairs(removal) do
    self.things[thing] = nil
  end
end

function PlayState:checkCollisions()
  for thing, _ in pairs(self.things) do
    if self.player:detectCollision(thing) then
      self.player.lives = self.player.lives - 1
      Sound.playsound("DEATH")
      if self.player.lives <= 0 then
        table.remove(stateStack)
        table.insert(stateStack, GameOverState( self.score ))
      else
        self.player.blink = self.mode.blink
      end
      break
    end
  end
end

function PlayState:draw()
  love.graphics.setColor(255, 255, 255, 255)
  self.background:draw()
  self:drawThings()
  self.player:draw()
  self:drawScore()
  self:drawLives()
end

function PlayState:pause()
  table.insert(stateStack, PausedState())
end

function PlayState:updateScore(dt)
  self.score = self.score + (dt * self.mode.score)
end

function PlayState:drawScore()
  text( "center", 98, WHITE, string.format("SCORE: %05i", self.score) )
  text( "center", 106, GRAY, string.format("HIGH:  %05i", globalHighScore) )
end

function PlayState:drawThings()
  things = {}
  for thing, _ in pairs(self.things) do
    table.insert( things, thing )
  end
  table.sort( things, function(a, b) if a.y < b.y then return true end; return false end )
  for _, thing in ipairs(things) do
    thing:draw()
  end
end

function PlayState:drawLives()
  local lives = self.player.lives
  local blink = (math.floor(self.clock*5)%2==0)
  local a, b, c
  if lives == 1 and blink then a = "playerLeftDead" else a = "playerLeftLife" end
  if lives == 2 and blink or lives < 2 then b = "playerMiddleDead" else b = "playerMiddleLife" end
  if lives == 3 and blink or lives < 3 then c = "playerRightDead" else c = "playerRightLife" end
  local quads = { "playerIcon", a, b, c }
  love.graphics.setColor(WHITE)
  for i, v in ipairs( quads ) do
    drawSprite( v, 56 + 8*i, 12 )
  end
end

----------------------------------------

ReadySetGoState = class()

function ReadySetGoState:init(mode)
  Sound.stopmod()
  self.clock = 0
  self.mode = mode
end

function ReadySetGoState:update(dt)
  self.clock = self.clock + dt
  if self.clock >= 1.5 then
    table.remove(stateStack)
    table.insert(stateStack, PlayState( self.mode ))
  end
end

function ReadySetGoState:draw()
  local label
  if self.clock < 0.5 then label = "START IN 3.."
  elseif self.clock < 1 then label = "START IN 3..2.."
  else label = "START IN 3..2..1.."
  end
  text( 8, 56, WHITE, label )
end

----------------------------------------

GameOverState = class()

function GameOverState:init( score )
  self.score = score
  self.clock = 0
  Sound.stopmod()
end

function GameOverState:update(dt)
  self.clock = self.clock + dt
  if self.clock > 3 or
     keypress["return"]==1 or
     keypress["escape"]==1
  then
    updateHighScore(self.score)
    table.remove(stateStack)
  end
end

function GameOverState:draw()
  text( "center", 20, WHITE, "YOU ARE LATE" )
  text( "center", 28, WHITE, "FOR WORK!!" )
  text( "center", 48, WHITE, "GAME OVER" )
  text( "center", 64, WHITE, "FINAL SCORE" )
  text( "center", 72, WHITE, string.format("%i", self.score) )
end

----------------------------------------

CreditState = class()
CreditState.text = {
 "Inmate2993",
 "E.Megas",
 "Angie",
 "Mr.Business",
 "Dormando",
 "MadBrain",
 "Angie",
 "Patches",
 "Spooky",
 "Dusty",
}

function CreditState:init()
  self.loop = 0
end

function CreditState:update(dt)
  self.loop = self.loop + 100*dt
  if self.loop > 120 then self.loop = self.loop - 120 end
  if keypress["escape"]==1 or keypress["return"]==1 then
    table.remove(stateStack)
  end
end

function CreditState:draw()
  for i, v in ipairs(self.text) do
    local y = -4 + ((self.loop + 12*(i-1)) % 120)
    text( "center", y, WHITE, v )
  end
end

----------------------------------------

TitleMarquee = class()
TitleMarquee.text = {
  "----XXX---XX--X--X-XXX--XX-X--X-X---X----XX--XX--X---X-X---X-X--X-XXX-XXXX-XXX------";
  "----X--X-X--X-XX-X--X--X---X-X---X-X----X---X--X-XX-XX-XX-XX-X--X--X--X----X--X-----";
  "----XXX--XXXX-X-XX--X--X---XX-----X-----X---X--X-X-X-X-X-X-X-X--X--X--XXX--XXX------";
  "----X----X--X-X--X--X--X---X-X----X-----X---X--X-X---X-X---X-X--X--X--X----X--X-----";
  "----X----X--X-X--X-XXX--XX-X--X---X------XX--XX--X---X-X---X--XX---X--XXXX-X--X-----";
}

function TitleMarquee:init()
  self.offset = 0
end

function TitleMarquee:update(dt)
  self.offset = self.offset + (100 * dt)
  local N = self.text[1]:len()
  if self.offset > N*8 then self.offset = self.offset - N*8 end
end

function TitleMarquee:draw()
  local sx = math.floor(self.offset / 8)
  local ox = self.offset - ( sx * 8 )
  local J = #self.text
  local N = self.text[1]:len()
  for x = 0, 20 do
    local t = x + 1 + sx
    while t > N do t = t - N end
    local yo = sine( 360 * (x*8-ox)/160 )
    for j = 1, J do
      if self.text[j]:sub( t, t ) == 'X' then
        drawSprite( "playerRightLife", x*8-ox, 8*j + 12*yo )
      end
    end
  end
end

----------------------------------------

TitleState = class()
TitleState.modeList = {
  "LOCAL",
  "SHUTTLE",
  "EXPRESS",
  "CREDITS"
}

function TitleState:init()
  self.mode = 0
  self.marquee = TitleMarquee()
end

function TitleState:update(dt)
  self:setMusic()
  self.marquee:update(dt)
  if keypress["escape"]==1 then
    table.remove(stateStack)
    return
  elseif keypress["down"]==1 then
    self.mode = (self.mode + 1) % #self.modeList
    Sound.playsound("CHIRP")
  elseif keypress["up"]==1 then
    self.mode = (self.mode - 1) % #self.modeList
    Sound.playsound("CHIRP")
  elseif keypress["return"]==1 then
    if self.mode == (#self.modeList - 1) then
      newState = CreditState()
    else
      newState = ReadySetGoState( DIFFICULTY[self.mode+1] )
    end
    table.insert( stateStack, newState )
  end
end

function TitleState:draw()
  self.marquee:draw()
  for i, v in ipairs( self.modeList ) do
    text( 32, 50 + (i * 12), WHITE, v )
  end
  text( 4, 110, WHITE, "(X) 2993 INMATARIAN" )
  drawSprite( "playerIcon", 16, 50 + ((self.mode+1) * 12) )
end

function TitleState:setMusic()
  if Sound.bgmfile ~= "title.s3m" then
    Sound.playmod("title.s3m")
  end
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
  text( "center", 56, WHITE, "PAUSED" )
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
  playerIcon = { 100, 2, 5, 6 },
  playerLeftLife = { 106, 2, 6, 6 },
  playerMiddleLife = { 113, 2, 6, 6 },
  playerRightLife = { 120, 2, 6, 6 },
  playerLeftDead = { 106, 9, 6, 6 },
  playerMiddleDead = { 113, 9, 6, 6 },
  playerRightDead = { 120, 9, 6, 6 },
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
  sittingThree = { 119, 80, 7, 14 },
  sittingFour = { 119, 64, 7, 14 }
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

function drawTile( name, x, y )
  love.graphics.drawq( tilesetImage, tileQuads[name],
    math.floor(x*xScale)/xScale, math.floor(y*yScale)/yScale )
end

function drawSprite( name, x, y )
  love.graphics.drawq( tilesetImage, spriteQuads[name],
    math.floor(x*xScale)/xScale, math.floor(y*yScale)/yScale )
end

----------------------------------------

function saveScreenshot()
  local screen = love.graphics.newScreenshot()
  filedata = love.image.newEncodedImageData(screen, "bmp")
  love.filesystem.write( "screenshot.bmp", filedata)
end

function changeScale( size )
  xScale, yScale = size, size
  love.graphics.setMode( 160 * xScale, 120 * yScale, false )
end

----------------------------------------

function love.load()
  math.randomseed( os.time() )
  love.graphics.setColorMode("modulate")
  love.graphics.setBlendMode("alpha")
  loadFont("cgafont.png")
  loadTileset("tileset.png")
  Sound.init()
  table.insert( stateStack, TitleState() )
end

function love.update(dt)
  if dt > 0.1 then dt = 0.1 end
  for i, v in pairs(keypress) do
    keypress[i] = v+1
  end
  if keypress["f2"] == 1 then
    saveScreenshot()
  elseif keypress["1"]==1 then changeScale(1)
  elseif keypress["2"]==1 then changeScale(2)
  elseif keypress["3"]==1 then changeScale(3)
  elseif keypress["4"]==1 then changeScale(4)
  elseif keypress["5"]==1 then changeScale(5)
  elseif keypress["6"]==1 then changeScale(6)
  elseif keypress["7"]==1 then changeScale(7)
  elseif keypress["8"]==1 then changeScale(8)
  end
  local n = #stateStack
  if n > 0 then
    stateStack[n]:update(dt)
  else
    love.event.push('q')
  end
  Sound.update()
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

