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

---@class KillTrack
KT = KT or {}

---@class KillTrackTimer
local T = {
  Time = {
    Start = 0,
    Stop = 0
  },
  Running = false,
  ---@enum KillTrackTimerState
  State = {
    START = 0,
    UPDATE = 1,
    STOP = 2
  }
}

KT.Timer = T

local KTT = KT.Tools

---@class KillTrackTimerData
---@field Last integer
---@field Current integer
---@field Start integer
---@field Stop integer
---@field Total integer
---@field Left integer
---@field LeftFormat string
---@field Progress number
---@field __DATA__ { [any]: any }
local TimerData = {}

---@alias KillTrackTimerCallback fun(data: KillTrackTimerData, state: KillTrackTimerState)

T.Frame = CreateFrame( "Frame" )

local function TimeCheck( _, _ )
  if not T.Running then
    T.Frame:SetScript( "OnUpdate", nil )
    return
  end
  local now = time()
  TimerData.Last = now
  TimerData.Current = now - T.Time.Start
  TimerData.Start = T.Time.Start
  TimerData.Stop = T.Time.Stop
  TimerData.Total = TimerData.Stop - TimerData.Start
  TimerData.Left = TimerData.Total - TimerData.Current
  TimerData.LeftFormat = KTT:FormatSeconds( TimerData.Left )
  TimerData.Progress = TimerData.Current / TimerData.Total
  T:RunCallback( T:GetAllData(), T.State.UPDATE )
  if now >= T.Time.Stop then T:Stop() end
end

---@return KillTrackTimerData
function T:GetAllData()
  return KTT:TableCopy( TimerData )
end

---@param key any
---@param failsafe boolean
---@return any
function T:GetData( key, failsafe )
  local r
  if failsafe then r = 0 end
  if not TimerData.__DATA__ then if failsafe then return 0 else return nil end end
  return TimerData.__DATA__[ key ] or r
end

---@param key any
---@param value any
function T:SetData( key, value )
  if type( TimerData.__DATA__ ) ~= "table" then TimerData.__DATA__ = {} end
  TimerData.__DATA__[ key ] = value
end

---@return boolean
function T:IsRunning()
  return self.Running
end

---@param seconds integer?
---@param minutes integer?
---@param hours integer?
---@param callback KillTrackTimerCallback?
---@param data { [any]: any }?
---@return boolean
function T:Start( seconds, minutes, hours, callback, data )
  if self.Running then return false end
  self.Running = true
  self:Reset()
  seconds = tonumber( seconds ) or 0
  minutes = tonumber( minutes ) or 0
  hours = tonumber( hours ) or 0
  seconds = seconds + minutes * 60 + hours * 60 ^ 2
  if seconds <= 0 then
    self.Running = false
    KT:Msg( "Time must be greater than zero." )
    return false
  end
  if type( callback ) == "function" then
    self:SetCallback( callback )
  end
  if type( data ) == "table" then
    for k, v in pairs( data ) do
      self:SetData( k, v )
    end
  end
  self.Time.Start = time()
  self.Time.Stop = self.Time.Start + seconds
  self:RunCallback( self:GetAllData(), self.State.START )
  self.Frame:SetScript( "OnUpdate", TimeCheck )
  return true
end

function T:Stop()
  if not self.Running then return end
  self.Frame:SetScript( "OnUpdate", nil )
  self:RunCallback( self:GetAllData(), self.State.STOP )
  self.Running = false
  self.Time.Diff = self.Time.Stop - self.Time.Start
  return self.Time.Diff
end

function T:Reset()
  KTT:Wipe( TimerData )
  self.Time.Start = 0
  self.Time.Stop = 0
end

---@return KillTrackTimerCallback
function T:GetCallback()
  return self.Callback
end

---@param func KillTrackTimerCallback
function T:SetCallback( func )
  if type( func ) ~= "function" then error( "Argument 'func' must be of type 'function'." ) end
  self.Callback = func
end

---@param data KillTrackTimerData
---@param state KillTrackTimerState
function T:RunCallback( data, state )
  if type( data ) ~= "table" then error( "Argument 'data' must be of type 'table'." ) end
  local callback = self:GetCallback()
  if callback then callback( data, state ) end
end
