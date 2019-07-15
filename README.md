# PolygonDrawLib-1.0

A library for WoW-Classic to draw polygons out of a table with x, y coordinates.

## Requirements

Set the path of the libary within the .toc file of your addon.

```lua
## X-PolygonDrawLib-Path: Interface/AddOns/<YourAddon>/Libs/PolygonDrawLib-1.0
```

## Usage

```lua
local PolygonDraw = LibStub:GetLibrary("PolygonDrawLib-1.0")

local Points = {
    {36.5,56.3},{37.5,56.9},{42.7,54.8},{43.9,50.0},{43.0,46.0},{40.3,46.4},{37.1,48.6}
}

-- This calculates a new polygon with points anchor at "TOPLEFT"
-- a points table with [1] = x, [2] = y
-- and error output on fail / true would just return nil
local pointPoly = PolygonDraw:New(Points, "TOPLEFT", false, true)
-- draw the polygon with a border
pointPoly:Draw(WorldMapFrame.ScrollContainer, true)
-- set random color for polygon
pointPoly:SetRandomColor()

```
