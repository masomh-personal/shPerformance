local _, ns = ...
local SHP = ns.SHP

----------------------
--> Module Frames and Update Controllers
----------------------
local FRAME_FPS = CreateFrame("frame")

-- Adding one to update period to ensure first and immediate update
local elapsedFpsController = SHP.CONFIG.UPDATE_PERIOD_FPS_DATA_TEXT + 1
local elapsedLatencyController = SHP.CONFIG.UPDATE_PERIOD_LATENCY_DATA_TEXT + 1

-- Since we are using latency information, get it immediately b/c it won't be updated for 30 seconds in OnUpdateScript
local cachedLatencyText = "Initializing ms..."

local DATA_TEXT_FPS = SHP.LibStub:NewDataObject("shFps", {
	type = "data source",
	text = "Initializing (fps)",
	icon = SHP.CONFIG.FPS_ICON,
})

----------------------
--> Helper Functions
----------------------
-- Helper function to update data text for FPS display
local function updateDataText()
	local fpsText = SHP.UpdateFPSDataText()
	DATA_TEXT_FPS.text = SHP.string.format("%s | %s", fpsText, cachedLatencyText)
end

-- Helper function to update tooltip content
local function updateTooltipContent()
	SHP.GameTooltip:ClearLines()
	SHP.GameTooltip:AddLine("|cff0062ffsh|r|cff0DEB11Performance|r")
	SHP.GameTooltip:AddLine(SHP.CONFIG.SHOW_BOTH and "[Memory/Latency]" or "[Memory]")
	SHP.AddLineSeparatorToTooltip()
	SHP.AddNetworkStatsToTooltip()

	-- Add column headers and a separator line
	SHP.AddLineSeparatorToTooltip()
	SHP.GameTooltip:AddDoubleLine(
		"ADDON NAME",
		SHP.string.format("MEMORY USED (|cff06ddfaabove %sK|r)", SHP.CONFIG.MEM_THRESHOLD)
	)
	SHP.AddLineSeparatorToTooltip(true)

	-- Update memory usage for all addons in `SHP.ADDONS_TABLE` using the SHP method
	SHP.UpdateUserAddonMemoryUsageTable()

	-- Sort `SHP.ADDONS_TABLE` directly based on config
	if not SHP.CONFIG.WANT_ALPHA_SORTING then
		SHP.table.sort(SHP.ADDONS_TABLE, function(a, b)
			return a.memory > b.memory
		end)
	else
		SHP.table.sort(SHP.ADDONS_TABLE, function(a, b)
			return a.colorizedTitle:lower() < b.colorizedTitle:lower()
		end)
	end

	-- Display memory usage for each addon from `SHP.ADDONS_TABLE`
	local counter, hiddenAddonMemoryUsage = 0, 0
	local totalNumAddons, totalUserAddonMemoryUsage = #SHP.ADDONS_TABLE, 0
	for _, addon in ipairs(SHP.ADDONS_TABLE) do
		local colorizedTitle = addon.colorizedTitle
		local addonMemUsage = addon.memory
		totalUserAddonMemoryUsage = totalUserAddonMemoryUsage + addonMemUsage
		if addonMemUsage > SHP.CONFIG.MEM_THRESHOLD then
			counter = counter + 1
			-- Determine color gradient for memory usage and format string
			local r, g, b = SHP.GetColorFromGradientTable((addonMemUsage - SHP.CONFIG.MEM_THRESHOLD) / 15e3)
			local memStr = SHP.ColorizeText(r, g, b, SHP.FormatMemString(addonMemUsage))
			-- Format counter with padding for numbers under 10
			local counterText = counter < 10 and SHP.string.format("|cffDAB024 %d)|r", counter)
				or SHP.string.format("|cffDAB024%d)|r", counter)
			SHP.GameTooltip:AddDoubleLine(SHP.string.format("%s %s", counterText, colorizedTitle), memStr)
		else
			hiddenAddonMemoryUsage = hiddenAddonMemoryUsage + addonMemUsage
		end
	end

	-- Display summary for hidden addons if applicable
	if hiddenAddonMemoryUsage > 0 then
		SHP.GameTooltip:AddDoubleLine(
			SHP.string.format(
				"|cff06DDFA... [%d] hidden addons|r (usage less than %dK)",
				totalNumAddons - counter,
				SHP.CONFIG.MEM_THRESHOLD
			),
			" "
		)
	end

	-- Display total user addon memory usage
	SHP.GameTooltip:AddDoubleLine(" ", "|cffffffff——————|r")
	SHP.GameTooltip:AddDoubleLine(
		" ",
		SHP.string.format(
			"|cffC3771ATOTAL ADDON|r memory usage → |cff06ddfa%s|r",
			SHP.FormatMemString(totalUserAddonMemoryUsage)
		)
	)

	-- Display hint for forced garbage collection
	SHP.AddLineSeparatorToTooltip()
	SHP.GameTooltip:AddLine("→ *Click to force |cffc3771agarbage|r collection and to |cff06ddfaupdate|r tooltip*")
	SHP.GameTooltip:Show()
end

----------------------
--> Frame Scripts
----------------------
-- Update FPS data text in real time
FRAME_FPS:SetScript("OnUpdate", function(_, t)
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
DATA_TEXT_FPS.OnEnter = OnEnterFPS

-- Clear the `OnUpdate` handler when the tooltip is no longer hovered
local function OnLeaveFPS(self)
	SHP.HideTooltip()
	self:SetScript("OnUpdate", nil)
end
DATA_TEXT_FPS.OnLeave = OnLeaveFPS

-- OnClick handler for garbage collection
local function OnClickFPS()
	local preCollect = SHP.collectgarbage("count")
	SHP.collectgarbage("collect")
	local deltaMemCollected = preCollect - SHP.collectgarbage("count")

	-- Display the amount of memory collected
	print(
		SHP.string.format(
			"|cff0062ffsh|r|cff0DEB11Performance|r - Garbage Collected: |cff06ddfa%s|r",
			SHP.FormatMemString(deltaMemCollected, true)
		)
	)

	-- Update tooltip after garbage collected
	updateTooltipContent()
end
DATA_TEXT_FPS.OnClick = OnClickFPS
