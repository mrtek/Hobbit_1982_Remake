# 🧙‍♂️ The Hobbit / Хоббит (1982 Remake)

[🇷🇺 Читать на русском (README.md)](README.md) | [🇬🇧 English version](README_EN.md)

[![Play Online](https://img.shields.io/badge/▶_PLAY_ONLINE-GitHub_Pages-brightgreen?style=for-the-badge&logo=googlechrome&logoColor=white)](https://mrtek.github.io/Hobbit_1982_Remake/)
[![Download Release](https://img.shields.io/badge/📥_DOWNLOAD_(WINDOWS)-v0.99.01_Beta-blue?style=for-the-badge&logo=windows&logoColor=white)](https://github.com/mrtek/Hobbit_1982_Remake/releases)

[![Godot Engine](https://img.shields.io/badge/Godot-4.3+-478CBF?logo=godotengine&logoColor=white)](https://godotengine.org)
[![Version](https://img.shields.io/badge/version-v0.99.01_Beta-gold)](#)
[![Genre](https://img.shields.io/badge/genre-Text--Graphic_Adventure-darkgreen)](#)
[![Platform](https://img.shields.io/badge/platform-Web_%7C_Windows_%7C_Linux_%7C_macOS-lightgrey)](#)
[![Author](https://img.shields.io/badge/Author-Freeonce_(aka_MrTEK)-blue)](#)
[![AI](https://img.shields.io/badge/AI_Pair_Programming-Gemini_3.8_Flash-8E75C2?logo=google&logoColor=white)](#)

> ### 🎮 **[PLAY ONLINE IN BROWSER (CLICK HERE)](https://mrtek.github.io/Hobbit_1982_Remake/)**
> *Runs directly in your browser on PC, laptop, or tablet with zero download or installation required! All 6 save slots and audio settings persist automatically in your browser storage (IndexedDB).*

A modern cross-platform remake of the legendary 1982 text-graphic adventure **«The Hobbit»** by *Melbourne House* (original authors: **Philip Mitchell** and **Veronika Megler**), rebuilt from the ground up in the **Godot 4.3+** engine. Features complete bilingual support (**English** and **Russian**) with authentic 1982 original texts from the historical Melbourne House disassembly.

---

## ✨ Key Features

### 🎭 Three Authentic Game Modes
Switch between visual and audio presentation styles at any moment from the main menu or in-game settings:

1. **🌟 Modern Edition**
   - High-resolution digital artwork for all 79 locations.
   - Cinematic orchestral soundtrack and intro sequence.
   - Atmospheric medieval typography with the *Greengoth* font.
2. **💾 Retro (VGA Edition)**
   - Vintage 16/256-color MS-DOS pixel art style of the late 1980s.
   - Authentic AdLib / Sound Blaster FM synthesizer soundtrack.
   - Classic DOS 8x16 bitmap typography (*dos2000*).
3. **🕹️ Classic (ZX Spectrum Edition)**
   - Original 8-bit vector illustrations from 1982.
   - Legendary **Neil Brennan** chiptune soundtrack (Commodore 64 SID arrangement).
   - Authentic ZX Spectrum raster font and nostalgic tape-loading animation.

---

### 🧠 Natural Language Parser & Living World (WorldSim)
- **Full Bilingualism (English / Russian)**: Switch language on the fly right on the mode selection screen or in settings. Features authentic original 1982 texts for all 79 locations, 44 objects, and 17 NPCs directly from the ZX Spectrum assembly source. All save files are fully cross-compatible between languages without conflicts.
- **Natural Language Parser (Inglish)**: Understands complete English and Russian sentences (movement, examination, inventory management, container manipulation, and talking to companions: *"Gandalf, give me the map"*).
- **Autonomous Simulation (WorldSim)**: Gandalf, Thorin, Bard, Elrond, Gollum, the goblins, and trolls live independent lives — traversing Middle-earth in real-time, picking up items, fighting, or assisting Bilbo.
- **Authentic Mechanics**: Openable chests, barrels, locked doors (the green round door in Bag End), crossing the Enchanted River by boat and rope, troll petrification at dawn, and triumph upon placing the Arkenstone into the chest in Bag End.

---

### 🎮 Modern & Accessible Interface
- **Hybrid Controls**: Classic text command line + interactive directional compass (N, S, E, W, NE, NW, SE, SW, Up, Down) + quick action bar (Look, Inventory, Wait, Take All, Save, Load) + command dropdown helper.
- **Ren'Py-Style Save & Load System**: 6 independent slots with automatic location screenshots, timestamps, game mode tags, and trash bin deletion with confirmation modals.
- **Dynamic Soundtrack**: 18 musical compositions featuring smooth 2-second crossfades (fade-out/fade-in) across room transitions and story milestones.
- **Cinematic Credits Screen**: Smoothly scrolling credits detailing the history and creators of the 1982 masterpiece, speed-up by holding Spacebar, mouse-wheel scrolling, and procedural ragged-edge picture mask shader.
- **👁️ Accessibility Mode (Self-Voicing & Screen Reader)**:
  - High-contrast visual theme (solid deep black containers, vibrant gold and cyan borders).
  - Scaled typography for visually impaired players (event log up to 30px, command input to 26px, location title to 34px).
  - Automatic audio ducking: background music dims to 10% during speech output for perfect voice clarity.
  - Real-time Text-to-Speech (TTS) reading room descriptions, events, compass, and UI buttons (native OS voice in desktop builds, Web Speech API in browser).
  - Global hotkeys: <kbd>F1</kbd> (Help), <kbd>F2</kbd> (Location repeat), <kbd>F3</kbd>/<kbd>F4</kbd> (Last event repeat), <kbd>Page Up</kbd>/<kbd>Page Down</kbd> (Log history scrolling), <kbd>V</kbd> (Quick accessibility toggle).

---

## 🚀 How to Clone & Run in Godot

### Requirements
- **Godot Engine 4.3 or newer** (Standard 64-bit edition, without .NET).

### Quick Steps:
1. Clone the repository:
   ```bash
   git clone https://github.com/mrtek/Hobbit_1982_Remake.git
   ```
2. Open **Godot Engine**.
3. Click **Import** in the Project Manager.
4. Select the `project.godot` file in the root of the cloned directory.
5. Click **Import & Edit**.
6. Press <kbd>F5</kbd> (or the Play button in the top right corner) to run the game.

---

## 📂 Project Architecture

```
├── project.godot            # Main Godot project configuration
├── export_presets.cfg       # Export presets (Web & Windows Desktop)
├── README.md                # Russian documentation (Main)
├── README_EN.md             # English documentation
├── assets/
│   ├── fonts/               # Authentic fonts (Greengoth, DOS2000, ZX Spectrum 7)
│   ├── images/              # Location graphics for 3 modes, splashes, UI icons, credits
│   ├── music/               # 18 soundtrack themes (Modern, VGA SoundBlaster, ZX SID)
│   └── shaders/             # Shaders (ragged-edge credits picture mask)
├── data/
│   ├── dictionary.json      # Bilingual parser vocabulary (verbs, directions, nouns)
│   ├── npcs.json            # Stats, inventories, and initial positions of 17 NPCs
│   ├── original_locations.json # Descriptions and exits for all 79 rooms
│   └── original_objects.json   # Properties of 43 items (mass, containers, keys)
├── scenes/
│   ├── main.tscn            # Main game scene, HUD, compass, and game screens
│   ├── save_load_screen.tscn# Visual novel style modal save/load screen
│   └── credits_screen.tscn  # Cinematic scrolling credits
└── scripts/
    ├── main.gd              # UI coordinator, video playback, and mode switching
    ├── game_state.gd        # Core state machine, inventory, game rules, and persistence
    ├── parser.gd            # Bilingual Inglish natural language parser (EN / RU)
    ├── world_sim.gd         # Autonomous NPC simulation and AI routines
    ├── audio_manager.gd     # Dynamic soundtrack manager with crossfade transitions
    ├── save_load_screen.gd  # Save/load slot grid logic and thumbnail serialization
    ├── credits_screen.gd    # Scrolling credits logic and shader picture carousel
    └── test_runner.gd       # Automated integration test runner (25 comprehensive tests)
```

---

## 🧪 Automated Testing

The project includes an automated test runner validating the database, game state, parser, graphics for all 3 modes, music triggers, save/load serialization, and credits:

```bash
godot --headless -s res://scripts/test_runner.gd
```
*All 25 integration tests pass with 100% PASS status.*

---

## 📜 Authors & Acknowledgments

- **Remake Developer:** Freeonce (aka MrTEK)
- **AI Pair Programming Partner:** Developed with **Gemini 3.8 Flash**
- **Original 1982 Game:** Philip Mitchell, Veronika Megler (*Melbourne House*)
- **Original Music Themes:** Neil Brennan
- **Literary Basis:** J.R.R. Tolkien, *«The Hobbit, or There and Back Again»*

---
*Created with love and respect for the golden age of text-graphic adventures.*
