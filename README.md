# GameSeagull

Get it on my [repo](https://donato-fiore.github.io/repo)

If you would like to support me, consider donating [here](http://paypal.me/donatofiore)!

# Building & Installation

### Local Build (macOS or Linux with Theos)
```SHELL
git clone https://github.com/donato-fiore/GameSeagull.git
cd GameSeagull
./build_release.sh
```

### Cloud CI Builds (No local Mac required)
* **Codemagic**: Included `codemagic.yaml` builds rootful and rootless packages on macOS runners with artifacts uploaded automatically.
* **GitHub Actions**: Push or trigger the included `.github/workflows/build.yml` workflow on any GitHub repo to get compiled `.deb` artifacts directly from GitHub Actions.

# Changelog
## [3.0] - Enhanced Edition
### Critical Fixes:
- Guarded memory patching against null-pointer crashes on offset misses.
- Eliminated infinite recursion hook bug in Cup Pong.
- Fixed collection mutation crash during fast enumeration in Word Hunt.
- Resolved repeated letter tile selection bug in Anagrams.
- Fixed Darts aimbot menu selection check typo and out-of-bounds array hazards.

### Architecture:
- Implemented real-time dynamic Darwin notification preference reloading (`com.fiore.gameseagull.prefs/ReloadPrefs`) — no more killing `MobileSMS`!
- Replaced unreadable `UIAlertController` word modals with modern iOS 15+ draggable bottom sheets with "Copy All".
- Deduplicated `PoolScene`, `PoolScene2`, and `PoolScene3` hooks using unified macro.

### New Features:
- **Pool (8-Ball & 9-Ball)**:
  - **Full Multi-Ball Trajectory**: Real-time 2D raycasting engine predicting cue ball path, cushion reflections, ghost ball impact, primary object ball paths, and secondary ball-to-ball collisions!
  - **Break to Win in One Turn**: Perfectly distributes impulses across the rack on the break shot so balls scatter and drain into all 6 pockets, sinking the rack and 8-ball/9-ball in one turn.
- **Mini Golf**:
  - **Full Trajectory / Bounce Map**: Forward-simulates ball path across 160 steps with surface friction and boundary/obstacle rebounds, indicating hole intersections.
  - **Stealth Auto-Shoot Hole-in-One**: Scans launch vectors to calculate trick shots that bounce off walls and sink into the cup, synthesizing realistic touch gestures.
  - **Legit Mode**: Lets the ball sink smoothly on stroke 2+ to look completely natural.
- **Basketball**:
  - Added Auto Swish button and freeze shot clock timer hack.
- **Tanks**:
  - Added persistent ballistic trajectory guide.
### Updates:
- Fixed some icons not showing on < iOS 16
- Added:
    - Always 50ft Target
    - Auto Cup Pong Button
    - Darts Aimbot

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
