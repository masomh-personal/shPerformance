if not LibStub then
	error("shPerformance requires LibStub")
end

local addonName, ns = ...
ns.SHP = {}
local SHP = ns.SHP
SHP.ADDON_NAME = addonName
SHP.LDB = LibStub:GetLibrary("LibDataBroker-1.1")

local C_AddOns = C_AddOns
local CreateFrame = CreateFrame
local math_floor = math.floor
local math_min = math.min
local string_find = string.find
local string_format = string.format

SHP.FORMAT_STRINGS = {
	FPS_TEXT = "%s FPS",
	PERFORMANCE_TEXT = "%s | %s",
	ADDON_COUNTER_SINGLE = "|cffDAB024 %d)|r",
	ADDON_COUNTER_DOUBLE = "|cffDAB024%d)|r",
	ADDON_USAGE_HEADER = "USAGE (|cff06ddfaabove %sK|r)",
	ADDON_HIDDEN = "|cff06DDFA[%d] hidden addons|r (usage at or below %dK)",
	TOTAL_MEMORY = "→ |cff06ddfa%s|r",
}

SHP.CONFIG = {
	WANT_ALPHA_SORTING = false,
	UPDATE_PERIOD_TOOLTIP = 1.5,
	UPDATE_PERIOD_FPS_DATA_TEXT = 1.5,
	UPDATE_PERIOD_LATENCY_DATA_TEXT = 15, -- Blizzard's static default is 30; refresh every 15 for more responsive displays.
	MEM_THRESHOLD = 500, -- in KB (only will show addons that use >= this number)
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

-- 101 entries (1% precision); hex is cached so colorizing never formats at runtime.
local GRADIENT_TABLE = {}
local function InitializeGradientTable()
	local colors = SHP.CONFIG.GRADIENT_COLOR_SEQUENCE_TABLE
	local numSegments = #colors / 3 - 1

	for i = 0, 100 do
		local perc = i / 100
		local segment = math_min(numSegments - 1, math_floor(perc * numSegments))
		local segmentPerc = (perc * numSegments) - segment

		local idx = segment * 3
		local r = colors[idx + 1] + (colors[idx + 4] - colors[idx + 1]) * segmentPerc
		local g = colors[idx + 2] + (colors[idx + 5] - colors[idx + 2]) * segmentPerc
		local b = colors[idx + 3] + (colors[idx + 6] - colors[idx + 3]) * segmentPerc

		GRADIENT_TABLE[i] = {
			r = r,
			g = g,
			b = b,
			hex = string_format(
				"%02x%02x%02x",
				math_floor(r * 255 + 0.5),
				math_floor(g * 255 + 0.5),
				math_floor(b * 255 + 0.5)
			),
		}
	end
end
InitializeGradientTable()
SHP.GRADIENT_TABLE = GRADIENT_TABLE

SHP.ADDONS_TABLE = {}

-- Titles may embed color, texture, and atlas escapes that would otherwise dominate string ordering.
local function toSortKey(title)
	local plain = title
		:gsub("|c%x%x%x%x%x%x%x%x", "")
		:gsub("|cn[^:]*:", "")
		:gsub("|r", "")
		:gsub("|T.-|t", "")
		:gsub("|A.-|a", "")
	return plain:match("^%s*(.-)%s*$"):lower()
end

local function CreateAddonTable()
	for i = 1, C_AddOns.GetNumAddOns() do
		local name, title, _, loadable, reason, security = C_AddOns.GetAddOnInfo(i)

		-- Memory usage can only be queried safely for user-installed addons.
		if security == "INSECURE" and (loadable or reason == "DEMAND_LOADED") then
			local displayTitle = title or "Unknown Addon"
			local ADDONS_TABLE = SHP.ADDONS_TABLE
			ADDONS_TABLE[#ADDONS_TABLE + 1] = {
				name = name,
				title = displayTitle,
				colorizedTitle = string_find(displayTitle, "|cff") and displayTitle or "|cffffffff" .. displayTitle,
				sortKey = toSortKey(displayTitle),
				memory = 0,
				isLoaded = false,
			}
		end
	end
end

local loginFrame = CreateFrame("Frame")
loginFrame:RegisterEvent("PLAYER_LOGIN")
loginFrame:SetScript("OnEvent", function(self)
	self:UnregisterEvent("PLAYER_LOGIN")
	self:SetScript("OnEvent", nil)
	CreateAddonTable()
	SHP.StartFeeds()
end)
