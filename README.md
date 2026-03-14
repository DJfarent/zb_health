==============================
      ZB SIMPLE LIMB HUD
==============================

A lightweight Garry’s Mod HUD for Z-City that shows only **limb damage**.  
This mod removes complex medical UI (blood, organs, pulse, oxygen, etc.) and focuses purely on limb condition.  

Goal: A **clean, minimal injury system** that players can read instantly during gameplay.

------------------------------
         FEATURES
------------------------------

- Displays 6 limbs only:
    • Head
    • Torso
    • Left Arm
    • Right Arm
    • Left Leg
    • Right Leg

- 4 limb states:
    • Healthy – Gray
    • Injured – Yellow
    • Broken – Red
    • Severed – Hidden

- Automatic sprite coloring based on damage level
- Amputated limbs are hidden
- Very lightweight HUD
- Designed specifically for Z-City organism damage values

------------------------------
     DESIGN PHILOSOPHY
------------------------------

Most Z-City HUD mods include multiple systems:
- Blood meters
- Oxygen meters
- Pulse meters
- Organ damage indicators
- Moodles
- Stamina systems

This mod intentionally removes all but **one core mechanic**: limb damage.

Resulting HUD is:
- Easier to read
- Less distracting
- More immersive during combat

------------------------------
      LIMB DAMAGE STATES
------------------------------

State      | Description        | Color
----------------------------------------
Healthy    | No serious damage  | Gray
Injured    | Moderate damage    | Yellow
Broken     | Severe damage      | Red
Severed    | Limb amputated     | Hidden

------------------------------
        INSTALLATION
------------------------------

1. Place the Lua file in your Garry’s Mod addon:
   garrysmod/addons/zb_simple_limb_hud/lua/autorun/

2. Ensure the following materials exist:
   materials/vgui/hud/health_head.png
   materials/vgui/hud/health_torso.png
   materials/vgui/hud/health_right_arm.png
   materials/vgui/hud/health_left_arm.png
   materials/vgui/hud/health_right_leg.png
   materials/vgui/hud/health_left_leg.png

3. Restart the server or reload Lua.  
   HUD will automatically appear when joining the server.

------------------------------
       REQUIREMENTS
------------------------------

- Garry's Mod
- Z-City gamemode
- HUD reads damage values from: `ply.organism`

------------------------------
       CUSTOMIZATION
------------------------------

Change HUD position inside the script:

HUD.base_x = ScrW() - 120  
HUD.base_y = 80

------------------------------
        PERFORMANCE
------------------------------

Very lightweight:  
- Reads limb damage  
- Converts it to a state  
- Draws the limb sprite  

No heavy UI logic or extra calculations.

------------------------------
        FUTURE IDEAS
------------------------------

- Limb break notifications  
- Cleaner UI design

------------------------------
        LICENSE
------------------------------

Free to use and modify for Garry’s Mod servers.

------------------------------
       AUTHOR / CREDITS
------------------------------

Created for Z-City servers as a minimal limb-based health HUD.

Original Z-City inspiration / credit:  
https://steamcommunity.com/sharedfiles/filedetails/?id=3662920449&searchtext=zcity

==============================
