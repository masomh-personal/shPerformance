local _, ns = ...
local SHP = ns.SHP

-- ===================================================================================
-- OPTIMIZED: Localize frequently used functions
-- ===================================================================================
local CreateFrame = CreateFrame
local ipairs = ipairs
local string_format = SHP.string.format
local print = print

local GameTooltip = SHP.GameTooltip
local FORMAT_STRINGS = SHP.FORMAT_STRINGS

----------------------
--> Module Frames and Update Controllers
----------------------
local FRAME_PERFORMANCE = CreateFrame("frame")

-- Adding one to update period to ensure first and immediate update
local elapsedFpsController = SHP.CONFIG.UPDATE_PERIOD_FPS_DATA_TEXT + 1
local elapsedLatencyController = SHP.CONFIG.UPDATE_PERIOD_LATENCY_DATA_TEXT + 1

-- Since we are using latency information, get it immediately b/c it won't be updated for 30 seconds in OnUpdateScript
local cachedLatencyText = "Initializing ms..."

local DATA_TEXT_PERFORMANCE = SHP.LibStub:NewDataObject("shPerformance", {
	type = "data source",
	text = "Initializing...",
	icon = SHP.CONFIG.FPS_ICON,
})

----------------------
--> Helper Functions
----------------------
-- Helper function to update data text for FPS display
local function updateDataText()
	local fpsText = SHP.UpdateFPSDataText()
	DATA_TEXT_PERFORMANCE.text = string_format(FORMAT_STRINGS.PERFORMANCE_TEXT, fpsText, cachedLatencyText)
end

-- Sorts the addons table based on memory usage or alphabetically if configured.
local function sortAddonMemoryTable()
	if not SHP.CONFIG.WANT_ALPHA_SORTING then
		SHP.table.sort(SHP.ADDONS_TABLE, function(a, b)
			return a.memory > b.memory
		end)
	else
		SHP.table.sort(SHP.ADDONS_TABLE, function(a, b)
			return a.colorizedTitle:lower() < b.colorizedTitle:lower()
		end)
	end
end

--[[
    Adds formatted addon memory usage details to the tooltip.
]]
local function addMemoryUsageDetailsToTooltip()
	local counter, hiddenAddonMemoryUsage, totalAddonMemoryUsage = 0, 0, 0

	for _, addon in ipairs(SHP.ADDONS_TABLE) do
		local addonMemUsage = addon.memory
		totalAddonMemoryUsage = totalAddonMemoryUsage + addonMemUsage

		-- Check if addon exceeds memory threshold or is 'shPerformance'
		if addonMemUsage > SHP.CONFIG.MEM_THRESHOLD then
			counter = counter + 1

			-- WoW reports addon memory in KB; color the gradient from 1 MB to the configured max.
			local minThreshold = 1e3 -- 1 MB in KB
			local maxThreshold = SHP.CONFIG.MEM_GRADIENT_THRESHOLD_MAX -- 30 MB in KB by default

			-- Calculate proportion for gradient color based on memory usage
			local proportion = (addonMemUsage - minThreshold) / (maxThreshold - minThreshold)
			local r, g, b = SHP.GetColorFromGradientTable(proportion)

			-- Format memory usage string with color
			local memStr = SHP.ColorizeText(r, g, b, SHP.FormatMemString(addonMemUsage))

			-- Format and display addon counter with color
			local counterText = counter < 10 and string_format(FORMAT_STRINGS.ADDON_COUNTER_SINGLE, counter)
				or string_format(FORMAT_STRINGS.ADDON_COUNTER_DOUBLE, counter)
			GameTooltip:AddDoubleLine(string_format("%s %s", counterText, addon.colorizedTitle), memStr)
		else
			-- Accumulate memory usage for addons below threshold
			hiddenAddonMemoryUsage = hiddenAddonMemoryUsage + addonMemUsage
		end
	end

	-- Display total user addon memory usage
	--SHP.GameTooltip:AddDoubleLine(" ", "|cffffffff————|r")
	SHP.AddLineSeparatorToTooltip(true)
	GameTooltip:AddDoubleLine(
		"|cffC3771ATOTAL ADDON|r memory usage",
		string_format(FORMAT_STRINGS.TOTAL_MEMORY, SHP.FormatMemString(totalAddonMemoryUsage))
	)

	if hiddenAddonMemoryUsage > 0 then
		SHP.AddLineSeparatorToTooltip()
		GameTooltip:AddDoubleLine(
			string_format(
				FORMAT_STRINGS.ADDON_HIDDEN,
				#SHP.ADDONS_TABLE - counter,
				SHP.CONFIG.MEM_THRESHOLD
			),
			" "
		)
	end

	-- Display hint for forced garbage collection
	GameTooltip:AddLine("**Click to force |cffc3771agarbage|r collection and to |cff06ddfaupdate|r tooltip")
	GameTooltip:Show()
end

-- Helper function to update tooltip content
local function updateTooltipContent()
	GameTooltip:ClearLines()
	GameTooltip:AddLine("|cff0062ffsh|r|cff0DEB11Performance|r")
	GameTooltip:AddLine("[Latency + Memory]")
	SHP.AddLineSeparatorToTooltip()
	SHP.AddNetworkStatsToTooltip()

	-- Add column headers and a separator line
	SHP.AddLineSeparatorToTooltip()
	GameTooltip:AddDoubleLine("ADDON", string_format(FORMAT_STRINGS.ADDON_USAGE_HEADER, SHP.CONFIG.MEM_THRESHOLD))
	SHP.AddLineSeparatorToTooltip(true)

	-- Update memory usage for all addons in `SHP.ADDONS_TABLE` using the SHP method
	SHP.UpdateUserAddonMemoryUsageTable()

	-- Sort `SHP.ADDONS_TABLE` directly based on config
	sortAddonMemoryTable()

	-- Display memory usage for each addon from `SHP.ADDONS_TABLE`
	addMemoryUsageDetailsToTooltip()
end

----------------------
--> Frame Scripts
----------------------
-- Update FPS data text in real time
FRAME_PERFORMANCE:SetScript("OnUpdate", function(_, t)
	elapsedFpsController = elapsedFpsController + t
	elapsedLatencyController = elapsedLatencyController + t

	-- Update latency text on the configured slower interval due to Blizzard's own network stat cadence.
	if elapsedLatencyController >= SHP.CONFIG.UPDATE_PERIOD_LATENCY_DATA_TEXT then
		elapsedLatencyController = 0
		cachedLatencyText = SHP.UpdateLatencyDataText()
	end

	-- Update FPS text based on config and independent of latency updates
	if elapsedFpsController >= SHP.CONFIG.UPDATE_PERIOD_FPS_DATA_TEXT then
		elapsedFpsController = 0
		updateDataText()
	end
end)

SHP.AttachTooltipHandlers(DATA_TEXT_PERFORMANCE, updateTooltipContent)

-- OnClick handler for garbage collection
local function OnClickFPS()
	local preCollect = SHP.collectgarbage("count")
	SHP.collectgarbage("collect")
	local deltaMemCollected = preCollect - SHP.collectgarbage("count")

	-- Display the amount of memory collected
	print(
		string_format(
			"|cff0062ffsh|r|cff0DEB11Performance|r - Garbage Collected: |cff06ddfa%s|r",
			SHP.FormatMemString(deltaMemCollected, true)
		)
	)

	-- Update tooltip after garbage collected
	updateTooltipContent()
end
DATA_TEXT_PERFORMANCE.OnClick = OnClickFPS
