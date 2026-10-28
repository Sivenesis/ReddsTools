<p align="center">
  <img src="assets/logo.png" width="96" height="96" alt="ReddsTools Logo" />
</p>

<h1 align="center">ReddsTools</h1>

<p align="center">
  <strong>Floating In-Game Mod Menu for Animal Crossing: Pocket Camp Complete</strong><br>
  <em>In-process UIKit overlay for iOS (arm64) with native IL2CPP hooks and memory gates</em>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-iOS%2015.0%20--%2016.x+-blue.svg" alt="Platform">
  <img src="https://img.shields.io/badge/Architecture-Rootless%20arm64-green.svg" alt="Architecture">
  <img src="https://img.shields.io/badge/Target-com.nintendo.zasa%20v7.1.4-orange.svg" alt="Target App">
  <img src="https://img.shields.io/badge/License-PolyForm%20Noncommercial%201.0.0-lightgrey.svg" alt="License">
</p>

---

## 1. Description

ReddsTools is a standalone, in-process UIKit floating modification menu for *Animal Crossing: Pocket Camp Complete* (`com.nintendo.zasa`, v7.1.4 Build 270). It injects directly into the game's Unity runtime, hooking native IL2CPP methods and toggling memory gates without requiring background daemons, network proxies, or external tools.

---

## 2. Features

- **Currencies & Materials:** Adjust Bells (up to 9,999,999) and Leaf Tokens (up to 99,999) using native `GuardLong` setters; instantly fill all crafting materials to 999; freeze active currency balances.
- **Camp Caretaker & Companion (Strategy B):** Bypass special furniture ownership checks to appoint any character as a walking companion from a searchable 478-character database (including 65 Special NPCs like Isabelle, Tom Nook, Brewster, and Redd); toggle real-time overworld roaming locomotion AI.
- **Time Travel & Clock Spoofing:** Bidirectional time shifts and clock freeze via `NDcube.Type.UtcTime.get_Now`; includes anti-save-pollution protection that commits real POSIX hardware time during save routines.
- **Instant Workshop & Gardening:** Complete craft queues instantly; trigger immediate bloom across all 20 flowerbed plots; enforce a 100% creature capture rate via `PaidCatch`.
- **Fishing & Bug Hunting:** Remove fish nibble delays with instant bite hooks; enable instant fish pull; eliminate insect flee reactions.
- **Villagers & Campsite:** Elevate animal friendship levels to max (70+); auto-fulfill visiting animal requests; cycle campsite villager roster presets.
- **Shovelstrike Quarry:** Bypass daily entrance limits and friend assistance requirements for permanent, unlimited entry.
- **Engine Diagnostics:** Variable engine speed multiplier (1.0x to 10.0x) via `Time.set_timeScale`; toggle the native Unity Universal Render Pipeline (URP) runtime debug overlay.

---

## 3. Installation

### Method A: Rootless Jailbreak (Dopamine / Palera1n)
1. Build or download the rootless Debian package (`com.phuror.reddstools_1.0.0_iphoneos-arm64.deb`).
2. Transfer the `.deb` to your device and install via Sileo, Zebra, Filza, or terminal:
   ```bash
   dpkg -i com.phuror.reddstools_1.0.0_iphoneos-arm64.deb
   ```
3. Launch the game. The draggable Redd icon will appear over the game view.

### Method B: Sideloaded IPA Injection (TrollStore / Sideloadly / Azule)
1. Extract the compiled dynamic library (`ReddsTools.dylib`) and the rootless payload directory (`layout/Library/Application Support/ReddsTools/`).
2. Inject the dynamic library into the decrypted ACPCC binary using Azule, Sideloadly, or `optool`:
   ```bash
   azule -i target.ipa -o output.ipa -f ReddsTools.dylib
   ```
3. Bundle the `ReddsTools/` asset folder (`characters.json` and `icons/`) into the application container's `Library/Application Support/` path.
4. Sign and install the resulting IPA via TrollStore or your preferred sideloading utility.

---

## 4. Camp Caretaker Stability Warning & Emergency Overwrite

Certain Special NPCs or non-standard character models lack completed locomotion animation blends or valid overworld state machines. Assigning an incompatible character as your Camp Caretaker can cause the game client to crash during overworld loading.

### Emergency Rescue Mechanisms

If the game crashes on startup or becomes unresponsive due to an appointed companion:

1. **Floating Icon Double-Tap:** Double-tap the floating Redd avatar icon on the screen at any point.
2. **Settings Panel Reset:** Open the tweak menu, switch to Settings, and tap **RESET COMPANION**.

Both actions immediately force-appoint a verified standard character (Bob / `cat00`) and set an automatic boot-recovery flag (`Pref_EmergencySafeBobPending`) that cleanses persistent companion state on next launch.

---

## 5. Intellectual Property & Copyright Notice

*Animal Crossing: Pocket Camp Complete*, *Animal Crossing*, character names, textures, and associated media are registered trademarks and copyrights of **Nintendo Co., Ltd.**

ReddsTools is an independent, community-driven reverse-engineering project created solely for personal entertainment, research, and noncommercial offline game preservation. This repository contains no proprietary game code, decrypted game binaries, or proprietary database files.

---

## 6. "As Is" Warranty & Liability Disclaimer

This software is provided by the copyright holders and contributors "as is" and any express or implied warranties, including, but not limited to, the implied warranties of merchantability and fitness for a particular purpose are disclaimed. In no event shall the authors or contributors be liable for any direct, indirect, incidental, special, exemplary, or consequential damages (including loss of save game data, application instability, or device malfunction) however caused and on any theory of liability, whether in contract, strict liability, or tort arising in any way out of the use of this software.

---

## 7. AI Assistance Disclosure

Portions of this codebase, technical documentation, and reverse-engineering research blueprints were authored, analyzed, and structured with the assistance of Artificial Intelligence (AI) models. Users, researchers, and developers should independently review and verify implementation details before deployment.

---

## Documentation & License

- Complete Technical Architecture & Reverse Engineering Specification: [RESEARCH.md](RESEARCH.md)
- Feasibility Analysis: [docs/IOS_FLOATING_MENU_FEASIBILITY_REPORT.md](docs/IOS_FLOATING_MENU_FEASIBILITY_REPORT.md)
- Developer Flags & Anti-Cheat Analysis: [docs/DEVELOPER_SYSTEMS_AND_ANTI_CHEAT_ANALYSIS.md](docs/DEVELOPER_SYSTEMS_AND_ANTI_CHEAT_ANALYSIS.md)
- Time Spoofing Specification: [docs/DATE_AND_TIME_SPOOFING_SPECIFICATION.md](docs/DATE_AND_TIME_SPOOFING_SPECIFICATION.md)
- Camp Caretaker Strategy B: [docs/STRATEGY_B_CAMP_CARETAKER_COMPANION_BYPASS.md](docs/STRATEGY_B_CAMP_CARETAKER_COMPANION_BYPASS.md)
- License: [PolyForm Noncommercial License 1.0.0](LICENSE)
