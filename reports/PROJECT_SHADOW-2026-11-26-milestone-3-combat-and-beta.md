# INITIATIVE REPORT: PROJECT SHADOW — MILESTONE 3.0 COMBAT LOOP & FOLLOWER ROSTER EXPANSION

**Project:** PROJECT SHADOW  
**Date:** 2026-11-26  
**Status:** Completed & Verified  

---

## 1. Context & Trigger
Following Milestone 2.5 (Shadow Persona Dialogue Pipeline), the project lacked real-time combat execution in the 2D world and only had a single follower (Alpha) active in the Sanctuary hideout. The user requested:
1. Implementation of the core 2D combat loop.
2. Follower roster expansion (introducing Beta).
3. Verification, re-export of the WebAssembly build, and launching the game in the browser.

---

## 2. Scope & Technical Architecture
- **Combat Pipeline (`project/mechanics/combat/`)**:
  - `CombatController2D.gd`: 4-phase deterministic finite state machine (Startup -> Active -> Recovery -> Idle) with persona-based damage scaling (Shadow persona delivers $1.8\times$ damage and $1.5\times$ poise damage).
  - `HitboxComponent2D.gd`: Area2D component monitoring hurtboxes, managing knockback vectors, and dispatching hit-stop and strike notifications.
  - `HurtboxComponent2D.gd`: Area2D component managing HP, poise accumulation/decay, invulnerability frames, and poise break signals.
  - `CombatDummy2D.tscn`: Interactive training target displaying real-time HP/Poise bars and poise break visual flashing.
  - `PlayerCharacter2D`: Attack trigger mapped to `J`, `Z`, or `Left Click` with slime-blade slash visual effects.
- **Follower Roster Expansion (Beta)**:
  - `BetaProfile.gd`: Codename "Beta", Archetype `FANATICAL_CHRONICLER`, with *The War Chronicles of Shadow* bias. Formulates literary treatises and propaganda operations from player directives.
  - `BetaNPC` in `SanctuaryInterior.tscn` with interactive recruitment dialogue.
- **Verification & Deployment**:
  - 9 new unit tests (`test_combat_2d.gd` and `test_beta_follower.gd`), bringing total tests to 42 passing with zero failures.
  - Re-exported single-threaded WebAssembly bundle to `build/web/index.html`.
  - Started local HTTP server with COOP/COEP headers on port 8085 and launched the game in Google Chrome.

---

## 3. Verification Evidence
- Native headless test runner:
  ```
  Test Results: Total: 42 | Passed: 42 | Failed: 0
  ```
- Browser build verified and running at `http://localhost:8085/build/web/index.html`.
