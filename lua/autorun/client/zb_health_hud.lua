if SERVER then
	local SPRITES = {
		"materials/vgui/hud/health_head.png",
		"materials/vgui/hud/health_torso.png",
		"materials/vgui/hud/health_right_arm.png",
		"materials/vgui/hud/health_left_arm.png",
		"materials/vgui/hud/health_right_leg.png",
		"materials/vgui/hud/health_left_leg.png",
	}

	for _, path in ipairs(SPRITES) do
		resource.AddFile(path)
	end

	AddCSLuaFile()
	return
end

local surface_SetDrawColor = surface.SetDrawColor
local surface_SetMaterial = surface.SetMaterial
local surface_DrawTexturedRect = surface.DrawTexturedRect

local sprites = {}

local function loadSprites()
	if sprites.loaded then return end
	sprites.loaded = true
	sprites.head = Material("vgui/hud/health_head.png","smooth")
	sprites.torso = Material("vgui/hud/health_torso.png","smooth")
	sprites.right_arm = Material("vgui/hud/health_right_arm.png","smooth")
	sprites.left_arm = Material("vgui/hud/health_left_arm.png","smooth")
	sprites.right_leg = Material("vgui/hud/health_right_leg.png","smooth")
	sprites.left_leg = Material("vgui/hud/health_left_leg.png","smooth")
end

local HUD = { base_x = -100, base_y = 940 } 
local size = 200            
local FLASH_TIME = 1.0      
local IDLE_ALPHA = 80       
local FULL_ALPHA = 255      

local limb_flash = {
	head = 0,
	torso = 0,
	left_arm = 0,
	right_arm = 0,
	left_leg = 0,
	right_leg = 0,
}

local function getLimbState(dmg, amputated)
	if amputated then return 3 end
	if dmg >= 0.9 then return 2 end
	if dmg >= 0.4 then return 1 end
	return 0
end

local function getLimbColor(state)
	if state == 0 then return Color(130,130,130)
	elseif state == 1 then return Color(255,200,40)
	elseif state == 2 then return Color(255,60,60) end
	return Color(255,255,255)
end

hook.Add("Think", "UpdateLimbFlashTimers", function()
	local ply = LocalPlayer()
	if not IsValid(ply) or not ply.organism then return end

	for limbName, _ in pairs(limb_flash) do
		local dmg = ply.organism[limbName] or 0
		if ply.organism["_last_"..limbName] == nil then ply.organism["_last_"..limbName] = dmg end

		if dmg > ply.organism["_last_"..limbName] then
			limb_flash[limbName] = FLASH_TIME
		end

		ply.organism["_last_"..limbName] = dmg

		if limb_flash[limbName] > 0 then
			limb_flash[limbName] = math.max(limb_flash[limbName] - FrameTime(), 0)
		end
	end
end)

local function draw_limbs()
	local ply = LocalPlayer()
	if not IsValid(ply) or not ply.organism then return end

	loadSprites()

	local org = ply.organism
	local x = HUD.base_x
	local y = HUD.base_y

	local limb_positions = {
		head       = {x = x + size/2, y = y + size*1},
		torso      = {x = x + size/2, y = y + size},      
		left_arm   = {x = x - size*-0.5, y = y + size},     
		right_arm  = {x = x + size*0.5, y = y + size},    
		left_leg   = {x = x + size*0.50, y = y + size*1}, 
		right_leg  = {x = x + size*0.50, y = y + size*1},  
	}

	local limbs = {
		{name="head", dmg=math.max(org.skull or 0, org.brain or 0), amput=nil},
		{name="torso", dmg=math.max(org.chest or 0, org.spine1 or 0, org.spine2 or 0), amput=nil},
		{name="right_arm", dmg=org.rarm or 0, amput="rarmamputated"},
		{name="left_arm", dmg=org.larm or 0, amput="larmamputated"},
		{name="right_leg", dmg=org.rleg or 0, amput="rlegamputated"},
		{name="left_leg", dmg=org.lleg or 0, amput="llegamputated"},
	}

	for _, limb in ipairs(limbs) do
		local amputated = limb.amput and org[limb.amput]
		local state = getLimbState(limb.dmg, amputated)

		if state ~= 3 then
			local col = getLimbColor(state)
			local mat = sprites[limb.name]
			if mat and not mat:IsError() then
				local alpha = IDLE_ALPHA
				if state == 1 or state == 2 then
					alpha = FULL_ALPHA
				end
				if limb_flash[limb.name] > 0 then
					alpha = math.max(alpha, IDLE_ALPHA + (FULL_ALPHA - IDLE_ALPHA) * (limb_flash[limb.name] / FLASH_TIME))
				end

				surface_SetDrawColor(col.r, col.g, col.b, alpha)
				surface_SetMaterial(mat)
				local pos = limb_positions[limb.name]
				surface_DrawTexturedRect(pos.x, pos.y, size, size)
			end
		end
	end
end

local function draw_limb_status()
	local ply = LocalPlayer()
	if not IsValid(ply) or not ply.organism then return end

	local x = HUD.base_x - -120
	local y = HUD.base_y - -425 
	local org = ply.organism

	local limb_map = {
		head       = {"skull","brain"},
		torso      = {"chest","spine1","spine2"},
		left_arm   = {"larm"},
		right_arm  = {"rarm"},
		left_leg   = {"lleg"},
		right_leg  = {"rleg"}
	}

	local display_names = {
		head = "Head",
		torso = "Torso",
		left_arm = "LArm",
		right_arm = "RArm",
		left_leg = "LLeg",
		right_leg = "RLeg"
	}

	local status_texts = {}

	for limbName, organs in pairs(limb_map) do
		local dmg = 0
		for _, organ in ipairs(organs) do
			dmg = math.max(dmg, org[organ] or 0)
		end

		local amput = org[limbName.."amputated"]
		local state = getLimbState(dmg, amput)

		local status = ""
		if state == 0 then
			status = "✓"
		elseif state == 1 then
			status = "M Pain"
		elseif state == 2 then
			status = "HPain"
		end

		table.insert(status_texts, display_names[limbName]..": "..status)
	end

	local final_text = table.concat(status_texts, "   |   ")

	surface.CreateFont("ZB_LimbFont", {
		font = "Bahnschrift",
		size = 27,
		weight = 900,
		antialias = true
	})

	draw.SimpleText(final_text, "ZB_LimbFont", x + 2.5, y + 2, Color(0,0,0,200), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	draw.SimpleText(final_text, "ZB_LimbFont", x, y, Color(255,0,0,255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end

hook.Add("HUDPaint","ZB_Simple_LimbHUD",function()
	draw_limbs()
	draw_limb_status()
end)
