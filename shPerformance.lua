local _, ns = ...
local SHP = ns.SHP

-- Cache frequently used functions for performance
local format = SHP.format or string.format
local sort = SHP.sort or table.sort
local ipairs = SHP.ipairs or ipairs
local floor = SHP.floor or math.floor
local GetTime = GetTime

----------------------
--> Module Frames and Update Controllers
----------------------
local FRAME_PERFORMANCE = CreateFrame("frame")

-- Cache update periods for better performance
local UPDATE_PERIOD_FPS = SHP.CONFIG.UPDATE_PERIOD_FPS_DATA_TEXT
local UPDATE_PERIOD_LATENCY = SHP.CONFIG.UPDATE_PERIOD_LATENCY_DATA_TEXT
local UPDATE_PERIOD_TOOLTIP = SHP.CONFIG.UPDATE_PERIOD_TOOLTIP

-- Use GetTime() for more accurate timing
local nextFpsUpdate = 0
local nextLatencyUpdate = 0
local nextTooltipUpdate = 0

-- Cache frequently accessed data
local cachedLatencyText = "Initializing ms..."
local cachedFpsText = "Initializing..."
local tooltipOwner = nil

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
	cachedFpsText = SHP.UpdateFPSDataText()
	DATA_TEXT_PERFORMANCE.text = format("%s | %s", cachedFpsText, cachedLatencyText)
end

-- Optimized sorting function with cached comparison
local memoryComparison, alphaComparison
memoryComparison = function(a, b)
	return a.memory > b.memory
end
alphaComparison = function(a, b)
	return a.colorizedTitle:lower() < b.colorizedTitle:lower()
end

-- Sorts the addons table based on memory usage or alphabetically if configured.
local function sortAddonMemoryTable()
	sort(SHP.ADDONS_TABLE, SHP.CONFIG.WANT_ALPHA_SORTING and alphaComparison or memoryComparison)
end

-- Optimized memory usage details function
local function addMemoryUsageDetailsToTooltip()
	local counter, hiddenAddonMemoryUsage, shownAddonMemoryUsage = 0, 0, 0
	local addonsTable = SHP.ADDONS_TABLE
	local threshold = SHP.CONFIG.MEM_THRESHOLD
	local maxThreshold = SHP.CONFIG.MEM_GRADIENT_THRESHOLD_MAX
	local minThreshold = 1e3 -- 1 KB in bytes

	-- Pre-calculate gradient range
	local gradientRange = maxThreshold - minThreshold

	for i = 1, #addonsTable do
		local addon = addonsTable[i]
		local addonMemUsage = addon.memory
		shownAddonMemoryUsage = shownAddonMemoryUsage + addonMemUsage

		-- Check if addon exceeds memory threshold
		if addonMemUsage > threshold then
			counter = counter + 1

			-- Calculate proportion for gradient color based on memory usage
			local proportion = (addonMemUsage - minThreshold) / gradientRange
			local r, g, b = SHP.GetColorFromGradientTable(proportion)

			-- Format memory usage string with color
			local memStr = SHP.ColorizeText(r, g, b, SHP.FormatMemString(addonMemUsage))

			-- Format and display addon counter with color
			local counterText = counter < 10 and format("|cffDAB024 %d)|r", counter)
				or format("|cffDAB024%d)|r", counter)
			SHP.GameTooltip:AddDoubleLine(format("%s %s", counterText, addon.colorizedTitle), memStr)
		else
			-- Accumulate memory usage for addons below threshold
			hiddenAddonMemoryUsage = hiddenAddonMemoryUsage + addonMemUsage
		end
	end

	-- Display total user addon memory usage
	SHP.AddLineSeparatorToTooltip(true)
	SHP.GameTooltip:AddDoubleLine(
		"|cffC3771ATOTAL ADDON|r memory usage",
		format("→ |cff06ddfa%s|r", SHP.FormatMemString(shownAddonMemoryUsage + hiddenAddonMemoryUsage))
	)

	if hiddenAddonMemoryUsage > 0 then
		SHP.AddLineSeparatorToTooltip()
		SHP.GameTooltip:AddDoubleLine(
			format("|cff06DDFA[%d] hidden addons|r (usage less than %dK)", #addonsTable - counter, threshold),
			" "
		)
	end

	-- Display hint for forced garbage collection
	SHP.GameTooltip:AddLine("**Click to force |cffc3771agarbage|r collection and to |cff06ddfaupdate|r tooltip")
	SHP.GameTooltip:Show()
end

-- Helper function to update tooltip content
local function updateTooltipContent()
	SHP.GameTooltip:ClearLines()
	SHP.GameTooltip:AddLine("|cff0062ffsh|r|cff0DEB11Performance|r")
	SHP.GameTooltip:AddLine("[Latency + Memory]")
	SHP.AddLineSeparatorToTooltip()
	SHP.AddNetworkStatsToTooltip()

	-- Add column headers and a separator line
	SHP.AddLineSeparatorToTooltip()
	SHP.GameTooltip:AddDoubleLine("ADDON", format("USAGE (|cff06ddfaabove %sK|r)", SHP.CONFIG.MEM_THRESHOLD))
	SHP.AddLineSeparatorToTooltip(true)

	-- Update memory usage for all addons in `SHP.ADDONS_TABLE` using the SHP method
	SHP.UpdateUserAddonMemoryUsageTable()

	-- Sort `SHP.ADDONS_TABLE` directly based on config
	sortAddonMemoryTable()

	-- Display memory usage for each addon from `SHP.ADDONS_TABLE`
	addMemoryUsageDetailsToTooltip()
end

----------------------
--> Optimized Single OnUpdate Handler
----------------------
-- Single OnUpdate handler for all updates
local function OnUpdateHandler(self, elapsed)
	local currentTime = GetTime()

	-- Update latency text
	if currentTime >= nextLatencyUpdate then
		nextLatencyUpdate = currentTime + UPDATE_PERIOD_LATENCY
		cachedLatencyText = SHP.UpdateLatencyDataText()
	end

	-- Update FPS text
	if currentTime >= nextFpsUpdate then
		nextFpsUpdate = currentTime + UPDATE_PERIOD_FPS
		updateDataText()
	end

	-- Update tooltip if visible
	if tooltipOwner and currentTime >= nextTooltipUpdate then
		nextTooltipUpdate = currentTime + UPDATE_PERIOD_TOOLTIP
		updateTooltipContent()
	end
end

-- Set the single OnUpdate handler
FRAME_PERFORMANCE:SetScript("OnUpdate", OnUpdateHandler)

----------------------
--> Event Handlers
----------------------
-- Use helper function in OnEnter to update tooltip in real time
local function OnEnterFPS(self)
	SHP.GameTooltip:SetOwner(self, "ANCHOR_NONE")
	SHP.GameTooltip:SetPoint(SHP.GetTipAnchor(self))
	tooltipOwner = self
	nextTooltipUpdate = 0 -- Force immediate update
	updateTooltipContent() -- Initial call to display tooltip content
end
DATA_TEXT_PERFORMANCE.OnEnter = OnEnterFPS

-- Clear the tooltip owner when the tooltip is no longer hovered
local function OnLeaveFPS(self)
	SHP.HideTooltip()
	tooltipOwner = nil
end
DATA_TEXT_PERFORMANCE.OnLeave = OnLeaveFPS

-- OnClick handler for garbage collection
local function OnClickFPS()
	local preCollect = SHP.collectgarbage("count")
	SHP.collectgarbage("collect")
	local deltaMemCollected = preCollect - SHP.collectgarbage("count")

	-- Display the amount of memory collected
	print(
		format(
			"|cff0062ffsh|r|cff0DEB11Performance|r - Garbage Collected: |cff06ddfa%s|r",
			SHP.FormatMemString(deltaMemCollected, true)
		)
	)

	-- Update tooltip after garbage collected
	if tooltipOwner then
		updateTooltipContent()
	end
end
DATA_TEXT_PERFORMANCE.OnClick = OnClickFPS
