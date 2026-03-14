ZB Simple Limb HUD

A lightweight Garry’s Mod HUD for Z-City that displays only limb damage. 
This mod removes complex medical UI (blood, organs, pulse, oxygen, etc.) 
and focuses purely on limb condition.

The goal is a clean, minimal injury system that players can read instantly during gameplay.

Features:
- Displays 6 limbs only:
  - Head
  - Torso
  - Left Arm
  - Right Arm
  - Left Leg
  - Right Leg

- 4 limb states:
  - Healthy – Gray
  - Injured – Yellow
  - Broken – Red
  - Severed – Hidden

- Automatic sprite coloring based on damage level
- Amputated limbs are hidden
- Very lightweight HUD (no unnecessary calculations or UI clutter)
- Designed specifically for Z-City organism damage values

Design Philosophy:
Most Z-City HUD mods include multiple systems:
- Blood meters
- Oxygen meters
- Pulse meters
- Organ damage indicators
- Moodles
- Stamina systems

This mod intentionally removes all but one core mechanic: limb damage.

The result is a HUD that is:
- Easier to read
- Less distracting
- More immersive during combat

Limb Damage States:
State       Description           Color
Healthy     No serious damage     Gray
Injured     Moderate damage       Yellow
Broken      Severe damage         Red
Severed     Limb amputated        Hidden

Installation:
1. Place the Lua file inside your Garry’s Mod addon:
   garrysmod/addons/zb_simple_limb_hud/lua/autorun/
2. Ensure the following materials exist:
   materials/vgui/hud/health_head.png
   materials/vgui/hud/health_torso.png
   materials/vgui/hud/health_right_arm.png
   materials/vgui/hud/health_left_arm.png
   materials/vgui/hud/health_right_leg.png
   materials/vgui/hud/health_left_leg.png
3. Restart the server or reload Lua. The HUD will automatically appear when joining the server.

Requirements:
- Garry's Mod
- Z-City gamemode
- The HUD reads damage values from: ply.organism

Customization:
HUD position can be changed inside the script:
HUD.base_x = ScrW() - 120
HUD.base_y = 80

Performance:
This HUD is designed to be very lightweight. It only:
- Reads limb damage
- Converts it to a state
- Draws the limb sprite

No expensive status systems or heavy UI logic.

Future Ideas:
- Limb break notifications
- Cleaner UI

License:
Free to use and modify for Garry’s Mod servers.

Author / Credits:
Created for Z-City servers as a minimal limb-based health HUD.
Original Z-City inspiration / credit:
https://steamcommunity.com/sharedfiles/filedetails/?id=3662920449&searchtext=zcity
