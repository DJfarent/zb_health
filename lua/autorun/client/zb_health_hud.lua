if SERVER then
	local SPRITES = {
		"materials/vgui/hud/health_head.png",
		"materials/vgui/hud/health_torso.png",
		"materials/vgui/hud/health_right_arm.png",
		"materials/vgui/hud/health_left_arm.png",
		"materials/vgui/hud/health_right_leg.png",
		"materials/vgui/hud/health_left_leg.png",
	}

	for i=1,#SPRITES do
		resource.AddFile(SPRITES[i])
	end

	AddCSLuaFile()
	return
end

local surface_SetDrawColor = surface.SetDrawColor
local surface_SetMaterial = surface.SetMaterial
local surface_DrawTexturedRect = surface.DrawTexturedRect

surface.CreateFont("ZB_LimbFont",{
	font="Bahnschrift",
	size=27,
	weight=1000,
	antialias=true
})

local HUD_X = -100
local HUD_Y = 940
local SIZE = 200

local IDLE_ALPHA = 80
local FULL_ALPHA = 255

local sprites = {
	head = Material("vgui/hud/health_head.png","smooth"),
	torso = Material("vgui/hud/health_torso.png","smooth"),
	left_arm = Material("vgui/hud/health_left_arm.png","smooth"),
	right_arm = Material("vgui/hud/health_right_arm.png","smooth"),
	left_leg = Material("vgui/hud/health_left_leg.png","smooth"),
	right_leg = Material("vgui/hud/health_right_leg.png","smooth")
}

local dmg_head = 0
local dmg_torso = 0
local dmg_larm = 0
local dmg_rarm = 0
local dmg_lleg = 0
local dmg_rleg = 0

local status_text = ""

local function getState(dmg,amp)
	if amp then return 3 end
	if dmg >= 0.9 then return 2 end
	if dmg >= 0.4 then return 1 end
	return 0
end

local function getColor(state)
	if state==0 then return 130,130,130
	elseif state==1 then return 255,200,40
	elseif state==2 then return 255,60,60 end
	return 255,255,255
end

hook.Add("Think","ZB_UpdateLimbCache",function()

	local ply = LocalPlayer()
	if not IsValid(ply) then return end

	local org = ply.organism
	if not org then return end

	dmg_head = math.max(org.skull or 0,org.brain or 0)
	dmg_torso = math.max(org.chest or 0,org.spine1 or 0,org.spine2 or 0)
	dmg_larm = org.larm or 0
	dmg_rarm = org.rarm or 0
	dmg_lleg = org.lleg or 0
	dmg_rleg = org.rleg or 0

	local s1 = getState(dmg_head)
	local s2 = getState(dmg_torso)
	local s3 = getState(dmg_larm,org.larmamputated)
	local s4 = getState(dmg_rarm,org.rarmamputated)
	local s5 = getState(dmg_lleg,org.llegamputated)
	local s6 = getState(dmg_rleg,org.rlegamputated)

	local t=""

	if s1==1 then t=t.."Head:M Pain | " elseif s1==2 then t=t.."Head:HPain | " end
	if s2==1 then t=t.."Torso:M Pain | " elseif s2==2 then t=t.."Torso:HPain | " end
	if s3==1 then t=t.."LArm:M Pain | " elseif s3==2 then t=t.."LArm:HPain | " end
	if s4==1 then t=t.."RArm:M Pain | " elseif s4==2 then t=t.."RArm:HPain | " end
	if s5==1 then t=t.."LLeg:M Pain | " elseif s5==2 then t=t.."LLeg:HPain | " end
	if s6==1 then t=t.."RLeg:M Pain | " elseif s6==2 then t=t.."RLeg:HPain | " end

	status_text = t

end)

local function draw_limb(mat,x,y,state)

	if state==3 then return end

	local r,g,b = getColor(state)
	local alpha = IDLE_ALPHA

	if state==1 or state==2 then
		alpha = FULL_ALPHA
	end

	surface_SetDrawColor(r,g,b,alpha)
	surface_SetMaterial(mat)
	surface_DrawTexturedRect(x,y,SIZE,SIZE)

end

hook.Add("HUDPaint","ZB_LimbHUD",function()

	local x = HUD_X
	local y = HUD_Y

	local s1 = getState(dmg_head)
	local s2 = getState(dmg_torso)
	local s3 = getState(dmg_larm)
	local s4 = getState(dmg_rarm)
	local s5 = getState(dmg_lleg)
	local s6 = getState(dmg_rleg)

	draw_limb(sprites.head,x+SIZE/2,y+SIZE,s1)
	draw_limb(sprites.torso,x+SIZE/2,y+SIZE,s2)
	draw_limb(sprites.left_arm,x+SIZE*0.5,y+SIZE,s3)
	draw_limb(sprites.right_arm,x+SIZE*0.5,y+SIZE,s4)
	draw_limb(sprites.left_leg,x+SIZE*0.5,y+SIZE,s5)
	draw_limb(sprites.right_leg,x+SIZE*0.5,y+SIZE,s6)

	draw.SimpleText(status_text,"ZB_LimbFont",x+120,y+425,Color(0,0,0,200),TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
	draw.SimpleText(status_text,"ZB_LimbFont",x+118,y+423,Color(255,0,0),TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)

end)