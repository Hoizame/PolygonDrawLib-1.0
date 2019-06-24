local AddonName = ...
local LibPath = GetAddOnMetadata(AddonName, "X-MapDrawLib-Path")
assert(LibPath, "X-MapDrawLib-Path for \"MapDrawLib\" not found! ".." Set ## X-MapDrawLib-Path: in the "..AddonName..".toc")

local MAJOR, MINOR = "MapDrawLib", 1
assert(LibStub, MAJOR .. " requires LibStub")

local MDL, oldversion = LibStub:NewLibrary(MAJOR, MINOR)
if not MDL then return end

-- upvalue lua api
local wipe = table.wipe
local setmetatable, next = setmetatable, next
local type = type
local min, max = math.min, math.max

-- upvalue wow api
local CreateFrame = CreateFrame
local print = print

-- locales

-- ########################
-- local
-- ########################
local testTable = {
    {46.40,36.00},
    {46.90,35.80},
    {48.89,36.44},
    {49.55,36.06},
    {49.15,36.93},
    {48.1,36.96},
    {48.37,36.74},
    {49.32,35.81},
    {48.87,35.14},
    {49.87,36.3},
    {48.52,36.13},
    {49.17,36.55},
    {46.93,35.67},
    {47.58,35.94},
    {47.65,36.91},
    {47.86,36.26},
    {47.57,36.37},
    {47.62,35.75},
    {47.91,35.49},
    {47.36,36.31},
    {47.22,36.0},
    {47.55,34.98},
    {49.79,35.17},
    {49.44,35.34},
    {49.73,35.8},
    {50.04,35.46},
    {51.3,36.5},
    {51.23,36.02},
    {51.61,35.68},
    {50.49,37.61},
    {50.98,37.58},
    {51.29,37.43},
    {50.76,37.47},
    {51.36,37.02},
    {51.68,37.01},
}
local testTab2 = {
    {45.91,40.31},{49.16,45.38},{46.66,39.39},{49.41,37.75},{48.17,37.37},{48.15,34.91},{45.96,36.37},{46.6,35.13},{46.15,35.53},{46.25,36.73},{48.51,33.67},{46.34,34.42},{45.2,35.15},{45.69,34.96},{46.96,34.46},{50.93,35.71},{52.74,35.14},{50.16,37.41},{51.24,40.45},{52.51,39.15},{52.65,38.37},{52.63,40.48},{53.07,38.74},{51.88,41.56},{52.53,42.19},{51.53,43.7},{50.92,44.14},{50.89,44.37},{51.71,43.13},{51.61,42.38},{49.9,46.59},{49.48,49.26},{49.35,47.46},{48.98,47.04},{51.45,45.58},{50.38,44.94},
}
local TestFrame = CreateFrame("Frame", WorldMapFrame.ScrollContainer)
TestFrame:SetAllPoints(WorldMapFrame.ScrollContainer)


local function InitDefaultColor(colorTable, rDefault, gDefault, bDefault, aDefault, r, g, b, a)
    colorTable[1] = r or colorTable[1] or rDefault
    colorTable[2] = g or colorTable[2] or gDefault
    colorTable[3] = b or colorTable[3] or bDefault
    colorTable[4] = a or colorTable[4] or aDefault
end

-- Some parts here are from the AVR addon
local function DrawTriangle(parent,tri,x1,y1,x2,y2,x3,y3)
    local frameWidth = parent:GetWidth()
    local frameHeight = parent:GetHeight()

    -- format the positions
    local calcX, calcY = frameWidth / 100, frameHeight / 100
    x1, y1 = x1*calcX, y1*calcY
    x2, y2 = x2*calcX, y2*calcY
    x3, y3 = x3*calcX, y3*calcY

    local minx=min(x1,x2,x3)
    local miny=min(y1,y2,y3)
    local maxx=max(x1,x2,x3)
    local maxy=max(y1,y2,y3)
    
    if maxx<-frameWidth then return
    elseif minx>frameWidth then return
    elseif maxy<-frameHeight then return
    elseif miny>frameHeight then return
    end

    local dx=maxx-minx
    local dy=maxy-miny
    if dx==0 or dy==0 then return end
    
    local tx3,ty1,ty2,ty3
    if x1==minx then
        if x2==maxx then
            tx3,ty1,ty2,ty3=(x3-minx)/dx,(maxy-y1),(maxy-y2),(maxy-y3)
        else
            tx3,ty1,ty2,ty3=(x2-minx)/dx,(maxy-y1),(maxy-y3),(maxy-y2)
        end
    elseif x2==minx then
        if x1==maxx then
            tx3,ty1,ty2,ty3=(x3-minx)/dx,(maxy-y2),(maxy-y1),(maxy-y3) 
        else
            tx3,ty1,ty2,ty3=(x1-minx)/dx,(maxy-y2),(maxy-y3),(maxy-y1) 
        end
    else -- x3==minx
        if x2==maxx then
            tx3,ty1,ty2,ty3=(x1-minx)/dx,(maxy-y3),(maxy-y2),(maxy-y1) 
        else
            tx3,ty1,ty2,ty3=(x2-minx)/dx,(maxy-y3),(maxy-y1),(maxy-y2) 
        end
    end
    
    local t1=-0.99609375/(ty3-tx3*ty2+(tx3-1)*ty1) -- 0.99609375==510/512
    local t2=dy*t1
    x1=0.001953125-t1*tx3*ty1 -- 0.001953125=1/512
    x2=0.001953125+t1*ty1
    x3=t2*tx3+x1
    y1=t1*(ty2-ty1)
    y2=t1*(ty1-ty3)
    y3=-t2+x2

    tri:Show()
    tri:SetTexCoord(x1,x2,x3,y3,x1+y2,x2+y1,y2+x3,y1+y3)
    tri:SetPoint("BOTTOMLEFT",parent,"BOTTOMLEFT",minx,miny)
    tri:SetPoint("TOPRIGHT",parent,"BOTTOMLEFT",maxx,maxy)
end

local ConvexHullContainer = {}
local ConvexHullFrameContainer = {}
-- TODO: The Path :S
local TRIANGLE_PATH = LibPath.."/Utils/triangle.tga"
local LINE_PATH = LibPath.."/Utils/line.blp"

ConvexHull = {
	Proto = {}
}
ConvexHull.mt = { __index = ConvexHull.Proto }

local function ConvexHull_FreeContainer(frame)
    for i = 1, #frame.container do
        frame.unusedContainer[frame.container[i].ty][frame.container[i]] = true
    end
    wipe(frame.container)
end

local function ConvexHull_FreeFrame(frame)
	if frame.ty == "main" then
        ConvexHull_FreeContainer(frame)
        ConvexHullFrameContainer[frame] = true

        frame.borderThickness = nil
        frame.frame = nil
        frame.borderColor = nil
        frame.hullColor = nil
        frame:ClearAllPoints()
        frame:Hide()
    end
end

local function ConvexHull_GetFrame(ty, parent)
    if not ty then return end
	local frame = next(ty == "main" and ConvexHullFrameContainer or parent.unusedContainer[ty])
	if not frame then
		if ty == "triangle" and parent then
			frame = parent:CreateTexture(nil, "TOOLTIP")
			frame:SetTexture(TRIANGLE_PATH, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            --frame:SetVertexColor(0,0,1,0.5)
        elseif ty == "line" and parent then
            frame = parent:CreateLine(nil, "TOOLTIP")
            frame:SetTexture(LINE_PATH)
            frame:SetBlendMode("ADD")
            --frame:SetVertexColor(0,0,1,0.8)
            --frame:SetAtlas('_UI-Taxi-Line-horizontal')
            --frame:SetAlpha(0.5)
		elseif ty == "main" and parent then
			frame = CreateFrame("Frame")

			frame.unusedContainer = {
                ["triangle"] = {},
                ["line"] = {},
            }
			frame.container = {}
		elseif (ty == "triangle" or ty == "main" or ty == "line") and not parent then
			error(ty.." no parent found ConvexHull_GetFrame")
		else
			error(ty.." not found for ConvexHull_GetFrame")
		end
        frame.ty = ty
        frame:Hide()
	elseif ty == "main" then
		ConvexHullFrameContainer[frame] = nil
	elseif ty == "triangle" or ty == "line" then
        parent.unusedContainer[ty][frame] = nil
	end
	
	if ty == "triangle" or ty == "line" then
		parent.container[#parent.container+1] = frame
    end
    if ty ~= "line" then
        frame:ClearAllPoints()
        frame:SetParent(parent)
    end
	return frame
end

local function IsCounterClockWise(curPoint, checkPoint, nextPoint, isXYtable) 
	local x,y = 1,2
	if isXYtable then
		x,y = "x","y"
	end
	return ((checkPoint[y] - curPoint[y]) * (nextPoint[x] - checkPoint[x]) - (checkPoint[x] - curPoint[x]) * (nextPoint[y] - checkPoint[y])) < 0 
end

-- ########################
-- API
-- ########################

--- Create a new convex hull
-- at least 3 points are needed
-- @param	tab			<table>		format: { [1] = { x, y }, [2] = { x, y }, [2] = { x, y } } or { x=1, y=2 }
-- @param	isXYtable	<bool>		true: { x=1, y=2 }		false: { 1, 2 }     default: false
function ConvexHull:New(tab, isXYtable)
	if not tab or type(tab) ~= "table" or #tab < 3 then return end
	
	local x,y = 1,2
	if isXYtable then
		x,y = "x","y"
	end
	-- check if the tab is aready existing
	if ConvexHullContainer[tab] then return ConvexHullContainer[tab] end
	
	-- Jarvis gift wrapping algorithm
	-- find the left x point
	local leftPointIndex = 1
	for i = 1, #tab do 
		if tab[i][x] < tab[leftPointIndex][x] then
			leftPointIndex = i
		end
	end
	
	local curPoint = leftPointIndex
	local nextPoint
	local hullTable = {}	-- format is same as given tab
	-- start with the left point and calculate the rest
	repeat
		-- get the next point
		nextPoint = tab[curPoint + 1] and curPoint + 1 or 1
		for i = 1, #tab do
			if IsCounterClockWise(tab[curPoint], tab[i], tab[nextPoint], isXYtable) then 
				nextPoint = i 
			end
		end
		
		-- add the next point in the hull and go on with the next one
        hullTable[#hullTable+1] = tab[nextPoint]
		curPoint = nextPoint
	until(curPoint == leftPointIndex)	-- end when back at the startPoint
	
	-- get the centroid / boxSize
	local centroid = { [x] = 0, [y] = 0 }
	local centroidAbsolute = { [x] = 0, [y] = 0 }
	local boxSize = { 0, 0 }
	local helperCentroid = { left = tab[leftPointIndex], top = hullTable[1], right = hullTable[1], bottom = hullTable[1] }
	local xTmp,yTmp
	for i = 1, #hullTable do 
		xTmp,yTmp = hullTable[i][x], hullTable[i][y]
		if yTmp > helperCentroid.top[y] then helperCentroid.top = hullTable[i] end
		if xTmp > helperCentroid.right[x] then helperCentroid.right = hullTable[i] end
		if yTmp < helperCentroid.bottom[y] then helperCentroid.bottom = hullTable[i] end
    end

    
	
	-- get box boundings of the whole thing
	boxSize[1] = helperCentroid.right[x] - helperCentroid.left[x] 
	boxSize[2] = helperCentroid.top[y] - helperCentroid.bottom[y] 
    
    if boxSize[1] == 0 or boxSize[2] == 0 then return end
	-- we get the center of the box as that is needed for the drawing
	centroid[x] = (boxSize[1]*0.5)*(100 / boxSize[1])
	centroid[y] = (boxSize[2]*0.5)*(100 / boxSize[2])
	-- "TOPLEFT"
	centroidAbsolute[x] = helperCentroid.left[x] + boxSize[1]*0.5
    centroidAbsolute[y] = helperCentroid.top[y] - boxSize[2]*0.5
    
    -- boxHull
    local boxHull = {}
    for i = 1, #hullTable do
        boxHull[i] = {
            [x] = (hullTable[i][x] - helperCentroid.left[x])*(100 / boxSize[1]),
            [y] = (hullTable[i][y] - helperCentroid.bottom[y])*(100 / boxSize[2]),
        }
    end

	-- finalize
	local convexHull = {
		centroid = centroid,	-- { x, y }
		centroidAbsolute = centroidAbsolute,
		boxSize = boxSize,		-- { width, height }
        hull = hullTable,
        boxHull = boxHull,
        xEntry = x,
        yEntry = y,
	}
	setmetatable(convexHull, ConvexHull.mt)
	ConvexHullContainer[tab] = convexHull
	
	return convexHull
end

--- Adds a border around the hull
-- this only works if the hull is already drawn, if not it draws it with the call of :Draw
-- @param   thickness     <number>    thickness of the border     default: 15
function ConvexHull.Proto:DrawBorder(thickness)
    thickness = thickness or 15
    self.borderThickness = thickness

    -- only draw if the hull is created and shown
    if not self.frame then return end
    local x,y = self.xEntry, self.yEntry
    local frame = self.frame

    -- format the positions
    local calcX, calcY = frame:GetWidth() / 100, frame:GetHeight() / 100

    -- draw the border 
    local hull = self.boxHull
    local lastPoint
    for i = 1, #hull+1 do
        local entry = i > #hull and hull[1] or hull[i]
		-- the first one needs more points so skip it
		if i > 1 then
            local line = ConvexHull_GetFrame("line", frame)
            line:SetThickness(thickness)
            line:SetStartPoint("BOTTOMLEFT", frame, lastPoint[x]*calcX, lastPoint[y]*calcY)
            line:SetEndPoint("BOTTOMLEFT", frame, entry[x]*calcX, entry[y]*calcY)
            line:Show()
		end
		lastPoint = entry
    end
    --init colors
    self:SetBorderColor()
end

--- Draws the hull
-- @param   parent          <frame>     Frame where the hull should be drawn
-- @param   border          <bool>      Draw border         default: false 
-- @param   borderThickness <number>    See :DrawBorder     default: (:DrawBorder) => default
function ConvexHull.Proto:Draw(parent, border, borderThickness)
	-- check format
    local x,y = self.xEntry, self.yEntry
    
    -- this frees the frame and let us redraw
    if self.frame then
        ConvexHull_FreeFrame(self.frame)
    end
	
	-- the center is start
    local startPointX, startPointY = self.centroidAbsolute[x], self.centroidAbsolute[y]
	--ConvexHull_GetFrame("main", UIParent)
	local frame = ConvexHull_GetFrame("main", parent)
	frame:SetPoint("CENTER", parent, "TOPLEFT", startPointX*(parent:GetWidth()/100), -(startPointY*(parent:GetHeight()/100)))
    frame:SetSize(self.boxSize[1]*(parent:GetWidth()/100), self.boxSize[2]*(parent:GetHeight()/100))
    --frame:SetAllPoints(parent)
    frame:Show()
    --print("SetSize", self.boxSize[1], self.boxSize[2], startPointX, startPointY)
    self.frame = frame

	-- get triangle points
    local lastPoint
    local hull = self.boxHull
	for i = 1, #hull+1 do
		local entry = i > #hull and hull[1] or hull[i]
		-- the first one needs more points so skip it
		if i > 1 then
			local tri = ConvexHull_GetFrame("triangle", frame)
            DrawTriangle(frame,tri,self.centroid[x],self.centroid[y],lastPoint[x],lastPoint[y],entry[x],entry[y])
		end
		lastPoint = entry
    end
    --init colors
    self:SetColor()
    
    -- Draw border if needed
    if border or self.borderThickness then
        self:DrawBorder(thickness or self.borderThickness)
    end
end

--- Set the color of the border
-- blend mode is set to "ADD"
-- fallback: param -> existing -> default
-- @param   r,g,b       <number>    colors  default: 1,1,1 (white)
-- @param   a           <number>    alpha   default: 0.6
function ConvexHull.Proto:SetBorderColor(r, g, b, a)
    if not self.borderColor then self.borderColor = {} end

    InitDefaultColor(self.borderColor, 1, 1, 1, 0.6, r, g, b, a)

    -- check if we must update color
    if self.borderThickness and self.frame and #self.frame.container > 0 then
        local container = self.frame.container
        for i = 1, #container do
            if container[i].ty == "line" then
                container[i]:SetVertexColor(unpack(self.borderColor))
            end
        end
    end
end

--- Set the color of the hull
-- fallback: param -> existing -> default
-- @param   r,g,b       <number>    colors  default: 1,1,1 (white)
-- @param   a           <number>    alpha   default: 0.5
function ConvexHull.Proto:SetColor(r, g, b, a)
    if not self.hullColor then self.hullColor = {} end

    InitDefaultColor(self.hullColor, 1, 1, 1, 0.5, r, g, b, a)

    -- check if we must update color
    if self.frame and #self.frame.container > 0 then
        local container = self.frame.container
        for i = 1, #container do
            if container[i].ty == "triangle" then
                container[i]:SetVertexColor(unpack(self.hullColor))
            end
        end
    end
end


-- ########################
-- Test
-- ########################
--TestB:Draw(WorldMapFrame.ScrollContainer)
TestB = ConvexHull:New(testTable)
TestB:Draw(WorldMapFrame.ScrollContainer)
TestB:DrawBorder()
TestB:SetColor(1, 0, 0)

--TestC = ConvexHull:New(testTab2)
--TestC:Draw(WorldMapFrame.ScrollContainer)
--TestC:DrawBorder()
--TestC:SetColor(1, 0, 0)