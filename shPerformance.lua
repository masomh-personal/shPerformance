local _, ns = ...
local SHP = ns.SHP

-- Cache frequently used functions for performance
local format = string.format
local sort = table.sort
local ipairs = ipairs

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
	DATA_TEXT_PERFORMANCE.text = format("%s | %s", fpsText, cachedLatencyText)
end

-- Sorts the addons table based on memory usage or alphabetically if configured.
local function sortAddonMemoryTable()
	if not SHP.CONFIG.WANT_ALPHA_SORTING then
		sort(SHP.ADDONS_TABLE, function(a, b)
			return a.memory > b.memory
		end)
	else
		sort(SHP.ADDONS_TABLE, function(a, b)
			return a.colorizedTitle:lower() < b.colorizedTitle:lower()
		end)
	end
end

--[[ 
    Adds formatted addon memory usage details to the tooltip.
]]
local function addMemoryUsageDetailsToTooltip()
	local counter, hiddenAddonMemoryUsage, shownAddonMemoryUsage = 0, 0, 0

	for _, addon in ipairs(SHP.ADDONS_TABLE) do
		local addonMemUsage = addon.memory
		shownAddonMemoryUsage = shownAddonMemoryUsage + addonMemUsage

		-- Check if addon exceeds memory threshold or is 'shPerformance'
		if addonMemUsage > SHP.CONFIG.MEM_THRESHOLD then
			counter = counter + 1

			-- Set min and max thresholds for memory gradient (1 KB to 100 MB)
			local minThreshold = 1e3 -- 1 KB in bytes
			local maxThreshold = SHP.CONFIG.MEM_GRADIENT_THRESHOLD_MAX -- 100 MB in bytes

			-- Calculate proportion for gradient color based on memory usage
			local proportion = (addonMemUsage - minThreshold) / (maxThreshold - minThreshold)
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
	--SHP.GameTooltip:AddDoubleLine(" ", "|cffffffff————|r")
	SHP.AddLineSeparatorToTooltip(true)
	SHP.GameTooltip:AddDoubleLine(
		"|cffC3771ATOTAL ADDON|r memory usage",
		format("→ |cff06ddfa%s|r", SHP.FormatMemString(shownAddonMemoryUsage + hiddenAddonMemoryUsage))
	)

	if hiddenAddonMemoryUsage > 0 then
		SHP.AddLineSeparatorToTooltip()
		SHP.GameTooltip:AddDoubleLine(
			format(
				"|cff06DDFA[%d] hidden addons|r (usage less than %dK)",
				#SHP.ADDONS_TABLE - counter,
				SHP.CONFIG.MEM_THRESHOLD
			),
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
--> Frame Scripts
----------------------
-- Update FPS data text in real time
FRAME_PERFORMANCE:SetScript("OnUpdate", function(_, t)
	elapsedFpsController = elapsedFpsController + t
	elapsedLatencyController = elapsedLatencyController + t

	-- Update latency text every 30 seconds only due to Blizzard limitations
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

-- Use helper function in OnEnter to update tooltip in real time
local function OnEnterFPS(self)
	SHP.GameTooltip:SetOwner(self, "ANCHOR_NONE")
	SHP.GameTooltip:SetPoint(SHP.GetTipAnchor(self))
	updateTooltipContent() -- Initial call to display tooltip content

	-- Set up OnUpdate to refresh tooltip content in real time while hovered
	local elapsed = 0
	self:SetScript("OnUpdate", function(_, t)
		elapsed = elapsed + t
		if elapsed >= SHP.CONFIG.UPDATE_PERIOD_TOOLTIP then
			elapsed = 0
			updateTooltipContent() -- Refresh tooltip content
		end
	end)
end
DATA_TEXT_PERFORMANCE.OnEnter = OnEnterFPS

-- Clear the `OnUpdate` handler when the tooltip is no longer hovered
local function OnLeaveFPS(self)
	SHP.HideTooltip()
	self:SetScript("OnUpdate", nil)
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
	updateTooltipContent()
end
DATA_TEXT_PERFORMANCE.OnClick = OnClickFPS
