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

ReddsTools is a standalone, in-process UIKit floating modification menu engineered specifically for *Animal Crossing: Pocket Camp Complete* (`com.nintendo.zasa`, v7.1.4 Build 270). It hooks directly into the game's Unity IL2CPP runtime, modifying balances, bypassing progression restrictions, enabling companion walk mechanics, and providing bidirectional time travel without external background daemons or network proxies.

---

## 2. Features

<p align="center">
  <img src="assets/screenshots/1_menu_overview.png" width="31%" alt="Menu Overview" />
  <img src="assets/screenshots/2_currencies.png" width="31%" alt="Currencies" />
  <img src="assets/screenshots/4_camp_caretaker.png" width="31%" alt="Camp Caretaker" />
</p>

### 1. Currencies
- **Bells Editor:** Input exact Bell balances, tap `+Add` for +1,000,000, or tap `Max` for 9,999,999 Bells.
- **Leaf Tokens Editor:** Input exact Leaf Token balances, tap `+Add` for +1,000, or tap `Max` for 99,999 Tokens.
- **Complete Tickets Editor:** Input exact Complete Ticket balances, tap `+Add` for +100, or tap `Max` for 9,999 Tickets.
- **Currency Freeze:** Prevents active Bell, Leaf Token, and Complete Ticket balances from depleting during purchases and crafting.
- **Max All Crafting Materials (x9999):** One-tap button that maxes out all bag crafting materials (Wood, Steel, Cotton, Paper, Preserves, and all Essences) to 9,999.

### 2. Fortune Cookies
- **Unlock Crossover Cookies (Shop):** Adds crossover fortune cookies (Sanrio Characters, Splatoon, etc.) directly into the in-game Fortune Cookie Shop.

### 3. Exclusive Shops & Crossovers
- **Unlock Full Catalog:** Unlocks all crossover items, seasonal event exclusives, and Complete Ticket catalog items for viewing and immediate crafting.

### 4. Happy Homeroom
- **Infinite Tickets & Free Vouchers:** Take Happy Homeroom interior design classes without consuming Golden or Normal event tickets.
- **Auto-Pass 3 Medals (Instant Win):** Automatically scores maximum medals (3 stars) on any entered class evaluation.
- **Universal Furniture (Flawless):** Overrides class item validation so any submitted furniture item registers with a "Flawless!" score.

### 5. Camp Caretaker (Strategy B)
- **Active Companion Card:** Live HUD displaying the currently appointed companion name, species, NPC ID, and avatar, alongside an instant `Dismiss` button.
- **Character Browser Modal:** Searchable modal with real-time text filter and category tabs (`All (474)`, `Special (60)`, `Villagers (413)`).
- **60 Special NPCs Supported:** Direct selection of major NPCs including Isabelle, Tom Nook, Brewster, Blathers, DJ KK, KK Slider, Labelle, Harriet, Reese, and Redd.
- **Quick Assign Shortcuts:** Instant companion buttons for popular Special NPCs directly on the main menu panel.
- **Bypass Furniture Requirement:** Memory gate allowing any Special NPC to be appointed as Camp Caretaker without crafting or owning their special Leaf Token furniture.
- **Overworld Roaming Walk:** Enables companion locomotion AI so the appointed character follows the player character across campsites, cabins, and overworld recreation spots in real time.
- **Notice on Crashing Characters:** Certain Special NPCs or non-standard character models lack complete walking animations or valid overworld state machines and may crash the game upon spawning. Users encountering a crashing character ID are advised to **open an issue on GitHub** so the character can be blacklisted or patched. If your game crashes, refer to [Section 4: Camp Caretaker Stability Warning & Emergency Overwrite](#4-camp-caretaker-stability-warning--emergency-overwrite) for immediate recovery.

<p align="center">
  <img src="assets/screenshots/3_shops_and_homeroom.png" width="31%" alt="Shops & Homeroom" />
  <img src="assets/screenshots/5_creatures_and_quarry.png" width="31%" alt="Creatures & Quarry" />
  <img src="assets/screenshots/6_time_and_speed.png" width="31%" alt="Time Travel & Speedhack" />
</p>

### 6. Creatures
- **100% Catch Rate:** Enforces guaranteed capture success for all rare event creatures and garden bugs by routing through `PaidCatch`.
- **Never-Flee Insects:** Disables bug escape reactions so rare beetles and butterflies never fly away.
- **Auto-Bite:** Eliminates fish nibble delays so fish strike the lure instantly on first contact.

### 7. Quarry
- **Unlimited Daily Entries:** Memory gate removing the once-per-day lock and friend assistance requirement for Shovelstrike Quarry.

### 8. Time Travel
- **Live Game Clock HUD:** Real-time updating display showing current effective in-game time, active offset, and status (`Real Time`, `SPOOFED`, `FROZEN`).
- **Master Enable:** Toggles in-process interception of `NDcube.Type.UtcTime.get_Now`.
- **Freeze Game Clock:** Halts in-game clock advancement.
- **Date/Time Selector:** Embedded `UIDatePicker` allowing direct jumping to any year, month, day, hour, and minute.
- **Seasonal Presets:** Instant jumps to major festivals (Halloween, Toy Day, Cherry Blossoms, Summer Island, New Year Countdown).
- **Quick Jumps:** `+3h (Villagers)`, `+12h (Quarry)`, `+24h (Daily)`, `-3h (Undo)`, `-24h (Back)`, and `Reset Real Time`.
- **Anti-Save-Pollution:** Automatically commits true hardware POSIX time during save routines so future spoofed timestamps never poison the save file.

### 9. Speedhack
- **Speed Multiplier:** Smooth slider from 1.0x to 10.0x accelerating game animations, dialogue text, and overworld traversal via `Time.set_timeScale`.
- **Reset Speed (1.0x):** One-tap button restoring default 1.0x speed.

### 10. Diagnostics & Settings Panel (Long-Press on Floating Icon)
- **FPS & Performance HUD:** Live top-screen overlay displaying frame rate, frame time in milliseconds, and resident memory usage.
- **RESET COMPANION:** Emergency recovery button immediately restoring a safe villager (Bob / `cat00`).
- **Debug Screen:** Invokes native Unity Universal Render Pipeline (URP) performance diagnostics.

---

## 3. Installation

ReddsTools is distributed as both a rootless Debian package (`.deb`) and a standalone dynamic library (`.dylib`).

### Method 1: iOS Rootless Jailbreak (Dopamine / Palera1n)
1. Download the pre-compiled `.deb` package (`com.phuror.reddstools_1.0.0_iphoneos-arm64.deb`).
2. Install via Sileo, Zebra, Filza, or terminal:
   ```bash
   dpkg -i com.phuror.reddstools_1.0.0_iphoneos-arm64.deb
   ```
3. Launch the game. The draggable Redd icon will appear over the screen.

### Method 2: Sideloaded IPA Injection (TrollStore / Sideloadly / Esign / Feather / Azule)
Because ReddsTools provides self-contained packages, you only need to inject a **singular file** into the decrypted `.ipa`:

- **Using Sideloadly:** Select the decrypted ACPCC `.ipa`, open "Advanced Options", add the singular `com.phuror.reddstools_1.0.0_iphoneos-arm64.deb` (or `ReddsTools.dylib`) under "Tweak Injection", and click Start.
- **Using Azule:**
  ```bash
  azule -i target.ipa -o output.ipa -f com.phuror.reddstools_1.0.0_iphoneos-arm64.deb
  ```
- **Using Esign / Feather / TrollStore:** Import the decrypted `.ipa`, tap "Inject / Add Library", pick the provided `.deb` or `.dylib`, and sign the application. No manual filesystem folder copying is required.

---

## 4. Camp Caretaker Stability Warning & Emergency Overwrite

Certain Special NPCs or incomplete character models lack walking animations or valid overworld locomotion AI. Appointing an unsupported character as your Camp Caretaker can cause the game client to crash during overworld loading.

If you encounter an NPC that triggers a crash, please **open an issue on GitHub** stating the character name and ID so it can be added to the auto-sanitization blacklist.

<p align="center">
  <img src="assets/screenshots/7_settings_and_hud.png" width="31%" alt="Emergency Rescue & Settings" />
</p>

### Emergency Rescue Mechanisms

If the game crashes upon launch or becomes unresponsive due to a crashing companion:

1. **Floating Icon Double-Tap:** Double-tap the floating Redd avatar icon on the screen at any point.
2. **Settings Panel Reset:** Long-press the floating Redd icon to open Settings, then tap **RESET COMPANION**.

Both mechanisms immediately force-appoint a verified standard character (Bob / `cat00`) and set an automatic boot-recovery flag (`Pref_EmergencySafeBobPending`) that cleanses persistent companion state on next boot.

---

## 5. Intellectual Property & Copyright Notice

*Animal Crossing: Pocket Camp Complete*, *Animal Crossing*, character names, textures, and associated media are registered trademarks and copyrights of **Nintendo Co., Ltd.**

ReddsTools is an independent, community-driven reverse-engineering project created strictly for personal entertainment, research, and noncommercial offline game preservation. This repository contains no proprietary game code, decrypted game binaries, or proprietary database files.

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
