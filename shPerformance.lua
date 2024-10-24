if not LibStub then
	error("shPerformance requires LibStub")
end

local _, ns = ...
local SHP = ns.SHP

-- Math and string functions
local format = format
local floor = math.floor
local modf = math.modf
local abs = math.abs

-- Game and system-related functions
local GetNetStats = GetNetStats
local GetFramerate = GetFramerate
local collectgarbage = collectgarbage

-- Add-on management functions
local UpdateAddOnMemoryUsage = UpdateAddOnMemoryUsage
local GetAddOnMemoryUsage = GetAddOnMemoryUsage
local GetAddOnInfo = C_AddOns.GetAddOnInfo
local IsAddOnLoaded = C_AddOns.IsAddOnLoaded

-- Utility functions
local select = select
local sort = table.sort
local ipairs = ipairs
local insert = table.insert
local print = print

-- Tooltip references
local GameTooltip = GameTooltip

-- Static values and icons
local prevmem = collectgarbage("count")
local tipshownMem
local tipshownLatency

---------------------
--> FUNCTIONS
---------------------

-->sort based on usage (will check to see what usage in tooltip updater)
local usageSort = function(a, b)
	return GetAddOnMemoryUsage(a) > GetAddOnMemoryUsage(b)
end

-->Format Mem with stylez
local formatMem = function(mem, x)
	if x then
		if abs(mem) > 1024 then
			return format("%.2f|cffE8D200M|r", mem / 1e3)
		else
			return format("%.1f|cffE8D200K|r", mem)
		end
	else
		if mem > 1024 then
			return format("%.2fM", mem / 1e3)
		else
			return format("%.1fK", mem)
		end
	end
end

-- Function to interpolate between colors based on a percentage
local function ColorGradient(perc, providedColorSequence)
	-- Use the provided color sequence or the default (green -> yellow -> red)
	local colors = providedColorSequence or { 0, 1, 0, 1, 1, 0, 1, 0, 0 }
	local num = #colors / 3

	-- Clamp the percentage between 0 and 1
	if perc >= 1 then
		-- Return the last color in the sequence when percentage is at or above 100%
		local r, g, b = colors[(num - 1) * 3 + 1], colors[(num - 1) * 3 + 2], colors[(num - 1) * 3 + 3]
		return r, g, b
	elseif perc <= 0 then
		-- Return the first color in the sequence when percentage is at or below 0%
		local r, g, b = colors[1], colors[2], colors[3]
		return r, g, b
	end

	-- Determine the segment and the relative percentage within that segment
	local segment = math.floor(perc * (num - 1))
	local relperc = (perc * (num - 1)) - segment

	-- Get the colors for the current segment
	local r1, g1, b1 = colors[(segment * 3) + 1], colors[(segment * 3) + 2], colors[(segment * 3) + 3]
	local r2, g2, b2 = colors[(segment * 3) + 4], colors[(segment * 3) + 5], colors[(segment * 3) + 6]

	-- Interpolate between the two colors
	return r1 + (r2 - r1) * relperc, g1 + (g2 - g1) * relperc, b1 + (b2 - b1) * relperc
end

-- Function to create the gradient table with 0.5% intervals
local function CreateGradientTable(providedColorSequence)
	local gradientTable = {}
	local colorSequence = providedColorSequence or nil
	for i = 0, 200 do
		local percent = i / 2 -- 0.5% intervals (0.0, 0.5, 1.0, ..., 100.0)
		local r, g, b = ColorGradient(percent / 100, colorSequence)
		gradientTable[percent] = { r, g, b }
	end
	return gradientTable
end

-- Create the gradient table when the addon loads
-- Interpolate between green (0, 1, 0), yellow (1, 1, 0), and red (1, 0, 0)
local colorSequence = { 0, 1, 0, 1, 1, 0, 1, 0, 0 }
local GRADIENT_TABLE = CreateGradientTable(colorSequence)

local function GetColorFromGradientTable(proportion, gradientTable)
	-- Use GRADIENT_TABLE as default if no gradientTable is provided
	gradientTable = gradientTable or GRADIENT_TABLE
	-- Convert proportion to a scale of 0 to 100
	local normalized_value = math.max(0, math.min(proportion * 100, 100))
	-- Round down the value to the nearest 0.5
	local roundedValue = math.floor(normalized_value * 2) / 2
	-- Retrieve and return the RGB values from the gradient table
	return unpack(gradientTable[roundedValue])
end

-- Special function for FPS color text
local function GetFPSColor(fps)
	-- Invert the proportion for the gradient
	local proportion = 1 - (fps / SHP.config.FPS_GRADIENT_THRESHOLD)
	-- Clamp the proportion between 0 and 1
	proportion = math.max(0, math.min(proportion, 1))
	-- Use the standard gradient table
	return GetColorFromGradientTable(proportion, GRADIENT_TABLE)
end

-->END - GRADIENT COLOR TABLE CREATION

-->tooltip anchor
local UIParent = UIParent
local GetTipAnchor = function(frame)
	local x, y = frame:GetCenter()
	if not x or not y then
		return "TOPLEFT", "BOTTOMLEFT"
	end
	local hhalf = (x > UIParent:GetWidth() * 2 / 3) and "RIGHT" or (x < UIParent:GetWidth() / 3) and "LEFT" or ""
	local vhalf = (y > UIParent:GetHeight() / 2) and "TOP" or "BOTTOM"
	return vhalf .. hhalf, frame, (vhalf == "TOP" and "BOTTOM" or "TOP") .. hhalf
end

----------------------
--> MODULES AND FRAMES
----------------------
local ffps = CreateFrame("frame")
local flatency = CreateFrame("frame")
local lib = LibStub:GetLibrary("LibDataBroker-1.1")
local datafps =
	lib:NewDataObject("shFps", { type = "data source", text = "Initializing...fps", icon = SHP.config.FPS_ICON })
local datalatency =
	lib:NewDataObject("shLatency", { type = "data source", text = "Initializing...ms", icon = SHP.config.MS_ICON })

----------------------
--> ONUPDATE HANDLERS
----------------------

-->shFps OnUpdate script
local elapsedFpsController = -10
ffps:SetScript("OnUpdate", function(self, t)
	elapsedFpsController = elapsedFpsController - t
	if elapsedFpsController < 0 then
		if tipshownMem and not IsAddOnLoaded("shMem") then
			datafps.OnEnter(tipshownMem)
		end

		local fps = GetFramerate()
		-- Use the inverted proportion for the FPS gradient with the standard gradient table
		local rf, gf, bf = GetFPSColor(fps)

		if SHP.config.SHOW_BOTH then
			local _, _, lh, lw = GetNetStats()
			local rl, gl, bl =
				GetColorFromGradientTable(((lh + lw) / 2) / SHP.config.MS_GRADIENT_THRESHOLD, GRADIENT_TABLE)
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
			--datafps.text = format("|cff%02x%02x%02x%.0f|r |cffE8D200fps|r", r*255, g*255, b*255, fps)
			datafps.text = format("|cff%02x%02x%02x%.0f|r |cffE8D200fps|r", rf * 255, gf * 255, bf * 255, fps)
		end

		elapsedFpsController = SHP.config.UPDATE_PERIOD
	end
end)

-->shLatency OnUpdate script
local elapsedLatencyController = -10
flatency:SetScript("OnUpdate", function(self, t)
	elapsedLatencyController = elapsedLatencyController - t
	if elapsedLatencyController < 0 then
		if tipshownLatency then
			datalatency.OnEnter(tipshownLatency)
		end
		local _, _, lh, lw = GetNetStats()
		local r, g, b = GetColorFromGradientTable(((lh + lw) / 2) / SHP.config.MS_GRADIENT_THRESHOLD, GRADIENT_TABLE)
		datalatency.text = format("|cff%02x%02x%02x%.0f/%.0f(w)|r |cffE8D200ms|r", r * 255, g * 255, b * 255, lh, lw)
		elapsedLatencyController = SHP.config.UPDATE_PERIOD + 20 --> blizzard set high update rate on this
	end
end)

----------------------
--> ONLEAVE FUNCTIONS
----------------------
local GameTooltip = GameTooltip
if not IsAddOnLoaded("shMem") then
	function datafps.OnLeave()
		GameTooltip:SetClampedToScreen(true)
		GameTooltip:Hide()
		tipshownMem = nil
	end
end

function datalatency.OnLeave()
	GameTooltip:SetClampedToScreen(true)
	GameTooltip:Hide()
	tipshownLatency = nil
end

----------------------
--> ONENTER FUNCTIONS
----------------------
function datalatency.OnEnter(self)
	tipshownLatency = self
	GameTooltip:SetOwner(self, "ANCHOR_NONE")
	GameTooltip:SetPoint(GetTipAnchor(self))
	GameTooltip:ClearLines()

	GameTooltip:AddLine("|cff0062ffsh|r|cff0DEB11Latency|r")
	GameTooltip:AddLine("[Bandwidth/Latency]")
	GameTooltip:AddLine(
		format(
			"|cffc3771aDataBroker|r based addon to show your network latency (ms)\nupdated every |cff06DDFA%s second(s)|r!\n",
			30
		)
	)

	local binz, boutz, l, w = GetNetStats()
	local rin, gin, bins = GetColorFromGradientTable(binz / 20, GRADIENT_TABLE)
	local rout, gout, bout = GetColorFromGradientTable(boutz / 5, GRADIENT_TABLE)
	local r, g, b = GetColorFromGradientTable(((l + w) / 2) / SHP.config.MS_GRADIENT_THRESHOLD, GRADIENT_TABLE)

	GameTooltip:AddDoubleLine(
		"|cff42AAFFHOME|r |cffFFFFFFRealm|r |cff0deb11(latency)|r:",
		format("%.0f ms", l),
		nil,
		nil,
		nil,
		r,
		g,
		b
	)
	GameTooltip:AddDoubleLine(
		"|cffDCFF42WORLD|r |cffFFFFFFServer|r |cff0deb11(latency)|r:",
		format("%.0f ms", w),
		nil,
		nil,
		nil,
		r,
		g,
		b
	)
	GameTooltip:AddLine(" ")
	GameTooltip:AddDoubleLine(
		"|cff06ddfaIncoming bandwidth|r |cff0deb11(download)|r usage:",
		format("%.2f kb/sec", binz),
		nil,
		nil,
		nil,
		rin,
		gin,
		bins
	)
	GameTooltip:AddDoubleLine(
		"|cff06ddfaOutgoing bandwidth|r |cff0deb11(upload)|r usage:",
		format("%.2f kb/sec", boutz),
		nil,
		nil,
		nil,
		rout,
		gout,
		bout
	)
	elapsedLatencyController = -10
	GameTooltip:Show()
end

function datalatency.OnClick(self)
	return
end

if not IsAddOnLoaded("shMem") then
	function datafps.OnEnter(self)
		tipshownMem = self
		GameTooltip:SetOwner(self, "ANCHOR_NONE")
		GameTooltip:SetPoint(GetTipAnchor(self))
		GameTooltip:ClearLines()

		GameTooltip:AddLine("|cff0062ffsh|r|cff0DEB11Performance|r")
		if SHP.config.SHOW_BOTH then
			GameTooltip:AddLine("[Memory/Latency]")
		else
			GameTooltip:AddLine("[Memory]")
		end

		GameTooltip:AddLine(
			format(
				"|cffc3771aDataBroker|r based addon to show your addon memory\nand fps updated every |cff06DDFA%s second(s)|r!\n",
				SHP.config.UPDATE_PERIOD
			)
		)
		GameTooltip:AddDoubleLine(" ", " ")
		GameTooltip:AddDoubleLine("Addon name", format("Memory above (|cff06ddfa%s kb|r)", SHP.config.MEM_THRESHOLD))
		GameTooltip:AddDoubleLine("|cffffffff------------|r", "|cffffffff------------|r")

		local counter = 0 -- for numbering (listing) and coloring
		local addonmem = 0
		local hidden, hiddenmem, shownmem = 0, 0, 0

		if SHP.config.WANT_ALPHA_SORTING == false then
			sort(SHP.ADDONS_TABLE, usageSort) -->sort numerically by usage (descending) if desired
		end

		UpdateAddOnMemoryUsage()
		for i, v in ipairs(SHP.ADDONS_TABLE) do
			local newname
			local mem = GetAddOnMemoryUsage(v)
			local r, g, b = GetColorFromGradientTable((mem - SHP.config.MEM_THRESHOLD) / 15e3, GRADIENT_TABLE)
			addonmem = addonmem + mem
			if mem > SHP.config.MEM_THRESHOLD and SHP.config.MAX_ADDONS > counter then
				counter = counter + 1
				hidden = #SHP.ADDONS_TABLE - counter
				shownmem = shownmem + mem
				newname = select(2, GetAddOnInfo(v))
				local memstr = formatMem(mem)
				if SHP.config.WANT_COLORING then
					if counter < 10 then
						GameTooltip:AddDoubleLine(
							format("  |cffDAB024%.0f)|r %s", counter, newname),
							memstr,
							r,
							g,
							b,
							r,
							g,
							b
						)
					else
						GameTooltip:AddDoubleLine(
							format("|cffDAB024%.0f)|r %s", counter, newname),
							memstr,
							r,
							g,
							b,
							r,
							g,
							b
						)
					end
				else
					if counter < 10 then
						GameTooltip:AddDoubleLine(
							format("  |cffDAB024%.0f)|r %s", counter, newname),
							memstr,
							1,
							1,
							1,
							r,
							g,
							b
						)
					else
						GameTooltip:AddDoubleLine(
							format("|cffDAB024%.0f)|r %s", counter, newname),
							memstr,
							1,
							1,
							1,
							r,
							g,
							b
						)
					end
				end
			end
		end

		hiddenmem = addonmem - shownmem
		if hiddenmem > 0 then
			GameTooltip:AddDoubleLine(
				format(
					"|cff06DDFA... [%d] hidden SHP.ADDONS_TABLE|r (usage less than %d kb)",
					hidden,
					SHP.config.MEM_THRESHOLD
				),
				" "
			)
		end

		local memstr = formatMem(addonmem)
		local mem = collectgarbage("count")
		local deltamem = mem - prevmem
		prevmem = mem

		GameTooltip:AddDoubleLine(" ", "|cffffffff------------|r")
		GameTooltip:AddDoubleLine(
			" ",
			format("|cffC3771ATOTAL USER ADDON|r |cffffffffmemory usage:|r  |cff06ddfa%s|r", memstr)
		)
		GameTooltip:AddDoubleLine(
			" ",
			format(
				"|cffC3771ADefault Blizzard UI|r |cffffffffmemory usage:|r  |cff06ddfa%s|r",
				formatMem(mem - addonmem)
			)
		)
		GameTooltip:AddDoubleLine(" ", " ")

		if SHP.config.SHOW_BOTH then
			local _, _, l, w = GetNetStats()
			local rw, gw, bw = GetColorFromGradientTable(w / SHP.config.MS_GRADIENT_THRESHOLD, GRADIENT_TABLE)
			local rl, gl, bl = GetColorFromGradientTable(l / SHP.config.MS_GRADIENT_THRESHOLD, GRADIENT_TABLE)

			GameTooltip:AddDoubleLine(
				" ",
				format("|cff42AAFFHOME|r |cffFFFFFFRealm (latency)|r:  %.0f ms", l),
				nil,
				nil,
				nil,
				rl,
				gl,
				bl
			)
			GameTooltip:AddDoubleLine(
				" ",
				format("|cffDCFF42WORLD|r |cffFFFFFFServer (latency)|r:  %.0f ms", w),
				nil,
				nil,
				nil,
				rw,
				gw,
				bw
			)
			GameTooltip:AddDoubleLine(" ", " ")
		end

		local r, g, b = GetColorFromGradientTable(deltamem / SHP.config.MEM_GRADIENT_THRESHOLD, GRADIENT_TABLE)
		GameTooltip:AddDoubleLine("|cffc3771aGarbage|r churn", format("%.2f kb/sec", deltamem), nil, nil, nil, r, g, b)
		GameTooltip:AddLine("*Click to force |cffc3771agarbage|r collection and to |cff06ddfaupdate|r tooltip*")

		elapsedFpsController = -10
		GameTooltip:Show()
	end

	function datafps.OnClick(self)
		datafps.OnEnter(self) -->updates tooltip
		local collected, deltamem = 0, 0
		collected = collectgarbage("count")
		collectgarbage("collect")
		UpdateAddOnMemoryUsage()
		deltamem = collected - collectgarbage("count")
		print(
			format(
				"|cff0DEB11shPerformance|r - |cffC3771AGarbage|r Collected: |cff06ddfa%s|r",
				formatMem(deltamem, true)
			)
		)
	end
end
