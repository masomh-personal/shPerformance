local _, ns = ...
local SHP = ns.SHP

-- Cache frequently used functions for performance
local format = string.format
local floor = math.floor
local max = math.max
local min = math.min
local unpack = unpack

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
	return useColor and format("%.2f|cffE8D200%s|r", formattedMem, unit) or format("%.2f%s", formattedMem, unit)
end

--[[ 
	Interpolates between colors in a sequence based on a percentage.
	@param perc: Percentage (0 to 1) representing the position in the gradient.
	@param providedColorSequence: Optional table of RGB values (default is green -> yellow -> red).
	@return: Interpolated RGB color values.
]]
SHP.GetColorGradient = function(perc, providedColorSequence)
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
	local segment = floor(perc * (num - 1))
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
		local r, g, b = SHP.GetColorGradient(percent / 100, colorSequence)
		gradientTable[percent] = { r, g, b }
	end
	return gradientTable
end
SHP.GRADIENT_TABLE = SHP.CreateGradientTable(SHP.CONFIG.GRADIENT_COLOR_SEQUENCE_TABLE)

--[[ 
	Retrieves the RGB color values from the gradient table based on a proportion.
	@param proportion: Proportion (0 to 1) to map to a color.
	@param gradientTable: Optional gradient table (default is SHP.GRADIENT_TABLE).
	@return: RGB values from the gradient table.
]]
SHP.GetColorFromGradientTable = function(proportion, gradientTable)
	gradientTable = gradientTable or SHP.GRADIENT_TABLE
	local normalized_value = max(0, min(proportion * 100, 100))
	local roundedValue = floor(normalized_value * 2) / 2
	return unpack(gradientTable[roundedValue])
end

--[[ 
	Returns the appropriate color for FPS text based on the FPS value.
	@param fps: Frames per second value.
	@return: RGB color values corresponding to the FPS level.
]]
SHP.GetFPSColor = function(fps)
	local proportion = 1 - (fps / SHP.CONFIG.FPS_GRADIENT_THRESHOLD)
	proportion = max(0, min(proportion, 1))
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
local RGB_LOOKUP_TABLE = {
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
		hexColor = RGB_LOOKUP_TABLE.green
	elseif r == 1 and g == 1 and b == 0 then
		hexColor = RGB_LOOKUP_TABLE.yellow
	elseif r == 0 and g == 1 and b == 1 then
		hexColor = RGB_LOOKUP_TABLE.cyan
	elseif r == 1 and g == 0 and b == 0 then
		hexColor = RGB_LOOKUP_TABLE.red
	else
		hexColor = format("%02x%02x%02x", r * 255, g * 255, b * 255)
	end

	return format("|cff%s%s|r", hexColor, text)
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
	local fps = floor(SHP.GetFramerate())

	-- Determine color based on FPS value
	local rf, gf, bf = SHP.GetFPSColor(fps)

	-- Format FPS value with color and return the resulting string
	return SHP.ColorizeText(rf, gf, bf, format("%.0f", fps))
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
	local colorizedHome = SHP.ColorizeText(rH, gH, bH, format("%.0f", latencyHome))
	local colorizedWorld = SHP.ColorizeText(rW, gW, bW, format("%.0f (world)", latencyWorld))

	-- Combine latency details for display
	return format("%s → %s", colorizedHome, colorizedWorld)
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
		ipTypeHomeText = format("HOME (%s)", ipTypes[ipTypeHome or 0] or UNKNOWN)
		ipTypeWorldText = format("WORLD (%s)", ipTypes[ipTypeWorld or 0] or UNKNOWN)
	end

	-- Format latency values with color gradients based on thresholds
	local rH, gH, bH = SHP.GetColorFromGradientTable(latencyHome / SHP.CONFIG.MS_GRADIENT_THRESHOLD)
	local rW, gW, bW = SHP.GetColorFromGradientTable(latencyWorld / SHP.CONFIG.MS_GRADIENT_THRESHOLD)
	local colorizedHome = SHP.ColorizeText(rH, gH, bH, format("%.0f ms", latencyHome))
	local colorizedWorld = SHP.ColorizeText(rW, gW, bW, format("%.0f ms", latencyWorld))

	-- Add latency details to the tooltip
	local homeHexColor, worldHexColor = "42AAFF", "DCFF42"
	SHP.GameTooltip:AddDoubleLine(
		format("|cff%s%s|r |cffFFFFFFlatency:|r", homeHexColor, ipTypeHomeText),
		colorizedHome
	)
	SHP.GameTooltip:AddDoubleLine(
		format("|cff%s%s|r |cffFFFFFFlatency:|r", worldHexColor, ipTypeWorldText),
		colorizedWorld
	)

	-- Add a separator line in the tooltip
	SHP.AddLineSeparatorToTooltip(true)

	-- Format bandwidth values with color gradients based on thresholds
	local rIn, gIn, bIn = SHP.GetColorFromGradientTable(bandwidthIn / SHP.CONFIG.BANDWIDTH_INCOMING_GRADIENT_THRESHOLD)
	local rOut, gOut, bOut =
		SHP.GetColorFromGradientTable(bandwidthOut / SHP.CONFIG.BANDWIDTH_OUTGOING_GRADIENT_THRESHOLD)
	local colorizedBin = SHP.ColorizeText(rIn, gIn, bIn, format("▼ %.2f KB/s", bandwidthIn))
	local colorizedBOut = SHP.ColorizeText(rOut, gOut, bOut, format("▲ %.2f KB/s", bandwidthOut))

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
	return SHP.ColorizeText(rf, gf, bf, format("%.0f", fps))
end
