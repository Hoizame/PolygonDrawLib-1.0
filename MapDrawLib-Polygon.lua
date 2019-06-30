local AddonName = ...
local LibPath = GetAddOnMetadata(AddonName, "X-MapDrawLib-Path")
assert(LibPath, "X-MapDrawLib-Path for \"MapDrawLib\" not found! ".." Set ## X-MapDrawLib-Path: in the "..AddonName..".toc")

local MAJOR, MINOR = "MapDrawLib-Polygon", 1
assert(LibStub, MAJOR .. " requires LibStub")

local MDL_P, oldversion = LibStub:NewLibrary(MAJOR, MINOR)
if not MDL_P then return end

-- upvalue lua api
local wipe = table.wipe
local setmetatable, next = setmetatable, next
local type = type
local min, max, random = math.min, math.max, math.random

-- upvalue wow api
local CreateFrame = CreateFrame
local print = print

-- locales
local IS_TEST = true
local TRIANGLE_PATH = LibPath.."/Utils/triangle.tga"
local LINE_PATH = LibPath.."/Utils/line.blp"
local DEFAULT_COLORS = {
    polygon    =    {1, 1, 1, 0.5},
    border      =    {1, 1, 1, 0.6},
}

-- ########################
-- local
-- ########################
local MainFrameContainer = {}

local Proto = {}
local Proto_mt = { __index = Proto }

local function Frame_FreeContainer(frame)
    for i = 1, #frame.container do
        frame.unusedContainer[frame.container[i].ty][frame.container[i]] = true
    end
    wipe(frame.container)
end

local function Frame_FreeFrame(frame)
	if frame.ty == "main" then
        Frame_FreeContainer(frame)
        MainFrameContainer[frame] = true

        frame.borderThickness = nil
        frame.frame = nil
        frame.borderColor = nil
        frame.borderDrawn = nil
        frame.polygonColor = nil
        frame:ClearAllPoints()
        frame:Hide()
    end
end

local function Frame_FreeFrameType(mainFrame, typ)
    if mainFrame.ty ~= "main" then return end
    local saver = mainFrame.container
    mainFrame.container = {}
    local counter = 0
    for i = 1, #saver do
        if saver[i].ty == typ then
            mainFrame.unusedContainer[saver[i].ty][saver[i]] = true
            saver[i]:Hide()
            counter = counter + 1
        else
            mainFrame.container[#mainFrame.container+1] = saver[i]
        end
    end
    --print(counter.." of type "..typ.." are freed")
end

local function Frame_GetFrame(ty, parent)
    if not ty then return end
	local frame = next(ty == "main" and MainFrameContainer or parent.unusedContainer[ty])
    if not frame then
		if ty == "triangle" and parent then
			frame = parent:CreateTexture(nil, "TOOLTIP")
			frame:SetTexture(TRIANGLE_PATH, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        elseif ty == "line" and parent then
            frame = parent:CreateLine(nil, "TOOLTIP")
            frame:SetTexture(LINE_PATH)
            frame:SetBlendMode("ADD")
		elseif ty == "main" and parent then
			frame = CreateFrame("Frame")

			frame.unusedContainer = {
                ["triangle"] = {},
                ["line"] = {},
            }
			frame.container = {}
		elseif (ty == "triangle" or ty == "main" or ty == "line") and not parent then
			error(ty.." no parent found "..MAJOR.." - Frame_GetFrame")
		else
			error(ty.." not found for "..MAJOR.." - Frame_GetFrame")
		end
        frame.ty = ty
        frame:Hide()
	elseif ty == "main" then
        MainFrameContainer[frame] = nil
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

local function InitDefaultColor(colorTable, default, r, g, b, a)
    default = DEFAULT_COLORS[default]
    colorTable[1] = r or colorTable[1] or default[1]
    colorTable[2] = g or colorTable[2] or default[2]
    colorTable[3] = b or colorTable[3] or default[3]
    colorTable[4] = a or colorTable[4] or default[4]
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

local function IsCounterClockWise(curPoint, checkPoint, nextPoint, isXYtable) 
	local x,y = 1,2
	if isXYtable then
		x,y = "x","y"
	end
	return ((checkPoint[y] - curPoint[y]) * (nextPoint[x] - checkPoint[x]) - (checkPoint[x] - curPoint[x]) * (nextPoint[y] - checkPoint[y])) < 0 
end

local function CreateMainFrame(self, parent, freeFrames)
    local x,y = self.xEntry, self.yEntry

    assert(parent, "parent not found.")
    -- this frees the frame and let us redraw
    if self.frame and freeFrames then
        Frame_FreeFrame(self.frame)
    end

    local startPointX, startPointY = self.centroidAbsolute[x], self.centroidAbsolute[y]
	local frame = Frame_GetFrame("main", parent)
	frame:SetPoint("CENTER", parent, "TOPLEFT", startPointX*(parent:GetWidth()/100), -(startPointY*(parent:GetHeight()/100)))
    frame:SetSize(self.boxSize[1]*(parent:GetWidth()/100), self.boxSize[2]*(parent:GetHeight()/100))
    frame:Show()

    self.frame = frame
    return frame
end

-- ########################
-- API / Lib
-- ########################

--- Create a new polygon out of a table with coordinates
-- at least 3 points are needed
-- @param	tab			<table>		format: { [1] = { x, y }, [2] = { x, y }, [2] = { x, y } } or { x=1, y=2 }
-- @param	isXYtable	<bool>		true: { x=1, y=2 }		false: { 1, 2 }     default: false
-- @param   notSilent   <bool>      show error on fail creating a polygon
function MDL_P:New(tab, isXYtable, notSilent)
    if not tab or type(tab) ~= "table" or #tab < 3 then 
        if notSilent then
            assert(tab, "'tab' is nil.")
            assert(type(tab) == "table", "'tab' must be a table.")
            assert(#tab >= 3, "'tab' must at least contain 3 entrys.")
        else
            return 
        end
    end
	
	local x,y = 1,2
	if isXYtable then
		x,y = "x","y"
	end
	
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
    
    -- inBoxPolygon
    local inBoxPolygon = {}
    for i = 1, #hullTable do
        inBoxPolygon[i] = {
            [x] = (hullTable[i][x] - helperCentroid.left[x])*(100 / boxSize[1]),
            [y] = (hullTable[i][y] - helperCentroid.bottom[y])*(100 / boxSize[2]),
        }
    end

	-- finalize
	local polygonRetTable = {
		centroid = centroid,	-- { x, y }
		centroidAbsolute = centroidAbsolute,
		boxSize = boxSize,		-- { width, height }
        polygon = hullTable,
        inBoxPolygon = inBoxPolygon,
        xEntry = x,
        yEntry = y,
	}
	setmetatable(polygonRetTable, Proto_mt)
	
	return polygonRetTable
end

-- ########################
-- API / return of :New
-- ########################

--- Adds a border around the polygon
-- draws a border around the polygon, this needs a parent frame if the polygon is not drawn jet with :Draw
-- @param   thickness     <number>    thickness of the border     default: 15
-- @param   parent        <frame>     Frame where the polygon should be drawn
function Proto:DrawBorder(thickness, parent)
    thickness = thickness or 15
    if self.borderDrawn and thickness == self.borderThickness then
        return
    elseif self.frame then
        Frame_FreeFrameType(self.frame, "line")
    end
    self.borderThickness = thickness

    -- Create the main frame if not exist.
    if not self.frame and parent then 
        CreateMainFrame(self, parent, true)
    elseif not self.frame then
        return 
    end

    local x,y = self.xEntry, self.yEntry
    local frame = self.frame

    -- format the positions
    local calcX, calcY = frame:GetWidth() / 100, frame:GetHeight() / 100

    -- draw the border 
    local polygon = self.inBoxPolygon
    local lastPoint
    for i = 1, #polygon+1 do
        local entry = i > #polygon and polygon[1] or polygon[i]
		-- the first one needs more points so skip it
		if i > 1 then
            local line = Frame_GetFrame("line", frame)
            line:SetThickness(thickness)
            line:SetStartPoint("BOTTOMLEFT", frame, lastPoint[x]*calcX, lastPoint[y]*calcY)
            line:SetEndPoint("BOTTOMLEFT", frame, entry[x]*calcX, entry[y]*calcY)
            line:Show()
		end
		lastPoint = entry
    end
    --init colors
    self:SetBorderColor()
    self.borderDrawn = true
end

--- Remove the border
function Proto:RemoveBorder()
    if self.frame and self.borderDrawn then
        Frame_FreeFrameType(self.frame, "line")
        self.borderDrawn = nil
        self.borderThickness = nil
    end
end

--- Draws the polygon
-- @param   parent          <frame>     Frame where the polygon should be drawn
-- @param   border          <bool>      Draw border         default: false 
-- @param   borderThickness <number>    See :DrawBorder     default: (:DrawBorder) => default
function Proto:Draw(parent, border, borderThickness)
	-- check format
    local x,y = self.xEntry, self.yEntry
    
    
    local frame = CreateMainFrame(self, parent, true)

	-- get triangle points
    local lastPoint
    local polygon = self.inBoxPolygon
	for i = 1, #polygon+1 do
		local entry = i > #polygon and polygon[1] or polygon[i]
		-- the first one needs more points so skip it
		if i > 1 then
			local tri = Frame_GetFrame("triangle", frame)
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
function Proto:SetBorderColor(r, g, b, a)
    if not self.borderColor then self.borderColor = {} end

    InitDefaultColor(self.borderColor, "border", r, g, b, a)

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

--- Set the color of the polygon
-- fallback: param -> existing -> default
-- @param   r,g,b       <number>    colors  default: 1,1,1 (white)
-- @param   a           <number>    alpha   default: 0.5
function Proto:SetColor(r, g, b, a)
    if not self.polygonColor then self.polygonColor = {} end

    InitDefaultColor(self.polygonColor, "polygon", r, g, b, a)

    -- check if we must update color
    if self.frame and #self.frame.container > 0 then
        local container = self.frame.container
        for i = 1, #container do
            if container[i].ty == "triangle" then
                container[i]:SetVertexColor(unpack(self.polygonColor))
            end
        end
    end
end

--- Set a random color of the polygon
-- @param   a           <number>    alpha   default: 0.5
function Proto:SetRandomColor(alpha)
    -- mybe change this later with a better solution?
    self:SetColor(random(), random(), random(), alpha)
end

--- Add a button into the center of the polygon
-- @param   button      <frame>     frame
function Proto:AddButton(button)
    -- Hide old button if there is one
    if self.Button then 
        self.Button:ClearAllPoints()
        self.Button:Hide() 
    end
    self.button = button
    -- Only go on if there is a new button
    if not button then return end

    button:ClearAllPoints()
    button:SetParent(self.frame)
    button:SetPoint("CENTER", self.frame, "CENTER")
end

--- Remove the set button
function Proto:RemoveButton()
    self:AddButton(nil)
end

--- This destroys the polygon
-- set all frames free and remove all Proto functions from the polygon but keeps the data
function Proto:Destroy()
    Frame_FreeFrame(self.frame)
    self.frame = nil
    setmetatable(self, nil)
end

--- Change the alpha values of the drawings
-- nil reset the alpha to default
-- @param   polygonAlpha         <number>    0 - 1
-- @param   borderAlpha       <number>    0 - 1
function Proto:SetAlpha(polygonAlpha, borderAlpha)
    self:SetColor(nil, nil, nil, polygonAlpha or DEFAULT_COLORS["polygon"][4])
    self:SetBorderColor(nil, nil, nil, borderAlpha or DEFAULT_COLORS["border"][4])
end

--- Show the polygon
function Proto:Show()
    if self.frame then
        self.frame:Show()
    end
end

--- Hide the polygon
function Proto:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

-- ########################
-- Test
-- ########################

if not IS_TEST then return end
local testTab3 = {
    [3] = {'Flesh Eater',664,713,24,25,0,{[10]={{25.06,38.2},{25.37,36.04},{25.69,34.45},{23.81,39.21},{22.81,39.09},{22.04,32.62},{21.7,38.3},{22.2,36.96},{25.37,39.03},},},nil,10,nil,nil,},
    [6] = {'Kobold Vermin',42,55,1,2,0,{[12]={{48.89,36.44},{49.55,36.06},{49.15,36.93},{48.1,36.96},{48.37,36.74},{49.32,35.81},{48.87,35.14},{49.87,36.3},{48.52,36.13},{49.17,36.55},{46.93,35.67},{47.58,35.94},{47.65,36.91},{47.86,36.26},{47.57,36.37},{47.62,35.75},{47.91,35.49},{47.36,36.31},{47.22,36.0},{47.55,34.98},{49.79,35.17},{49.44,35.34},{49.73,35.8},{50.04,35.46},{51.3,36.5},{51.23,36.02},{51.61,35.68},{50.49,37.61},{50.98,37.58},{51.29,37.43},{50.76,37.47},{51.36,37.02},{51.68,37.01},},},nil,12,nil,nil,},
    [30] = {'Forest Spider',102,120,5,6,0,{[12]={{36.43,55.89},{31.43,57.03},{35.98,62.7},{38.47,62.4},{28.46,66.71},{31.95,68.46},{35.76,69.07},{37.96,69.98},{38.2,72.85},{33.54,73.76},{39.54,78.66},{43.87,76.69},{40.76,75.13},{41.86,72.16},{38.79,73.3},{44.59,71.23},},},nil,12,nil,nil,},
    [36] = {'Harvest Golem',222,247,11,12,0,{[40]={{47.11,67.64},{35.81,45.9},{34.46,46.05},{32.51,36.36},{48.98,33.82},{32.92,37.29},{56.84,35.72},{36.13,46.93},{47.88,33.47},{46.54,69.08},{50.32,33.96},{34.33,47.79},{35.35,47.2},{33.42,36.19},{48.74,32.34},{47.46,66.53},{46.7,65.92},{46.87,67.03},{56.85,34.26},{33.56,46.66},{32.93,35.52},{57.29,35.37},{57.16,33.97},{56.52,35.1},{56.34,35.94},{56.97,36.27},{49.67,32.97},{48.67,32.19},},},nil,40,nil,nil,},
    [38] = {'Defias Thug',71,86,3,4,0,{[12]={{53.24,45.58},{54.05,44.86},{53.87,44.27},{54.59,42.87},{53.01,47.18},{52.93,47.28},{52.47,47.14},{51.95,48.53},{52.8,47.03},{51.87,47.52},{51.06,49.25},{52.28,49.48},{52.55,48.77},{52.25,50.09},{52.01,51.01},{51.38,49.26},{51.29,50.67},{53.22,50.57},{53.56,51.48},{52.36,51.66},{52.62,51.93},{52.92,49.41},{52.87,49.34},{53.29,49.55},{53.77,49.73},{53.86,49.17},{53.81,49.07},{53.78,49.19},{53.99,50.58},{53.22,48.17},{53.62,48.33},{53.59,47.76},{51.83,51.44},{54.47,51.35},{55.11,49.16},{55.1,49.0},{54.07,52.2},{54.86,52.08},{55.45,51.21},{55.69,49.73},{54.47,48.92},{54.49,49.87},{54.55,50.25},{55.04,47.84},{54.61,47.02},{54.05,46.92},{54.88,48.46},{54.14,47.84},{56.38,49.75},{56.07,48.13},{55.48,45.76},{54.71,45.96},{55.7,47.29},{55.3,47.02},{56.1,44.99},{56.63,43.72},{56.41,43.92},{56.66,44.02},{55.47,43.95},{55.22,42.27},{54.91,44.22},{55.01,40.17},{54.78,41.74},{54.63,41.56},{55.54,40.92},{57.07,40.9},{57.07,42.54},{56.08,40.56},{55.7,41.04},{54.94,40.19},{55.86,42.22},{54.98,43.14},{54.65,42.05},{54.51,42.78},{55.46,42.07},{53.98,44.76},{57.44,48.07},},},{[12]={{53.47,46.2},{53.96,43.55},{54.24,41.99},{54.4,40.77},{54.22,41.95},{54.49,40.69},{54.38,42.05},{54.0,43.5},{53.89,45.0},{53.47,46.2},{52.93,47.28},{52.55,47.31},{52.27,47.33},{51.88,47.75},{51.36,48.8},{50.84,49.18},{50.61,49.64},{50.35,50.63},{50.15,50.77},{50.64,49.84},{50.65,49.53},{50.54,49.06},{50.79,48.38},{51.24,47.5},{52.05,46.98},{52.64,46.47},{52.81,46.54},{52.87,46.92},{52.29,50.04},{52.7,50.0},{53.04,50.63},{53.39,51.62},{54.02,51.9},{54.81,51.74},{55.23,51.79},{55.7,50.72},{55.82,49.91},{55.25,49.88},{55.02,50.25},{54.92,50.84},{54.21,51.35},{54.09,51.62},{53.76,51.54},{53.45,51.2},{52.73,51.41},{52.27,51.24},{51.9,50.83},{52.01,51.01},{51.72,50.57},{51.83,50.66},{52.18,51.01},{53.22,51.14},{54.02,51.79},{54.98,51.22},{55.16,51.21},{53.28,51.55},{53.08,51.49},{52.92,49.41},{52.92,49.41},{53.86,49.17},{53.86,49.17},{53.79,49.16},{53.48,49.32},{53.0,49.28},{52.94,49.32},{53.3,48.79},{53.72,49.22},{55.1,49.0},{54.09,50.88},{53.79,50.94},{53.47,50.51},{53.05,49.63},{52.83,49.59},{52.76,49.47},{52.43,48.81},{52.43,48.51},{52.72,48.01},{53.16,47.43},{53.69,46.73},{53.97,46.77},{54.32,47.18},{54.81,48.0},{55.23,48.64},{55.29,49.11},{54.9,49.71},{55.54,45.27},{55.32,45.99},{54.78,45.69},{54.29,45.74},{54.07,45.25},{54.08,43.43},{54.37,42.93},{54.62,41.58},{55.03,40.85},{55.54,44.5},{55.32,43.66},{55.24,42.85},{55.48,42.16},{55.53,40.62},{55.24,40.19},{55.01,40.19},{56.08,40.56},{55.74,40.63},{55.52,41.42},{55.5,42.12},{55.06,42.72},{55.01,44.04},{55.1,42.42},{54.8,41.89},{54.94,40.2},{56.08,40.56},{56.08,40.56},},[46]={{2.42,98.17},{2.75,96.31},{2.94,94.87},{2.73,96.28},{3.04,94.78},{2.92,96.39},{2.47,98.11},{2.34,99.89},{2.56,98.03},{2.9,97.43},{3.2,95.83},{3.68,94.97},{4.29,99.3},{4.03,98.3},{3.94,97.34},{4.22,96.53},{4.28,94.69},{3.94,94.18},{3.67,94.18},{4.93,94.62},{4.53,94.71},{4.26,95.64},{4.25,96.47},{3.72,97.18},{3.66,98.75},{3.76,96.83},{3.42,96.2},{3.58,94.2},{4.93,94.62},{4.93,94.62},},},12,nil,nil,},
    [40] = {'Kobold Miner',120,137,6,7,0,{[12]={{40.45,80.26},{40.87,80.68},{40.71,81.4},{40.84,80.42},{41.09,80.96},{39.86,81.01},{39.95,78.62},{40.22,79.6},{39.77,79.09},{39.97,80.12},{41.43,79.87},{41.27,79.26},{41.64,80.09},{41.87,81.35},{41.04,78.16},{41.02,79.92},{41.6,80.04},{40.32,77.69},{40.35,78.16},{41.48,77.93},{41.71,78.67},{40.84,77.46},{64.78,59.93},{63.69,61.13},{64.5,57.42},{64.3,56.83},{64.79,56.41},{64.63,56.88},{63.58,55.35},{63.8,58.17},{63.12,56.56},{62.9,59.97},{61.97,58.32},{62.04,55.31},{62.82,53.82},{60.07,57.4},{61.12,56.36},{60.71,52.8},{61.5,51.92},{61.41,51.51},{61.51,53.26},{61.01,49.23},{61.11,50.9},{60.84,49.5},{60.27,49.55},{61.22,49.61},{61.48,50.2},{60.62,50.85},{61.14,49.89},{60.91,59.71},{58.02,59.83},},},nil,12,nil,nil,},
    [43] = {'Mine Spider',156,176,8,9,0,{[12]={{62.01,47.92},{60.03,48.68},{61.11,47.28},{61.75,47.45},{60.2,47.56},{61.91,47.12},{61.6,46.9},{60.53,46.9},},},nil,12,nil,nil,},
    [46] = {'Murloc Forager',176,198,9,10,0,{[12]={{68.64,85.46},{68.62,85.39},{65.78,84.42},{64.73,83.0},{61.87,80.56},{56.36,85.21},{52.34,86.73},{57.0,84.24},{59.3,82.43},{61.17,82.38},{63.36,82.8},{67.93,83.69},{69.98,84.08},{76.72,82.77},{76.79,85.94},{76.6,85.57},{77.25,85.18},{77.56,85.95},{76.16,84.87},{77.78,86.13},{79.34,57.2},{79.26,56.87},{79.65,55.22},{79.43,56.36},{78.8,55.73},{78.44,56.65},{78.45,56.16},{78.93,55.01},{79.34,54.08},{79.24,54.22},{79.46,50.74},{79.42,47.96},{79.46,48.2},{79.16,47.39},{79.36,47.7},{80.31,45.24},{79.19,45.21},{79.12,45.99},{79.48,45.36},{79.34,45.25},{79.54,47.18},{79.51,46.31},{79.96,46.28},{78.83,44.53},{77.95,45.11},{78.6,44.91},{78.23,44.87},{79.47,43.52},{78.57,43.17},{77.9,44.36},{77.74,44.28},{77.31,44.1},{78.56,42.09},{79.39,58.05},{75.56,86.58},{76.27,86.46},{75.86,85.94},{74.74,85.27},},},nil,12,nil,nil,},
    [48] = {'Skeletal Warrior',531,573,21,22,0,{[10]={{77.41,73.76},{76.91,72.2},{78.96,69.68},{80.34,72.03},{77.68,71.76},{76.88,70.25},{78.63,70.85},{80.57,70.2},{79.78,68.75},{82.14,68.7},{80.84,73.82},{79.75,73.0},{80.61,66.66},{81.03,69.32},{78.03,67.01},},},nil,10,nil,nil,},
    [54] = {'Corina Steele',396,396,10,10,0,{[12]={{41.53,65.9},},},nil,12,nil,nil,},
    [60] = {'Ruklar the Trapper',148,148,8,8,0,{[12]={{64.64,56.65},},},nil,12,nil,nil,},
    [61] = {'Thuros Lightfingers',222,222,11,11,4,{[12]={{52.66,58.91},{28.58,59.92},{29.23,58.0},{30.81,57.12},{50.51,82.93},{50.94,83.1},{89.94,79.45},{89.3,79.28},},},{[12]={{52.66,58.91},{52.67,58.99},{52.68,59.35},{52.73,59.83},{52.67,58.99},{52.66,58.91},{52.58,58.84},},},12,nil,nil,},
    [66] = {'Tharynn Bouden',396,396,10,10,0,{[12]={{41.82,67.16},},},nil,12,nil,nil,},
    [68] = {'Stormwind City Guard',3921,3921,55,55,0,{[12]={{32.08,49.95},{32.47,49.51},},[1519]={{51.47,27.87},{42.55,40.68},{32.96,64.5},{42.45,60.04},{38.6,58.48},{38.37,58.03},{62.46,64.18},{62.4,61.82},{60.61,67.98},{64.18,73.56},{59.93,68.81},{62.76,74.91},{55.43,67.88},{57.06,60.93},{55.1,68.14},{55.22,44.3},{59.93,45.25},{55.42,44.69},{59.69,45.56},{42.96,59.66},{48.95,62.23},{64.22,77.08},{67.82,81.39},{69.96,89.21},{71.48,87.39},},},{[12]={{28.64,38.56},{28.02,37.87},{27.31,37.1},{28.1,37.93},{28.59,38.58},{26.54,38.27},{26.99,37.53},{27.56,38.17},{26.96,37.53},{26.56,38.27},{29.09,44.33},{29.4,44.58},{29.86,45.48},{29.93,45.61},{30.9,47.48},{31.08,48.29},{31.5,49.15},{31.08,48.29},{30.9,47.48},{29.93,45.61},{29.86,45.48},{29.4,44.58},{29.58,43.66},{29.63,44.17},{30.21,45.23},{31.23,47.14},{32.34,46.09},{31.52,47.37},{32.07,48.38},{31.52,47.37},{32.34,46.09},{31.23,47.14},{30.21,45.23},{29.63,44.17},},[1519]={{62.47,61.72},{60.85,59.93},{59.01,57.95},{61.06,60.09},{62.34,61.78},{57.04,60.98},{58.19,59.05},{59.67,60.7},{58.12,59.07},{57.09,60.98},{63.61,76.62},{64.42,77.27},{65.62,79.58},{65.79,79.93},{68.28,84.75},{68.76,86.85},{69.84,89.08},{68.76,86.85},{68.28,84.75},{65.79,79.93},{65.62,79.58},{64.42,77.27},{64.89,74.89},{65.02,76.21},{66.52,78.95},{69.13,83.87},{72.0,81.18},{69.9,84.46},{71.32,87.07},{69.9,84.46},{72.0,81.18},{69.13,83.87},{66.52,78.95},{65.02,76.21},},},1519,nil,nil,},
    [69] = {'Timber Wolf',55,55,2,2,0,{[12]={{45.91,40.31},{49.16,45.38},{46.66,39.39},{49.41,37.75},{48.17,37.37},{48.15,34.91},{45.96,36.37},{46.6,35.13},{46.15,35.53},{46.25,36.73},{48.51,33.67},{46.34,34.42},{45.2,35.15},{45.69,34.96},{46.96,34.46},{50.93,35.71},{52.74,35.14},{50.16,37.41},{51.24,40.45},{52.51,39.15},{52.65,38.37},{52.63,40.48},{53.07,38.74},{51.88,41.56},{52.53,42.19},{51.53,43.7},{50.92,44.14},{50.89,44.37},{51.71,43.13},{51.61,42.38},{49.9,46.59},{49.48,49.26},{49.35,47.46},{48.98,47.04},{51.45,45.58},{50.38,44.94},},},nil,12,nil,nil,},
    [74] = {'Kurran Steele',396,396,10,10,0,{[12]={{41.37,65.59},},},nil,12,nil,nil,},
    [78] = {'Janos Hammerknuckle',204,204,5,5,0,{[12]={{47.24,41.9},},},nil,12,nil,nil,},
    [79] = {'Narg the Taskmaster',257,257,10,10,4,{[12]={{40.93,77.5},},},nil,12,nil,nil,},
}

TESTA = {}
for k, v in pairs(testTab3)do
    for x, y in pairs(v[7]) do
        local t = MDL_P:New(y)
        if t then 
            t:Draw(WorldMapFrame.ScrollContainer)
            t:DrawBorder()
            t:SetRandomColor()
            TESTA[#TESTA+1] = t
        end
    end
end