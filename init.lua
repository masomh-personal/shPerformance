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
	UPDATE_PERIOD_FPS_DATA_TEXT = 1.5,
	UPDATE_PERIOD_LATENCY_DATA_TEXT = 30, -- Static default by blizzard
	MEM_THRESHOLD = 100, -- in KB (only will show addons that use >= this number)
	SHOW_BOTH = true,
	FPS_GRADIENT_THRESHOLD = 75,
	MS_GRADIENT_THRESHOLD = 300,
	MEM_GRADIENT_THRESHOLD = 40,
	BANDWIDTH_INCOMING_GRADIENT_THRESHOLD = 20,
	BANDWIDTH_OUTGOING_GRADIENT_THRESHOLD = 5,
	GRADIENT_COLOR_SEQUENCE_TABLE = { 0, 0.97, 0, 0.97, 0.97, 0, 0.95, 0, 0 }, -- True RGB gradient: green -> yellow -> red
	-- Starts with green, transitions through yellow, and ends at red (0.95, 0, 0).
	-- This sequence provides a high-contrast gradient for maximum readability and color intensity.
	FPS_ICON = "Interface\\AddOns\\shPerformance\\media\\fpsicon",
	MS_ICON = "Interface\\AddOns\\shPerformance\\media\\msicon",
}

-- Localized: libraries and commonly used functions
local math = math
local string = string
local table = table

SHP.math = math
SHP.string = string
SHP.table = table

SHP.GetFramerate = GetFramerate
SHP.collectgarbage = collectgarbage

SHP.UpdateAddOnMemoryUsage = UpdateAddOnMemoryUsage
SHP.GetAddOnMemoryUsage = GetAddOnMemoryUsage
SHP.GetNumAddOns = C_AddOns.GetNumAddOns
SHP.GetAddOnInfo = C_AddOns.GetAddOnInfo
SHP.IsAddOnLoaded = C_AddOns.IsAddOnLoaded

SHP.GetNetStats = GetNetStats
SHP.GetCVarBool = C_CVar.GetCVarBool
SHP.GetNetIpTypes = GetNetIpTypes

SHP.GameTooltip = GameTooltip

-- Initialize `SHP.ADDONS_TABLE` as an array-style table
SHP.ADDONS_TABLE = {}

-- Function to create `SHP.ADDONS_TABLE` once at player login
local function CreateAddonTable()
	local numAddOns = SHP.GetNumAddOns()

	for i = 1, numAddOns do
		local name, title, _, loadable, reason = SHP.GetAddOnInfo(i)

		-- Only add addons that are loadable or load on demand
		if loadable or reason == "DEMAND_LOADED" then
			table.insert(SHP.ADDONS_TABLE, {
				name = name,
				index = i, -- Store the addon’s index for easy reference later if needed
				title = title or "Unknown Addon",
				colorizedTitle = title and (title:find("|cff") and title or "|cffffffff" .. title)
					or "|cffffffffUnknown Addon",
				memory = 0, -- Default memory usage, to be updated later
			})
		end
	end
end

-- Initialize `SHP.ADDONS_TABLE` once at player login
local gFrame = CreateFrame("Frame")
gFrame:RegisterEvent("PLAYER_LOGIN")
gFrame:SetScript("OnEvent", function()
	CreateAddonTable() -- Populate the addons table only once on login
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
SHP.GRADIENT_TABLE = SHP.CreateGradientTable(SHP.config.GRADIENT_COLOR_SEQUENCE_TABLE)

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

--[[ 
	Determines the optimal anchor point for tooltips based on the provided frame's position on the screen.
	@param frame: The frame for which the tooltip anchor position is calculated.
	@return: The tooltip anchor point, relative frame, and attachment point based on the screen position
--]]
SHP.GetTipAnchor = function(frame)
	local x, y = frame:GetCenter()
	if not x or not y then
		return "TOPLEFT", "BOTTOMLEFT"
	end

	-- Determine horizontal and vertical halves based on screen location
	local hhalf = (x > UIParent:GetWidth() * 2 / 3) and "RIGHT" or (x < UIParent:GetWidth() / 3) and "LEFT" or ""
	local vhalf = (y > UIParent:GetHeight() / 2) and "TOP" or "BOTTOM"

	-- Return calculated tooltip position based on frame's screen section
	return vhalf .. hhalf, frame, (vhalf == "TOP" and "BOTTOM" or "TOP") .. hhalf
end

-- Precomputed RGB Lookup for frequent colors (optional; improves heavy usage performance)
local RGB_Lookup = {
	green = "00FF00",
	red = "FF0000",
	yellow = "FFFF00",
	cyan = "00FFFF",
}

--[[ 
    Formats a string with a specific RGB color for display in the game tooltip or UI.
    @param r: Red component of the color (0 to 1)
    @param g: Green component of the color (0 to 1)
    @param b: Blue component of the color (0 to 1)
    @param text: The string of text to be colorized
    @return: A formatted string wrapped in the specified RGB color, ready for display
--]]
-- Optimized ColorizeText using RGB_Lookup (if applicable colors are reused frequently)
SHP.ColorizeText = function(r, g, b, text)
	local hexColor
	if r == 0 and g == 1 and b == 0 then
		hexColor = RGB_Lookup.green
	elseif r == 1 and g == 1 and b == 0 then
		hexColor = RGB_Lookup.yellow
	elseif r == 0 and g == 1 and b == 1 then
		hexColor = RGB_Lookup.cyan
	elseif r == 1 and g == 0 and b == 0 then
		hexColor = RGB_Lookup.red
	else
		hexColor = SHP.string.format("%02x%02x%02x", r * 255, g * 255, b * 255)
	end

	return SHP.string.format("|cff%s%s|r", hexColor, text)
end

--[[ 
	Adds network latency stats to a specified tooltip with colorized formatting.
	@param tooltip: The tooltip object to which the network stats will be added.
--]]
SHP.AddNetworkStatsToTooltip = function()
	-- Retrieve network stats from WoW's API or custom function
	local bandwidthIn, bandwidthOut, latencyHome, latencyWorld = SHP.GetNetStats()

	local ipTypeHomeText, ipTypeWorldText = "HOME", "WORLD"
	if not SHP.GetCVarBool("useIPv6") then
		local ipTypes = { "IPv4", "IPv6" }
		local ipTypeHome, ipTypeWorld = SHP.GetNetIpTypes()
		ipTypeHomeText = SHP.string.format("HOME (%s)", ipTypes[ipTypeHome or 0] or UNKNOWN)
		ipTypeWorldText = SHP.string.format("WORLD (%s)", ipTypes[ipTypeWorld or 0] or UNKNOWN)
	end

	-- Calculate RGB gradient colors for latency based on thresholds in the config
	local rH, gH, bH = SHP.GetColorFromGradientTable(latencyHome / SHP.config.MS_GRADIENT_THRESHOLD)
	local rW, gW, bW = SHP.GetColorFromGradientTable(latencyWorld / SHP.config.MS_GRADIENT_THRESHOLD)

	-- Format latency values to display as integers with "ms" suffix
	local formattedHomeLatency = string.format("%.0f ms", latencyHome)
	local formattedWorldLatency = string.format("%.0f ms", latencyWorld)

	-- Apply color to formatted latency strings
	local colorizedHome = SHP.ColorizeText(rH, gH, bH, formattedHomeLatency)
	local colorizedWorld = SHP.ColorizeText(rW, gW, bW, formattedWorldLatency)

	-- Add colorized latency details to the tooltip
	local homeHexColor = "42AAFF"
	local worldHexColor = "DCFF42"
	SHP.GameTooltip:AddDoubleLine(
		SHP.string.format("|cff%s%s|r |cffFFFFFFlatency:|r", homeHexColor, ipTypeHomeText),
		colorizedHome
	)
	SHP.GameTooltip:AddDoubleLine(
		SHP.string.format("|cff%s%s|r |cffFFFFFFlatency:|r", worldHexColor, ipTypeWorldText),
		colorizedWorld
	)

	-- based back to tooltip if needed
	return bandwidthIn, bandwidthOut
end

--[[ 
	Adds a colored double line to the tooltip.
	@param leftLabel: The text displayed on the left side.
	@param rightText: The text displayed on the right side.
	@param r: Red component of the color (0-1) for the right text.
	@param g: Green component of the color (0-1) for the right text.
	@param b: Blue component of the color (0-1) for the right text.
--]]
SHP.AddColoredDoubleLine = function(leftLabel, rightText, r, g, b)
	SHP.GameTooltip:AddDoubleLine(leftLabel, rightText, r, g, b)
end

--[[ 
	Adds a colored single line of text to the tooltip.
	@param text: The line of text to be added to the tooltip.
	@param r: Red component of the color (0-1).
	@param g: Green component of the color (0-1).
	@param b: Blue component of the color (0-1).
--]]
SHP.AddColoredSingleLine = function(text, r, g, b)
	SHP.GameTooltip:AddLine(text, r, g, b)
end

--[[ 
	Adds a line spacer to the tooltip. Optionally adds a dashed line if dashedSpacer is true.
	@param dashedSpacer: Boolean value; if true, adds a dashed line. Otherwise, adds a blank line.
--]]
SHP.AddToolTipLineSpacer = function(dashedSpacer)
	if dashedSpacer then
		SHP.GameTooltip:AddDoubleLine("|cffffffff------------|r", "|cffffffff------------|r")
	else
		SHP.GameTooltip:AddLine(" ")
	end
end

--[[ 
    Updates the memory usage for each addon in `SHP.ADDONS_TABLE`.
    This function refreshes WoW's internal memory usage data, then iterates over `SHP.ADDONS_TABLE`
    to retrieve and update each addon's current memory usage in KB. This function does not recreate
    or modify the `SHP.ADDONS_TABLE` structure; it only updates the `memory` field for each addon.

    @return: None. Modifies the `memory` field of each entry in `SHP.ADDONS_TABLE` in place.
--]]
SHP.UpdateUserAddonMemoryUsageTable = function()
	-- Refresh memory usage data for all loaded addons in WoW
	SHP.UpdateAddOnMemoryUsage() -- WoW API call to refresh memory data

	-- Loop through each addon in `SHP.ADDONS_TABLE` (now an array) and update its memory usage
	for _, addonData in ipairs(SHP.ADDONS_TABLE) do
		-- Retrieve memory usage for each addon by its `index`
		-- `SHP.GetAddOnMemoryUsage(addonData.index)` returns memory in KB; fallback to 0 if unavailable
		addonData.memory = SHP.GetAddOnMemoryUsage(addonData.index) or 0
	end
end

--[[ 
    Retrieves the current FPS, applies a color gradient based on the FPS value,
    and returns the colorized FPS as a formatted string.

    @return: A colorized string representing the FPS value.
--]]
SHP.GetColorizedFPSText = function()
	-- Retrieve current FPS and round down to the nearest integer
	local fps = SHP.math.floor(SHP.GetFramerate())

	-- Determine color based on FPS value
	local rf, gf, bf = SHP.GetFPSColor(fps)

	-- Format FPS value with color and return the resulting string
	return SHP.ColorizeText(rf, gf, bf, SHP.string.format("%.0f", fps))
end
