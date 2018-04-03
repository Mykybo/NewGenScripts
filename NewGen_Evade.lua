--[[ NewGen Evade
      made by
        Code BK-201 ]]--

require 'utils'
require 'Vector'
require 'NewGen_EvadeConfig'

-- print('-----------------')
-- print(io.popen"cd":read'*l')
-- print('-----------------')
-- local send = require 'sendinputscheduled'

local lengthOf, huge, pi,  floor, ceil, sqrt, max, min = math.lengthOf, math.huge, math.pi, math.floor, math.ceil, math.sqrt, math.max, math.min
local abs, deg, acos, atan = math.abs, math.deg, math.acos, math.atan
local insert, contains, remove, sort = table.insert, table.contains, table.remove, table.sort
local _HERO, _MINION, _TURRET = GameObjectType.AIHeroClient, GameObjectType.obj_AI_Minion, GameObjectType.obj_AI_Turret
local TEAM_JUNGLE = 300
local TEAM_ALLY = myHero.team
local TEAM_ENEMY = TEAM_JUNGLE - TEAM_ALLY
local Q,W,E,R = SpellSlot.Q, SpellSlot.W, SpellSlot.E, SpellSlot.R

-- local function clone(o, seen)
--   seen = seen or {}
--   if o == nil then return nil end
--   if seen[o] then return seen[o] end
--   local no
--   if type(o) == 'table' or type(o) == 'userdata' then
--     no = {}
--     seen[o] = no
--     for k, v in pairs(o) do
--       no[clone(k, seen)] = clone(v, seen)
--     end
--     setmetatable(no, clone(getmetatable(o), seen))
--   else -- number, string, boolean, etc
--     no = o
--   end
--   return no
-- end

local function class()
  local cls = {}
  cls.__index = cls
  return setmetatable(cls, {__call = function (c, ...)
      local instance = setmetatable({}, cls)
      if cls.__init then
          cls.__init(instance, ...)
      end
      return instance
  end})
end

Evade = class()

function OnLoad()
  Evade()
end

function Evade:__init()
  print('== LOADING EVADE ==')
  PrintChat("-- INITIALIZING EVADE --")
  -- AddEvent(Events.OnBasicAttack, function(...) self:OnProcessAutoAttack(...) end)
  -- AddEvent(Events.OnStopCastSpell, function(...) self:OnStopCast(...) end)
  -- AddEvent(Events.OnDeleteObject, function(...) self:OnDeleteObject(...) end)
  AddEvent(Events.OnProcessSpell, function(...) self:OnProcessSpell(...) end)
  AddEvent(Events.OnCreateObject, function(...) self:OnCreateObject(...) end)
  AddEvent(Events.OnIssueOrder, function(...) return self:OnIssueOrder(...) end)
  AddEvent(Events.OnTick, function() self:OnUpdate() end)
  AddEvent(Events.OnDraw, function() self:OnDraw() end)

  -- lists
  self.SpellObjectList = {}
  self.SpellList = {}
  -- settings
  self.drawFriendlySpells = true

  print("Loading spells...")
  self:LoadSpells(ObjectManager:GetEnemyHeroes())
  if self.drawFriendlySpells then
    self:LoadSpells(ObjectManager:GetAllyHeroes())
  end
  PrintChat("<font color=\"#66CCCC\"><b>NewGen Evade</b></font><b><font color=\"#FFFFFF\"> Loaded!</font>")
  print('== LOADED ==')
end

function Evade:LoadSpells(heroes)
  for k, hero in pairs(heroes) do
    for name, Spell in pairs(SkillShotDatabase) do
      if Spell.charName == hero.charName then -- mb should be charName?
        -- table.insert(self.SpellList, Spell)
        self.SpellList[name] = Spell
        print("Added "..name)
      end
    end
  end
end

-- workaround for start pos being overwritten in memory and userdata iteration not being implemented
function Evade:cloneSpellCastInfo(spell)
  local clonedSpell = {}
  clonedSpell.spellData = spell.spellData
  clonedSpell.spellSlot = spell.spellSlot
  clonedSpell.target = spell.target
  clonedSpell.level = spell.level
  clonedSpell.counter = spell.counter
  clonedSpell.startPos = D3DXVECTOR3(spell.startPos.x, spell.startPos.y, spell.startPos.z)
  clonedSpell.endPos = D3DXVECTOR3(spell.endPos.x, spell.endPos.y, spell.endPos.z)
  return clonedSpell
end

function Evade:OnUpdate()
  if (not myHero.isDead and self.SpellObjectList ~= nil) then
    self:Evade()
  end
end

function Evade:OnDraw()
  if self.BlockMovement then
    DrawHandler:Circle3D(self.lastOrderPos:ToDX3(), 50, 0xFFFFFFFF)
  end
  if (self.SpellObjectList ~= nil) then
    self:DrawSpells()
  end
end

function Evade:OnIssueOrder(order, targetPos)
  if self.BlockMovement and not CompareVectors(Vector(targetPos), self.lastOrderPos) then
    return 0
  end
  return 1
end

function CompareVectors(v1, v2)
  return floor(v1.x) == floor(v2.x) and floor(v1.z) == floor(v2.z)
end

function Evade:OnCreateObject(object, networkId)
  if (myHero.isDead or object == nil or object.name == nil or object.type == nil or object.type == -1 or object.type == 5 or (object.team == myHero.team and not self.drawFriendlySpells) or
      string.match(object.name, "SRU") or string.match(object.name, "BasicAttack") or string.match(object.name, "Item")) then
    return
  end
  print('name: '..object.name..' type: '..object.type)
  local spellInfo, spellName = self:GetSpellInfo(object.name)
  if (spellInfo ~= nil and spellName ~= nil) then
    if (self.SpellObjectList[spellName] == nil or self.SpellObjectList[spellName].spell == nil) then
      self.SpellObjectList[spellName] = {}
      self.SpellObjectList[spellName].allAdded = false
      self.SpellObjectList[spellName].timeToLive = GetTickCount() + 1000
    else
      self.SpellObjectList[spellName].allAdded = true
      self.SpellObjectList[spellName].timeToLive = nil
    end
    self.SpellObjectList[spellName].object = object
    self.SpellObjectList[spellName].spellInfo = spellInfo
    self.SpellObjectList[spellName].objectAdded = true
    print("-- INSERTED OBJECT: "..spellName)
  end
end

function Evade:OnProcessSpell(unit, spell)
  if spell and (unit ~= myHero or self.drawFriendlySpells) then
    if (spell.spellData and spell.spellData.name and spell.spellData.spellDataInfo) and (unit.team ~= myHero.team or self.drawFriendlySpells) then
      print("SPELL: "..spell.spellData.name)
      local spellInfo, spellName = self:GetSpellInfo(spell.spellData.name)
      if (spellInfo ~= nil and spellName ~= nil) then
        if (self.SpellObjectList[spellName] == nil or self.SpellObjectList[spellName].object == nil) then
          self.SpellObjectList[spellName] = {}
          self.SpellObjectList[spellName].allAdded = false
          self.SpellObjectList[spellName].timeToLive = GetTickCount() + 1000
        else
          self.SpellObjectList[spellName].allAdded = true
          self.SpellObjectList[spellName].timeToLive = nil
        end
        self.SpellObjectList[spellName].spell = self:cloneSpellCastInfo(spell)
        self.SpellObjectList[spellName].spellInfo = spellInfo
        self.SpellObjectList[spellName].evade = unit.team ~= myHero.team
        self.SpellObjectList[spellName].spellAdded = true
        print("-- INSERTED SPELL: "..spellName)
        -- fix end pos (currently it's on mouse location)
        local startP = Vector(spell.startPos.x, spell.startPos.y, spell.startPos.z)
        local endP = Vector(spell.endPos.x, spell.endPos.y, spell.endPos.z)
        self.SpellObjectList[spellName].spell.endPos = (startP - (startP - endP):Normalized() * (spellInfo.range + spellInfo.radius)):ToDX3()
      end
    end
  end
end

function Evade:GetSpellInfo(spellName)
  for name, Spell in pairs(self.SpellList) do
    if name == spellName or name..'Missile' == spellName or (Spell.particleName and Spell.particleName == spellName) then -- or string.match(spellName, name) then
      return Spell, name
    end
  end
  return nil, nil
end

function getOffsetLine(line, offset)
  local x1, y1, x2, y2 = line.startPos.x, line.startPos.y, line.endPos.x, line.endPos.y
  local L = sqrt((x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2))
  local resultLine = {}
  -- calc line start
  x = x1 + offset * (y2 - y1) / L
  y = y1 + offset * (x1 - x2) / L
  resultLine.startPos = D3DXVECTOR2(x, y)
  -- calc line end
  x = x2 + offset * (y2 - y1) / L
  y = y2 + offset * (x1 - x2) / L
  resultLine.endPos = D3DXVECTOR2(x, y)
  return resultLine
end

-- making this funct a member of Evade: makes it act weird... wtf?!
function DrawRect(startPos, endPos, width)
  -- first line
  local referenceLine = {}
  referenceLine.startPos = startPos
  referenceLine.endPos = endPos
  local line1 = getOffsetLine(referenceLine, width / 2)
  local line2 = getOffsetLine(referenceLine, -width / 2)
  -- side lines
  DrawHandler:Line(line1.startPos, line1.endPos, 0xFFFFFFFF)
  DrawHandler:Line(line2.startPos, line2.endPos, 0xFFFFFFFF)
  -- end line
  DrawHandler:Line(line1.endPos, line2.endPos, 0xFFFFFFFF)
  -- start line
  DrawHandler:Line(line1.startPos, line2.startPos, 0xFFFFFFFF)
end

function Evade:DrawSpells()
  for name, o in pairs(self.SpellObjectList) do
    -- print(o.object.name..'  '..o.spellInfo.particleName)
    if (o.allAdded and (o.object == nil or not o.object.isValid or (not string.match(o.object.name, name) and o.object.name ~= o.spellInfo.particleName))) then
      self.SpellObjectList[name] = nil
      print('REMOVED '..name)
    elseif (o.object ~= nil) then
      -- Draw the particle
      DrawHandler:Circle3D(o.object.position, o.spellInfo.radius, 0xFFFFFFFF)
      -- Draw spell path
      if (o.spellInfo.type == "circular") then
        if (o.spell == nil) then return end
        -- DrawHandler:Circle3D(o.spell.endPos, o.spellInfo.radius, 0xFFFFFFFF)
        -- DrawHandler:Circle3D(o.object.position, o.spellInfo.radius, 0xFFFFFFFF)
      --   -- print("Drawing CIRC skillshot: "..name)
      elseif (o.spellInfo.type == "linear") then
        if (o.spell ~= nil) then
          -- highlights start & end pos
          -- DrawHandler:Circle3D(o.spell.startPos, o.spellInfo.radius, 0xFFFFFFFF) -- 0xff0000
          -- DrawHandler:Circle3D(o.spell.endPos, o.spellInfo.radius, 0xFFFFFFFF) -- 0xff0000
          screenStart = Renderer:WorldToScreen(D3DXVECTOR3(o.object.position.x, 0, o.object.position.z))
          screenEnd = Renderer:WorldToScreen(D3DXVECTOR3(o.spell.endPos.x, 0, o.spell.endPos.z))
          DrawRect(screenStart, screenEnd, o.spellInfo.radius)
        end
      end
    end
  end
end

-- EVASION functs
function Evade:isValid(o)
    if (o == nil or (o.allAdded and (o.object == nil or not o.object.isValid))) then
    print("NOT VALID: "..o.spellInfo.name)
    return false
  end
  return true
end

-- winapi was not loading for some reason
-- function Evade:BlockMovement()
--   send.block_input(self.BlockMovement) -- 800 - useless
--   send.tick()
-- end

function Evade:Evade()
  self.BlockMovement = false
  for name, skillshot in pairs(self.SpellObjectList) do
    -- check validity
    if (skillshot.timeToLive and skillshot.timeToLive < GetTickCount()) then
      self.SpellObjectList[name] = nil
      -- self:BlockMovement()
      print("Removed! - timed out "..name)
      -- print('skillshot.timeToLive '..skillshot.timeToLive..' GetTickCount() '..GetTickCount())
      return
    end
    if not skillshot.evade then
      return
    end
    if (not skillshot.spellAdded or not skillshot.spell) then
      print('SPELL NOT ADDED '..name)
      return
    end
    if (not self:isValid(skillshot)) then
      self.SpellObjectList[name] = nil
      -- self:BlockMovement()
      print("Removed! - not valid")
      return
    end
    if (GetDistance(skillshot.spell.startPos) > skillshot.spellInfo.range) then
      print('SKILLSHOT out of RANGE '..name)
      return
    end
    -- XXX: use: skillshot.spell.startPos
    if (skillshot.objectAdded and (skillshot.spell == nil or GetDistance(skillshot.spell.startPos) < GetDistance(skillshot.object, skillshot.spell.startPos))) then
      print("Skillshot HAS PASSED: "..name)
      return
    end
    -- begin evasion
    if (skillshot.spellInfo.type == "linear") then
      self:EvadeLine(skillshot)
    elseif (skillshot.spellInfo.type == "circular") then
      self:EvadeCirc(skillshot)
    end
  end
end

function getSpPoint(A,B,C)
  x1, y1, x2, y2, x3, y3 = A.x, A.z, B.x, B.z, C.x, C.z
  px =  x2-x1
  py = y2-y1
  dAB = px*px + py*py
  u = ((x3 - x1) * px + (y3 - y1) * py) / dAB
  x = x1 + u * px
  y = y1 + u * py
  return x, y
end

function Evade:EvadeLine(skillshot)
  -- startPos = skillshot.startPos
  startPos = skillshot.spell.startPos
  endPos = skillshot.spell.endPos
  radius = skillshot.spellInfo.radius
  range = skillshot.spellInfo.range
  -- tempX = startPos.x + (range) / (floor(sqrt((startPos.x - endPos.x)^2 + (startPos.z - endPos.z)^2)))*(endPos.x - startPos.x)
  -- tempZ = startPos.z + (range) / (floor(sqrt((startPos.x - endPos.x)^2 + (startPos.z - endPos.z)^2)))*(endPos.z - startPos.z)

  -- calc1 = (floor(sqrt((endPos.x - myHero.position.x)^2 + (endPos.z - myHero.position.z)^2)))
  -- calc2 = (floor(sqrt((startPos.x - myHero.position.x)^2 + (startPos.z - myHero.position.z)^2)))
  -- calc4 = (floor(sqrt((startPos.x - endPos.x)^2 + (startPos.z - endPos.z)^2)))
  -- perpendicular = (floor((abs((endPos.x - startPos.x) * (startPos.z - myHero.position.z) - (startPos.x - myHero.position.x) * (endPos.z - startPos.z))) / (sqrt((endPos.x - startPos.x)^2 + (endPos.z - startPos.z)^2))))
  -- k = ((endPos.z - startPos.z) * (myHero.position.x - startPos.x) - (endPos.x - startPos.x) * (myHero.position.z - startPos.z)) / ((endPos.z - startPos.z)^2 + (endPos.x - startPos.x)^2)
  -- x4 = myHero.position.x - k * (endPos.z - startPos.z)
  -- z4 = myHero.position.z + k * (endPos.x - startPos.x)
  -- calc3 = sqrt((x4 - myHero.position.x)^2 + (z4 - myHero.position.z)^2) -- (floor
  -- if (calc3 == 0) then
  --   print('   startPos x '..startPos.x.. ' y '..startPos.y..' z '..startPos.z)
  --   print('   endPos x '..endPos.x.. ' y '..endPos.y..' z '..endPos.z)
  --   print('   myHero.position x '..myHero.position.x.. ' y '..myHero.position.y..' z '..myHero.position.z)
  --   print('   radius '..radius)
  --   print('   range '..range)
  --   print('   k '..k)
  --   print('   x4 '..x4)
  --   print('   z4 '..z4)
  --   return

  -- dodgeX -inf dodgeZ inf
  --  startPos x 12716 y 51.729400634766 z 5212
  --  endPos x 11578.04296875 y 51.729400634766 z 4745.1450195313
  --  myHero.position x 12358 y 51.729400634766 z 5066
  --  radius 80
  --  range 1150
  --  tempX 11652.056640625
  --  tempZ 4775.509765625

  -- startPos x 13508.93359375 y 52.300567626953 z 4588.3784179688
  --  endPos x 12976.634765625 y 50.851345062256 z 3479.5251464844
  --  myHero.position x 13166 y 51.366905212402 z 3874
  --  radius 80
  --  range 1150
  --  k 1.6524580814803e-07
  --  x4 13166
  --  z4 3874
  -- end
  x4, z4 = getSpPoint(startPos, endPos, myHero.position)
  onLine = Vector(x4, 0, z4)
  -- dodgeX = x4 + ((radius + myHero.boundingRadius / 2) / calc3) * (myHero.position.x - x4)
  -- dodgeZ = z4 + ((radius + myHero.boundingRadius / 2) / calc3) * (myHero.position.z - z4)
  heroV = Vector(myHero.position.x, 0, myHero.position.z)
  dodgePos = (onLine - (onLine - heroV):Normalized() * (radius + myHero.boundingRadius))
  dodgePos2 = (onLine - (onLine - heroV):Normalized() * (radius + myHero.boundingRadius + 20))
  dodgeX, dodgeZ = floor(dodgePos.x), floor(dodgePos.z)
  -- if perpendicular < radius and calc1 < calc4 and calc2 < calc4 then
  if (abs((onLine - heroV):Len()) < abs((onLine - dodgePos2):Len())) then
    print('dodgeX '..dodgeX..' dodgeZ '..dodgeZ)
    self.BlockMovement = true
    self.lastOrderPos = Vector(dodgeX, 0, dodgeZ)
    MoveToVec(D3DXVECTOR3(dodgeX, 0, dodgeZ))
    -- TODO: make this optional through menu
  self:DashEvadeTo(dodgeX, dodgeZ)
  end
  -- self:BlockMovement()
end

function Evade:EvadeCirc(skillshot)
  startPos = skillshot.spell.startPos
  endPos = skillshot.spell.endPos
  radius = skillshot.spellInfo.radius
  range = skillshot.spellInfo.range
  calc = (floor(sqrt((endPos.x - myHero.position.x)^2 + (endPos.z - myHero.position.z)^2)))
  dodgeX = endPos.x + ((radius + myHero.boundingRadius / 2) / calc)*(myHero.position.x - endPos.x)
  dodgeZ = endPos.z + ((radius + myHero.boundingRadius / 2) / calc)*(myHero.position.z - endPos.z)
  if calc < radius then
    self.BlockMovement = true
    self.lastOrderPos = Vector(dodgeX, 0, dodgeZ)
    MoveToVec(D3DXVECTOR3(dodgeX, 0, dodgeZ))
    -- TODO: make this optional through menu
    self:DashEvadeTo(dodgeX, dodgeZ)
  end
  -- self:BlockMovement()
end

function Evade:DashEvadeTo(x, z)
  startP = Vector(myHero.position.x, 0, myHero.position.z)
  endP = Vector(x, 0, z)
  dashPos = startP - (startP - endP):Normalized() * 300
  self:UseDash(dashPos:ToDX3())
end

function Evade:UseDash(dodgePos)
  ability = DashList[myHero.charName]
  if (ability ~= nil and IsReady(ability)) then
    CastSpell(ability, dodgePos)
  end
end

function IsReady(spell)
  return 0 == myHero.spellbook:CanUseSpell(spell)
end
