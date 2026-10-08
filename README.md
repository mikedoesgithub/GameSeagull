# GameSeagull

Get it on my [repo](https://donato-fiore.github.io/repo)

If you would like to support me, consider donating [here](http://paypal.me/donatofiore)!

# Building & Installation

### Local Build (macOS or Linux with Theos)
* **Linux (Arch / Omarchy / Ubuntu)**: Run `./setup_linux_theos.sh` to automatically install Theos, fetch the iOS 16.5 SDK, configure headers, and build `.deb` packages locally.
* **macOS**:
```SHELL
git clone https://github.com/donato-fiore/GameSeagull.git
cd GameSeagull
./build_release.sh
```

### Cloud CI Builds (No local Mac required)
* **Codemagic**: Included `codemagic.yaml` builds rootful and rootless packages on macOS runners with artifacts uploaded automatically.
* **GitHub Actions**: Push or trigger the included `.github/workflows/build.yml` workflow on any GitHub repo to get compiled `.deb` artifacts directly from GitHub Actions.

# Changelog
## [3.0] - Ultimate Edition
### Critical Fixes:
- Guarded memory patching against null-pointer crashes on offset misses.
- Eliminated infinite recursion hook bug in Cup Pong.
- Fixed collection mutation crash during fast enumeration in Word Hunt.
- Resolved repeated letter tile selection bug in Anagrams.
- Fixed Darts aimbot menu selection check typo and out-of-bounds array hazards.

### Architecture & UI:
- **In-Game Floating Seagull HUD (`🕊️`)**: Injected sleek draggable HUD directly inside all GamePigeon games. Toggle cheats and trigger instant solvers without leaving iMessage or switching to Settings!
- **Dynamic Live Preference Sync**: CoreFoundation Darwin notifications (`com.fiore.gameseagull.prefs/ReloadPrefs`) update tweak state instantly in real time — zero `killall MobileSMS` required.
- **Native Bottom Sheet Viewer**: Replaced truncated `UIAlertController` modals with iOS 15+ `UISheetPresentationController` containing monospaced scroll view and "Copy All" clipboard button.
- **Unified Codebase**: Macro deduplication across Pool scenes and board games.

### Advanced Physics & Solvers:
- **Pool (8-Ball & 9-Ball)**:
  - **Full Multi-Ball Trajectory**: 2D raycasting engine predicting cue ball paths, up to 3 cushion reflections, ghost ball impacts, primary object ball paths, and secondary ball-to-ball collisions!
  - **Break to Win in One Turn**: Coordinates impulse vectors across the rack on break shot, scattering object balls into all 6 pockets to win in 1 turn without scratching.
  - **Auto-Aim Best Ball**: Mathematically calculates the easiest, straightest legal pot on the table and aligns the cue stick automatically.
- **Mini Golf**:
  - **Full Trajectory / Bounce Map**: 160-step forward simulation with rolling friction ($0.982$) and boundary bank rebounds ($0.82$).
  - **Stealth Auto-Shoot Hole-in-One**: Scans 72 angles and 8 power levels to discover trick bank shots into the cup, synthesizing humanized touches.
  - **Legit Mode**: Allows sinking on stroke 2+ for natural-looking replays.
- **Word Games (Word Hunt, Anagrams, Word Bites)**:
  - **Word Bites**: Added complete solver, word list drawer, and auto-submit solver.
  - **Word Hunt & Anagrams**: Sheet viewers and instant auto-win triggers.
- **Board Games (Connect 4, Mancala, Dots & Boxes, Gomoku)**:
  - **Connect 4**: Minimax alpha-beta solver rendering column decision icons (`👑` Best / `💀` Blunder / `•` Safe).
  - **Mancala**: Kalah rule engine overlay displaying `⭐ Turn` badges on pits that land in your store and `🎯 +N` badges on capture pits.
  - **Dots and Boxes**: Dynamic line color guide (`🟢` Closes box / `🔵` Safe line / `🔴` Blunder giving chain to opponent).
  - **Gomoku**: 5-in-a-row threat scanner ring highlighting immediate wins, open 4s, and urgent blocks.
- **Cup Pong (Beer Pong)**:
  - Live cup filter ensuring auto-shoot only targets remaining unsunk cups.
- **Sea Battle (Battleship)**:
  - Auto-Sink Enemy Fleet button and ESP reveal.
- **Basketball**:
  - Auto Swish ballistic shooter and timer freeze hack.
- **Tanks & Archery**:
  - Persistent trajectory line and zero-wind lock.

## [2.0](https://github.com/donato-fiore/GameSeagull/releases/tag/2.0) - 2024-01-28
### Updates:
- **Dropped iOS 13 Support**
- Rootless and rootful support
- Rebuilt preferences
- Improve backend functionality
- Added "Disable Timer" hack

## [1.6](https://github.com/donato-fiore/GameSeagull/releases/download/1.6/com.fiore.gameseagull_1.6_iphoneos-arm.deb) - 2021-11-19
### Changed
- How the tweak uses prefs (hopefully this works)
### Added
- Always move 8 ball cue
- Archery target always set to 50ft away
## [1.5.1](https://github.com/donato-fiore/GameSeagull/releases/download/1.5.1/com.donato.gameseagull_1.5.1_iphoneos-arm.deb) - 2021-08-23
### Changed
- How the tweak loads the preferences, which was causing some users to not be able to use the tweak (Thank you [Chr1s](https://github.com/Chr1sDev))
## [1.5](https://github.com/donato-fiore/GameSeagull/releases/download/1.5/com.donato.gameseagull_1.5_iphoneos-arm.deb) - 2021-08-21
### Added
- Infinite 8 ball lines
- RGB 8 ball lines
## [1.4](https://github.com/donato-fiore/GameSeagull/releases/download/1.4/com.donato.gameseagull_1.4_iphoneos-arm.deb) - 2021-08-18
### Added
- See enemy ships in sea battle
- Auto anagrams word solver
## [1.3.1](https://github.com/donato-fiore/GameSeagull/releases/download/1.3.1/com.donato.gameseagull_1.3.1_iphoneos-arm.deb) - 2021-08-17
### Added
- Disabling hard mode in all 8 ball games
### Changed
- The code for win spoofing
## [1.3](https://github.com/donato-fiore/GameSeagull/releases/download/1.3/com.donato.gameseagull_1.3_iphoneos-arm.deb) - 2021-08-15
### Added
- Icon to the settings preference
- Word Solver for Word Hunt
### Changed
- The button used in anagrams
- The code for unscrambling words in anagrams
## [1.2](https://github.com/donato-fiore/GameSeagull/releases/download/1.2/com.donato.gameseagull_1.2_iphoneos-arm.deb) - 2021-08-07
### Added
- Win Spoofer
- Anagrams Word Unscrambler
- One shot Cup Pong win
## [1.1](https://github.com/donato-fiore/GameSeagull/releases/download/1.1/com.donato.gameseagull_1.1_iphoneos-arm.deb) - 2021-08-01
### Added
- Auto Hole in One for Mini Golf
### Changed
- Starting to use [Cephei](https://hbang.github.io/libcephei/) for a better preference bundle
## 1.0 - 2021-05-23
Initial Release
### Added
- Archery No Wind
- Always showing trajectory line in 8 ball **NOT EXTENDED LINES**
- Darts One Shot Win
- Tanks No Wind
