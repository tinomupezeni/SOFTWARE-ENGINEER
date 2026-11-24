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
- **Phase 0 & 1 Complete**: Evaluated Godot 4.7.2 with Compatibility renderer; established Four-Layer Architecture and Headless Simulation separation.
- **Milestone 2.2 Complete**: Single-threaded WebAssembly export verified with IndexedDB persistence.
- **Milestone 2.3 Complete**: Top-down 2D Oakhaven Outskirts, 8-directional player, NPC raycast line-of-sight cones, observable appearance decoupling, and alleyway persona switching verified.
- **Milestone 2.4 Complete**: First follower-command loop implemented. Abandoned shed trapdoor transitions to Sanctuary Interior. Alpha NPC recruited with cognitive profile and Shadow Parable Bias. Command Desk UI (3-slot directive builder) and Parchment Debrief UI with player responses. CausalResolutionEngine resolves operations against authoritative WorldKnowledgeGraph facts, generating ActualWorldEvents and FalseConclusions without altering ground truth. All 16 headless unit tests passing; browser bundle updated.
