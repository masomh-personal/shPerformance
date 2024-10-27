local _, ns = ...
local SHP = ns.SHP

-- Tooltip variables
local GameTooltip = GameTooltip
local tipshownMem, tipshownLatency
local prevmem = SHP.collectgarbage("count") -- Initialize memory tracking

----------------------
--> MODULES AND FRAMES
----------------------
local ffps = CreateFrame("frame")
local flatency = CreateFrame("frame")
local lib = LibStub:GetLibrary("LibDataBroker-1.1")

local datafps = lib:NewDataObject("shFps", {
	type = "data source",
	text = "Initializing (fps)",
	icon = SHP.config.FPS_ICON,
})
local datalatency = lib:NewDataObject("shLatency", {
	type = "data source",
	text = "Initializing (ms)",
	icon = SHP.config.MS_ICON,
})

----------------------
--> ONUPDATE HANDLERS
----------------------

-- FPS OnUpdate script
local elapsedFpsController = -10
ffps:SetScript("OnUpdate", function(self, t)
	elapsedFpsController = elapsedFpsController - t
	if elapsedFpsController < 0 then
		if tipshownMem and not SHP.IsAddOnLoaded("shMem") then
			datafps.OnEnter(tipshownMem)
		end

		local fps = SHP.GetFramerate()
		local rf, gf, bf = SHP.GetFPSColor(fps)

		if SHP.config.SHOW_BOTH then
			local _, _, lh, lw = SHP.GetNetStats()
			local rl, gl, bl = SHP.GetColorFromGradientTable(((lh + lw) / 2) / SHP.config.MS_GRADIENT_THRESHOLD)
			datafps.text = format(
				"|cff%02x%02x%02x%.0f|r | |cff%02x%02x%02x%.0f|r",
				rf * 255,
				gf * 255,
				bf * 255,
				fps,
				rl * 255,
				gl * 255,
				bl * 255,
				lw
			)
		else
			datafps.text = format("|cff%02x%02x%02x%.0f|r |cffE8D200fps|r", rf * 255, gf * 255, bf * 255, fps)
		end

		elapsedFpsController = SHP.config.UPDATE_PERIOD
	end
end)

-- Latency OnUpdate script
local elapsedLatencyController = -10
flatency:SetScript("OnUpdate", function(self, t)
	elapsedLatencyController = elapsedLatencyController - t
	if elapsedLatencyController < 0 then
		if tipshownLatency then
			datalatency.OnEnter(tipshownLatency)
		end

		local _, _, lh, lw = SHP.GetNetStats()
		local r, g, b = SHP.GetColorFromGradientTable(((lh + lw) / 2) / SHP.config.MS_GRADIENT_THRESHOLD)
		datalatency.text = format("|cff%02x%02x%02x%.0f/%.0f(w)|r |cffE8D200ms|r", r * 255, g * 255, b * 255, lh, lw)
		elapsedLatencyController = SHP.config.UPDATE_PERIOD + 20
	end
end)

----------------------
--> ONLEAVE FUNCTIONS
----------------------

if not SHP.IsAddOnLoaded("shMem") then
	local function OnLeaveFPS()
		GameTooltip:SetClampedToScreen(true)
		GameTooltip:Hide()
		tipshownMem = nil
	end
	datafps.OnLeave = OnLeaveFPS
end

local function OnLeaveLatency()
	GameTooltip:SetClampedToScreen(true)
	GameTooltip:Hide()
	tipshownLatency = nil
end
datalatency.OnLeave = OnLeaveLatency

----------------------
--> ONENTER FUNCTIONS
----------------------

local function OnEnterLatency(self)
	tipshownLatency = self
	GameTooltip:SetOwner(self, "ANCHOR_NONE")
	GameTooltip:SetPoint(SHP.GetTipAnchor(self))
	GameTooltip:ClearLines()

	GameTooltip:AddLine("|cff0062ffsh|r|cff0DEB11Latency|r")
	GameTooltip:AddLine("[Bandwidth/Latency]")
	GameTooltip:AddLine(
		format("|cffc3771aDataBroker|r addon shows latency updated every |cff06DDFA%s second(s)|r!\n", 30)
	)

	local binz, boutz, l, w = SHP.GetNetStats()
	local rin, gin, bins = SHP.GetColorFromGradientTable(binz / 20)
	local rout, gout, bout = SHP.GetColorFromGradientTable(boutz / 5)
	local r, g, b = SHP.GetColorFromGradientTable(((l + w) / 2) / SHP.config.MS_GRADIENT_THRESHOLD)

	GameTooltip:AddDoubleLine("Realm latency:", format("%.0f ms", l), r, g, b)
	GameTooltip:AddDoubleLine("Server latency:", format("%.0f ms", w), r, g, b)
	GameTooltip:AddLine(" ")
	GameTooltip:AddDoubleLine("Incoming bandwidth:", format("%.2f kb/sec", binz), rin, gin, bins)
	GameTooltip:AddDoubleLine("Outgoing bandwidth:", format("%.2f kb/sec", boutz), rout, gout, bout)
	GameTooltip:Show()
	elapsedLatencyController = -10
end
datalatency.OnEnter = OnEnterLatency

local function OnClickLatency()
	return
end
datalatency.OnClick = OnClickLatency

if not SHP.IsAddOnLoaded("shMem") then
	local function OnEnterFPS(self)
		tipshownMem = self
		GameTooltip:SetOwner(self, "ANCHOR_NONE")
		GameTooltip:SetPoint(SHP.GetTipAnchor(self))
		GameTooltip:ClearLines()

		GameTooltip:AddLine("|cff0062ffsh|r|cff0DEB11Performance|r")
		GameTooltip:AddLine(SHP.config.SHOW_BOTH and "[Memory/Latency]" or "[Memory]")
		GameTooltip:AddLine(
			format(
				"|cffc3771aDataBroker|r addon shows memory and fps updated every |cff06DDFA%s second(s)|r!\n",
				SHP.config.UPDATE_PERIOD
			)
		)

		GameTooltip:AddDoubleLine("Addon name", format("Memory above (|cff06ddfa%s kb|r)", SHP.config.MEM_THRESHOLD))
		GameTooltip:AddDoubleLine("|cffffffff------------|r", "|cffffffff------------|r")

		local counter, addonmem, hiddenmem, shownmem = 0, 0, 0, 0

		-- Ensure addons are sorted by usage if not alphabetically sorted
		if not SHP.config.WANT_ALPHA_SORTING then
			table.sort(SHP.ADDONS_TABLE, SHP.usageSort)
		end

		SHP.UpdateAddOnMemoryUsage()
		for _, v in ipairs(SHP.ADDONS_TABLE) do
			local mem = SHP.GetAddOnMemoryUsage(v)
			if mem > SHP.config.MEM_THRESHOLD and counter < SHP.config.MAX_ADDONS then
				counter = counter + 1
				shownmem = shownmem + mem
				local r, g, b = SHP.GetColorFromGradientTable((mem - SHP.config.MEM_THRESHOLD) / 15e3)
				local memstr = SHP.formatMem(mem, SHP.config.WANT_COLORING)

				GameTooltip:AddDoubleLine(
					format("  |cffDAB024%.0f)|r %s", counter, v),
					memstr,
					SHP.config.WANT_COLORING and r or 1,
					SHP.config.WANT_COLORING and g or 1,
					SHP.config.WANT_COLORING and b or 1
				)
			else
				hiddenmem = hiddenmem + mem
			end
		end

		-- Additional memory details
		local totalmem = SHP.collectgarbage("count")
		local deltamem = totalmem - prevmem
		prevmem = totalmem
		GameTooltip:AddDoubleLine("Total addon memory usage:", SHP.formatMem(totalmem, true))

		GameTooltip:Show()
		elapsedFpsController = -10
	end
	datafps.OnEnter = OnEnterFPS

	local function OnClickFPS(self)
		datafps.OnEnter(self)
		local collected = SHP.collectgarbage("count")
		SHP.collectgarbage("collect")
		local deltamem = collected - SHP.collectgarbage("count")
		print(
			format(
				"|cff0DEB11shPerformance|r - |cffC3771AGarbage|r Collected: |cff06ddfa%s|r",
				SHP.formatMem(deltamem, true)
			)
		)
	end
	datafps.OnClick = OnClickFPS
end
