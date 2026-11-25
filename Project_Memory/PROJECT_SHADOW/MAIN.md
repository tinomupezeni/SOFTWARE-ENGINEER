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
- **Milestone 2.5 Complete (2026-11-25)**: Shadow Persona dialogue system implemented per owner authorization — deterministic, template-only, fully offline (no remote LLM, no backend, no network, no API keys). `DramaticEventDetector` + `ShadowKnowledgeFilter` + `TemplateDialogueGenerator` + `ShadowPersonaAgent` produce a validated `ShadowLine` from a `ShadowDialogueContext` for two real gameplay events (Alpha recruitment, mission debrief resolution — combat-dependent triggers explicitly deferred until Milestone 3's combat loop exists, no placeholder combat was built). `CinematicDirector2D` presents the beat via `Camera2D` zoom + a modest `Engine.time_scale` dip, reusing the existing `DialogueBox`. `AlphaProfile.evaluate_shadow_line()` lets Alpha subjectively (mis)interpret cryptic lines through her existing Parable Bias without ever mutating `WorldKnowledgeGraph` or auto-dispatching a mission. Knowledge boundary enforced structurally (no method signature in the pipeline accepts a `WorldKnowledgeGraph`/`VerifiedFactNode`). 33 headless tests passing (17 new), browser export re-verified to include all new files; interactive in-browser playthrough was **not** captured this session (no browser automation tool reachable in the environment) — open verification gap. Commit `8fdf63f`.

### ⚠️ Architecture doc / actual implementation drift (found during M2.5 audit, partially addressed)
The "Architecture Blueprint" section above (and parts of `docs/PROJECT_STRUCTURE.md`/`docs/SYSTEM_ARCHITECTURE.md`) describe a 3D action-combat engine (CharacterBody3D, swept-capsule KCC, cel-shading shaders, Perlin camera trauma, hit-stop `TimeManager`, GAS/combat state machine). **None of this exists in `project/` as of M2.5.** The actual implementation is 2D (`CharacterBody2D`-based `PlayerCharacter2D`/`NPCCharacter2D`, a 2D `ObserverSystem`), has no 3D camera system, no hit-stop, and no combat loop at all (combat outcomes are narrated by `CausalResolutionEngine`, not simulated). As of M2.5, `GAME_DEVELOPMENT_COMPENDIUM.md` is now tracked in the repo with a status banner marking it aspirational/future-phase reference, and `docs/IMPLEMENTATION_STATUS.md` gives a concise implemented/designed/aspirational breakdown. This section (above) and `docs/PROJECT_STRUCTURE.md`/`docs/SYSTEM_ARCHITECTURE.md` themselves are still not reconciled — spot-check before relying on them for any new work.
