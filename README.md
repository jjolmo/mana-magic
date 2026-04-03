# Mana Magic

A Godot 4.6 template/engine for creating Secret of Mana-style action RPGs.

![Mana Magic](engine/mana-magic.png)

## About

Mana Magic is a **Godot 4.6 template** designed to recreate the core mechanics and gameplay systems found in the classic SNES title *Secret of Mana*. It provides a ready-to-use foundation for building your own action RPG based on those premises.

The project originates from the [Doner Engine](https://github.com/jjolmo/doner-engine-godot), originally built in GameMaker Studio 2. Mana Magic is the Godot 4.6 port of that engine, adapted and restructured to take advantage of Godot's node system, signals, and editor tooling.

More info about the original engine: [cidwel.com/doner](https://cidwel.com/doner)

## Current Status

**Phase: Early Development / Engine Port**

The template is in active development. The core systems ported from the GMS2 version include:

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

The template is functional but incomplete. Many areas, enemies, and content are still being implemented.

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

In a future version, the project will include tooling to allow users to extract original assets directly from a **US version ROM of Secret of Mana (SNES)**. This will be done under each user's own responsibility. The project will not distribute any copyrighted assets, but will provide the tools to use your own legally obtained ROM as a source.

## License

This project is licensed under the **GNU General Public License v3.0**. See the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome, especially in the area of open-source asset replacement. Feel free to open issues or pull requests.
