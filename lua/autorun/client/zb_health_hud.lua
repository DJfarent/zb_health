--========================================================
-- SIMPLE LIMB HUD
-- Shows ONLY limb damage
--========================================================

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


--========================================================
-- CLIENT
--========================================================

local surface_SetDrawColor = surface.SetDrawColor
local surface_SetMaterial = surface.SetMaterial
local surface_DrawTexturedRect = surface.DrawTexturedRect
local draw_SimpleText = draw.SimpleText

local sprites = {}

local HUD = {
	base_x = nil,
	base_y = 80
}

--========================================================
-- Load sprites
--========================================================

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

--========================================================
-- Limb state system
--========================================================

local function getLimbState(dmg, amputated)

	if amputated then
		return 3
	end

	if dmg >= 0.9 then
		return 2
	end

	if dmg >= 0.4 then
		return 1
	end

	return 0

end


local function getLimbColor(state)

	if state == 0 then
		return Color(130,130,130)
	elseif state == 1 then
		return Color(255,200,40)
	elseif state == 2 then
		return Color(255,60,60)
	end

	return Color(255,255,255)

end


--========================================================
-- Draw limbs
--========================================================

local function draw_limbs()

	local ply = LocalPlayer()
	if not IsValid(ply) or not ply.organism then return end

	loadSprites()

	if HUD.base_x == nil then
		HUD.base_x = ScrW() - 120
	end

	local org = ply.organism
	local x = HUD.base_x
	local y = HUD.base_y

	local limbs = {

		{name="head", dmg=math.max(org.skull or 0, org.brain or 0), amput=nil},

		{name="torso", dmg=math.max(org.chest or 0, org.spine1 or 0, org.spine2 or 0), amput=nil},

		{name="right_arm", dmg=org.rarm or 0, amput="rarmamputated"},

		{name="left_arm", dmg=org.larm or 0, amput="larmamputated"},

		{name="right_leg", dmg=org.rleg or 0, amput="rlegamputated"},

		{name="left_leg", dmg=org.lleg or 0, amput="llegamputated"}

	}

	local spacing = 45

	for i, limb in ipairs(limbs) do

		local amputated = limb.amput and org[limb.amput]

		local state = getLimbState(limb.dmg, amputated)

		-- hide severed limbs
		if state ~= 3 then

			local col = getLimbColor(state)
			local mat = sprites[limb.name]

			if mat and not mat:IsError() then

				surface_SetDrawColor(col.r,col.g,col.b,255)
				surface_SetMaterial(mat)

				surface_DrawTexturedRect(
					x,
					y + (i-1)*spacing,
					40,
					40
				)

			end

		end

	end

end

hook.Add("HUDPaint","ZB_Simple_LimbHUD",draw_limbs)