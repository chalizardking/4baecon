# FORESAKEN - Survival Extraction Roblox Game

## Overview
FORESAKEN is a session-based survival-extraction Roblox game built according to the comprehensive PRD specifications. Players scavenge, fight, extract, upgrade, and repeat in intense 12-18 minute sessions.

## 🎯 Core Features
- **Session-based gameplay**: 12-18 minute matches
- **Risk vs Reward extraction**: Players must choose when to extract with their loot
- **Fair combat system**: Low TTK with clear readability and counter-play
- **Persistent progression**: Hideout upgrades and character advancement
- **Weight-based inventory**: Strategic inventory management
- **AI enemies**: Intelligent behavior trees with multiple enemy types
- **Tiered loot system**: 5-tier rarity system with weighted drops

## 📁 Project Structure

```
FORESAKEN/
├── ReplicatedStorage/
│   ├── Shared/
│   │   └── Modules/
│   │       ├── Config.lua              # Game configuration and constants
│   │       ├── Items.lua               # Item database and utilities
│   │       ├── Enemies.lua             # Enemy definitions and AI configs
│   │       ├── Signals.lua             # Custom event system
│   │       ├── Net/
│   │       │   └── Events.lua          # Networking layer with validation
│   │       └── Util/
│   │           ├── Math.lua            # Mathematical utilities
│   │           └── Tables.lua          # Table manipulation functions
│   ├── Assets/
│   │   ├── UI/                         # UI assets and layouts
│   │   ├── VFX/                        # Visual effects
│   │   └── SFX/                        # Sound effects
│   └── Remotes/
│       └── init.lua                    # RemoteEvents/Functions setup
├── ServerScriptService/
│   └── GameServer/
│       ├── Matchmaker.server.lua       # Match lifecycle and spawning
│       ├── Combat.server.lua           # Weapon systems and damage
│       ├── AISystem.server.lua         # Enemy AI and behavior trees
│       ├── Spawner.server.lua          # Loot containers and item spawning
│       ├── Extraction.server.lua       # Extract zones and mechanics
│       └── Save.server.lua             # Data persistence and profiles
├── StarterPlayer/
│   ├── StarterPlayerScripts/
│   │   └── Controllers/
│   │       ├── Input.client.lua        # Input handling and key bindings
│   │       ├── HUD.client.lua          # UI management and display
│   │       ├── Combat.client.lua       # Client-side combat effects
│   │       └── Inventory.client.lua    # Inventory UI and management
│   └── StarterCharacterScripts/
│       └── Camera.client.lua           # Camera system (3rd/1st person)
└── Workspace/
    ├── Map_Greyfall/                   # Main game map
    ├── Spawns/
    │   ├── Players/                    # Player spawn points
    │   └── Enemies/                    # Enemy spawn locations
    └── ExtractZones/                   # Extraction zones (ZoneA, ZoneB)
```

## 🔧 Core Systems

### 1. Config System (`Config.lua`)
Centralized configuration management for all game parameters:

```lua
-- Match Configuration
Config.Match = {
    MaxPlayers = 12,
    SessionMinutes = 15,
    ExtractOpenAt = { t = 5, zones = {"ZoneA", "ZoneB"} }
}

-- Weapon Statistics
Config.Weapons = {
    Pistol = { dmg = 18, rpm = 360, spread = 2.0, range = 60 },
    SMG = { dmg = 14, rpm = 720, spread = 3.5, range = 40 },
    BRifle = { dmg = 26, rpm = 450, spread = 1.4, range = 80 }
}
```

### 2. Items System (`Items.lua`)
Comprehensive item database with tier-based organization:

- **5 Rarity Tiers**: Common (Gray), Uncommon (Green), Rare (Blue), Epic (Purple), Legendary (Gold)
- **Item Categories**: Weapons, Ammunition, Medical, Armor, Attachments, Materials
- **Utility Functions**: Weight calculation, value determination, tag system

### 3. Combat System
**Server-side (`Combat.server.lua`)**:
- Hit validation with raycast detection
- Damage calculation with armor system
- Fire rate enforcement and anti-exploit
- Player health/armor management

**Client-side (`Combat.client.lua`)**:
- Weapon firing with recoil and spread
- Visual effects (muzzle flash, tracers)
- Sound system integration
- Weapon switching and reloading

### 4. AI System (`AISystem.server.lua`)
Advanced enemy AI with behavior trees:

**Enemy Types**:
- **Bandit Scout**: Ranged harassment, flees at low health
- **Bandit Bruiser**: Melee pressure with stagger mechanics
- **Sentry Drone**: Area denial with reinforcement calls

**Features**:
- Pathfinding with PathfindingService
- Dynamic targeting and awareness
- Loot drops on death
- Spawn weight management

### 5. Loot & Extraction
**Loot System (`Spawner.server.lua`)**:
- Container types with different loot tables
- Weighted probability drops
- Anti-exploit pickup validation
- Dynamic loot refresh

**Extraction System (`Extraction.server.lua`)**:
- Timed extraction (8-second channel)
- Combat interruption mechanics
- Zone activation at match milestones
- Reward calculation and distribution

### 6. Inventory System (`Inventory.client.lua`)
Weight-based inventory management:
- 40-slot grid system with weight limits
- Tier-based color coding
- Drag-and-drop functionality
- Quick-use slots (1-5 keys)
- Item tooltips and information

### 7. Data Persistence (`Save.server.lua`)
Robust player data management:
- Profile-based data structure
- Automatic periodic saves
- Retry logic with exponential backoff
- Data validation and migration

## 🎮 Gameplay Loop

1. **Queue & Drop-in**: Players join 12-player sessions
2. **Scavenge**: Loot containers spawn throughout the map
3. **Combat**: Engage PvE enemies and PvP players
4. **Extract**: Channel for 8 seconds in extraction zones
5. **Hideout**: Upgrade facilities and craft items
6. **Repeat**: Queue for next session

## 📊 Progression System

### Player Progression
```lua
-- XP Sources
ExtractXP = 50      -- Successful extraction
KillXP = 25         -- Player/enemy kills
SurvivalXP = 10     -- Per minute survived

-- Currency System
StartingCredits = 500
ExtractReward = 100 (base)
```

### Hideout Tiers
- **Tier 1**: Basic crafting capabilities
- **Tier 2**: Advanced crafting bench
- **Tier 3**: Expert crafting and storage

## 🔒 Anti-Exploit Features

### Movement Validation
- Server-side distance checks
- Speed ceiling enforcement
- Position validation

### Combat Protection
- Server-authoritative damage
- Fire rate validation
- Range and line-of-sight checks

### Data Security
- Input validation on all RemoteEvents
- Rate limiting on RemoteFunctions
- Checkpointed data saves

## 🎯 Performance Targets

- **60 FPS** on PC/Console
- **30 FPS** on Mobile (planned v1.1)
- **<3.0k parts** live in world
- **<200 MB** streamed assets
- **<16ms** average server step time

## 📈 Analytics Events

The system tracks key metrics:
- `match_start` / `match_end`
- `loot_pick` with tier and location
- `combat` events with weapon data
- `extract` success/failure rates
- `spend` currency transactions

## 🚀 Getting Started

### Installation
1. Open Roblox Studio
2. Create new place
3. Import each `.rbxm` package to corresponding location:
   - `FORESAKEN_GameServer.rbxm` → `ServerScriptService/GameServer`
   - `FORESAKEN_Shared.rbxm` → `ReplicatedStorage/Shared`
   - `FORESAKEN_Remotes.rbxm` → `ReplicatedStorage/Remotes`
   - `Map_Greyfall.rbxm` → `Workspace/Map_Greyfall`

### Configuration
1. Adjust spawn points in `Workspace/Spawns/`
2. Modify game parameters in `Config.lua`
3. Set up DataStore keys for live deployment
4. Configure extract zones in `Workspace/ExtractZones/`

## 🎨 UI/UX Features

### HUD Elements
- Health/Armor bars with animations
- Weapon/Ammo display
- Inventory weight indicator
- Extract timer with progress
- Kill feed and notifications

### Input System
- WASD movement with sprint/crouch
- Mouse look with sensitivity control
- Weapon firing (LMB) and aiming (RMB)
- Reload (R), Interact (E), Extract (F)
- Inventory (Tab), Quick slots (1-5)

## 🔄 Network Architecture

### Client → Server Events
- `WeaponFire`: Weapon firing with validation
- `LootPickup`: Item collection requests
- `ExtractEnter/Exit`: Extraction zone interaction
- `ItemUse`: Item consumption

### Server → Client Events
- `PlayerDamaged`: Health/armor updates
- `LootSpawned`: New loot notifications
- `ExtractionComplete`: Extract success/failure
- `HudUpdate`: UI data updates

## 📝 Development Notes

### Code Style
- Strict type annotations using Luau
- Modular architecture with clear separation
- Event-driven communication via Signals
- Comprehensive error handling

### Testing Strategy
- Unit tests for core utility functions
- Integration tests for combat system
- Load testing for concurrent players
- Anti-exploit validation tests

## 🎯 Future Roadmap (v1.1+)

### Planned Features
- Mobile touch controls
- Duo/trio team modes
- Additional biomes and maps
- Faction reputation system
- Advanced crafting mechanics
- Dynamic weather and day/night cycles

### Performance Optimizations
- Level-of-detail (LOD) system
- Texture streaming improvements
- Network optimization
- Mobile-specific optimizations

## 📄 License

This project is designed for educational and demonstration purposes, showcasing modern Roblox game development practices and architectural patterns.

---

**Built with ❤️ for the Roblox community**

For questions or contributions, refer to the comprehensive code documentation within each module.