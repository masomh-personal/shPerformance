local _, ns = ...
local SHP = ns.SHP

-- ===================================================================================
-- OPTIMIZED: Localize all frequently used functions
-- ===================================================================================
local GetFramerate = SHP.GetFramerate
local GetNetStats = SHP.GetNetStats
local GetNetIpTypes = SHP.GetNetIpTypes
local UpdateAddOnMemoryUsage = SHP.UpdateAddOnMemoryUsage
local GetAddOnMemoryUsage = SHP.GetAddOnMemoryUsage
local GameTooltip = SHP.GameTooltip
local UIParent = UIParent
local C_CVar = C_CVar
local GetTime = SHP.GetTime
local unpack = unpack
local ipairs = ipairs

local math_floor = SHP.math.floor
local math_max = SHP.math.max
local math_min = SHP.math.min
local string_format = SHP.string.format
local string_lower = SHP.string.lower
local table_sort = SHP.table.sort

-- Cache frequently accessed tables
local FORMAT_STRINGS = SHP.FORMAT_STRINGS
local GRADIENT_TABLE = SHP.GRADIENT_TABLE

--[[ 
	Formats memory usage with optional color coding.
	@param mem: Memory value in kilobytes (number).
	@param useColor: Boolean to determine if the formatted output should be colored.
	@return: Formatted string with memory value in either "K" or "M" units, colored if specified.
]]
SHP.FormatMemString = function(mem, useColor)
	local isMB = mem > 1024
	local unit = isMB and "M" or "K"
	local formattedMem = isMB and mem / 1e3 or mem

	-- Conditional formatting with pseudo-ternary for optional coloring
	return useColor and SHP.string.format("%.2f|cffE8D200%s|r", formattedMem, unit)
		or SHP.string.format("%.2f%s", formattedMem, unit)
end

-- ===================================================================================
-- OPTIMIZED: Direct gradient lookup from pre-computed table
-- The new gradient table in init.lua uses integer keys (0-100) with named fields
-- ===================================================================================
SHP.GetColorFromGradientTable = function(proportion)
	-- Convert proportion (0-1) to index (0-100)
	local index = math_min(100, math_max(0, math_floor(proportion * 100 + 0.5)))
	local entry = GRADIENT_TABLE[index]
	-- Return the r, g, b values from the named fields
	return entry.r, entry.g, entry.b
end

-- ===================================================================================
-- OPTIMIZED: Get pre-computed hex color for efficiency
-- ===================================================================================
SHP.GetColorHex = function(proportion)
	local index = math_min(100, math_max(0, math_floor(proportion * 100 + 0.5)))
	return GRADIENT_TABLE[index].hex
end

-- ===================================================================================
-- OPTIMIZED: FPS color calculation
-- ===================================================================================
SHP.GetFPSColor = function(fps)
	local proportion = 1 - math_min(1, math_max(0, fps / SHP.CONFIG.FPS_GRADIENT_THRESHOLD))
	return SHP.GetColorFromGradientTable(proportion)
end


-- ===================================================================================
-- OPTIMIZED: Efficient tooltip anchor calculation
-- ===================================================================================
SHP.GetTipAnchor = function(frame)
	local x, y = frame:GetCenter()
	if not x or not y then
		return "TOPLEFT", "BOTTOMLEFT"
	end
	
	local screenWidth = UIParent:GetWidth()
	local screenHeight = UIParent:GetHeight()
	
	local hPos = (x > screenWidth * 0.66) and "RIGHT" or (x < screenWidth * 0.33) and "LEFT" or ""
	local vPos = (y > screenHeight * 0.5) and "TOP" or "BOTTOM"
	
	return vPos .. hPos, frame, (vPos == "TOP" and "BOTTOM" or "TOP") .. hPos
end

-- ===================================================================================
-- OPTIMIZED: Color cache for common colors
-- ===================================================================================
local COLOR_CACHE = {
	green = "00FF00",
	red = "FF0000",
	yellow = "FFFF00",
	cyan = "00FFFF",
	white = "FFFFFF",
}

-- ===================================================================================
-- OPTIMIZED: Fast color text formatting with caching
-- ===================================================================================
SHP.ColorizeText = function(r, g, b, text)
	local hex
	
	-- Check color cache for common colors
	if r == 0 and g == 1 and b == 0 then
		hex = COLOR_CACHE.green
	elseif r == 1 and g == 1 and b == 0 then
		hex = COLOR_CACHE.yellow
	elseif r == 1 and g == 0 and b == 0 then
		hex = COLOR_CACHE.red
	elseif r == 0 and g == 1 and b == 1 then
		hex = COLOR_CACHE.cyan
	else
		hex = string_format(FORMAT_STRINGS.HEX_FORMAT, r * 255, g * 255, b * 255)
	end
	
	return string_format(FORMAT_STRINGS.COLOR_WRAP, hex, text)
end

--[[ 
	Adds a colored double line to the tooltip.
	@param leftLabel: The text displayed on the left side.
	@param rightText: The text displayed on the right side.
	@param r: Red component of the color (0-1) for the right text.
	@param g: Green component of the color (0-1) for the right text.
	@param b: Blue component of the color (0-1) for the right text.
--]]
SHP.AddColoredDoubleLineToTooltip = function(leftLabel, rightText, r, g, b)
	SHP.GameTooltip:AddDoubleLine(leftLabel, rightText, r, g, b)
end

--[[ 
	Adds a colored single line of text to the tooltip.
	@param text: The line of text to be added to the tooltip.
	@param r: Red component of the color (0-1).
	@param g: Green component of the color (0-1).
	@param b: Blue component of the color (0-1).
--]]
SHP.AddColoredSingleLineToTooltip = function(text, r, g, b)
	SHP.GameTooltip:AddLine(text, r, g, b)
end

--[[ 
	Adds a line spacer to the tooltip. Optionally adds a dashed line if dashedSpacer is true.
	@param dashedSpacer: Boolean value; if true, adds a dashed line. Otherwise, adds a blank line.
--]]
SHP.AddLineSeparatorToTooltip = function(dashedSpacer)
	if dashedSpacer then
		SHP.GameTooltip:AddDoubleLine("|cffffffff————|r", "|cffffffff————|r")
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
SHP.GetColorizedFPSString = function()
	-- Retrieve current FPS and round down to the nearest integer
	local fps = SHP.math.floor(SHP.GetFramerate())

	-- Determine color based on FPS value
	local rf, gf, bf = SHP.GetFPSColor(fps)

	-- Format FPS value with color and return the resulting string
	return SHP.ColorizeText(rf, gf, bf, SHP.string.format("%.0f", fps))
end

--[[ 
    Hides the GameTooltip and ensures it is cleared and clamped to the screen.

    This function is used to safely hide the GameTooltip when the mouse 
    leaves a data display element or tooltip anchor. It provides three actions:
    - Clamps the tooltip to the screen, ensuring it stays within visible bounds.
    - Clears any lines currently displayed in the tooltip, preventing residual 
      content from previous displays.
    - Hides the tooltip from the UI.

    Usage:
    Call `SHP.HideTooltip()` in any `OnLeave` handler or context where 
    the tooltip needs to be safely dismissed and reset.

    @return: None. This function performs actions directly on the GameTooltip object.
]]
SHP.HideTooltip = function()
	GameTooltip:SetClampedToScreen(true)
	GameTooltip:ClearLines()
	GameTooltip:Hide()
end

--[[ 
    Updates the latency data text with formatted home and world latency values.
    
    This function retrieves the formatted latency for both home and world connections, 
    combines them into a single string separated by an arrow (→), and updates the 
    `DATA_TEXT_LATENCY.text` field with this formatted output. 

    Usage:
    Call `SHP.UpdateLatencyDataText()` whenever you need to refresh or display updated 
    latency information in the data text. 

    @return: None. This function directly updates `DATA_TEXT_LATENCY.text`.
]]
SHP.UpdateLatencyDataText = function()
	local _, _, latencyHome, latencyWorld = SHP.GetNetStats()

	-- Apply color gradients and format latency values
	local rH, gH, bH = SHP.GetColorFromGradientTable(latencyHome / SHP.CONFIG.MS_GRADIENT_THRESHOLD)
	local rW, gW, bW = SHP.GetColorFromGradientTable(latencyWorld / SHP.CONFIG.MS_GRADIENT_THRESHOLD)
	local colorizedHome = SHP.ColorizeText(rH, gH, bH, SHP.string.format("%.0f", latencyHome))
	local colorizedWorld = SHP.ColorizeText(rW, gW, bW, SHP.string.format("%.0f (world)", latencyWorld))

	-- Combine latency details for display
	return SHP.string.format("%s → %s", colorizedHome, colorizedWorld)
end

--[[ 
    Adds network latency and bandwidth stats to a specified tooltip with colorized formatting.
    
    This function retrieves network statistics, formats the latency and bandwidth values with 
    color gradients, and adds them to the specified tooltip. Supports IPv4 and IPv6 identification 
    when available and color-codes the output based on thresholds in the configuration.

    Usage:
    Call `SHP.AddNetworkStatsToTooltip(tooltip)` within any tooltip setup to include network stats. 

    @param tooltip: The tooltip object to which the network stats will be added.
    @return: bandwidthIn, bandwidthOut - Optionally returns incoming and outgoing bandwidth values.
]]
SHP.AddNetworkStatsToTooltip = function()
	-- Retrieve network stats from WoW's API or custom function
	local bandwidthIn, bandwidthOut, latencyHome, latencyWorld = SHP.GetNetStats()

	-- Define IP type texts for home and world latency
	local ipTypeHomeText, ipTypeWorldText = "HOME", "WORLD"
	if not SHP.GetCVarBool("useIPv6") then
		local ipTypes = { "IPv4", "IPv6" }
		local ipTypeHome, ipTypeWorld = SHP.GetNetIpTypes()
		ipTypeHomeText = SHP.string.format("HOME (%s)", ipTypes[ipTypeHome or 0] or UNKNOWN)
		ipTypeWorldText = SHP.string.format("WORLD (%s)", ipTypes[ipTypeWorld or 0] or UNKNOWN)
	end

	-- Format latency values with color gradients based on thresholds
	local rH, gH, bH = SHP.GetColorFromGradientTable(latencyHome / SHP.CONFIG.MS_GRADIENT_THRESHOLD)
	local rW, gW, bW = SHP.GetColorFromGradientTable(latencyWorld / SHP.CONFIG.MS_GRADIENT_THRESHOLD)
	local colorizedHome = SHP.ColorizeText(rH, gH, bH, SHP.string.format("%.0f ms", latencyHome))
	local colorizedWorld = SHP.ColorizeText(rW, gW, bW, SHP.string.format("%.0f ms", latencyWorld))

	-- Add latency details to the tooltip
	local homeHexColor, worldHexColor = "42AAFF", "DCFF42"
	SHP.GameTooltip:AddDoubleLine(
		SHP.string.format("|cff%s%s|r |cffFFFFFFlatency:|r", homeHexColor, ipTypeHomeText),
		colorizedHome
	)
	SHP.GameTooltip:AddDoubleLine(
		SHP.string.format("|cff%s%s|r |cffFFFFFFlatency:|r", worldHexColor, ipTypeWorldText),
		colorizedWorld
	)

	-- Add a separator line in the tooltip
	SHP.AddLineSeparatorToTooltip(true)

	-- Format bandwidth values with color gradients based on thresholds
	local rIn, gIn, bIn = SHP.GetColorFromGradientTable(bandwidthIn / SHP.CONFIG.BANDWIDTH_INCOMING_GRADIENT_THRESHOLD)
	local rOut, gOut, bOut =
		SHP.GetColorFromGradientTable(bandwidthOut / SHP.CONFIG.BANDWIDTH_OUTGOING_GRADIENT_THRESHOLD)
	local colorizedBin = SHP.ColorizeText(rIn, gIn, bIn, SHP.string.format("▼ %.2f KB/s", bandwidthIn))
	local colorizedBOut = SHP.ColorizeText(rOut, gOut, bOut, SHP.string.format("▲ %.2f KB/s", bandwidthOut))

	-- Add bandwidth details to the tooltip
	SHP.AddColoredDoubleLineToTooltip("|cff00FFFFIncoming|r |cffFFFFFFbandwidth:|r", colorizedBin)
	SHP.AddColoredDoubleLineToTooltip("|cff00FFFFOutgoing|r |cffFFFFFFbandwidth:|r", colorizedBOut)

	return bandwidthIn, bandwidthOut
end

--[[ 
    Retrieves the current FPS and applies a color gradient based on the FPS value, 
    returning the formatted FPS as a colorized string.

    This function fetches the current frames per second (FPS), determines the appropriate 
    color gradient, and formats the FPS value as a string with color coding. 

    Usage:
    Call `SHP.GetFormattedFPS()` wherever a colorized FPS string is needed for display.

    @return: A string representing the FPS value, formatted with color based on the FPS level.
]]
SHP.UpdateFPSDataText = function()
	local fps = SHP.GetFramerate()
	local rf, gf, bf = SHP.GetFPSColor(fps)
	return SHP.ColorizeText(rf, gf, bf, SHP.string.format("%.0f", fps))
end
