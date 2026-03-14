--================================================================================
-- ZB Health HUD — FINAL VERSION WITH BLEEDING STATUS
-- Features:
--   • Bleeding status for external wounds (neck cuts, arterial wounds)
--   • Internal bleeding status (from organ damage)
--   • Fixed stamina calculation using org.stamina[1] and org.stamina.max
--   • Consciousness hidden at >=90%
--   • Shared level backgrounds for pain/conscious/stamina
--   • Complete hiding of amputated limbs
--   • Recolored limb sprites: Gray → Orange → Red
--================================================================================

if SERVER then
	-- Limb sprites
	local SPRITES = {
		"materials/vgui/hud/health_head.png",
		"materials/vgui/hud/health_torso.png",
		"materials/vgui/hud/health_right_arm.png",
		"materials/vgui/hud/health_left_arm.png",
		"materials/vgui/hud/health_right_leg.png",
		"materials/vgui/hud/health_left_leg.png",
	}
	
	-- Parameter icons
	local ICONS = {
		"materials/vgui/hud/bloodmeter.png",
		"materials/vgui/hud/pulsemeter.png",
		"materials/vgui/hud/assimilationmeter.png",
		"materials/vgui/hud/o2meter.png",
		"materials/vgui/hud/o2meter_alt.png",
	}
	
	-- Status effect sprites (INCLUDING BLEEDING)
	local STATUS_SPRITES = {
		-- Shared level backgrounds (1-4) for ALL leveled statuses
		"materials/vgui/hud/status_level1_bg.png",   -- Level 1: Good (Green)
		"materials/vgui/hud/status_level2_bg.png",   -- Level 2: Moderate (Yellow)
		"materials/vgui/hud/status_level3_bg.png",   -- Level 3: Bad (Orange)
		"materials/vgui/hud/status_level4_bg.png",   -- Level 4: Critical (Red)
		
		-- Base background for non-leveled statuses
		"materials/vgui/hud/status_background.png",
		
		-- Status icons (INCLUDING BLEEDING)
		"materials/vgui/hud/status_pain_icon.png",
		"materials/vgui/hud/status_conscious_icon.png",
		"materials/vgui/hud/status_stamina_icon.png",
		"materials/vgui/hud/status_bleeding_icon.png",      -- NEW: External bleeding
		"materials/vgui/hud/status_internal_bleed_icon.png",-- NEW: Internal bleeding
		"materials/vgui/hud/status_organ_damage.png",
		"materials/vgui/hud/status_dislocation.png",
		"materials/vgui/hud/status_spine_fracture.png",
		"materials/vgui/hud/status_leg_fracture.png",
		"materials/vgui/hud/status_arm_fracture.png",
	}
	
	for _, path in ipairs(SPRITES) do resource.AddFile(path) end
	for _, path in ipairs(ICONS) do resource.AddFile(path) end
	for _, path in ipairs(STATUS_SPRITES) do resource.AddFile(path) end
	
	AddCSLuaFile("autorun/zb_health_hud.lua")
	
	hook.Add("Initialize", "ZB_HealthHUD_ServerInit", function()
		print("\n[ZB Health HUD] Server initialized")
	end)
	
	return
end

--================================================================================
-- CLIENT SIDE (WITH BLEEDING STATUS)
--================================================================================

-- CRITICAL FIX: Added math.sin to local variables!
local math_min, math_max, math_floor, math_sin = math.min, math.max, math.floor, math.sin
local Color = Color
local draw_SimpleText = draw.SimpleText
local surface_SetDrawColor = surface.SetDrawColor
local surface_DrawRect = surface.DrawRect
local surface_DrawOutlinedRect = surface.DrawOutlinedRect
local surface_SetMaterial = surface.SetMaterial
local surface_DrawTexturedRect = surface.DrawTexturedRect
local ScrW, ScrH = ScrW, ScrH
local FrameTime = FrameTime
local Lerp = Lerp
local CurTime = CurTime
local gui = gui

-- Safe value getter
local function getOrgVal(org, key, def)
	local v = org[key]
	return type(v) == "number" and v or (def or 0)
end

-- Color interpolation
local function lerpCol(ratio, from, to)
	ratio = math_min(math_max(ratio, 0), 1)
	return Color(
		math_floor((from.r or 0) + ((to.r or 0) - (from.r or 0)) * ratio),
		math_floor((from.g or 0) + ((to.g or 0) - (from.g or 0)) * ratio),
		math_floor((from.b or 0) + ((to.b or 0) - (from.b or 0)) * ratio),
		255
	)
end

-- NEW: Limb color scheme (Gray → Orange → Red)
local function getLimbColor(damage)
	local ratio = math_min(math_max(damage, 0), 1)
	if ratio <= 0.3 then return Color(128, 128, 128, 255)    -- Gray = healthy
	elseif ratio <= 0.6 then return Color(255, 165, 0, 255)  -- Orange = moderate
	else return Color(255, 0, 0, 255) end                    -- Red = severe
end

-- ===== CONFIGURATION =====
local HUD = {
	enabled = true,
	bar_y = -40,
	bar_scale = 1.0,
	base_x = nil,
	base_y = 60,
	use_alt_icons = false,
	
	limb_offsets = {
		head =        { x = 10,   y = 22 },
		torso =       { x = 10,   y = 20 },
		right_arm =   { x = 10.9 ,  y = 20 },
		left_arm =    { x = 10, y = 20 },
		right_leg =   { x = 10,  y = 19 },
		left_leg =    { x = 10, y = 19 },
	},
	
	limb_scale = {
		head =        { w = 3.0, h = 4.2 },
		torso =       { w = 3.0, h = 4.0 },
		right_arm =   { w = 3.0, h = 4.0 },
		left_arm =    { w = 3.0, h = 4.0 },
		right_leg =   { w = 3.0, h = 4.5 },
		left_leg =    { w = 3.0, h = 4.5 },
	},
	
	sprite_visibility = 50,
	always_show_limbs = true,
	smooth = 0.35,
	show_damage_percent = false,
	
	blood_hide_threshold = 4500,
	pulse_hide_min = 60,
	pulse_hide_max = 100,
	stable_time = 15,
	
	status_effects_x = -10,
	status_effects_y = 10,
	status_effects_spacing = 42,
	status_effects_size = 38,
	show_status_effects = true,
	
	organ_damage_threshold = 0.3,
	fracture_threshold = 0.95,
	
	-- Bleeding thresholds (from sv_blood.lua analysis)
	bleeding_threshold = 0.1,        -- External bleeding visible
	internal_bleed_threshold = 0.1,  -- Internal bleeding visible
}

-- Material cache
local sprites = {}
local icons = {}
local status_sprites = {
	level_backgrounds = {nil, nil, nil, nil},
	background = nil,
	pain_icon = nil,
	conscious_icon = nil,
	stamina_icon = nil,
	bleeding_icon = nil,             -- NEW
	internal_bleed_icon = nil,       -- NEW
	organ_damage = nil,
	dislocation = nil,
	spine_fracture = nil,
	leg_fracture = nil,
	arm_fracture = nil,
}
local status_sprites_loaded = false
local debug_done = false
local statusEffectAppearance = {}
local statusEffectPositions = {}
local tooltipHoverTime = {}
local lastHoveredStatus = nil

-- Smoothed values
local smooth = {
	blood = 5000,
	conscious = 1.0,
	pain = 0,
	pulse = 70,
	assimilation = 0,
	o2 = 100,
	bleed = 0,                       -- NEW
	internalBleed = 0,               -- NEW
}

-- Stability tracking
local stability = {
	blood = {last_value = 5000, last_change = 0, hidden = false},
	pulse = {last_value = 70, last_change = 0, hidden = false},
}

--================================================================================
-- LOAD PARAMETER ICONS
--================================================================================
local function load_icons()
	if icons.loaded and icons.alt == HUD.use_alt_icons then return end
	icons.loaded = true
	icons.alt = HUD.use_alt_icons
	
	local fixed_icons = {
		blood = "vgui/hud/bloodmeter.png",
		pulse = "vgui/hud/pulsemeter.png",
		assimilation = "vgui/hud/assimilationmeter.png",
	}
	
	local suffix = HUD.use_alt_icons and "_alt" or ""
	local dynamic_icons = {
		o2 = "vgui/hud/o2meter" .. suffix .. ".png",
	}
	
	for name, path in pairs(fixed_icons) do
		local mat = Material(path, "smooth")
		icons[name] = (mat and not mat:IsError()) and mat or false
	end
	
	for name, path in pairs(dynamic_icons) do
		local mat = Material(path, "smooth")
		icons[name] = (mat and not mat:IsError()) and mat or false
	end
end

--================================================================================
-- LOAD STATUS EFFECT SPRITES (INCLUDING BLEEDING)
--================================================================================
local function load_status_sprites()
	if status_sprites_loaded then return end
	status_sprites_loaded = true
	
	-- Load 4 shared level backgrounds for ALL leveled statuses
	for i = 1, 4 do
		status_sprites.level_backgrounds[i] = Material("vgui/hud/status_level" .. i .. "_bg.png", "smooth")
	end
	
	-- Base background for non-leveled statuses
	status_sprites.background = Material("vgui/hud/status_background.png", "smooth")
	
	-- Status icons (INCLUDING BLEEDING)
	status_sprites.pain_icon = Material("vgui/hud/status_pain_icon.png", "smooth")
	status_sprites.conscious_icon = Material("vgui/hud/status_conscious_icon.png", "smooth")
	status_sprites.stamina_icon = Material("vgui/hud/status_stamina_icon.png", "smooth")
	status_sprites.bleeding_icon = Material("vgui/hud/status_bleeding_icon.png", "smooth")           -- NEW
	status_sprites.internal_bleed_icon = Material("vgui/hud/status_internal_bleed_icon.png", "smooth") -- NEW
	status_sprites.organ_damage = Material("vgui/hud/status_organ_damage.png", "smooth")
	status_sprites.dislocation = Material("vgui/hud/status_dislocation.png", "smooth")
	status_sprites.spine_fracture = Material("vgui/hud/status_spine_fracture.png", "smooth")
	status_sprites.leg_fracture = Material("vgui/hud/status_leg_fracture.png", "smooth")
	status_sprites.arm_fracture = Material("vgui/hud/status_arm_fracture.png", "smooth")
end

--================================================================================
-- UPDATE STABILITY TRACKERS
--================================================================================
local function update_stability(blood_val, pulse_val)
	local now = CurTime()
	
	if math.abs(blood_val - stability.blood.last_value) > 50 then
		stability.blood.last_value = blood_val
		stability.blood.last_change = now
		stability.blood.hidden = false
	end
	
	if math.abs(pulse_val - stability.pulse.last_value) > 3 then
		stability.pulse.last_value = pulse_val
		stability.pulse.last_change = now
		stability.pulse.hidden = false
	end
	
	if blood_val >= HUD.blood_hide_threshold and (now - stability.blood.last_change) >= HUD.stable_time then
		stability.blood.hidden = true
	end
	
	if pulse_val >= HUD.pulse_hide_min and pulse_val <= HUD.pulse_hide_max and (now - stability.pulse.last_change) >= HUD.stable_time then
		stability.pulse.hidden = true
	end
end

--================================================================================
-- DRAW: Status bar (PAIN/CONSCIOUS REMOVED)
--================================================================================
local function draw_bar()
	if not HUD.enabled then return end
	
	local ply = LocalPlayer()
	if not IsValid(ply) or not ply.organism then return end
	
	local org = ply.organism
	local scale = math_max(HUD.bar_scale, 0.5)
	
	local base_bar_h = 34
	local base_bar_w = 440
	local bar_h = math_floor(base_bar_h * scale)
	local bar_w = math_floor(base_bar_w * scale)
	local bar_y = ScrH() + HUD.bar_y
	
	local max_bar_w = ScrW() * 0.95
	local max_scale = max_bar_w / base_bar_w
	if scale > max_scale then
		scale = max_scale
		bar_w = math_floor(base_bar_w * scale)
		bar_h = math_floor(base_bar_h * scale)
	end
	
	local bar_x = ScrW() * 0.5 - bar_w * 0.5
	local pad = math_floor(5 * scale)
	local icon_size = math_floor(26 * scale)
	
	load_icons()
	
	local dt = math_min(FrameTime() * 60, 1)
	local s = HUD.smooth
	
	smooth.blood = Lerp(s * dt, smooth.blood or 5000, getOrgVal(org, "blood", 5000))
	smooth.conscious = Lerp(s * dt, smooth.conscious or 1.0, getOrgVal(org, "consciousness", 1))
	smooth.pain = Lerp(s * dt, smooth.pain or 0, getOrgVal(org, "pain", 0))
	smooth.pulse = Lerp(s * dt, smooth.pulse or 70, getOrgVal(org, "pulse", 70))
	smooth.assimilation = Lerp(s * dt, smooth.assimilation or 0, getOrgVal(org, "assimilated", 0))
	smooth.o2 = Lerp(s * dt, smooth.o2 or 100, getOrgVal(org, "o2", 100))
	smooth.bleed = Lerp(s * dt, smooth.bleed or 0, getOrgVal(org, "bleed", 0))               -- NEW
	smooth.internalBleed = Lerp(s * dt, smooth.internalBleed or 0, getOrgVal(org, "internalBleed", 0)) -- NEW
	
	update_stability(smooth.blood or 5000, smooth.pulse or 70)
	
	local segs = {}
	
	-- Blood
	local blood_val = smooth.blood or 5000
	if not stability.blood.hidden then
		local r_blood = math_min(blood_val / 5000, 1)
		local c_blood = r_blood < 0.5 and lerpCol(r_blood * 2, Color(80, 255, 80), Color(255, 180, 50)) or lerpCol((r_blood - 0.5) * 2, Color(255, 180, 50), Color(255, 50, 50))
		table.insert(segs, {label = "BLOOD", val = math_floor(blood_val), suf = "ml", ratio = r_blood, col = c_blood, w = math_floor(95 * scale), icon = "blood", prio = 1})
	end
	
	-- Oxygen
	local o2_val = smooth.o2 or 100
	local r_o2 = math_min(o2_val / 100, 1)
	local c_o2 = lerpCol(r_o2, Color(255, 50, 50), Color(80, 200, 255))
	if o2_val < 98 then
		table.insert(segs, {label = "O2", val = math_floor(o2_val), suf = "%", ratio = r_o2, col = c_o2, w = math_floor(75 * scale), icon = "o2", prio = 2})
	end
	
	-- Assimilation
	local assim_val = smooth.assimilation or 0
	if assim_val > 0.005 then
		local r_assim = assim_val
		table.insert(segs, {label = "ASSIMILATION", val = math_floor(assim_val * 100), suf = "%", ratio = r_assim, col = Color(180, 50, 255, 255), w = math_floor(105 * scale), icon = "assimilation", prio = 3})
	end
	
	-- Pulse
	local pulse_val = smooth.pulse or 70
	if not stability.pulse.hidden then
		local r_pulse = math_min(pulse_val / 100, 1)
		local c_pulse = (pulse_val < 50 or pulse_val > 130) and Color(255, 80, 80) or Color(180, 220, 255)
		table.insert(segs, {label = "PULSE", val = math_floor(pulse_val), suf = "bpm", ratio = r_pulse, col = c_pulse, w = math_floor(80 * scale), icon = "pulse", prio = 4})
	end
	
	if #segs == 0 then return end
	
	table.sort(segs, function(a, b) return a.prio < b.prio end)
	
	local total_width = pad
	for _, seg in ipairs(segs) do total_width = total_width + seg.w + pad end
	
	if total_width > bar_w then
		local new_scale = (bar_w - pad) / (total_width - pad)
		scale = scale * new_scale * 0.98
		bar_w = math_floor(base_bar_w * scale)
		bar_h = math_floor(base_bar_h * scale)
		bar_x = ScrW() * 0.5 - bar_w * 0.5
		pad = math_floor(5 * scale)
		icon_size = math_floor(26 * scale)
		
		for i, seg in ipairs(segs) do
			segs[i].w = math_floor(segs[i].w * new_scale * 0.98)
		end
	end
	
	local x = bar_x + pad
	
	for _, seg in ipairs(segs) do
		local icon = icons[seg.icon]
		if icon and not icon:IsError() then
			surface_SetDrawColor(255, 255, 255, 255)
			surface_SetMaterial(icon)
			surface_DrawTexturedRect(x, bar_y + (bar_h - icon_size) * 0.5, icon_size, icon_size)
		else
			local letters = {blood = "B", o2 = "O", assimilation = "A", pulse = "♥"}
			surface_SetDrawColor(40, 40, 50, 200)
			surface_DrawRect(x + 1, bar_y + (bar_h - icon_size) * 0.5 + 1, icon_size - 2, icon_size - 2)
			surface_SetDrawColor(seg.col.r, seg.col.g, seg.col.b, 255)
			surface_DrawRect(x + 2, bar_y + (bar_h - icon_size) * 0.5 + 2, icon_size - 4, icon_size - 4)
			draw_SimpleText(letters[seg.icon] or "?", "TargetID", x + icon_size * 0.5, bar_y + bar_h * 0.5, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		
		local meter_x = x + icon_size + math_floor(3 * scale)
		local meter_w = seg.w - icon_size - math_floor(10 * scale)
		local meter_y = bar_y + pad + math_floor(2 * scale)
		local meter_h = bar_h - pad * 2 - math_floor(4 * scale)
		
		surface_SetDrawColor(30, 30, 40, 180)
		surface_DrawRect(meter_x, meter_y, meter_w, meter_h)
		
		surface_SetDrawColor(seg.col.r, seg.col.g, seg.col.b, 200)
		surface_DrawRect(meter_x, meter_y, meter_w * seg.ratio, meter_h)
		
		surface_SetDrawColor(80, 80, 90, 230)
		surface_DrawOutlinedRect(meter_x, meter_y, meter_w, meter_h)
		
		local value_text = seg.val .. (seg.suf or "")
		local text_x = meter_x + math_floor(4 * scale)
		local text_y = bar_y + bar_h * 0.5
		draw_SimpleText(value_text, "DermaDefault", text_x, text_y, Color(255, 255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		
		x = x + seg.w + pad
	end
end

--================================================================================
-- DRAW: Status effects with BLEEDING STATUS (FIXED SHAKE ANIMATION)
--================================================================================
local function draw_status_effects()
	if not HUD.enabled or not HUD.show_status_effects then 
		statusEffectPositions = {}
		return 
	end
	
	local ply = LocalPlayer()
	if not IsValid(ply) or not ply.organism then 
		statusEffectPositions = {}
		return 
	end
	
	local org = ply.organism
	local base_x = ScrW() + HUD.status_effects_x
	local base_y = HUD.status_effects_y
	local spacing = HUD.status_effects_spacing
	local size = HUD.status_effects_size
	local currentTime = CurTime()
	
	load_status_sprites()
	statusEffectPositions = {}
	
	local currentEffectNames = {}
	local effects = {}
	
	-- PAIN STATUS (4 LEVELS)
	local pain_val = smooth.pain or getOrgVal(org, "pain", 0)
	if pain_val > 10 then
		local level_num = 1
		if pain_val >= 60 then level_num = 4
		elseif pain_val >= 40 then level_num = 3
		elseif pain_val >= 25 then level_num = 2 end
		
		table.insert(effects, {
			name = "pain",
			level_num = level_num,
			has_levels = true,
			priority = 0,
			value = math_floor(pain_val)
		})
		currentEffectNames["pain"] = true
	end
	
	-- ===== BLEEDING STATUS (EXTERNAL) - CRITICAL FIX FOR NECK CUTS =====
	local bleed_val = smooth.bleed or getOrgVal(org, "bleed", 0)
	if bleed_val > HUD.bleeding_threshold then
		table.insert(effects, {
			name = "bleeding",
			priority = 0.3,  -- Between pain (0) and consciousness (1)
			value = math_floor(bleed_val)  -- ml/s from sv_blood.lua
		})
		currentEffectNames["bleeding"] = true
	end
	
	-- ===== INTERNAL BLEEDING STATUS =====
	local internal_bleed_val = smooth.internalBleed or getOrgVal(org, "internalBleed", 0)
	if internal_bleed_val > HUD.internal_bleed_threshold then
		table.insert(effects, {
			name = "internal_bleed",
			priority = 0.4,  -- Between bleeding and consciousness
			value = math_floor(internal_bleed_val * 100)  -- Convert to percentage
		})
		currentEffectNames["internal_bleed"] = true
	end
	
	-- CONSCIOUSNESS STATUS (HIDDEN AT >=90%)
	local cons_val = smooth.conscious or getOrgVal(org, "consciousness", 1)
	local cons_percent = math_floor(cons_val * 100)
	if cons_percent < 90 then
		local level_num = 1
		if cons_percent <= 24 then level_num = 4
		elseif cons_percent <= 49 then level_num = 3
		elseif cons_percent <= 74 then level_num = 2 end
		
		table.insert(effects, {
			name = "conscious",
			level_num = level_num,
			has_levels = true,
			priority = 1,
			value = cons_percent
		})
		currentEffectNames["conscious"] = true
	end
	
	-- STAMINA STATUS (4 LEVELS) - Uses org.stamina[1] and org.stamina.max from sv_stamina.lua
	local stamina_table = org.stamina
	if stamina_table and type(stamina_table) == "table" then
		local stamina_val = stamina_table[1] or 0
		local stamina_max = stamina_table.max or 180
		
		if stamina_max <= 0 then stamina_max = 180 end
		
		local stamina_percent = (stamina_val / stamina_max) * 100
		
		if stamina_percent < 75 then
			local level_num = 1
			if stamina_percent <= 24 then level_num = 4
			elseif stamina_percent <= 49 then level_num = 3
			elseif stamina_percent <= 74 then level_num = 2 end
			
			table.insert(effects, {
				name = "stamina",
				level_num = level_num,
				has_levels = true,
				priority = 2,
				value = math_floor(stamina_percent)
			})
			currentEffectNames["stamina"] = true
		end
	end
	
	-- SPINE FRACTURE
	local spine1 = getOrgVal(org, "spine1", 0)
	local spine2 = getOrgVal(org, "spine2", 0)
	local spine3 = getOrgVal(org, "spine3", 0)
	local spine_fracture = spine1 >= HUD.fracture_threshold or spine2 >= HUD.fracture_threshold or spine3 >= HUD.fracture_threshold
	if spine_fracture then
		table.insert(effects, {name = "spine_fracture", priority = 3})
		currentEffectNames["spine_fracture"] = true
	end
	
	-- ORGAN DAMAGE (with lungs from sv_stamina.lua)
	local organ_damage = math_max(
		getOrgVal(org, "heart", 0),
		getOrgVal(org, "liver", 0),
		getOrgVal(org, "stomach", 0),
		getOrgVal(org, "intestines", 0),
		getOrgVal(org, "lungsR", {})[1] or 0,
		getOrgVal(org, "lungsL", {})[1] or 0,
		getOrgVal(org, "lungsR", {})[2] or 0,
		getOrgVal(org, "lungsL", {})[2] or 0
	)
	if organ_damage > HUD.organ_damage_threshold then
		table.insert(effects, {name = "organ_damage", priority = 4})
		currentEffectNames["organ_damage"] = true
	end
	
	-- DISLOCATIONS
	if org.llegdislocation or org.rlegdislocation or 
	   org.larmdislocation or org.rarmdislocation or 
	   org.jawdislocation then
		table.insert(effects, {name = "dislocation", priority = 5})
		currentEffectNames["dislocation"] = true
	end
	
	-- LEG FRACTURE
	local lleg = getOrgVal(org, "lleg", 0)
	local rleg = getOrgVal(org, "rleg", 0)
	local leg_fracture = 
		(lleg >= HUD.fracture_threshold and not org.llegamputated) or
		(rleg >= HUD.fracture_threshold and not org.rlegamputated)
	if leg_fracture then
		table.insert(effects, {name = "leg_fracture", priority = 6})
		currentEffectNames["leg_fracture"] = true
	end
	
	-- ARM FRACTURE
	local larm = getOrgVal(org, "larm", 0)
	local rarm = getOrgVal(org, "rarm", 0)
	local arm_fracture = 
		(larm >= HUD.fracture_threshold and not org.larmamputated) or
		(rarm >= HUD.fracture_threshold and not org.rarmamputated)
	if arm_fracture then
		table.insert(effects, {name = "arm_fracture", priority = 7})
		currentEffectNames["arm_fracture"] = true
	end
	
	-- Clean up appearance tracker
	for name, _ in pairs(statusEffectAppearance) do
		if not currentEffectNames[name] then
			statusEffectAppearance[name] = nil
			tooltipHoverTime[name] = nil
		end
	end
	
	-- Set appearance time for new effects
	for _, effect in ipairs(effects) do
		if not statusEffectAppearance[effect.name] then
			statusEffectAppearance[effect.name] = currentTime
		end
	end
	
	table.sort(effects, function(a, b) return a.priority < b.priority end)
	
	-- Draw effects with CORRECT SHAKE ANIMATION
	for i, effect in ipairs(effects) do
		-- BASE POSITION (without shake)
		local base_x_pos = base_x - size
		local base_y_pos = base_y + (i - 1) * spacing
		
		-- CALCULATE SHAKE OFFSET
		local shakeOffset = 0
		local appearanceTime = statusEffectAppearance[effect.name]
		if appearanceTime then
			local timeActive = currentTime - appearanceTime
			if timeActive < 1.5 then
				local easeOut = (1 - timeActive) ^ 3
				shakeOffset = math_sin(timeActive * 18) * easeOut * 30
			end
		end
		
		-- FINAL POSITION WITH SHAKE
		local final_x = base_x_pos + shakeOffset
		local final_y = base_y_pos
		
		-- Save position for tooltips
		table.insert(statusEffectPositions, {
			x = final_x,
			y = final_y,
			size = size,
			name = effect.name,
			level_num = effect.level_num,
			value = effect.value
		})
		
		-- SELECT BACKGROUND
		local bg_mat
		if effect.has_levels then
			bg_mat = status_sprites.level_backgrounds[effect.level_num] or status_sprites.background
		else
			bg_mat = status_sprites.background
		end
		
		-- DRAW BACKGROUND
		if bg_mat and not bg_mat:IsError() then
			surface_SetDrawColor(255, 255, 255, 220)
			surface_SetMaterial(bg_mat)
			surface_DrawTexturedRect(final_x, final_y, size, size)
		else
			-- Fallback colored background
			local bg_color = Color(40, 40, 50, 220)
			if effect.name == "bleeding" then
				bg_color = Color(180, 30, 30, 220)  -- Red for bleeding
			elseif effect.name == "internal_bleed" then
				bg_color = Color(200, 50, 100, 220) -- Dark red for internal
			elseif effect.has_levels then
				if effect.level_num == 4 then bg_color = Color(180, 30, 30, 220)
				elseif effect.level_num == 3 then bg_color = Color(220, 60, 30, 220)
				elseif effect.level_num == 2 then bg_color = Color(255, 140, 40, 220)
				else bg_color = Color(80, 200, 100, 220) end
			end
			surface_SetDrawColor(bg_color.r, bg_color.g, bg_color.b, bg_color.a)
			surface_DrawRect(final_x, final_y, size, size)
			surface_SetDrawColor(255, 255, 255, 255)
			surface_DrawOutlinedRect(final_x, final_y, size, size)
		end
		
		-- DRAW ICON
		local icon_mat = nil
		if effect.name == "pain" then icon_mat = status_sprites.pain_icon
		elseif effect.name == "conscious" then icon_mat = status_sprites.conscious_icon
		elseif effect.name == "stamina" then icon_mat = status_sprites.stamina_icon
		elseif effect.name == "bleeding" then icon_mat = status_sprites.bleeding_icon        -- NEW
		elseif effect.name == "internal_bleed" then icon_mat = status_sprites.internal_bleed_icon -- NEW
		else icon_mat = status_sprites[effect.name] end
		
		if icon_mat and not icon_mat:IsError() then
			surface_SetDrawColor(255, 255, 255, 255)
			surface_SetMaterial(icon_mat)
			surface_DrawTexturedRect(final_x + 2, final_y + 2, size - 4, size - 4)
		else
			-- Fallback letters with value
			local letter = "?"
			local value_text = ""
			
			if effect.name == "pain" then
				letter = "P"
				value_text = effect.value .. ""
			elseif effect.name == "conscious" then
				letter = "C"
				value_text = effect.value .. "%"
			elseif effect.name == "stamina" then
				letter = "S"
				value_text = effect.value .. "%"
			elseif effect.name == "bleeding" then
				letter = "B"
				value_text = effect.value .. ""  -- ml/s
			elseif effect.name == "internal_bleed" then
				letter = "IB"
				value_text = effect.value .. "%" -- percentage
			else
				local letters = {spine_fracture = "SF", organ_damage = "OD", dislocation = "D", leg_fracture = "LF", arm_fracture = "AF"}
				letter = letters[effect.name] or "?"
			end
			
			draw_SimpleText(letter, "TargetID", final_x + size * 0.4, final_y + size * 0.3, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			if value_text ~= "" then
				draw_SimpleText(value_text, "DermaDefault", final_x + size * 0.5, final_y + size * 0.7, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
		end
	end
end

--================================================================================
-- DRAW: Tooltips on hover (INCLUDING BLEEDING)
--================================================================================
local function draw_status_tooltips()
	if not HUD.enabled or not HUD.show_status_effects or #statusEffectPositions == 0 then return end
	
	local mx, my = gui.MousePos()
	if not mx or mx == 0 then return end
	
	local currentTime = CurTime()
	local hoveredStatus = nil
	local hoveredPos = nil
	
	for _, pos in ipairs(statusEffectPositions) do
		if mx >= pos.x and mx <= pos.x + pos.size and my >= pos.y and my <= pos.y + pos.size then
			hoveredStatus = pos.name
			hoveredPos = pos
			break
		end
	end
	
	if hoveredStatus then
		if hoveredStatus ~= lastHoveredStatus then
			tooltipHoverTime[hoveredStatus] = currentTime
			lastHoveredStatus = hoveredStatus
		end
		
		local hoverDuration = currentTime - (tooltipHoverTime[hoveredStatus] or currentTime)
		if hoverDuration >= 0.3 and hoveredPos then
			local tooltipText = ""
			
			if hoveredStatus == "pain" then
				local desc = hoveredPos.level_num == 4 and "Unbearable" or
				             hoveredPos.level_num == 3 and "Severe" or
				             hoveredPos.level_num == 2 and "Moderate" or "Mild"
				tooltipText = "Pain\n" .. desc .. " pain\nMovement impaired"
				
			elseif hoveredStatus == "bleeding" then
				tooltipText = "External Bleeding " .. hoveredPos.value .. "ml/s "
				
			elseif hoveredStatus == "internal_bleed" then
				tooltipText = "Internal Bleeding"
				
			elseif hoveredStatus == "conscious" then
				local desc = hoveredPos.level_num == 4 and "Critical" or
				             hoveredPos.level_num == 3 and "Poor" or
				             hoveredPos.level_num == 2 and "Fair" or "Good"
				tooltipText = "Consciousness\n" .. desc .. ""
				
			elseif hoveredStatus == "stamina" then
				local desc = hoveredPos.level_num == 4 and "Exhausted" or
				             hoveredPos.level_num == 3 and "Very Low" or
				             hoveredPos.level_num == 2 and "Low" or "Moderate"
				tooltipText = "Stamina\n" .. desc .. ""
				
			elseif hoveredStatus == "spine_fracture" then
				tooltipText = "Spine Fracture"
			elseif hoveredStatus == "organ_damage" then
				tooltipText = "Organ Damage"
			elseif hoveredStatus == "dislocation" then
				tooltipText = "Dislocation"
			elseif hoveredStatus == "leg_fracture" then
				tooltipText = "Leg Fracture"
			elseif hoveredStatus == "arm_fracture" then
				tooltipText = "Arm Fracture"
			end
			
			local font = "DermaDefault"
			surface.SetFont(font)
			local textW, textH = surface.GetTextSize(tooltipText)
			
			local tooltipX = mx - textW - 15
			local tooltipY = my - textH / 2
			
			local padding = 6
			surface.SetDrawColor(25, 25, 35, 240)
			surface.DrawRect(tooltipX - padding, tooltipY - padding, textW + padding * 2, textH + padding * 2)
			
			surface.SetDrawColor(100, 150, 255, 255)
			surface.DrawOutlinedRect(tooltipX - padding, tooltipY - padding, textW + padding * 2, textH + padding * 2)
			
			draw.SimpleText(tooltipText, font, tooltipX, tooltipY, Color(255, 255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		end
	else
		if lastHoveredStatus then lastHoveredStatus = nil end
	end
end

--================================================================================
-- DRAW: Limb sprites (COMPLETELY HIDE amputated limbs)
--================================================================================
local function draw_sprites()
	if not HUD.enabled then return end
	
	local ply = LocalPlayer()
	if not IsValid(ply) or not ply.organism then return end
	
	if HUD.base_x == nil then HUD.base_x = ScrW() - 120 end
	
	local org = ply.organism
	local base_x = HUD.base_x
	local base_y = HUD.base_y
	
	if not debug_done then
		debug_done = true
		local paths = {
			head = {"vgui/hud/health_head.png", "vgui/hud/health_head"},
			torso = {"vgui/hud/health_torso.png", "vgui/hud/health_torso"},
			right_arm = {"vgui/hud/health_right_arm.png", "vgui/hud/health_right_arm"},
			left_arm = {"vgui/hud/health_left_arm.png", "vgui/hud/health_left_arm"},
			right_leg = {"vgui/hud/health_right_leg.png", "vgui/hud/health_right_leg"},
			left_leg = {"vgui/hud/health_left_leg.png", "vgui/hud/health_left_leg"},
		}
		
		for name, tries in pairs(paths) do
			for _, path in ipairs(tries) do
				local mat = Material(path, "smooth")
				if mat and not mat:IsError() then
					sprites[name] = mat
					break
				end
			end
			if not sprites[name] then sprites[name] = false end
		end
	end
	
	local limbs = {
		{name = "head", dmg = math_max(getOrgVal(org, "skull", 0), getOrgVal(org, "jaw", 0) * 0.7, getOrgVal(org, "brain", 0) * 0.8), amput = "headamputated", label = "H"},
		{name = "torso", dmg = math_max(getOrgVal(org, "chest", 0), getOrgVal(org, "spine1", 0), getOrgVal(org, "spine2", 0), getOrgVal(org, "spine3", 0), getOrgVal(org, "pelvis", 0) * 0.9), amput = nil, label = "T"},
		{name = "right_arm", dmg = getOrgVal(org, "rarm", 0), amput = "rarmamputated", label = "RA"},
		{name = "left_arm", dmg = getOrgVal(org, "larm", 0), amput = "larmamputated", label = "LA"},
		{name = "right_leg", dmg = getOrgVal(org, "rleg", 0), amput = "rlegamputated", label = "RL"},
		{name = "left_leg", dmg = getOrgVal(org, "lleg", 0), amput = "llegamputated", label = "LL"},
	}
	
	for _, limb in ipairs(limbs) do
		if not (limb.amput and org[limb.amput]) then
			local dmg = limb.dmg
			local ofs = HUD.limb_offsets[limb.name] or {x = 0, y = 0}
			local scale = HUD.limb_scale[limb.name] or {w = 1.0, h = 1.0}
			
			local x = base_x + ofs.x
			local y = base_y + ofs.y
			
			local base_size = 40
			local width = base_size * scale.w
			local height = base_size * scale.h
			
			local col = getLimbColor(dmg)
			local damage_boost = math_min(dmg * 150, 100)
			local total_visibility = math_min(HUD.sprite_visibility + damage_boost, 100)
			local alpha = math_floor(total_visibility / 100 * 255)
			
			local mat = sprites[limb.name]
			if mat and not mat:IsError() then
				surface_SetDrawColor(col.r, col.g, col.b, alpha)
				surface_SetMaterial(mat)
				surface_DrawTexturedRect(x - width * 0.5, y - height * 0.5, width, height)
			else
				surface_SetDrawColor(0, 0, 0, math_floor(alpha * 0.5))
				surface_DrawRect(x - width * 0.5 + 2, y - height * 0.5 + 2, width - 4, height - 4)
				surface_SetDrawColor(col.r, col.g, col.b, alpha)
				surface_DrawRect(x - width * 0.5 + 4, y - height * 0.5 + 4, width - 8, height - 8)
				draw_SimpleText(limb.label, "TargetID", x, y, Color(255, 255, 255, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
		end
	end
end

-- Register hooks
hook.Add("HUDPaint", "ZB_Health_Bar", draw_bar)
hook.Add("HUDPaint", "ZB_Health_Sprites", draw_sprites)
hook.Add("HUDPaint", "ZB_Health_StatusEffects", draw_status_effects)
hook.Add("HUDPaint", "ZB_Health_StatusTooltips", draw_status_tooltips)

--================================================================================
-- Console commands
--================================================================================
concommand.Add("zb_health_toggle", function(ply, cmd, args)
	HUD.enabled = args[1] and (tonumber(args[1]) ~= 0) or not HUD.enabled
	chat.AddText(Color(0, 200, 255), "[ZB HUD] ", HUD.enabled and "Enabled" or "Disabled")
end)

concommand.Add("zb_health_reload", function()
	sprites = {}
	icons = {}
	status_sprites = {level_backgrounds = {nil, nil, nil, nil}}
	status_sprites_loaded = false
	debug_done = false
	statusEffectAppearance = {}
	statusEffectPositions = {}
	tooltipHoverTime = {}
	lastHoveredStatus = nil
	smooth = {blood = 5000, conscious = 1.0, pain = 0, pulse = 70, assimilation = 0, o2 = 100, bleed = 0, internalBleed = 0}
	stability = {
		blood = {last_value = 5000, last_change = CurTime(), hidden = false},
		pulse = {last_value = 70, last_change = CurTime(), hidden = false},
	}
	chat.AddText(Color(0, 200, 255), "[ZB HUD] Reloaded successfully")
end)

concommand.Add("zb_health_alt_icons", function(ply, cmd, args)
	HUD.use_alt_icons = not HUD.use_alt_icons
	icons = {}
	status_sprites = {level_backgrounds = {nil, nil, nil, nil}}
	status_sprites_loaded = false
	chat.AddText(Color(0, 200, 255), "[ZB HUD] Alternative icons: ", HUD.use_alt_icons and Color(100, 255, 100, 255) or Color(255, 100, 100, 255), HUD.use_alt_icons and "ON" or "OFF")
end)

concommand.Add("zb_health_smooth", function(ply, cmd, args)
	if args[1] then
		local v = tonumber(args[1])
		if v then
			HUD.smooth = math.Clamp(v, 0, 1)
			chat.AddText(Color(0, 200, 255), "[ZB HUD] Smoothness: ", Color(255, 255, 255), tostring(HUD.smooth))
		end
	end
end)

concommand.Add("zb_health_alpha", function(ply, cmd, args)
	if args[1] then
		local v = tonumber(args[1])
		if v then
			HUD.sprite_visibility = math.Clamp(v, 0, 100)
			chat.AddText(Color(0, 200, 255), "[ZB HUD] Limb visibility: ", Color(255, 255, 255), HUD.sprite_visibility .. "%")
		end
	end
end)

concommand.Add("zb_health_limbs", function(ply, cmd, args)
	HUD.always_show_limbs = not HUD.always_show_limbs
	chat.AddText(Color(0, 200, 255), "[ZB HUD] Limbs always visible: ", HUD.always_show_limbs and Color(100, 255, 100, 255) or Color(255, 100, 100, 255), HUD.always_show_limbs and "ON" or "OFF")
end)

concommand.Add("zb_health_bar_scale", function(ply, cmd, args)
	if args[1] then
		local v = tonumber(args[1])
		if v then
			HUD.bar_scale = math.Clamp(v, 0.5, 2.5)
			local pct = math_floor(HUD.bar_scale * 100)
			chat.AddText(Color(0, 200, 255), "[ZB HUD] Status bar scale: ", Color(255, 255, 255), HUD.bar_scale .. "x (" .. pct .. "%)")
		end
	end
end)

concommand.Add("zb_health_showall", function()
	stability.blood.hidden = false
	stability.blood.last_change = CurTime() - HUD.stable_time - 1
	stability.pulse.hidden = false
	stability.pulse.last_change = CurTime() - HUD.stable_time - 1
	chat.AddText(Color(0, 200, 255), "[ZB HUD] All parameters forced visible")
end)

concommand.Add("zb_health_percent", function(ply, cmd, args)
	HUD.show_damage_percent = not HUD.show_damage_percent
	chat.AddText(Color(0, 200, 255), "[ZB HUD] Limb damage percent: ", HUD.show_damage_percent and Color(100, 255, 100, 255) or Color(255, 100, 100, 255), HUD.show_damage_percent and "ON" or "OFF")
end)

concommand.Add("zb_health_status", function(ply, cmd, args)
	HUD.show_status_effects = not HUD.show_status_effects
	chat.AddText(Color(0, 200, 255), "[ZB HUD] Status effects: ", HUD.show_status_effects and Color(100, 255, 100, 255) or Color(255, 100, 100, 255), HUD.show_status_effects and "ON" or "OFF")
end)

--================================================================================
-- Initialization
--================================================================================
hook.Add("InitPostEntity", "ZB_Health_Init", function()
	timer.Simple(1, function()
		chat.AddText(Color(100, 200, 255), "[zcity health hud loaded!]\n type zb_health in console to view more commands")
	end)
end)