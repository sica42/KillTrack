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

StaticPopupDialogs.KILLTRACK_FINISH = {
  text = "%s entries removed.",
  button1 = "Okay",
  timeout = 10,
  enterClicksFirstButton = true,
  whileDead = true,
  hideOnEscape = true
}

StaticPopupDialogs.KILLTRACK_DELETE = {
  text = "Delete %s?",
  button1 = "Delete all",
  button2 = "CANCEL",
  button3 = "Character Only",
  OnAccept = function()
    KT:Delete( KT.Temp.DeleteName )
    KT.MobList:UpdateMobs()
    KT.MobList:UpdateEntries()
  end,
  OnAlt = function()
    KT:Delete( KT.Temp.DeleteName, true )
    KT.MobList:UpdateMobs()
    KT.MobList:UpdateEntries()
  end,
  showAlert = true,
  timeout = 10,
  whileDead = true,
  hideOnEscape = true
}

StaticPopupDialogs.KILLTRACK_PURGE = {
  text = "Remove all mob entries with their kill count below this threshold:",
  button1 = "Purge",
  button2 = "Cancel",
  hasEditBox = true,
  maxLetters = 6,
  OnAccept = function()
    local editBox = getglobal( this:GetParent():GetName() .. "EditBox" )
    KT:Purge( tonumber( editBox:GetText() ) --[[@as integer]] )
    KT.MobList:UpdateMobs()
    KT.MobList:UpdateEntries()
  end,
  OnCancel = function() KT.Temp.Threshold = nil end,
  OnShow = function()
    local editBox = getglobal( this:GetName() .. "EditBox" )
    local button1 = getglobal( this:GetName() .. "Button1" )

    if tonumber( KT.Temp.Threshold ) then
      editBox:SetText( tostring( KT.Temp.Threshold ) )
    else
      button1:Disable()
    end
  end,
  EditBoxOnTextChanged = function()
    local button1 = getglobal( this:GetParent():GetName() .. "Button1" )
    if tonumber( this:GetText() ) then
      button1:Enable()
    else
      button1:Disable()
    end
  end,
  EditBoxOnEscapePressed = function()
		this:GetParent():Hide()
	end,
  showAlert = true,
  enterClicksFirstButton = true,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true
}

StaticPopupDialogs.KILLTRACK_RESET = {
  text = "Remove all mob entries from the database? THIS CANNOT BE REVERSED.",
  button1 = "Yes",
  button2 = "No",
  OnAccept = function()
    KT:Reset()
    KT.MobList:UpdateMobs()
    KT.MobList:UpdateEntries()
  end,
  showAlert = true,
  enterClicksFirstButton = true,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true
}

---@param name string
function KT:ShowDelete( name )
  name = tostring( name )
  self.Temp.DeleteName = name
  StaticPopup_Show( "KILLTRACK_DELETE", name )
end

---@param threshold integer?
function KT:ShowPurge( threshold )
  if tonumber( threshold ) then
    self.Temp.Threshold = tonumber( threshold )
  end
  StaticPopup_Show( "KILLTRACK_PURGE" )
end

function KT:ShowReset()
  StaticPopup_Show( "KILLTRACK_RESET" )
end
