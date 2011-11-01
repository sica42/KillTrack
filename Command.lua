--[[
	* Copyright (c) 2011 by Adam Hellberg.
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

KillTrack.Command = {
	Slash = {
		"killtrack",
		"kt"
	},
	Commands = {}
}

local KT = KillTrack
local C = KT.Command
local KTT = KillTrack_Tools

--local CLib = ChocoboLib

-- Argument #1 (command) can be either string or a table.
function C:Register(command, func)
	if type(command) == "string" then
		command = {command}
	end
	for _,v in pairs(command) do
		if not self:HasCommand(v) then
			if v ~= "__DEFAULT__" then v = v:lower() end
			self.Commands[v] = func
		end
	end
end

function C:GetCommand(command)
	local cmd = self.Commands[command]
	if cmd then return cmd else return self.Commands["__DEFAULT__"] end
end

function C:HandleCommand(command, args)
	local cmd = self:GetCommand(command)
	if cmd then
		cmd(args)
	else
		KT:Msg(("%q is not a valid command."):format(command))
	end
end

C:Register("__DEFAULT__", function(args)
	KT:Msg(("%q is not a valid command."):format(tostring(msg)))
	KT:Msg("/kt target - Display number of kills on target mob.")
	KT:Msg("/kt <name> - Display number of kills on <name>, <name> can also be NPC ID.")
	KT:Msg("/kt print - Toggle printing kill updates to chat.")
	KT:Msg("/kt reset - Clear the mob database.")
	KT:Msg("/kt - Displays this help message.")
end)

C:Register({"target", "t", "tar"}, function(args)
	if not UnitExists("target") or UnitIsPlayer("target") then return end
	local id = KTT:GUIDToID(UnitGUID("target"))
	KT:PrintKills(id)
end)

C:Register({"print", "p"}, function(args)
	KT.Global.PRINTKILLS = not KT.Global.PRINTKILLS
	if KT.Global.PRINTKILLS then
		KT:Msg("Announcing kill updates.")
	else
		KT:Msg("No longer announcing kill updates.")
	end
end)

C:Register({"purge"}, function(args)
	local treshold
	if #args >= 1 then treshold = tonumber(args[1]) end
	KT:Purge(treshold)
end)

C:Register({"reset", "r"}, function(args)
	KT:Reset()
end)

C:Register({"lookup", "lo", "check"}, function(args)
	if #args <= 0 then
		KT:Msg("Missing argument: name")
		return
	end
	local name = table.concat(args, " ")
	KT:PrintKills(name)
end)

for i,v in ipairs(C.Slash) do
	_G["SLASH_" .. KT.Name:upper() .. i] = "/" .. v
end

SlashCmdList[KT.Name:upper()] = function(msg, editBox)
	msg = KTT:Trim(msg)
	local args = KTT:Split(msg)
	local cmd = args[1]
	local t = {}
	if #args > 1 then
		for i=2,#args do
			table.insert(t, args[i])
		end
	end
	C:HandleCommand(cmd, t)
end
