--[[
    * Copyright (c) 2011-2020 by Adam Hellberg.
    *
    * This file is part of KillTrack.
    *
    * KillTrack is free software: you can redistribute it and/or modify
    * it under the terms of the GNU General Public License as published by
    * the Free Software Foundation, either version 3 of the License, or
    * (at your option) any later version.
    *
    * KillTrack is distributed in the hope that it will be useful,
    * but WITHOUT ANY WARRANTY; without even the implied warranty of
    * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    * GNU General Public License for more details.
    *
    * You should have received a copy of the GNU General Public License
    * along with KillTrack. If not, see <http://www.gnu.org/licenses/>.
--]]

---@type string
local NAME = "KillTrack"

---@class KillTrack
---@field PlayerName string
local KT = KT or {}
--local KT = select(2, ...)

---@class KillTrackMobData
---@field Kills integer
---@field Name string
---@field ZoneName string
---@field LastKillAt integer?
---@field AchievCount integer
---@field Exp integer?

---@class KillTrackCharMobData
---@field Kills integer
---@field Name string
---@field ZoneName string
---@field LastKillAt integer?

_G = getfenv()
--_G[NAME] = KT

-- Upvalue some functions used in CLEU
local IsGUIDInGroup = IsGUIDInGroup
local UnitGUID = UnitGUID
local UnitIsTapDenied = UnitIsTapDenied
--local UnitTokenFromGUID = UnitTokenFromGUID
local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo
local GetServerTime = GetServerTime

local NO_NAME = "<No Name>"

KT.Name = NAME
KT.Version = GetAddOnMetadata( NAME, "Version" )
KT.Events = {}

---@class KillTrackImmediatePosition
---@field POINT string?
---@field RELATIVE string?
---@field X number?
---@field Y number?

---@class KillTrackGlobal
---@field LOAD_MESSAGE boolean
---@field PRINTKILLS boolean
---@field PRINTNEW boolean
---@field ACHIEV_THRESHOLD integer
---@field COUNT_GROUP boolean
---@field SHOW_EXP boolean
---@field MOBS { [integer]: KillTrackMobData }
---@field IMMEDIATE { POSITION: KillTrackImmediatePosition, THRESHOLD: integer, FILTER: string? }
---@field BROKER { SHORT_TEXT: boolean, MINIMAP: { hide: boolean } }
---@field DISABLE_DUNGEONS boolean
---@field DISABLE_RAIDS boolean
---@field TOOLTIP boolean
---@field DATETIME_FORMAT string
KT.Global = {}

---@class KillTrackCharGlobal
---@field MOBS { [integer]: KillTrackCharMobData }
KT.CharGlobal = {}

---@class KillTrackTemp
---@field Threshold integer?
---@field DeleteName string?
KT.Temp = {}

---@enum KillTrackMobSortMode
KT.Sort = {
  Desc = 0,
  Asc = 1,
  CharDesc = 2,
  CharAsc = 3,
  AlphaD = 4,
  AlphaA = 5,
  IdDesc = 6,
  IdAsc = 7
}
KT.Session = {
  Count = 0,
  ---@type { [string]: integer? }
  Kills = {}
}
KT.Messages = {
  Announce = "[KillTrack] Session Length: %s. Session Kills: %d. Kills Per Minute: %.2f."
}

KT.Defaults = {
  DateTimeFormat = "%Y-%m-%d %H:%M:%S"
}

KT.RosterDmg = {}
KT.PetDmg = {}

---@type KillTrackExpTracker
local ET

local KTT = KT.Tools

-- Upvalue as it's used in CLEU
local GUIDToID = KTT.GUIDToID

---@type { [string]: string? }
local FirstDamage = {} -- Tracks first damage to a mob registered by CLEU

---@type { [string]: string? }
local LastDamage = {} -- Tracks whoever did the most recent damage to a mob

---@type { [string]: boolean? }
local HasPlayerDamage = {} -- Tracks whether the player (or pet) has dealt damage to a mob

---@type { [string]: boolean? }
local HasGroupDamage = {} -- Tracks whether a group member has dealt damage to a mob

---@type { [string]: boolean? }
local DamageValid = {} -- Determines if mob is tapped by player/group

local combat_log_damage_events = {}
do
  local prefixes = { "SWING", "RANGE", "SPELL", "SPELL_PERIODIC", "SPELL_BUILDING" }
  local suffixes = { "DAMAGE", "DRAIN", "LEECH", "INSTAKILL" }
  for _, prefix in pairs( prefixes ) do
    for _, suffix in pairs( suffixes ) do
      combat_log_damage_events[ prefix .. "_" .. suffix ] = true
    end
  end
end

if KT.Version == "@" .. "project-version" .. "@" then
  KT.Version = "Development"
  KT.Debug = true
end

if not UnitTokenFromGUID then
  local units = {
    "player",
    "vehicle",
    "pet",
    "party1", "party2", "party3", "party4",
    "partypet1", "partypet2", "partypet3", "partypet4"
  }
  -- Multiple loops to get the same ordering as mainline API
  for i = 1, 40 do
    units[ getn( units ) + 1 ] = "raid" .. i
  end
  for i = 1, 40 do
    units[ getn( units ) + 1 ] = "raidpet" .. i
  end
  for i = 1, 40 do
    units[ getn( units ) + 1 ] = "nameplate" .. i
  end
  for i = 1, 5 do
    units[ getn( units ) + 1 ] = "arena" .. i
  end
  for i = 1, 5 do
    units[ getn( units ) + 1 ] = "arenapet" .. i
  end
  for i = 1, 8 do
    units[ getn( units ) + 1 ] = "boss" .. i
  end
  units[ getn( units ) + 1 ] = "target"
  units[ getn( units ) + 1 ] = "focus"
  units[ getn( units ) + 1 ] = "npc"
  units[ getn( units ) + 1 ] = "mouseover"
  units[ getn( units ) + 1 ] = "softenemy"
  units[ getn( units ) + 1 ] = "softfriend"
  units[ getn( units ) + 1 ] = "softinteract"

  UnitTokenFromGUID = function( guid )
    for _, unit in ipairs( units ) do
      if UnitGUID( unit ) == guid then
        return unit
      end
    end
    return nil
  end
end

---@param event string
function KT:OnEvent( event )
  if self.Events[ event ] then
    self.Events[ event ]()
  end
end

-----@param self KillTrack
-----@param name string
function KT.Events.ADDON_LOADED()
  local self = KT
  if arg1 ~= NAME then return end
  ET = KT.ExpTracker
  if type( _G[ "KILLTRACK" ] ) ~= "table" then
    _G[ "KILLTRACK" ] = {}
  end
  self.Global = _G[ "KILLTRACK" ]
  if type( self.Global.LOAD_MESSAGE ) ~= "boolean" then
    self.Global.LOAD_MESSAGE = false
  end
  if type( self.Global.PRINTKILLS ) ~= "boolean" then
    self.Global.PRINTKILLS = false
  end
  if type( self.Global.PRINTNEW ) ~= "boolean" then
    self.Global.PRINTNEW = false
  end
  if type( self.Global.ACHIEV_THRESHOLD ) ~= "number" then
    self.Global.ACHIEV_THRESHOLD = 1000
  end
  if type( self.Global.COUNT_GROUP ) ~= "boolean" then
    self.Global.COUNT_GROUP = false
  end
  if type( self.Global.SHOW_EXP ) ~= "boolean" then
    self.Global.SHOW_EXP = false
  end
  if type( self.Global.MOBS ) ~= "table" then
    self.Global.MOBS = {}
  end
  if type( self.Global.IMMEDIATE ) ~= "table" then
    self.Global.IMMEDIATE = {}
  end
  if type( self.Global.IMMEDIATE.POSITION ) ~= "table" then
    self.Global.IMMEDIATE.POSITION = {}
  end
  if type( self.Global.IMMEDIATE.THRESHOLD ) ~= "number" then
    self.Global.IMMEDIATE.THRESHOLD = 0
  end
  if type( self.Global.BROKER ) ~= "table" then
    self.Global.BROKER = {}
  end
  if type( self.Global.BROKER.SHORT_TEXT ) ~= "boolean" then
    self.Global.BROKER.SHORT_TEXT = false
  end
  if type( self.Global.BROKER.MINIMAP ) ~= "table" then
    self.Global.BROKER.MINIMAP = {}
  end
  if type( self.Global.DISABLE_DUNGEONS ) ~= "boolean" then
    self.Global.DISABLE_DUNGEONS = false
  end
  if type( self.Global.DISABLE_RAIDS ) ~= "boolean" then
    self.Global.DISABLE_RAIDS = false
  end
  if type( self.Global.TOOLTIP ) ~= "boolean" then
    self.Global.TOOLTIP = true
  end
  if type( self.Global.DATETIME_FORMAT ) ~= "string" then
    self.Global.DATETIME_FORMAT = self.Defaults.DateTimeFormat
  end
  if type( _G[ "KILLTRACK_CHAR" ] ) ~= "table" then
    _G[ "KILLTRACK_CHAR" ] = {}
  end
  self.CharGlobal = _G[ "KILLTRACK_CHAR" ]
  if type( self.CharGlobal.MOBS ) ~= "table" then
    self.CharGlobal.MOBS = {}
  end
  self.PlayerName = UnitName( "player" )

  self.Session.Start = time()
  self.Broker:OnLoad()
end

function KT.Events.PLAYER_LOGIN()
  if KT.Global.LOAD_MESSAGE then
    KT:Msg( "AddOn Loaded!" )
  end
end

function KT.Events.CHAT_MSG_COMBAT_PET_HITS()
  local target = string.match( arg1, "^%S+ %S+ (.+) for" )
  KT.PetDmg[ target ] = true
end

function KT.Events.CHAT_MSG_COMBAT_PARTY_HITS()
  if not KTT.IsInGroup() or not KT.Global.COUNT_GROUP then return end
  local target = string.match( arg1, "^%S+ %S+ (.+) for" )
  KT.RosterDmg[ target ] = true
end

function KT.Events.CHAT_MSG_SPELL_PARTY_DAMAGE()
  if not KTT.IsInGroup() or not KT.Global.COUNT_GROUP then return end
  local target = string.match( arg1, "^%S+'s .- hits (.+) for" )
  if not target then
    target = string.match( arg1, "^%S+'s .- crits (.+) for" )
  end

  if target then
    KT.RosterDmg[ target ] = true
  end
end

function KT.Events.CHAT_MSG_COMBAT_HOSTILE_DEATH()
  local re = "^" .. string.gsub( SELFKILLOTHER, "%%s!", "(%.+)!$")
  local target = string.match( arg1, re )

  if target then
    KT:AddKill( target )
    return
  end

  re = string.gsub( UNITDIESOTHER, "%%s", "^(%.+)")
  re = string.gsub( re, "%.$", ".$" )
  target = string.match( arg1, re )

  if target and KT.PetDmg[ target ] then
    KT:AddKill( target )
    return
  end

  if KTT.IsInGroup() and KT.Global.COUNT_GROUP then
    if target and KT.RosterDmg[ target ] then
      KT:AddKill( target )
      return
    end
  end
end

--[[
---@param self KillTrack
function KT.Events.COMBAT_LOG_EVENT_UNFILTERED( self )
  print( "combat log event" )
  local _, event, _, s_guid, _, _, _, d_guid, d_name, _, _ = CombatLogGetCurrentEventInfo()
  if combat_log_damage_events[ event ] then
    if FirstDamage[ d_guid ] == nil then
      -- s_guid is (probably) the player who first damaged this mob and probably has the tag
      FirstDamage[ d_guid ] = s_guid
    end

    LastDamage[ d_guid ] = s_guid

    if s_guid == self.PlayerGUID or s_guid == UnitGUID( "pet" ) then
      HasPlayerDamage[ d_guid ] = true
    elseif self:IsInGroup( s_guid ) then
      HasGroupDamage[ d_guid ] = true
    end

    if not DamageValid[ d_guid ] then
      -- if DamageValid returns true for a GUID, we can tell with 100% certainty that it's valid
      -- But this relies on one of the valid unit names currently being the damaged mob

      local d_unit = UnitTokenFromGUID( d_guid )

      if not d_unit then return end

      DamageValid[ d_guid ] = not UnitIsTapDenied( d_unit )
    end

    return
  end

  if event ~= "UNIT_DIED" then return end

  -- Perform solo/group checks
  local d_id = GUIDToID( d_guid )
  local firstDamage = FirstDamage[ d_guid ]
  local lastDamage = LastDamage[ d_guid ]
  local damageValid = DamageValid[ d_guid ]
  local hasPlayerDamage = HasPlayerDamage[ d_guid ]
  local hasGroupDamage = HasGroupDamage[ d_guid ]
  FirstDamage[ d_guid ] = nil
  LastDamage[ d_guid ] = nil
  DamageValid[ d_guid ] = nil
  HasPlayerDamage[ d_guid ] = nil
  HasGroupDamage[ d_guid ] = nil

  -- If we can't identify the mob there's no point continuing
  if d_id == nil or d_id == 0 then return end

  local petGUID = UnitGUID( "pet" )
  local firstByPlayer = firstDamage == self.PlayerGUID or firstDamage == petGUID
  local firstByGroup = self:IsInGroup( firstDamage )
  local lastByPlayer = lastDamage == self.PlayerGUID or lastDamage == petGUID

  -- The checks when DamageValid is non-false are not 100% failsafe
  -- Scenario: You deal the killing blow to an already tapped mob <- Would count as kill with current code

  -- If damageValid is false, it means tap is denied on the mob and there is no way the kill would count
  if damageValid == false then return end

  -- If neither the player not group was involved in the battle, we don't count the kill
  if not hasPlayerDamage and not hasGroupDamage then return end

  if damageValid == nil and not firstByPlayer and not firstByGroup then
    -- If we couldn't get a proper tapped status and the first recorded damage was not by player or group,
    -- we can't be sure the kill was valid, so ignore it
    return
  end

  if not lastByPlayer and not self.Global.COUNT_GROUP then
    return -- Player or player's pet did not deal the killing blow and addon only tracks player kills
  end

  self:AddKill( d_name )
  if self.Timer:IsRunning() then
    self.Timer:SetData( "Kills", self.Timer:GetData( "Kills", true ) + 1 )
  end
end
]]

function KT.Events.CHAT_MSG_COMBAT_XP_GAIN()
  ET:CheckMessage( arg1 )
end

---@param self KillTrack
---@param size integer
function KT.Events.ENCOUNTER_START( self, _, _, _, size )
  print("encounter start")
  if (self.Global.DISABLE_DUNGEONS and size == 5) or (self.Global.DISABLE_RAIDS and size > 5) then
    self.Frame:UnregisterEvent( "COMBAT_LOG_EVENT_UNFILTERED" )
    self.Frame:UnregisterEvent( "UPDATE_MOUSEOVER_UNIT" )
    self.Frame:UnregisterEvent( "CHAT_MSG_COMBAT_XP_GAIN" )
  end
end

---@param self KillTrack
---@param size integer
function KT.Events.ENCOUNTER_END( self, _, _, _, size )
  print("encounter end")
  if (self.Global.DISABLE_DUNGEONS and size == 5) or (self.Global.DISABLE_RAIDS and size > 5) then
    self.Frame:RegisterEvent( "COMBAT_LOG_EVENT_UNFILTERED" )
    self.Frame:RegisterEvent( "UPDATE_MOUSEOVER_UNIT" )
    self.Frame:RegisterEvent( "CHAT_MSG_COMBAT_XP_GAIN" )
  end
end

function KT.tooltip_enhancer( unit )
  if KT.Global.TOOLTIP and not KT.tooltipModified then
    if unit and not UnitIsPlayer( unit ) and UnitCanAttack( "player", unit ) then
      KT.tooltipModified = true
      local mob, charMob = KT:InitMob( UnitName( unit ) )
      local gKills, cKills = mob.Kills, charMob.Kills
      local exp = mob.Exp

      if gKills > 0 or cKills > 0 then
        GameTooltip:AddLine( string.format( "Killed %d (%d) times.", cKills, gKills ), 1, 1, 1 )
        if KT.Global.SHOW_EXP and exp then
          local toLevel = exp > 0 and math.ceil( (UnitXPMax( "player" ) - UnitXP( "player" )) / exp ) or "N/A"
          GameTooltip:AddLine( string.format( "EXP: %d (%s kills to level)", exp, toLevel ), 1, 1, 1 )
        end
        if KT.Debug then
          GameTooltip:AddLine( string.format( "ID = %s  ", UnitName( unit ) ) )
        end
        GameTooltip:Show()
      end
    end
  end
end

KT._SetUnit = GameTooltip.SetUnit
---@diagnostic disable-next-line: duplicate-set-field
function GameTooltip:SetUnit( unit )
  KT._SetUnit( self, unit )
  KT.tooltip_enhancer( unit )
end

KT._GameTooltipOnHide = GameTooltip:GetScript( "OnHide" )
GameTooltip:SetScript( "OnHide", function()
  if KT._GameTooltipOnHide then
    KT._GameTooltipOnHide()
  end
  KT.tooltipModified = false
end )

KT._GameTooltipOnUpdate = GameTooltip:GetScript( "OnUpdate" )
GameTooltip:SetScript( "OnUpdate", function()
  if KT._GameTooltipOnUpdate then
    KT._GameTooltipOnUpdate()
  end

  KT.tooltip_enhancer( "mouseover" )
end )

function KT:ToggleLoadMessage()
  self.Global.LOAD_MESSAGE = not self.Global.LOAD_MESSAGE
  if self.Global.LOAD_MESSAGE then
    self:Msg( "Now showing message on AddOn load" )
  else
    self:Msg( "No longer showing message on AddOn load" )
  end
end

function KT:ToggleExp()
  self.Global.SHOW_EXP = not self.Global.SHOW_EXP
  if self.Global.SHOW_EXP then
    self:Msg( "Now showing EXP on tooltips!" )
  else
    self:Msg( "No longer showing EXP on tooltips." )
  end
end

function KT:ToggleDebug()
  self.Debug = not self.Debug
  if self.Debug then
    self:Msg( "Debug enabled!" )
  else
    self:Msg( "Debug disabled!" )
  end
end

---@param threshold integer
function KT:SetThreshold( threshold )
  if type( threshold ) ~= "number" then
    error( "KillTrack.SetThreshold: Argument #1 (threshold) must be of type 'number'" )
  end
  self.Global.ACHIEV_THRESHOLD = threshold
  if threshold > 0 then
    self:ResetAchievCount()
    self:Msg( string.format("New kill notice (achievement) threshold set to %d.", threshold ) )
  else
    self:Msg( "Kill notices have been disabled (set threshold to a value greater than 0 to re-enable)." )
  end
end

---@param threshold integer
function KT:SetImmediateThreshold( threshold )
  if type( threshold ) ~= "number" then
    error( "KillTrack.SetImmediateThreshold: Argument #1 (threshold) must be of type 'number'" )
  end
  self.Global.IMMEDIATE.THRESHOLD = threshold
  if threshold > 0 then
    self:Msg( string.format( "New immediate threshold set to %d.", threshold ) )
  else
    self:Msg( "Immediate threshold disabled." )
  end
end

---@param filter string
function KT:SetImmediateFilter( filter )
  if type( filter ) ~= "string" then
    error( "KillTrack.SetImmediateFilter: Argument #1 (filter) must be of type 'string'" )
  end
  self.Global.IMMEDIATE.FILTER = filter
  self:Msg( "New immediate filter set to: " .. filter )
end

function KT:ClearImmediateFilter()
  self.Global.IMMEDIATE.FILTER = nil
  KT:Msg( "Immediate filter cleared!" )
end

function KT:ToggleCountMode()
  self.Global.COUNT_GROUP = not self.Global.COUNT_GROUP
  if self.Global.COUNT_GROUP then
    self:Msg( "Now counting kills for every player in the group (party/raid)!" )
  else
    self:Msg( "Now counting your own killing blows ONLY." )
  end
end

-----@param id string
---@param name string
---@return KillTrackMobData
---@return KillTrackCharMobData
function KT:InitMob( name )
  local id = name
  local zone_name = GetRealZoneText()

  if type( self.Global.MOBS[ name ] ) ~= "table" then
    self.Global.MOBS[ name ] = { Name = name, ZoneName = zone_name, Kills = 0, AchievCount = 0 }
    if self.Global.PRINTNEW then
      self:Msg( ("Created new entry for %q"):format( name ) )
    end
--  elseif self.Global.MOBS[ name ].Name ~= name then
    --self.Global.MOBS[ name ].Name = name
  end

  if type( self.CharGlobal.MOBS[ name ] ) ~= "table" then
    self.CharGlobal.MOBS[ name ] = { Name = name, ZoneName = zone_name, Kills = 0 }
    if self.Global.PRINTNEW then
      self:Msg( ("Created new entry for %q on this character."):format( name ) )
    end
  --elseif self.CharGlobal.MOBS[ id ].Name ~= name then
--    self.CharGlobal.MOBS[ id ].Name = name
  end

  return self.Global.MOBS[ name ], self.CharGlobal.MOBS[ name ]
end

---@param name string
function KT:AddKill( name )
  if not name then return end
  local id = name
  local current_time = time() --GetServerTime()
  self:InitMob( name )
  local globalMob = self.Global.MOBS[ id ]
  local charMob = self.CharGlobal.MOBS[ id ]
  globalMob.Kills = self.Global.MOBS[ id ].Kills + 1
  globalMob.LastKillAt = current_time
  charMob.Kills = self.CharGlobal.MOBS[ id ].Kills + 1
  charMob.LastKillAt = current_time

  KT.RosterDmg[ name ] = nil
  KT.PetDmg[ name ] = nil

  self:AddSessionKill( name )
  if self.Timer:IsRunning() then
    self.Timer:SetData( "Kills", self.Timer:GetData( "Kills", true ) + 1 )
  end

  if self.Global.PRINTKILLS then
    local kills = self.Global.MOBS[ id ].Kills
    local cKills = self.CharGlobal.MOBS[ id ].Kills
    self:Msg( string.format( "Updated %q, new kill count: %d. Kill count on this character: %d", name, kills, cKills ) )
  end

  if self.Immediate.Active then
    local filter = self.Global.IMMEDIATE.FILTER
    local filterPass = not filter or string.find( name, filter )
    if filterPass then
      self.Immediate:AddKill()
      if self.Global.IMMEDIATE.THRESHOLD > 0 and mod( self.Immediate.Kills, self.Global.IMMEDIATE.THRESHOLD ) == 0 then
        PlaySound( "RaidWarning" )
        PlaySound( "PVPTHROUGHQUEUE" )
        RaidWarningFrame:AddMessage( string.format( "%d KILLS!", self.Immediate.Kills ) )
      end
    end
  end
  if self.Global.ACHIEV_THRESHOLD <= 0 then return end
  if type( self.Global.MOBS[ id ].AchievCount ) ~= "number" then
    self.Global.MOBS[ id ].AchievCount = floor( self.Global.MOBS[ id ].Kills / self.Global.ACHIEV_THRESHOLD )
    if self.Global.MOBS[ id ].AchievCount >= 1 then
      self:KillAlert( self.Global.MOBS[ id ] )
    end
  else
    local achievCount = self.Global.MOBS[ id ].AchievCount
    self.Global.MOBS[ id ].AchievCount = floor( self.Global.MOBS[ id ].Kills / self.Global.ACHIEV_THRESHOLD )
    if self.Global.MOBS[ id ].AchievCount > achievCount then
      self:KillAlert( self.Global.MOBS[ id ] )
    end
  end
end

---@param id integer
---@param name string?
---@param globalCount integer
---@param charCount integer
function KT:SetKills( id, name, globalCount, charCount )
  if type( id ) ~= "number" then
    error( "'id' argument must be a number" )
  end

  if type( globalCount ) ~= "number" then
    error( "'globalCount' argument must be a number" )
  end

  if type( charCount ) ~= "number" then
    error( "'charCount' argument must be a number" )
  end

  name = name or NO_NAME

  self:InitMob( name )
  self.Global.MOBS[ id ].Kills = globalCount
  self.CharGlobal.MOBS[ id ].Kills = charCount

  self:Msg( ("Updated %q to %d global and %d character kills"):format( name, globalCount, charCount ) )
end

---@param name string
function KT:AddSessionKill( name )
  if self.Session.Kills[ name ] then
    self.Session.Kills[ name ] = self.Session.Kills[ name ] + 1
  else
    self.Session.Kills[ name ] = 1
  end
  self.Session.Count = self.Session.Count + 1
end

---@param name string
---@param exp integer|string
function KT:SetExp( name, exp )
  for _, mob in pairs( self.Global.MOBS ) do
    if mob.Name == name then mob.Exp = tonumber( exp ) end
  end
end

---@param max integer|string?
---@return { Name: string, Kills: integer }[]
function KT:GetSortedSessionKills( max )
  max = tonumber( max ) or 3
  local t = {}
  for k, v in pairs( self.Session.Kills ) do
    t[ getn( t ) + 1 ] = { Name = k, Kills = v }
  end
  table.sort( t, function( a, b ) return a.Kills > b.Kills end )
  -- Trim table to only contain 3 entries
  local trimmed = {}
  local c = 0
  for i, v in ipairs( t ) do
    trimmed[ i ] = v
    c = c + 1
    if c >= max then break end
  end
  return trimmed
end

function KT:ResetSession()
  KTT:Wipe( self.Session.Kills )
  self.Session.Count = 0
  self.Session.Start = time()
end

---@param id integer
---@return integer globalKills
---@return integer charKills
function KT:GetKills( id )
  local gKills, cKills = 0, 0
  local mob = self.Global.MOBS[ id ]
  if type( mob ) == "table" then
    gKills = mob.Kills
    local cMob = self.CharGlobal.MOBS[ id ]
    if type( cMob ) == "table" then
      cKills = cMob.Kills
    end
  end
  return gKills, cKills
end

---@return integer
function KT:GetTotalKills()
  local count = 0
  for _, mob in pairs( self.Global.MOBS ) do
    count = count + mob.Kills
  end
  return count
end

---@return integer killsPerSecond
---@return integer killsPerMinute
---@return integer killsPerHour
---@return integer killsThisSession
function KT:GetSessionStats()
  if not self.Session.Start then return 0, 0, 0, 0 end
  local now = time()
  local session = now - self.Session.Start
  local kps = session == 0 and 0 or self.Session.Count / session
  local kpm = kps * 60
  local kph = kpm * 60
  return kps, kpm, kph, session
end

---@param name string
function KT:PrintKills( name )
  local found = false
  local gKills = 0
  local cKills = 0
  local lastKillAt = nil
  --if type( identifier ) ~= "string" and type( identifier ) ~= "number" then identifier = NO_NAME end
  for k, v in pairs( self.Global.MOBS ) do
    if type( v ) == "table" and (tostring( k ) == tostring( name ) or v.Name == name) then
      name = v.Name
      gKills = v.Kills
      if type( v.LastKillAt ) == "number" then
        lastKillAt = KTT:FormatDateTime( v.LastKillAt )
      end
      if self.CharGlobal.MOBS[ k ] then
        cKills = self.CharGlobal.MOBS[ k ].Kills
      end
      found = true
    end
  end
  if found then
    self:Msg( string.format( "You have killed %q %d times in total, %d times on this character", name, gKills, cKills ) )
    if lastKillAt then
      self:Msg( string.format( "Last killed at %s", lastKillAt ) )
    end
  else
    if UnitExists( "target" ) and not UnitIsPlayer( "target" ) then
      name = UnitName( "target" )
    end
    self:Msg( string.format( "Unable to find %q in mob database.", tostring( name ) ) )
  end
end

---@param target string
function KT:Announce( target )
  if target == "GROUP" then
    target = ((KTT.IsInRaid() and "RAID") or (KTT.IsInGroup() and "PARTY")) or "SAY"
  end
  local _, kpm, _, length = self:GetSessionStats()
  local msg = string.format(self.Messages.Announce, KTT:FormatSeconds( length ), self.Session.Count, kpm )
  SendChatMessage( msg, target )
end

---@param msg string
function KT:Msg( msg )
  DEFAULT_CHAT_FRAME:AddMessage( "\124cff00FF00[KillTrack]\124r " .. msg )
end

---@param msg string
function KT:DebugMsg( msg )
  if not self.Debug then return end
  self:Msg( "[DEBUG] " .. msg )
end

---@param mob KillTrackMobData
function KT:KillAlert( mob )
  local data = {
    Text = string.format("%d kills on %s!", mob.Kills, mob.Name ),
    Title = "Kill Record!",
    bTitle = "Congratulations!",
    Icon = "Interface\\Icons\\ABILITY_Deathwing_Bloodcorruption_Death",
    FrameStyle = "GuildAchievement"
  }
  if IsAddOnLoaded( "Glamour" ) then
    if not _G[ "GlamourShowAlert" ] then
      self:Msg( "ERROR: GlamourShowAlert == nil! Notify AddOn developer." )
      return
    end
    _G.GlamourShowAlert( 500, data )
  else
    PlaySound( "RaidWarning" )
    PlaySound( "PVPTHROUGHQUEUE" )
    RaidWarningFrame:AddMessage( data.Text )
  end
  self:Msg( data.Text )
end

---@param id integer|string
---@return KillTrackMobData|false
---@return KillTrackCharMobData|nil
function KT:GetMob( id )
  for k, v in pairs( self.Global.MOBS ) do
    if type( v ) == "table" and (tostring( k ) == tostring( id ) or v.Name == id) then
      return v, self.CharGlobal.MOBS[ k ]
    end
  end
  return false, nil
end

---@param mode KillTrackMobSortMode|integer?
---@param filter string?
---@param caseSensitive boolean|nil
---@return { Id: integer, Name: string, gKills: integer, cKills: integer }[]
function KT:GetSortedMobTable( mode, filter, caseSensitive )
  if not tonumber( mode ) then mode = self.Sort.Desc end
  if mode < 0 or mode > 7 then mode = self.Sort.Desc end
  if filter and filter == "" then filter = nil end
  local t = {}
  for k, v in pairs( self.Global.MOBS ) do
    assert( type( v ) == "table", "Unexpected mob entry type in db: " .. type( v ) .. ". Expected table" )
    local matches = nil
    if filter then
      local name = caseSensitive and v.Name or string.lower( v.Name )
      filter = caseSensitive and filter or string.lower( filter )
      local status, result = pcall( function() return string.find( name, filter ) end )
      matches = status and result
    end
    if matches or not filter then
      local cKills = 0
      if self.CharGlobal.MOBS[ k ] and type( self.CharGlobal.MOBS[ k ] ) == "table" then
        cKills = self.CharGlobal.MOBS[ k ].Kills
      end
      local entry = { Id = k, Name = v.Name, gKills = v.Kills, cKills = cKills }
      table.insert( t, entry )
    end
  end
  local function compare( a, b )
    if mode == self.Sort.Asc then
      return a.gKills < b.gKills
    elseif mode == self.Sort.CharDesc then
      return a.cKills > b.cKills
    elseif mode == self.Sort.CharAsc then
      return a.cKills < b.cKills
    elseif mode == self.Sort.AlphaD then
      return a.Name > b.Name
    elseif mode == self.Sort.AlphaA then
      return a.Name < b.Name
    elseif mode == self.Sort.IdDesc then
      return a.Id > b.Id
    elseif mode == self.Sort.IdAsc then
      return a.Id < b.Id
    else
      return a.gKills > b.gKills -- Descending
    end
  end
  table.sort( t, compare )
  return t
end

---@param name string
---@param charOnly boolean?
function KT:Delete( name, charOnly )
  --id = tonumber( id ) --[[@as integer]]
  --if not id then error( ("Expected 'id' param to be number, got %s."):format( type( id ) ) ) end
  local found = false
  --local name
  if self.Global.MOBS[ name ] then
    --name = self.Global.MOBS[ id ].Name
    if not charOnly then self.Global.MOBS[ name ] = nil end
    if self.CharGlobal.MOBS[ name ] then
      self.CharGlobal.MOBS[ name ] = nil
    end
    found = true
  end
  if found then
    self:Msg( string.format("Deleted %s from database.", name ) )
    StaticPopup_Show( "KILLTRACK_FINISH", 1 )
  else
    self:Msg( string.format("%s was not found in the database.", name ) )
  end
end

---@param threshold integer
function KT:Purge( threshold )
  local count = 0
  for k, v in pairs( self.Global.MOBS ) do
    if type( v ) == "table" and v.Kills < threshold then
      self.Global.MOBS[ k ] = nil
      count = count + 1
    end
  end
  for k, v in pairs( self.CharGlobal.MOBS ) do
    if type( v ) == "table" and v.Kills < threshold then
      self.CharGlobal.MOBS[ k ] = nil
      count = count + 1
    end
  end
  self:Msg( ("Purged %d entries with a kill count below %d"):format( count, threshold ) )
  self.Temp.Threshold = nil
  StaticPopup_Show( "KILLTRACK_FINISH", tostring( count ) )
end

function KT:Reset()
  local count = getn( self.Global.MOBS ) + getn( self.CharGlobal.MOBS )
  wipe( self.Global.MOBS )
  wipe( self.CharGlobal.MOBS )
  self:Msg( ("%d mob entries have been removed!"):format( count ) )
  StaticPopup_Show( "KILLTRACK_FINISH", tostring( count ) )
end

function KT:ResetAchievCount()
  for _, v in pairs( self.Global.MOBS ) do
    v.AchievCount = floor( v.Kills / self.Global.ACHIEV_THRESHOLD )
  end
end

KT.Frame = CreateFrame( "Frame" )

for k, _ in pairs( KT.Events ) do
  KT.Frame:RegisterEvent( k )
end

KT.Frame:SetScript( "OnEvent", function() KT:OnEvent( event ) end )
