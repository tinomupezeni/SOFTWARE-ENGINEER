# PROJECT SHADOW (Eminence in Shadow RPG) - PROJECT MEMORY

## Overview
A third-person stylized action RPG and living underground faction simulation inspired by *The Eminence in Shadow*. 
The core gameplay philosophy balances the player's private chuunibyou power fantasy against a world that operates autonomously and takes every fabricated conspiracy with absolute seriousness.

## Core Pillars
1. **The Shadow (Protagonist & Combat)**: Stylized anime action with time dilation, hit-stop, extreme contrast impact frames, audio vacuums, and kinematic precision.
2. **The Organisation (Shadow Garden)**: Autonomous lieutenants who interpret vague/absurd player directives, execute clandestine missions, and build empires.
3. **The Conspiracy (Emergent Reality)**: A procedural knowledge graph engine that retroactively anchors player fabrications into actual underground conspiracies.

## Architecture Blueprint
- **Loop**: 120Hz deterministic fixed sub-stepped physics and gameplay simulation decoupled from uncapped rendering interpolation.
- **Physics**: Custom Kinematic Character Controller (KCC) with swept capsule bilinear continuous collision detection (CCD) and Verlet/PBD secondary motion (cloth/coat/slime).
- **Presentation**: Custom Forward/Deferred hybrid cel-shader with inverted hull outline extrusion, ramp LUTs, and non-linear trauma camera shake.
- **AI & Logic**: Gameplay Ability System (GAS), Hierarchical Finite State Machines (HFSM) for dual-identity masking, and Behavior Trees for autonomous followers.

## Current State
- Initial game architecture compendium researched and authored at `GAME_DEVELOPMENT_COMPENDIUM.md`.
