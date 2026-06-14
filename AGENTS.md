# AGENTS

## Purpose
This file helps AI coding agents understand the `Merge` Godot project quickly and avoid assumptions about build/test tooling.

## Project summary
- Godot 4.6 game project in `d:\Godot\Merge`
- Main scenes and game logic live under `Scene/`
- Shared state and core data are managed by the `Global.gd` autoload singleton
- Data-driven content is loaded from `Data/*.json`
- The game uses `user://savegame.json` for player progress
- There is no explicit CLI build or test system in the repo

## Key files and directories
- `project.godot` — project configuration, main scene, autoload registration, display settings
- `Scene/Global.gd` — central game state, save/load, audio setup, item data, quests, upgrades, and signals
- `Scene/Game.gd` — core merge game mechanics, grid and item interactions, tutorial flow, offline production
- `Scene/WorldMap.gd` — main menu / map transitions, UI navigation, tutorial display
- `Scene/ShopUI.gd` — shop UI logic, purchases, upgrade flows
- `Scene/QuestUI.gd` — quest list display and refresh logic
- `Scene/Item.gd` — item behavior, dragging, item placement, coin collection animations
- `Data/` — JSON files for backpack upgrades, field upgrades, dialogues, quests, and shop data

## Conventions for agents
- Use `Global` as the single source of truth for cross-scene state and persistent data
- Maintain save compatibility: do not remove or rename save fields in `Global.save_game()` unless the change is intentional and handled in load logic
- Item IDs are meaningful: `1-10` are merge items, `50` is coin, `60` is crystal, `101/102` are generators
- Avoid editing generated import metadata files such as `.import/` entries or Godot’s internal `.godot/` folder unless necessary
- Use existing scene node paths and method names when modifying scene scripts; Godot scenes are tightly coupled to script structure

## Notes for `cline` / command-line-style work
- This repository has no build scripts, package manifests, or automated tests. Treat the project as a Godot editor-native game.
- When asked about CLI-style workflows, prefer guidance based on Godot scene/script structure rather than assuming npm, make, or other toolchains
- If a change touches save data or JSON-driven game content, document the compatibility impact clearly in the code comments and commit message

## What to do first
- Inspect `Scene/Global.gd` for new state variables and signals before adding cross-scene features
- Use `Data/*.json` for content updates rather than hard-coding new dialogue, quests, or upgrades in scripts when possible
- Preserve Russian comments and naming conventions if editing existing code

## What not to do
- Do not create or manipulate `*.import` files manually
- Do not assume there is a CI/test pipeline or command-line build command in this workspace
- Do not add unrelated tooling; focus on Godot project files and game logic
