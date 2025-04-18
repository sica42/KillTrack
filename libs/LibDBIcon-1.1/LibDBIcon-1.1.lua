--[[
Name: DBIcon-1.0
Revision: $Rev: 30 $
Author(s): Rabbit (rabbit.magtheridon@gmail.com)
Description: Allows addons to register to recieve a lightweight minimap icon as an alternative to more heavy LDB displays.
Dependencies: LibStub
License: GPL v2 or later.
]]

--[[
Copyright (C) 2008-2011 Rabbit

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
]]

-----------------------------------------------------------------------
-- DBIcon-1.1
-- Modified by Sica to work with Turtle WoW Client (11200)
--
-- Disclaimer: Most of this code was ripped from Barrel but fixed, streamlined
--             and cleaned up a lot so that it no longer sucks.
--
GLOBAL_DBICON = "LibDBIcon-1.1"
local DBICON10 = "LibDBIcon-1.1"
local DBICON10_MINOR = 30 --tonumber(("$Rev: 30 $"):match("(%d+)"))
if not LibStub then error( DBICON10 .. " requires LibStub." ) end
local ldb = LibStub( "LibDataBroker-1.1", true )
if not ldb then error( DBICON10 .. " requires LibDataBroker-1.1." ) end
local lib = LibStub:NewLibrary( DBICON10, DBICON10_MINOR )
if not lib then return end

lib.disabled = lib.disabled or nil
lib.objects = lib.objects or {}
lib.callbackRegistered = lib.callbackRegistered or nil
lib.notCreated = lib.notCreated or {}

function lib:IconCallback( event, name, key, value, dataobj )
	if lib.objects[ name ] then
		if key == "icon" then
			lib.objects[ name ].icon:SetTexture( value )
		elseif key == "iconCoords" then
			lib.objects[ name ].icon:UpdateCoord()
		elseif key == "iconR" then
			local _, g, b = lib.objects[ name ].icon:GetVertexColor()
			lib.objects[ name ].icon:SetVertexColor( value, g, b )
		elseif key == "iconG" then
			local r, _, b = lib.objects[ name ].icon:GetVertexColor()
			lib.objects[ name ].icon:SetVertexColor( r, value, b )
		elseif key == "iconB" then
			local r, g = lib.objects[ name ].icon:GetVertexColor()
			lib.objects[ name ].icon:SetVertexColor( r, g, value )
		end
	end
end

if not lib.callbackRegistered then
	ldb.RegisterCallback( lib, "LibDataBroker_AttributeChanged__icon", "IconCallback" )
	ldb.RegisterCallback( lib, "LibDataBroker_AttributeChanged__iconCoords", "IconCallback" )
	ldb.RegisterCallback( lib, "LibDataBroker_AttributeChanged__iconR", "IconCallback" )
	ldb.RegisterCallback( lib, "LibDataBroker_AttributeChanged__iconG", "IconCallback" )
	ldb.RegisterCallback( lib, "LibDataBroker_AttributeChanged__iconB", "IconCallback" )
	lib.callbackRegistered = true
end

-- Tooltip code ripped from StatBlockCore by Funkydude
local function getAnchors( frame )
	local x, y = frame:GetCenter()
	if not x or not y then return "CENTER" end
	local hhalf = (x > UIParent:GetWidth() * 2 / 3) and "RIGHT" or (x < UIParent:GetWidth() / 3) and "LEFT" or ""
	local vhalf = (y > UIParent:GetHeight() / 2) and "TOP" or "BOTTOM"
	return vhalf .. hhalf, frame, (vhalf == "TOP" and "BOTTOM" or "TOP") .. hhalf
end

local function onEnter()
	if this.isMoving then return end
	local obj = this.dataObject
	if obj.OnTooltipShow then
		local a,b,c = getAnchors( this )
		GameTooltip:SetOwner( this, "ANCHOR_" .. c )
		obj.OnTooltipShow( GameTooltip )
		GameTooltip:Show()
	elseif obj.OnEnter then
		obj.OnEnter( this )
	end
end

local function onLeave()
	local obj = this.dataObject
	GameTooltip:Hide()
	if obj.OnLeave then obj.OnLeave( this ) end
end

--------------------------------------------------------------------------------

local onClick, onMouseUp, onMouseDown, onDragStart, onDragStop, onDragEnd, updatePosition

do
	local minimapShapes = {
		[ "ROUND" ] = { true, true, true, true },
		[ "SQUARE" ] = { false, false, false, false },
		[ "CORNER-TOPLEFT" ] = { false, false, false, true },
		[ "CORNER-TOPRIGHT" ] = { false, false, true, false },
		[ "CORNER-BOTTOMLEFT" ] = { false, true, false, false },
		[ "CORNER-BOTTOMRIGHT" ] = { true, false, false, false },
		[ "SIDE-LEFT" ] = { false, true, false, true },
		[ "SIDE-RIGHT" ] = { true, false, true, false },
		[ "SIDE-TOP" ] = { false, false, true, true },
		[ "SIDE-BOTTOM" ] = { true, true, false, false },
		[ "TRICORNER-TOPLEFT" ] = { false, true, true, true },
		[ "TRICORNER-TOPRIGHT" ] = { true, false, true, true },
		[ "TRICORNER-BOTTOMLEFT" ] = { true, true, false, true },
		[ "TRICORNER-BOTTOMRIGHT" ] = { true, true, true, false },
	}

	function updatePosition( button )
		local angle = math.rad( button.db and button.db.minimapPos or button.minimapPos or 225 )
		local x, y, q = math.cos( angle ), math.sin( angle ), 1
		if x < 0 then q = q + 1 end
		if y > 0 then q = q + 2 end
		local minimapShape = GetMinimapShape and GetMinimapShape() or "ROUND"
		local quadTable = minimapShapes[ minimapShape ]
		if quadTable[ q ] then
			x, y = x * 80, y * 80
		else
			local diagRadius = 103.13708498985 --math.sqrt(2*(80)^2)-10
			x = math.max( -80, math.min( x * diagRadius, 80 ) )
			y = math.max( -80, math.min( y * diagRadius, 80 ) )
		end
		button:SetPoint( "CENTER", Minimap, "CENTER", x, y )
	end
end

function onClick()
	--KT:Msg(arg1)
	--if this.dataObject.OnClick then this.dataObject.OnClick( this, arg1 ) end
end

function onMouseDown()
	this.isMouseDown = true; this.icon:UpdateCoord()
end

function onMouseUp()
	if this.dataObject.OnClick then this.dataObject.OnClick( this, arg1 ) end
	this.isMouseDown = false; this.icon:UpdateCoord()
end

do
	local function onUpdate()
		local mx, my = Minimap:GetCenter()
		local px, py = GetCursorPosition()
		local scale = Minimap:GetEffectiveScale()
		px, py = px / scale, py / scale
		if this.db then
			this.db.minimapPos = mod( math.deg( math.atan2( py - my, px - mx ) ), 360 )
		else
			this.minimapPos = mod( math.deg( math.atan2( py - my, px - mx ) ), 360 )
		end
		updatePosition( this )
	end

	function onDragStart()
		this:LockHighlight()
		this.isMouseDown = true
		this.icon:UpdateCoord()
		this:SetScript( "OnUpdate", onUpdate )
		this.isMoving = true
		GameTooltip:Hide()
	end
end

function onDragStop()
	this:SetScript( "OnUpdate", nil )
	this.isMouseDown = false
	this.icon:UpdateCoord()
	this:UnlockHighlight()
	this.isMoving = nil
end

local defaultCoords = { 0, 1, 0, 1 }
local function updateCoord( self )
	local coords = self:GetParent().dataObject.iconCoords or defaultCoords
	local deltaX, deltaY = 0, 0
	if not self:GetParent().isMouseDown then
		deltaX = (coords[ 2 ] - coords[ 1 ]) * 0.05
		deltaY = (coords[ 4 ] - coords[ 3 ]) * 0.05
	end
	self:SetTexCoord( coords[ 1 ] + deltaX, coords[ 2 ] - deltaX, coords[ 3 ] + deltaY, coords[ 4 ] - deltaY )
end

local function createButton( name, object, db )
	local button = CreateFrame( "Button", "LibDBIcon10_" .. name, Minimap )
	button.dataObject = object
	button.db = db
	button:SetFrameStrata( "MEDIUM" )
	button:SetWidth( 31 )
	button:SetHeight( 31 )
	button:SetFrameLevel( 8 )
	--button:RegisterForClicks( "AnyUp" )
	button:EnableMouse()
	button:RegisterForDrag( "LeftButton" )
	button:SetHighlightTexture( "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight" )
	local overlay = button:CreateTexture( nil, "OVERLAY" )
	overlay:SetWidth( 53 )
	overlay:SetHeight( 53 )
	overlay:SetTexture( "Interface\\Minimap\\MiniMap-TrackingBorder" )
	overlay:SetPoint( "TOPLEFT", 0, 0 )
	local background = button:CreateTexture( nil, "BACKGROUND" )
	background:SetWidth( 20 )
	background:SetHeight( 20 )
	background:SetTexture( "Interface\\Minimap\\UI-Minimap-Background" )
	background:SetPoint( "TOPLEFT", 7, -5 )
	local icon = button:CreateTexture( nil, "ARTWORK" )
	icon:SetWidth( 17 )
	icon:SetHeight( 17 )
	icon:SetTexture( object.icon )
	icon:SetPoint( "TOPLEFT", 7, -6 )
	button.icon = icon
	button.isMouseDown = false

	local r, g, b = icon:GetVertexColor()
	icon:SetVertexColor( object.iconR or r, object.iconG or g, object.iconB or b )

	icon.UpdateCoord = updateCoord
	icon:UpdateCoord()

	button:SetScript( "OnEnter", onEnter )
	button:SetScript( "OnLeave", onLeave )
	button:SetScript( "OnClick", onClick )
	if not db or not db.lock then
		button:SetScript( "OnDragStart", onDragStart )
		button:SetScript( "OnDragStop", onDragStop )
	end
	button:SetScript( "OnMouseDown", onMouseDown )
	button:SetScript( "OnMouseUp", onMouseUp )

	lib.objects[ name ] = button

	if lib.loggedIn then
		updatePosition( button )
		if not db or not db.hide then
			button:Show()
		else
			button:Hide()
		end
	end
end

-- We could use a metatable.__index on lib.objects, but then we'd create
-- the icons when checking things like :IsRegistered, which is not necessary.
local function check( name )
	if lib.notCreated[ name ] then
		createButton( name, lib.notCreated[ name ][ 1 ], lib.notCreated[ name ][ 2 ] )
		lib.notCreated[ name ] = nil
	end
end

lib.loggedIn = lib.loggedIn or false
-- Wait a bit with the initial positioning to let any GetMinimapShape addons
-- load up.
if not lib.loggedIn then
	local f = CreateFrame( "Frame" )
	f:SetScript( "OnEvent", function()
		for _, object in pairs( lib.objects ) do
			updatePosition( object )
			if not lib.disabled and (not object.db or not object.db.hide) then
				object:Show()
			else
				object:Hide()
			end
		end
		lib.loggedIn = true
		f:SetScript( "OnEvent", nil )
		f = nil
	end )
	f:RegisterEvent( "PLAYER_LOGIN" )
end

local function getDatabase( name )
	return lib.notCreated[ name ] and lib.notCreated[ name ][ 2 ] or lib.objects[ name ].db
end

function lib:Register( name, object, db )
	if not object.icon then error( "Can't register LDB objects without icons set!" ) end
	if lib.objects[ name ] or lib.notCreated[ name ] then error( "Already registered, nubcake." ) end
	if not lib.disabled and (not db or not db.hide) then
		createButton( name, object, db )
	else
		lib.notCreated[ name ] = { object, db }
	end
end

function lib:Lock( name )
	if not lib:IsRegistered( name ) then return end
	if lib.objects[ name ] then
		lib.objects[ name ]:SetScript( "OnDragStart", nil )
		lib.objects[ name ]:SetScript( "OnDragStop", nil )
	end
	local db = getDatabase( name )
	if db then db.lock = true end
end

function lib:Unlock( name )
	if not lib:IsRegistered( name ) then return end
	if lib.objects[ name ] then
		lib.objects[ name ]:SetScript( "OnDragStart", onDragStart )
		lib.objects[ name ]:SetScript( "OnDragStop", onDragStop )
	end
	local db = getDatabase( name )
	if db then db.lock = nil end
end

function lib:Hide( name )
	if not lib.objects[ name ] then return end
	lib.objects[ name ]:Hide()
end

function lib:Show( name )
	if lib.disabled then return end
	check( name )
	lib.objects[ name ]:Show()
	updatePosition( lib.objects[ name ] )
end

function lib:IsRegistered( name )
	return (lib.objects[ name ] or lib.notCreated[ name ]) and true or false
end

function lib:Refresh( name, db )
	if lib.disabled then return end
	check( name )
	local button = lib.objects[ name ]
	if db then button.db = db end
	updatePosition( button )
	if not button.db or not button.db.hide then
		button:Show()
	else
		button:Hide()
	end
	if not button.db or not button.db.lock then
		button:SetScript( "OnDragStart", onDragStart )
		button:SetScript( "OnDragStop", onDragStop )
	else
		button:SetScript( "OnDragStart", nil )
		button:SetScript( "OnDragStop", nil )
	end
end

function lib:GetMinimapButton( name )
	return lib.objects[ name ]
end

function lib:EnableLibrary()
	lib.disabled = nil
	for name, object in pairs( lib.objects ) do
		if not object.db or not object.db.hide then
			object:Show()
			updatePosition( object )
		end
	end
	for name, data in pairs( lib.notCreated ) do
		if not data.db or not data.db.hide then
			createButton( name, data[ 1 ], data[ 2 ] )
			lib.notCreated[ name ] = nil
		end
	end
end

function lib:DisableLibrary()
	lib.disabled = true
	for name, object in pairs( lib.objects ) do
		object:Hide()
	end
end
