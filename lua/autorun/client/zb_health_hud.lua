if SERVER then
	local SPRITES = {
		"materials/vgui/hud/health_head.png",
		"materials/vgui/hud/health_torso.png",
		"materials/vgui/hud/health_right_arm.png",
		"materials/vgui/hud/health_left_arm.png",
		"materials/vgui/hud/health_right_leg.png",
		"materials/vgui/hud/health_left_leg.png"
	}

	for i=1,#SPRITES do
		resource.AddFile(SPRITES[i])
	end

	AddCSLuaFile()
	return
end

surface.CreateFont("ZB_LimbFont",{
	font="Bahnschrift",
	size=27,
	weight=1000,
	antialias=true
})

local surface_SetDrawColor = surface.SetDrawColor
local surface_SetMaterial = surface.SetMaterial
local surface_DrawTexturedRect = surface.DrawTexturedRect

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

local dmg = {
	head = 0,
	torso = 0,
	larm = 0,
	rarm = 0,
	lleg = 0,
	rleg = 0
}

local last = {
	head = -1,
	torso = -1,
	larm = -1,
	rarm = -1,
	lleg = -1,
	rleg = -1
}

local state = {
	head = 0,
	torso = 0,
	larm = 0,
	rarm = 0,
	lleg = 0,
	rleg = 0
}

local status_text = ""

local function getState(dmg,amp)
	if amp then return 3 end
	if dmg >= 0.9 then return 2 end
	if dmg >= 0.4 then return 1 end
	return 0
end

local function getColor(st)
	if st==0 then return 130,130,130
	elseif st==1 then return 255,200,40
	elseif st==2 then return 255,60,60 end
	return 255,255,255
end

local function rebuildStatus()

	local t=""

	if state.head==1 then t=t.."Head:M Pain | " elseif state.head==2 then t=t.."Head:HPain | " end
	if state.torso==1 then t=t.."Torso:M Pain | " elseif state.torso==2 then t=t.."Torso:HPain | " end
	if state.larm==1 then t=t.."LArm:M Pain | " elseif state.larm==2 then t=t.."LArm:HPain | " end
	if state.rarm==1 then t=t.."RArm:M Pain | " elseif state.rarm==2 then t=t.."RArm:HPain | " end
	if state.lleg==1 then t=t.."LLeg:M Pain | " elseif state.lleg==2 then t=t.."LLeg:HPain | " end
	if state.rleg==1 then t=t.."RLeg:M Pain | " elseif state.rleg==2 then t=t.."RLeg:HPain | " end

	status_text = t

end

local nextCheck = 0

hook.Add("Think","ZB_LimbUpdate",function()

	if CurTime() < nextCheck then return end
	nextCheck = CurTime() + 0.1

	local ply = LocalPlayer()
	if not IsValid(ply) then return end

	local org = ply.organism
	if not org then return end

	dmg.head = math.max(org.skull or 0,org.brain or 0)
	dmg.torso = math.max(org.chest or 0,org.spine1 or 0,org.spine2 or 0)
	dmg.larm = org.larm or 0
	dmg.rarm = org.rarm or 0
	dmg.lleg = org.lleg or 0
	dmg.rleg = org.rleg or 0

	local changed=false

	if dmg.head ~= last.head then
		last.head = dmg.head
		state.head = getState(dmg.head)
		changed=true
	end

	if dmg.torso ~= last.torso then
		last.torso = dmg.torso
		state.torso = getState(dmg.torso)
		changed=true
	end

	if dmg.larm ~= last.larm then
		last.larm = dmg.larm
		state.larm = getState(dmg.larm,org.larmamputated)
		changed=true
	end

	if dmg.rarm ~= last.rarm then
		last.rarm = dmg.rarm
		state.rarm = getState(dmg.rarm,org.rarmamputated)
		changed=true
	end

	if dmg.lleg ~= last.lleg then
		last.lleg = dmg.lleg
		state.lleg = getState(dmg.lleg,org.llegamputated)
		changed=true
	end

	if dmg.rleg ~= last.rleg then
		last.rleg = dmg.rleg
		state.rleg = getState(dmg.rleg,org.rlegamputated)
		changed=true
	end

	if changed then
		rebuildStatus()
	end

end)

local function drawLimb(mat,x,y,st)

	if st==3 then return end

	local r,g,b = getColor(st)

	local alpha = IDLE_ALPHA
	if st==1 or st==2 then alpha = FULL_ALPHA end

	surface_SetDrawColor(r,g,b,alpha)
	surface_SetMaterial(mat)
	surface_DrawTexturedRect(x,y,SIZE,SIZE)

end

hook.Add("HUDPaint","ZB_LimbHUD",function()

	local x=HUD_X
	local y=HUD_Y

	drawLimb(sprites.head,x+SIZE/2,y+SIZE,state.head)
	drawLimb(sprites.torso,x+SIZE/2,y+SIZE,state.torso)
	drawLimb(sprites.left_arm,x+SIZE*0.5,y+SIZE,state.larm)
	drawLimb(sprites.right_arm,x+SIZE*0.5,y+SIZE,state.rarm)
	drawLimb(sprites.left_leg,x+SIZE*0.5,y+SIZE,state.lleg)
	drawLimb(sprites.right_leg,x+SIZE*0.5,y+SIZE,state.rleg)

	draw.SimpleText(status_text,"ZB_LimbFont",x+120,y+425,Color(0,0,0,200),TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
	draw.SimpleText(status_text,"ZB_LimbFont",x+118,y+423,Color(255,0,0),TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)

end)