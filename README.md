# Mana Magic

A Secret of Mana inspired action RPG built with Godot 4.6.

![Mana Magic](engine/mana-magic.png)

## About

Mana Magic is an action RPG that recreates the gameplay and feel of the classic SNES title *Secret of Mana*. The project was originally developed in GameMaker Studio 2 and has been fully converted to Godot Engine using the [Doner Engine](https://github.com/jjolmo/doner-engine-godot) framework.

## Current Status

**Phase: Early Development / Engine Port**

The game is currently in active development. The core systems ported from the GMS2 version include:

- Real-time combat with charge attacks
- Multi-character party system with character swapping
- AI-controlled party companions
- Creature/enemy state machines
- Weapon system
- Magic/skill system
- Dialog system with localization support (EN/ES)
- Tilemap-based world with collision layers
- Ring menu UI
- Music and sound management
- Save system
- Custom editor plugin for content creation

The project is playable but incomplete — many areas, enemies, and story content are still being implemented.

## Project Structure

```
engine/          - Core engine code (autoloads, combat, creatures, effects, systems, UI, world)
scenes/          - Game scenes (creatures, effects, rooms, UI, world objects)
assets/          - Sprites, animations, fonts, shaders, sounds
data/            - JSON databases (skills, dialogs, game data)
tilesets/        - Tilemap and atlas definitions
addons/          - Custom Godot editor plugin
tools/           - Development utilities
tests/           - Integration tests
```

## Requirements

- Godot 4.6+

## Required Changes

### Licensed Assets

This repository currently contains placeholder or licensed assets that **will be removed** in upcoming commits. These assets cannot be distributed and must be replaced.

**We need help replacing licensed assets with open-source alternatives:**

- Sprite sheets (characters, enemies, NPCs, bosses)
- Tilesets and background art
- UI elements and fonts
- Sound effects and music
- Animation strips

If you are an artist or know of compatible open-source asset packs (CC0, CC-BY, etc.), contributions and suggestions are welcome.

### Future: ROM Asset Extraction

In a future version, the project will include tooling to allow users to extract original assets directly from a **US version ROM of Secret of Mana (SNES)**. This will be done under each user's own responsibility — the project will not distribute any copyrighted assets, but will provide the tools to use your own legally obtained ROM as a source.

## License

TBD

## Contributing

Contributions are welcome, especially in the area of open-source asset replacement. Feel free to open issues or pull requests.
