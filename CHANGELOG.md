# Changelog

All notable changes to **ReddsTools** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.5.0] - 2026-10-29

### Added
- **Hybrid Jailed IPA Architecture**: Complete 32-gate static binary patch specification enabling full feature parity on non-jailbroken devices without JIT.
- **JIT-Free Time Travel Bridge**: Dynamic function pointer trampoline through writable memory slot `base + 0x7715B00` (`__DATA.__data`), routing in-game time checks into `ReddsTools.dylib` without requiring `vm_protect` on executable pages.
- **Automated Hybrid IPA Creator**: `create_hybrid_ipa.py` for automated Mach-O load command injection (`LC_LOAD_DYLIB`), 32-gate binary patching, and asset bundle staging.
- **Hybrid IPA Patching Guide**: `HYBRID_IPA_PATCHING_GUIDE.md` detailing the entire reverse-engineering specification, designed for immediate ingestion by AI coding agents.
- **Complete Tickets Live Balance**: In-process stock amount resolution via `CmpsUserSelf.GetItemStockAmount` with IL2CPP static string `"cookie_ticket"`.
- **Crossover Cookie Purchasing**: Static binary bypasses for `UIFortuneCookieDao.CampaignIdCheck` and `ReleaseIdCheck` resolving "item no longer available" error on jailed iOS.
- **Isolated Quarry Entry Gates**: Preserved unlimited daily quarry entries (`Daily Uses: 99`) while isolating and excluding map-level `get_IsOpened` patches to prevent Map screen crashes.
- **Dedicated Lite Mode Dylib**: Standalone `ReddsTools_lite_inject.dylib` for single-step IPA injection without JIT or binary patching, providing Currencies, Camp Caretaker companion browser, Speedhack, and HUD.
- **Embedded Villager Database**: Embedded fallback database of all 478 Animal Crossing characters in `EmbeddedVillagersData.h`, ensuring character selection operates reliably without bundled JSON files.
- **Rootless Debian Package v1.5.0**: Pre-compiled `ReddsTools_rootless.deb` for iOS 15.0 – 16.x+ with full dynamic ElleKit / Substrate hook support.

## [1.0.0] - 2026-10-28

### Initial Release

#### Core Overlay & Architecture
- Standalone in-process UIKit floating overlay with draggable Redd avatar button.
- Native dynamic IL2CPP API bindings (`il2cpp_domain_get`, `il2cpp_runtime_invoke`, `il2cpp_resolve_icall`).
- Proactive memory patching and neutralization of `Cheating.SendTrap` telemetry telemetry.

#### Features
- **Currencies & Bag Materials**: Set exact Bells, add +1,000,000, or max out at 9,999,999; set exact Leaf Tokens, add +1,000, or max out at 99,999; max all crafting materials (Wood, Steel, Cotton, Paper, Preserves, Essences) to 999; currency freeze loop.
- **Camp Caretaker & Roaming Companion**: Universal furniture ownership bypass for all 65 Special NPCs (`RegistrationChecker.CanRegister`); overworld following locomotion AI toggle (`WalkWithFacade`); 478-character searchable modal grid with categorized tabs and lazy icon loading; one-tap instant assign shortcuts for popular Special NPCs.
- **Time Travel & Clock Spoofing**: In-process interception of `NDcube.Type.UtcTime.get_Now`; anti-save-pollution protection committing real POSIX timestamps on save writes; arbitrary `UIDatePicker` selector; seasonal event presets (Halloween, Toy Day, Cherry Blossoms, Summer Island, New Year Countdown); quick offset jumps (+3h, +12h, +24h, -3h, -24h); clock freeze and live HUD status.
- **Instant Crafting & Workshop**: Zero-delay furniture, clothing, and amenity completion via memory gates on `get_CompleteDate` and `get_RecipeTime`.
- **Gardening & Events**: One-tap instant bloom for all 20 plots; permanent instant bloom memory gate; 100% event creature catch rate rerouted through `PaidCatch`.
- **Fishing & Insects**: Zero-delay instant bite (`FishBite.OnStart`); instant fish pull memory gate; never-flee insects memory gate.
- **Villagers & Campsite**: Max friendship levels (70+) across all animals; auto-fulfill active visitor and campsite requests; campsite villager force-spawner presets.
- **Shovelstrike Quarry**: Unlimited daily quarry entries; free entry without friend assistance; permanent quarry open state.
- **Engine Diagnostics**: Time scale multiplier (1.0x to 10.0x); Unity Universal Render Pipeline (URP) runtime debug overlay toggle.
