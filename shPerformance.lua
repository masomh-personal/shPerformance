local _, ns = ...
local SHP = ns.SHP

local GameTooltip = GameTooltip
local InCombatLockdown = InCombatLockdown
local collectgarbage = collectgarbage
local ipairs = ipairs
local print = print
local string_format = string.format
local table_sort = table.sort

local CONFIG = SHP.CONFIG
local FORMAT_STRINGS = SHP.FORMAT_STRINGS
local ADDONS_TABLE = SHP.ADDONS_TABLE
local CHAT_PREFIX = "|cff0062ffsh|r|cff0DEB11Performance|r"
local MEM_GRADIENT_MIN = 1024 -- 1 MB in KB; memory at or below this is fully green

local cachedLatencyText = "Initializing ms..."

local DATA_TEXT_PERFORMANCE = SHP.LDB:NewDataObject("shPerformance", {
	type = "data source",
	text = "Initializing...",
	icon = CONFIG.FPS_ICON,
})

SHP.OnLatencyUpdate(function(latencyText)
	cachedLatencyText = latencyText
end)

SHP.OnFpsUpdate(function(fpsText)
	DATA_TEXT_PERFORMANCE.text = string_format(FORMAT_STRINGS.PERFORMANCE_TEXT, fpsText, cachedLatencyText)
end)

local function byMemoryDescending(a, b)
	return a.memory > b.memory
end

local function byTitle(a, b)
	return a.sortKey < b.sortKey
end

local function addMemoryUsageDetailsToTooltip()
	local counter, hiddenCount, hiddenAddonMemoryUsage, totalAddonMemoryUsage = 0, 0, 0, 0
	local memGradientRange = CONFIG.MEM_GRADIENT_THRESHOLD_MAX - MEM_GRADIENT_MIN

	for _, addon in ipairs(ADDONS_TABLE) do
		local addonMemUsage = addon.memory
		totalAddonMemoryUsage = totalAddonMemoryUsage + addonMemUsage

		if addonMemUsage > CONFIG.MEM_THRESHOLD then
			counter = counter + 1

			local memStr = SHP.ColorizeByProportion(
				(addonMemUsage - MEM_GRADIENT_MIN) / memGradientRange,
				SHP.FormatMemString(addonMemUsage)
			)
			local counterFormat = counter < 10 and FORMAT_STRINGS.ADDON_COUNTER_SINGLE
				or FORMAT_STRINGS.ADDON_COUNTER_DOUBLE
			GameTooltip:AddDoubleLine(
				string_format("%s %s", string_format(counterFormat, counter), addon.colorizedTitle),
				memStr
			)
		elseif addon.isLoaded then
			hiddenCount = hiddenCount + 1
			hiddenAddonMemoryUsage = hiddenAddonMemoryUsage + addonMemUsage
		end
	end

	SHP.AddLineSeparatorToTooltip(true)
	GameTooltip:AddDoubleLine(
		"|cffC3771ATOTAL ADDON|r memory usage",
		string_format(FORMAT_STRINGS.TOTAL_MEMORY, SHP.FormatMemString(totalAddonMemoryUsage))
	)

	if hiddenAddonMemoryUsage > 0 then
		SHP.AddLineSeparatorToTooltip()
		GameTooltip:AddDoubleLine(string_format(FORMAT_STRINGS.ADDON_HIDDEN, hiddenCount, CONFIG.MEM_THRESHOLD), " ")
	end

	GameTooltip:AddLine("**Click to force |cffc3771agarbage|r collection (out of combat) and to |cff06ddfaupdate|r tooltip")
	GameTooltip:Show()
end

local function updateTooltipContent()
	GameTooltip:ClearLines()
	GameTooltip:AddLine("|cff0062ffsh|r|cff0DEB11Performance|r")
	GameTooltip:AddLine("[Latency + Memory]")
	SHP.AddLineSeparatorToTooltip()
	SHP.AddNetworkStatsToTooltip()

	SHP.AddLineSeparatorToTooltip()
	GameTooltip:AddDoubleLine("ADDON", string_format(FORMAT_STRINGS.ADDON_USAGE_HEADER, CONFIG.MEM_THRESHOLD))
	SHP.AddLineSeparatorToTooltip(true)

	SHP.UpdateUserAddonMemoryUsageTable()
	table_sort(ADDONS_TABLE, CONFIG.WANT_ALPHA_SORTING and byTitle or byMemoryDescending)
	addMemoryUsageDetailsToTooltip()
end

SHP.AttachTooltipHandlers(DATA_TEXT_PERFORMANCE, updateTooltipContent)

DATA_TEXT_PERFORMANCE.OnClick = function(frame)
	-- A full collection stalls the client until it finishes; never do that mid-fight.
	if InCombatLockdown() then
		print(CHAT_PREFIX .. " - Garbage collection skipped while in combat.")
		return
	end

	local preCollect = collectgarbage("count")
	collectgarbage("collect")
	local deltaMemCollected = preCollect - collectgarbage("count")

	print(
		string_format(
			"%s - Garbage Collected: |cff06ddfa%s|r",
			CHAT_PREFIX,
			SHP.FormatMemString(deltaMemCollected, true)
		)
	)

	if GameTooltip:IsOwned(frame) then
		updateTooltipContent()
	end
end
