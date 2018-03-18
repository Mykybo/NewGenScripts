--[[ NewGen Evade
      made by
        Code BK-201 ]]--

require 'utils'
require 'Vector'
require 'SkillShotDatabase'

local lengthOf, huge, pi,  floor, ceil, sqrt, max, min = math.lengthOf, math.huge, math.pi, math.floor, math.ceil, math.sqrt, math.max, math.min
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

  -- Setup Dash List
  self.dashList = {
    ["Vayne"] = Q,
    ["Ezreal"] = E,
    ["Riven"] = E,
    ["Graves"] = E,
    ["Kassadin"] = R,
    ["Leblanc"] = W,
    ["Fizz"] = E,
    ["Shaco"] = Q,
    ["Corki"] = W,
    ["Renekton"] = E,
    ["Lucian"] = E,
    ["Tristana"] = W,
    ["Shen"] = E,
    ["Tryndamere"] = E,
  }

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

function Evade:OnUpdate()
  if (self.SpellObjectList ~= nil) then
    -- self:Evade()
  end
end

function Evade:OnDraw()
  if (self.SpellObjectList ~= nil) then
    self:DrawSpells()
  end
end

function Evade:OnCreateObject(object, networkId)
  if (myHero.isDead or object == nil or object.name == nil or object.type == nil or object.type == -1 or object.type == 5 or (object.team == myHero.team and not self.drawFriendlySpells) or
      string.match(object.name, "SRU") or string.match(object.name, "BasicAttack") or string.match(object.name, "Item")) then
    return
  end

  print('name: '..object.name..' type: '..object.type)

  local spellInfo, spellName = self:GetSpellInfo(object.name)
  if (spellInfo ~= nil and spellName ~= nil) then
    if (self.SpellObjectList[spellName] == nil) then
      print("CREATED SpellObject "..spellName..'.'..GetTickCount())
      self.SpellObjectList[spellName] = {}
      self.SpellObjectList[spellName].allAdded = false
    else
      self.SpellObjectList[spellName].startPos = object.position
      self.SpellObjectList[spellName].allAdded = true
      -- print('object.position: x '..object.position.x..' y '..object.position.y..' z '..object.position.z)
      -- print('self.SpellObjectList[spellName].spell.startPos: x '..self.SpellObjectList[spellName].spell.startPos.x..' y '..self.SpellObjectList[spellName].spell.startPos.y..' z '..self.SpellObjectList[spellName].spell.startPos.z)
    end
    self.SpellObjectList[spellName].object = object
    self.SpellObjectList[spellName].spellInfo = spellInfo
    print("-- INSERTED OBJECT: "..spellName)
  end
end

-- workaround for start pos being overwritten in memory and userdata iteration not being implemented
function cloneSpellCastInfo(spell)
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

function Evade:OnProcessSpell(unit, spell)
  if spell then -- unit ~= myHero
    if (spell.spellData and spell.spellData.name and spell.spellData.spellDataInfo) and (unit.team ~= myHero.team or self.drawFriendlySpells) then
      local spellInfo, spellName = self:GetSpellInfo(spell.spellData.name)
      if (spellInfo ~= nil and spellName ~= nil) then
        if (self.SpellObjectList[spellName] == nil) then
          self.SpellObjectList[spellName] = {}
          self.SpellObjectList[spellName].allAdded = false
        else
          self.SpellObjectList[spellName].allAdded = true
        end
        self.SpellObjectList[spellName].spell = cloneSpellCastInfo(spell)
        self.SpellObjectList[spellName].spellInfo = spellInfo
        print("-- INSERTED SPELL: "..spellName)
      end
    end
  end
end

function Evade:GetSpellInfo(spellName)
  for name, Spell in pairs(self.SpellList) do
    if spellName == name or string.match(spellName, name) then
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
  -- second line TODO
  DrawHandler:Line(line1.startPos, line1.endPos, 0xFFFFFFFF)
  DrawHandler:Line(line2.startPos, line2.endPos, 0xFFFFFFFF)
end

function Evade:DrawSpells()
  for name, o in pairs(self.SpellObjectList) do
    if (o.allAdded and (o.object == nil or not o.object.isValid or not string.match(o.object.name, name))) then
      self.SpellObjectList[name] = nil
    elseif (o.object ~= nil) then
      -- Draw the particle
      DrawHandler:Circle3D(o.object.position, o.spellInfo.radius, 0xFFFFFFFF)
      -- Draw spell path
      if (o.spellInfo.type == "circular") then
        -- if (o.spell == nil) then return end
        -- DrawHandler:Circle3D(o.spell.endPos, o.spellInfo.radius, 0xFFFFFFFF)
        -- DrawHandler:Circle3D(o.object.position, o.spellInfo.radius, 0xFFFFFFFF)
        -- print("Drawing CIRC skillshot: "..name)
      elseif (o.spellInfo.type == "linear") then
        -- highlights start pos
        if (o.spell ~= nil) then
          DrawHandler:Circle3D(o.spell.startPos, o.spellInfo.radius, 0xFFFFFFFF) -- 0xff0000
          DrawHandler:Circle3D(o.spell.endPos, o.spellInfo.radius, 0xFFFFFFFF) -- 0xff0000
          screenStart = Renderer:WorldToScreen(o.spell.startPos)
          screenEnd = Renderer:WorldToScreen(o.spell.endPos)
          DrawRect(screenStart, screenEnd, o.spellInfo.radius)
          -- rect = D3DXVECTOR4(screenStartP.x, screenStartP.y, screenEndP.x, screenEndP.y)
          -- if (rect.z ~= nan and rect.w ~= nan) then
          --   print('screenStartP StartPos: x '..o.spell.startPos.x.." y "..o.spell.startPos.y.." EndPos: x "..o.spell.endPos.x.." y "..o.spell.endPos.y)
          --   print('Drawing StartPos: x '..screenStartP.x.." y "..screenStartP.y.." EndPos: x "..screenEndP.x.." y "..screenEndP.y)
          --   -- DrawHandler:Rect(rect, 2, 0xFFFFFFFF)
          -- end
        end
      end
    end
  end
end

-- EVASION functs
function Evade:isValid(skillshot)
  if (skillshot == nil or skillshot.object == nil or skillshot.object.position == nil) then
    print("Skillshot NOT valid anymore: "..skillshot.spellInfo.name)
    return false
  end
  return true
end

function Evade:Evade()
  for name, skillshot in pairs(self.SpellObjectList) do
    -- check validity
    if (not skillshot.object or skillshot.object.team == myHero.team) then return end
    if (not self:isValid(skillshot)) then
      self.SpellObjectList[skillshot.spellInfo.name] = nil
      self.SpellObjectList[i] = nil
      skillshot = nil
      self.BlockMovement = false
      print("Removed!")
      return
    end
    -- XXX: use: skillshot.spell.startPos
    if (skillshot.spell == nil and GetDistance(skillshot.startPos) < GetDistance(skillshot.object, skillshot.startPos)) then
      print("Skillshot HAS PASSED: "..skillshot.spellInfo.name)
      return
    end
    -- begin evasion
    skillshot.evading = true
    if (skillshot.spellInfo.type == "linear") then
      self:EvadeLine(skillshot)
    elseif (skillshot.shot.type == "circular") then
      self:EvadeCirc(skillshot, skillshot.proc.startPos, skillshot.proc.endPos, skillshot.shot.radius, dangerIndex)
    end
  end
end

function Evade:EvadeLine(skillshot, dangerIndex)
  -- startPos = skillshot.startPos
  startPos = skillshot.spell.startPos
  endPos = skillshot.spell.endPos
  radius = skillshot.spellInfo.radius
  range = skillshot.spellInfo.range
  tempX = startPos.x + (range) / (floor(sqrt((startPos.x - endPos.x)^2 + (startPos.z - endPos.z)^2)))*(endPos.x - startPos.x)
  tempZ = startPos.z + (range) / (floor(sqrt((startPos.x - endPos.x)^2 + (startPos.z - endPos.z)^2)))*(endPos.z - startPos.z)
  calc1 = (floor(sqrt((tempX - myHero.position.x)^2 + (tempZ - myHero.position.z)^2)))
  calc2 = (floor(sqrt((startPos.x - myHero.position.x)^2 + (startPos.z - myHero.position.z)^2)))
  calc4 = (floor(sqrt((startPos.x - tempX)^2 + (startPos.z - tempZ)^2)))
  perpendicular = (floor((abs((tempX - startPos.x) * (startPos.z - myHero.position.z) - (startPos.x - myHero.position.x) * (tempZ - startPos.z))) / (sqrt((tempX - startPos.x)^2 + (tempZ - startPos.z)^2))))
  k = ((tempZ - startPos.z) * (myHero.position.x - startPos.x) - (tempX - startPos.x) * (myHero.position.z - startPos.z)) / ((tempZ - startPos.z)^2 + (tempX - startPos.x)^2)
  x4 = myHero.position.x - k * (tempZ - startPos.z)
  z4 = myHero.position.z + k * (tempX - startPos.x)
  calc3 = (floor(sqrt((x4-myHero.position.x)^2 + (z4-myHero.position.z)^2)))
  dodgeX = x4 + ((radius + myHero.boundingRadius / 2) / calc3) * (myHero.x - x4)
  dodgeZ = z4 + ((radius + myHero.boundingRadius / 2) / calc3) * (myHero.z - z4)
  if perpendicular < radius and calc1 < calc4 and calc2 < calc4 then
    self.BlockMovement = true
    MoveToVec(D3DXVECTOR3(dodgeX, 0, dodgeZ))
    -- TODO: make this optional through menu
    self:DashEvadeTo(dodgeX, dodgeZ)
  else
    self.BlockMovement = false
  end
end

function Evade:EvadeCirc(skillshot, dangerIndex)
  startPos = skillshot.spell.startPos
  endPos = skillshot.spell.endPos
  radius = skillshot.spellInfo.radius
  range = skillshot.spellInfo.range
  calc = (floor(sqrt((endPos.x - myHero.x)^2 + (endPos.z - myHero.z)^2)))
  dodgeX = endPos.x + ((radius + myHero.boundingRadius / 2) / calc)*(myHero.x - endPos.x)
  dodgeZ = endPos.z + ((radius + myHero.boundingRadius / 2) / calc)*(myHero.z - endPos.z)
  if calc < radius then
    BlockMovement = true
    MoveToVec(D3DXVECTOR3(dodgeX, 0, dodgeZ))
    -- TODO: make this optional through menu
    self:DashEvadeTo(dodgeX,dodgeZ)
  else
    BlockMovement = false
  end
end

function Evade:DashEvadeTo(x, z)
  startP = Vector(myHero.x, 0, myHero.z)
  endP = Vector(x, 0, z)
  dashPos = startP - (startP - endP):Normalized() * 300
  UseDash(dashPos:ToDX3())
end

function Evade:UseDash(dodgePos)
  ability = self.dashList[myHero.charName]
  if (ability ~= nil and IsReady(ability)) then
    CastSpell(ability, dodgePos)
  end
end