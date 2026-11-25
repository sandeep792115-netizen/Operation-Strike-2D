# OPERATION STRIKE 2D

A Godot 4.x, Android-first, side-view cartoon military shooter prototype. The project uses procedural placeholder art drawn in GDScript, so it has no external asset dependencies.

## Current playable prototype

- Landscape side-view battlefield with a scrolling camera.
- Left virtual joystick: horizontal movement.
- Right virtual joystick: 360-degree aim **and hold-to-fire**. Returning the stick to neutral stops firing; weapon fire rates are respected.
- Independent multitouch tracking for both joysticks.
- Jump and toggle jetpack controls.
- Pistol, SMG, rifle and shotgun with different fire rates, damage, spread and magazines.
- Reload and weapon switching.
- Basic enemy bots that approach and shoot at the player.
- Practice, Team Deathmatch, Gun Game and Battle Royale mode selector foundation.
- Kill progression in Gun Game prototype.
- Randomized pickups: weapons, ammo, bandages, medkits, adrenaline, frag, sticky, smoke, stun and Golden Heart.
- Golden Heart: 2x effective HP for 15 seconds; on expiry HP is clamped to normal maximum.
- Frag/sticky explosions, smoke clouds and stun effects.
- Keyboard/mouse support for desktop testing.

## Important scope note

This is **Milestone 1: a playable offline prototype**, not the complete game. The mode selector and combat foundations are present, but the full production versions of TDM, Gun Game, Battle Royale, eight distinct maps, sophisticated AI, matchmaking, accounts, and dedicated-server multiplayer are not yet implemented. The current bots are local offline AI. No online mode is falsely presented as working.

## Open in Godot

1. Install Godot 4.3 or a compatible Godot 4.x stable release.
2. Import this folder by opening `project.godot` in Godot.
3. Press Play (F6/F5 depending on editor setup).
4. Set the game window to landscape for desktop testing.

## Controls

### Mobile (landscape)
- Bottom-left joystick: move left/right.
- Bottom-right joystick: aim and fire. Push in a direction to aim and shoot; release to stop.
- Top-right buttons: jump, jetpack, reload, swap weapon, quick heal, Golden Heart, frag, smoke, sticky and stun.
- Touch IDs are tracked independently so the two joysticks can be used simultaneously.

### Desktop test controls
- A/D or Left/Right: move.
- Space/W/Up: jump.
- Mouse: aim and fire.
- R: reload.
- Q: switch weapon.

## Android export

The repository includes an Android export preset and a GitHub Actions workflow. Android export requires matching Godot export templates and Android build tools. The workflow attempts a cloud APK build and uploads the artifact; if the selected CI image lacks a required Android SDK component, inspect the workflow log and update the image/toolchain rather than treating an unverified build as successful.

For a signed public release, configure a private keystore and GitHub Actions secrets. Never commit keystores or passwords.

## Multiplayer roadmap

Online multiplayer is not implemented in this prototype yet. A real online implementation needs a dedicated authoritative server, server-validated movement/combat/pickups, lobby/matchmaking, deployment hosting, and network tests with multiple clients. GitHub Actions builds artifacts; it does not host a continuously running game server.
