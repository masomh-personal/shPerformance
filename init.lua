if not LibStub then
	error("shPerformance requires LibStub")
end

local _, ns = ...
ns.SHP = {}
local SHP = ns.SHP
SHP.LibStub = LibStub:GetLibrary("LibDataBroker-1.1")

-- ===================================================================================
-- OPTIMIZED: Localize all WoW API and Lua functions for performance
-- ===================================================================================
local GetFramerate = GetFramerate
local GetNetStats = GetNetStats
local GetNetIpTypes = GetNetIpTypes
local UpdateAddOnMemoryUsage = UpdateAddOnMemoryUsage
local GetAddOnMemoryUsage = GetAddOnMemoryUsage
local collectgarbage = collectgarbage
local GameTooltip = GameTooltip
local UIParent = UIParent
local CreateFrame = CreateFrame
local C_AddOns = C_AddOns
local C_CVar = C_CVar
local GetTime = GetTime
local unpack = unpack
local ipairs = ipairs
local pairs = pairs
local tonumber = tonumber
local tostring = tostring

-- Lua standard library localizations
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local string_format = string.format
local string_lower = string.lower
local string_find = string.find
local table_insert = table.insert
local table_sort = table.sort

-- ===================================================================================
-- OPTIMIZED: Pre-cached format strings to avoid runtime string building
-- ===================================================================================
local FORMAT_STRINGS = {
	FPS = "%.0f",
	FPS_TEXT = "%s FPS",
	LATENCY = "%.0f",
	LATENCY_WORLD = "%.0f (world)",
	LATENCY_COMBINED = "%s → %s",
	MEMORY_KB = "%.2fK",
	MEMORY_MB = "%.2fM",
	MEMORY_COLORED_KB = "%.2f|cffE8D200K|r",
	MEMORY_COLORED_MB = "%.2f|cffE8D200M|r",
	BANDWIDTH_IN = "▼ %.2f KB/s",
	BANDWIDTH_OUT = "▲ %.2f KB/s",
	LATENCY_MS = "%.0f ms",
	PERFORMANCE_TEXT = "%s | %s",
	ADDON_COUNTER_SINGLE = "|cffDAB024 %d)|r",
	ADDON_COUNTER_DOUBLE = "|cffDAB024%d)|r",
	ADDON_USAGE_HEADER = "USAGE (|cff06ddfaabove %sK|r)",
	ADDON_HIDDEN = "|cff06DDFA[%d] hidden addons|r (usage less than %dK)",
	TOTAL_MEMORY = "→ |cff06ddfa%s|r",
	COLOR_WRAP = "|cff%s%s|r",
	HEX_FORMAT = "%02x%02x%02x",
	IP_TYPE_FORMAT = "%s (%s)",
	LATENCY_LABEL_HOME = "|cff%s%s|r |cffFFFFFFlatency:|r",
	LATENCY_LABEL_WORLD = "|cff%s%s|r |cffFFFFFFlatency:|r",
}

SHP.CONFIG = {
	WANT_ALPHA_SORTING = false,
	UPDATE_PERIOD_TOOLTIP = 1.5,
	UPDATE_PERIOD_FPS_DATA_TEXT = 1.5,
	UPDATE_PERIOD_LATENCY_DATA_TEXT = 15, -- Static default by Blizzad is 30 (lets do it every 15 for good measure)
	MEM_THRESHOLD = 500, -- in KB (only will show addons that use >= this number)
	SHOW_BOTH = true,
	FPS_GRADIENT_THRESHOLD = 75,
	MS_GRADIENT_THRESHOLD = 300,
	MEM_GRADIENT_THRESHOLD_MAX = 30e3,
	BANDWIDTH_INCOMING_GRADIENT_THRESHOLD = 20,
	BANDWIDTH_OUTGOING_GRADIENT_THRESHOLD = 5,
	-- True RGB gradient: green -> yellow -> red
	-- Starts with green, transitions through yellow, and ends at red (0.95, 0, 0).
	-- This sequence provides a high-contrast gradient for maximum readability and color intensity.
	GRADIENT_COLOR_SEQUENCE_TABLE = { 0, 0.97, 0, 0.97, 0.97, 0, 0.95, 0, 0 },
	FPS_ICON = "Interface\\AddOns\\shPerformance\\media\\fpsicon",
	MS_ICON = "Interface\\AddOns\\shPerformance\\media\\msicon",
}

-- Export localized functions to SHP namespace
SHP.math = {
	floor = math_floor,
	max = math_max,
	min = math_min,
}

SHP.string = {
	format = string_format,
	lower = string_lower,
	find = string_find,
}

SHP.table = {
	insert = table_insert,
	sort = table_sort,
}

SHP.GameTooltip = GameTooltip
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
SHP.GetTime = GetTime

-- Store format strings for global access
SHP.FORMAT_STRINGS = FORMAT_STRINGS

-- ===================================================================================
-- OPTIMIZED: Pre-computed gradient table for faster color lookups
-- ===================================================================================
local GRADIENT_TABLE = {}
local function InitializeGradientTable()
	local colors = SHP.CONFIG.GRADIENT_COLOR_SEQUENCE_TABLE
	local numSegments = #colors / 3 - 1
	
	for i = 0, 100 do  -- 1% precision is sufficient
		local perc = i / 100
		local segment = math_min(numSegments - 1, math_floor(perc * numSegments))
		local segmentPerc = (perc * numSegments) - segment
		
		local idx = segment * 3
		local r = colors[idx + 1] + (colors[idx + 4] - colors[idx + 1]) * segmentPerc
		local g = colors[idx + 2] + (colors[idx + 5] - colors[idx + 2]) * segmentPerc
		local b = colors[idx + 3] + (colors[idx + 6] - colors[idx + 3]) * segmentPerc
		
		-- Pre-compute hex strings for efficiency
		GRADIENT_TABLE[i] = {
			r = r,
			g = g, 
			b = b,
			hex = string_format(FORMAT_STRINGS.HEX_FORMAT, r * 255, g * 255, b * 255)
		}
	end
end
SHP.GRADIENT_TABLE = GRADIENT_TABLE

-- Initialize `SHP.ADDONS_TABLE` as an array-style table
SHP.ADDONS_TABLE = {}

-- Function to create `SHP.ADDONS_TABLE` once at player login
local function CreateAddonTable()
	local numAddOns = SHP.GetNumAddOns()

	for i = 1, numAddOns do
		local name, title, _, loadable, reason = SHP.GetAddOnInfo(i)

		-- Only add addons that are loadable or load on demand
		if loadable or reason == "DEMAND_LOADED" then
			local colorizedTitle
			if title then
				colorizedTitle = string_find(title, "|cff") and title or "|cffffffff" .. title
			else
				colorizedTitle = "|cffffffffUnknown Addon"
			end
			
			table_insert(SHP.ADDONS_TABLE, {
				name = name,
				index = i, -- Store the addon's index for easy reference later if needed
				title = title or "Unknown Addon",
				colorizedTitle = colorizedTitle,
				memory = 0, -- Default memory usage, to be updated later
			})
		end
	end
end

-- Initialize `SHP.ADDONS_TABLE` and create addon table once player logs in
local gFrame = CreateFrame("Frame")
gFrame:RegisterEvent("PLAYER_LOGIN")
gFrame:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_LOGIN" then
		-- Populate the addons table only once on login
		CreateAddonTable()
		InitializeGradientTable()
		self:UnregisterEvent("PLAYER_LOGIN")
		self:SetScript("OnEvent", nil)
	end
end)
