if not LibStub then
	error("shPerformance requires LibStub")
end

local _, ns = ...
ns.SHP = {}
local SHP = ns.SHP
SHP.LibStub = LibStub:GetLibrary("LibDataBroker-1.1")

SHP.CONFIG = {
	WANT_ALPHA_SORTING = false,
	WANT_COLORING = false,
	UPDATE_PERIOD_TOOLTIP = 2,
	UPDATE_PERIOD_FPS_DATA_TEXT = 1.5,
	UPDATE_PERIOD_LATENCY_DATA_TEXT = 30, -- Static default by blizzard
	MEM_THRESHOLD = 100, -- in KB (only will show addons that use >= this number)
	SHOW_BOTH = true,
	FPS_GRADIENT_THRESHOLD = 75,
	MS_GRADIENT_THRESHOLD = 300,
	MEM_GRADIENT_THRESHOLD_MAX = 25E3, -- Maximum memory usage (25,000 KB)
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

-- Initialize `SHP.ADDONS_TABLE` and creat addon table once player logs in
local gFrame = CreateFrame("Frame")
gFrame:RegisterEvent("PLAYER_LOGIN")
gFrame:SetScript("OnEvent", function()
	-- Populate the addons table only once on login
	CreateAddonTable()
end)
