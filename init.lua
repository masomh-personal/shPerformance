if not LibStub then
	error("shPerformance requires LibStub")
end

local _, ns = ...
ns.SHP = {}
local SHP = ns.SHP

--[[----------------CONFIG---------------------]]
SHP.config = {
	WANT_ALPHA_SORTING = false,
	WANT_COLORING = false,
	UPDATE_PERIOD_TOOLTIP = 2,
	UPDATE_PERIOD_DATA_TEXT = 1.5,
	MEM_THRESHOLD = 50,
	MAX_ADDONS = 40,
	SHOW_BOTH = true,
	FPS_GRADIENT_THRESHOLD = 75,
	MS_GRADIENT_THRESHOLD = 300,
	MEM_GRADIENT_THRESHOLD = 40,
	FPS_ICON = "Interface\\AddOns\\shPerformance\\media\\fpsicon",
	MS_ICON = "Interface\\AddOns\\shPerformance\\media\\msicon",
}

-- Libraries and commonly used functions
local math, string, table = math, string, table
SHP.math, SHP.string, SHP.table = math, string, table
SHP.GetNetStats, SHP.GetFramerate, SHP.collectgarbage = GetNetStats, GetFramerate, collectgarbage
SHP.UpdateAddOnMemoryUsage, SHP.GetAddOnMemoryUsage, SHP.GetNumAddOns, SHP.GetAddOnInfo, SHP.IsAddOnLoaded =
	UpdateAddOnMemoryUsage, GetAddOnMemoryUsage, C_AddOns.GetNumAddOns, C_AddOns.GetAddOnInfo, C_AddOns.IsAddOnLoaded
SHP.GameTooltip = GameTooltip

-- Initialize addons table
SHP.ADDONS_TABLE = {}

-- Function to create and populate the addons table with colorized titles initially
local function CreateAddonTable()
	local numAddOns = SHP.GetNumAddOns()
	for i = 1, numAddOns do
		if SHP.IsAddOnLoaded(i) then
			local name, title = SHP.GetAddOnInfo(i)
			local colorizedTitle = title and (title:find("|cff") and title or "|cffffffff" .. title)
				or "|cffffffffUnknown Addon"
			SHP.ADDONS_TABLE[name] = { memory = 0, colorizedTitle = colorizedTitle } -- Store as a table with `memory` and `colorizedTitle`
		end
	end
end

-- Event frame to initialize addon table on login
local gFrame = CreateFrame("Frame")
gFrame:RegisterEvent("PLAYER_LOGIN")
gFrame:SetScript("OnEvent", function()
	CreateAddonTable() -- Initialize addons table only once
end)

--[[ 
	Formats memory usage with optional color coding.
	@param mem: Memory value in kilobytes (number).
	@param useColor: Boolean to determine if the formatted output should be colored.
	@return: Formatted string with memory value in either "K" or "M" units, colored if specified.
]]
SHP.formatMem = function(mem, useColor)
	local isMB = mem > 1024
	local unit = isMB and "M" or "K"
	local formattedMem = isMB and mem / 1e3 or mem

	-- Conditional formatting with pseudo-ternary for optional coloring
	return useColor and format("%.2f|cffE8D200%s|r", formattedMem, unit) or format("%.2f%s", formattedMem, unit)
end

--[[ 
	Interpolates between colors in a sequence based on a percentage.
	@param perc: Percentage (0 to 1) representing the position in the gradient.
	@param providedColorSequence: Optional table of RGB values (default is green -> yellow -> red).
	@return: Interpolated RGB color values.
]]
SHP.ColorGradient = function(perc, providedColorSequence)
	local colors = providedColorSequence or { 0, 1, 0, 1, 1, 0, 1, 0, 0 }
	local num = #colors / 3

	-- Clamp the percentage
	if perc >= 1 then
		local r, g, b = colors[(num - 1) * 3 + 1], colors[(num - 1) * 3 + 2], colors[(num - 1) * 3 + 3]
		return r, g, b
	elseif perc <= 0 then
		local r, g, b = colors[1], colors[2], colors[3]
		return r, g, b
	end

	-- Determine the segment and interpolate
	local segment = math.floor(perc * (num - 1))
	local relperc = (perc * (num - 1)) - segment
	local r1, g1, b1 = colors[(segment * 3) + 1], colors[(segment * 3) + 2], colors[(segment * 3) + 3]
	local r2, g2, b2 = colors[(segment * 3) + 4], colors[(segment * 3) + 5], colors[(segment * 3) + 6]

	return r1 + (r2 - r1) * relperc, g1 + (g2 - g1) * relperc, b1 + (b2 - b1) * relperc
end

--[[ 
	Creates a gradient table with color values interpolated at 0.5% intervals.
	@param providedColorSequence: Optional color sequence for gradient creation.
	@return: Gradient table with RGB values mapped from 0 to 100 percent.
]]
SHP.CreateGradientTable = function(providedColorSequence)
	local gradientTable = {}
	local colorSequence = providedColorSequence or nil
	for i = 0, 200 do
		local percent = i / 2 -- 0.5% intervals
		local r, g, b = SHP.ColorGradient(percent / 100, colorSequence)
		gradientTable[percent] = { r, g, b }
	end
	return gradientTable
end

-- Create and store the gradient table when the addon loads
local colorSequence = { 0, 1, 0, 1, 1, 0, 1, 0, 0 }
SHP.GRADIENT_TABLE = SHP.CreateGradientTable(colorSequence)

--[[ 
	Retrieves the RGB color values from the gradient table based on a proportion.
	@param proportion: Proportion (0 to 1) to map to a color.
	@param gradientTable: Optional gradient table (default is SHP.GRADIENT_TABLE).
	@return: RGB values from the gradient table.
]]
SHP.GetColorFromGradientTable = function(proportion, gradientTable)
	gradientTable = gradientTable or SHP.GRADIENT_TABLE
	local normalized_value = math.max(0, math.min(proportion * 100, 100))
	local roundedValue = math.floor(normalized_value * 2) / 2
	return unpack(gradientTable[roundedValue])
end

--[[ 
	Returns the appropriate color for FPS text based on the FPS value.
	@param fps: Frames per second value.
	@return: RGB color values corresponding to the FPS level.
]]
SHP.GetFPSColor = function(fps)
	local proportion = 1 - (fps / SHP.config.FPS_GRADIENT_THRESHOLD)
	proportion = math.max(0, math.min(proportion, 1))
	return SHP.GetColorFromGradientTable(proportion, SHP.GRADIENT_TABLE)
end

-- Tooltip anchor function
-- Determines the anchor point for tooltips based on the frame's position on the screen.
SHP.GetTipAnchor = function(frame)
	local x, y = frame:GetCenter()
	if not x or not y then
		return "TOPLEFT", "BOTTOMLEFT"
	end
	local hhalf = (x > UIParent:GetWidth() * 2 / 3) and "RIGHT" or (x < UIParent:GetWidth() / 3) and "LEFT" or ""
	local vhalf = (y > UIParent:GetHeight() / 2) and "TOP" or "BOTTOM"
	return vhalf .. hhalf, frame, (vhalf == "TOP" and "BOTTOM" or "TOP") .. hhalf
end
