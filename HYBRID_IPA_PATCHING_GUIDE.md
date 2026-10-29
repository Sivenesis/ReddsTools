# Animal Crossing: Pocket Camp Complete (v7.1.4)
## Hybrid IPA & Jailed Modding Blueprint: Technical Specification and Reproduction Guide

This document provides a comprehensive technical reference for reproducing, maintaining, and extending the hybrid jailed modification for *Animal Crossing: Pocket Camp Complete* (`com.nintendo.zasa`, v7.1.4 Build 270) on non-jailbroken iOS devices.

---

## 1. System Architecture & Constraints

### 1.1 Jailed iOS Operating Environment
On non-jailbroken iOS (sideloaded via AltStore, Sideloadly, TrollStore, or Enterprise certificates):
1. **No Kernel / Root Privileges:** The process runs within standard application sandboxing.
2. **Strict W^X (Write XOR Execute) Memory Protection:** Calling `vm_protect` or `mprotect` with `VM_PROT_WRITE | VM_PROT_EXECUTE` on memory containing code fails with `KERN_PROTECTION_FAILURE`.
3. **Absence of JIT:** Dynamic code generation and runtime detour hooks (`MSHookFunction`, Substrate, ElleKit, Frida interposers) cannot patch instructions in `__TEXT`.
4. **Mach-O Binary Layout:**
   - Main Executable: `Payload/zasa.app/zasa` (Mach-O 64-bit arm64 executable).
   - Core Engine Framework: `Payload/zasa.app/Frameworks/UnityFramework.framework/UnityFramework` (Mach-O 64-bit arm64 dylib, containing all compiled IL2CPP code and Unity subsystems).

### 1.2 The Hybrid Modding Architecture
To achieve feature parity with jailbroken tweaks without JIT, the solution uses a tripartite architecture:
1. **Static Binary Modification of `UnityFramework`:** 32 pre-baked memory gates in the `__TEXT` segment replace method prologues or branching instructions with hardcoded returns, bypassing anti-cheat, unlocking catalogs, granting unlimited quarry entries, and nullifying check routines.
2. **Indirect Function Pointer Trampoline (`__DATA` Bridge):** For features that require runtime interactivity (such as Time Travel, which depends on real-time UI sliders, quick jumps, and clock freezes), `UtcTime.get_Now` is redirected through an unused, writable slot in `UnityFramework`'s `__DATA` segment (`base + 0x7715B00`). The injected dylib populates this slot with the address of its runtime handler.
3. **In-Process Injected Dylib (`ReddsTools.dylib`):** Injected via `LC_LOAD_DYLIB` into `zasa`. Spawns an overlay UIKit modal window directly above the Unity Metal view, performs direct in-memory reads and writes of encrypted game currency structures (`GuardInt` / `GuardLong`), reads live inventory amounts, alters assistant assignments, and hosts the Time Travel engine.

```
+-----------------------------------------------------------------------------------------+
|                                      ACPCC Process                                      |
|                                                                                         |
|  +-------------------------------------+      +--------------------------------------+  |
|  |             zasa (App)              |      |           ReddsTools.dylib           |  |
|  |  +-------------------------------+  |      |  +--------------------------------+  |  |
|  |  | LC_LOAD_DYLIB (ReddsTools)     |=======>|  | UIKit Floating Overlay Window  |  |  |
|  |  +-------------------------------+  |      |  | - Currency Modifiers           |  |  |
|  +-------------------------------------+      |  | - Complete Tickets Live Read   |  |  |
|                                               |  | - Companion Modal (478 Icons)  |  |  |
|  +-------------------------------------+      |  | - Time Travel Engine Handler   |  |  |
|  |   UnityFramework (IL2CPP Engine)    |      |  +--------------------------------+  |  |
|  |                                     |                     |                          |
|  |  [__TEXT] Static Binary Patches     |                     |                          |
|  |  - 31 Static Gates (Cheat, HH, etc.)|                     |                          |
|  |  - 0x1E2B904 (UtcTime.get_Now)      |                     |                          |
|  |      adrp x8, #0x7715000            |                     |                          |
|  |      ldr  x8, [x8, #0xb00]          |                     |                          |
|  |      br   x8                        |                     |                          |
|  |              |                      |                     |                          |
|  |              | (Reads Pointer)      |                     | (Writes Function Ptr)    |
|  |              v                      |                     v                          |
|  |  [__DATA] base + 0x7715B00 <------------------------------+                          |
|  +-------------------------------------+                                                |
+-----------------------------------------------------------------------------------------+
```

---

## 2. Reproduction Pipeline

To reproduce the modified hybrid IPA from a pristine stock IPA:

### Step 1: Compile `ReddsTools.dylib` for Jailed iOS
1. Toolchain requirement: Theos arm64 cross-compiler (iOS SDK 16.5, target `iphone:clang:16.5:15.0`).
2. Build script: [`ReddsTools/build_jailed_dylib.sh`](file:///f:/Progs/VIBECODE/PROJECTS/ios/games/acpcc/ReddsTools/build_jailed_dylib.sh).
3. Preprocessing:
   - Strips all Substrate/Logos macros (`%hook`, `%end`, `%ctor`).
   - Defines `-DJAILED=1`.
   - Compiles [`Tweak.xm`](file:///f:/Progs/VIBECODE/PROJECTS/ios/games/acpcc/ReddsTools/Tweak.xm) as pure Objective-C/C++ (`ReddsTools.mm`).
4. Output: [`ReddsTools/jailed/ReddsTools.dylib`](file:///f:/Progs/VIBECODE/PROJECTS/ios/games/acpcc/ReddsTools/jailed/ReddsTools.dylib).

### Step 2: Prepare Asset Bundle
The custom Caretaker companion picker modal requires character metadata and villager head icons:
- Metadata: [`villagers/characters.json`](file:///f:/Progs/VIBECODE/PROJECTS/ios/games/acpcc/villagers/characters.json) (contains 478 entries with `name`, `id`, `asset_name`, and `is_special`).
- Head Icons: 478 PNG files (named `<asset_name>.png`, e.g., `cmn_icon_chr_cat_00.png`) located in [`villagers/companion_icons/`](file:///f:/Progs/VIBECODE/PROJECTS/ios/games/acpcc/villagers/companion_icons/).
- Destination inside IPA:
  - `Payload/zasa.app/ReddsTools/characters.json`
  - `Payload/zasa.app/ReddsTools/icons/*.png`

### Step 3: Run the Packaging Script
Execute [`create_hybrid_ipa.py`](file:///f:/Progs/VIBECODE/PROJECTS/ios/games/acpcc/create_hybrid_ipa.py) with Python 3:
```powershell
python f:\Progs\VIBECODE\PROJECTS\ios\games\acpcc\create_hybrid_ipa.py
```
This script:
1. Reads `F:\Progs\VIBECODE\PROJECTS\ios\games\acpcc\raw\ACPCC_7.1.4.ipa`.
2. Injects `LC_LOAD_DYLIB` pointing to `@executable_path/Frameworks/ReddsTools.dylib` into `Payload/zasa.app/zasa`.
3. Validates and applies all 32 static memory patches directly to `Payload/zasa.app/Frameworks/UnityFramework.framework/UnityFramework`.
4. Copies `ReddsTools.dylib` into `Payload/zasa.app/Frameworks/`.
5. Stages `characters.json` and all 478 companion icons into `Payload/zasa.app/ReddsTools/`.
6. Generates `F:\Progs\VIBECODE\PROJECTS\ios\games\acpcc\raw\ACPCC_7.1.4_Hybrid.ipa`.

---

## 3. Complete Static Binary Patch Specification (32 Gates)

All RVAs are relative to `UnityFramework` base address (`0x0`). Every patch replaces an exact sequence of bytes with replacement ARM64 instructions.

### 3.1 Group 1: Anti-Cheat & Telemetry Suppression
| Gate Name | Target Method | RVA | Original Opcodes (Hex) | Replacement Opcodes (Hex) | Assembly / Effect |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `Cheating.SendTrap` | `Cheating.SendTrap` | `0x22C5628` | `f8 5f bc a9 f6 57 01 a9` | `c0 03 5f d6 1f 20 03 d5` | `ret; nop` (Suppresses EventCategory.CheatDevice) |

### 3.2 Group 2: Camp Caretaker Special Character Unlock
| Gate Name | Target Method | RVA | Original Opcodes (Hex) | Replacement Opcodes (Hex) | Assembly / Effect |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `RegistrationChecker.CanRegister` | `RegistrationChecker.CanRegister` | `0x25D74C8` | `f6 57 bd a9 f4 4f 01 a9` | `20 00 80 52 c0 03 5f d6` | `mov w0, #1; ret` (Bypasses special furniture requirement) |
| `CandidateNpcList.LovePointBypass` | `CandidateNpcList.CheckLovePoint` | `0x25D6884` | `f6 57 bd a9 f4 4f 01 a9` | `20 00 80 52 c0 03 5f d6` | `mov w0, #1; ret` (Bypasses friendship level requirement) |

### 3.3 Group 3: Full Catalog & Complete Ticket Unlock
| Gate Name | Target Method | RVA | Original Opcodes (Hex) | Replacement Opcodes (Hex) | Assembly / Effect |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `CatalogIsOnCatalog` | `UICatalogDao.IsOnCatalog` | `0x2951B30` | `00 14 40 f9 60 00 00 b4` | `20 00 80 52 c0 03 5f d6` | `mov w0, #1; ret` (Forces all catalog entries visible) |
| `CatalogBookIsValidItem` | `UICatalogBookDao.IsValidItem` | `0x2EDC784` | `ff 03 01 d1 f6 57 01 a9` | `20 00 80 52 c0 03 5f d6` | `mov w0, #1; ret` (Marks items valid for ordering) |
| `CatalogCompleteIsValidItem` | `UICatalogCompleteTicketDetailDao.IsValidItem` | `0x2EE4D10` | `ff 03 01 d1 f6 57 01 a9` | `20 00 80 52 c0 03 5f d6` | `mov w0, #1; ret` (Allows all items via Complete Tickets) |
| `CatalogCompleteAllowCookies` | Branch check in `UICatalogCompleteTicketDetailDao` | `0x2EE09E4` | `c0 1a 00 54` | `1f 20 03 d5` | `nop` (Bypasses Fortune Cookie exclusion check) |
| `CatalogIgnoreBypass` | `UICatalogListDao.IsIgnoreItem` | `0x2E76AE8` | `f6 57 bd a9 f4 4f 01 a9` | `00 00 80 52 c0 03 5f d6` | `mov w0, #0; ret` (Never filters out unreleased items) |

### 3.4 Group 4: Instant Crafting
| Gate Name | Target Method | RVA | Original Opcodes (Hex) | Replacement Opcodes (Hex) | Assembly / Effect |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `InstantCraftComplete` | `UICraftDao.GetRemainTime` | `0x29AB41C` | `00 08 40 f9 60 00 00 b4` | `00 00 80 d2 c0 03 5f d6` | `mov x0, #0; ret` (Crafting time remaining = 0s) |
| `InstantRecipeTime` | `UICraftDao.GetRecipeCraftTime` | `0x29AB5B4` | `00 14 40 f9 60 00 00 b4` | `00 00 80 52 c0 03 5f d6` | `mov w0, #0; ret` (Base recipe duration = 0s) |

### 3.5 Group 5: Instant Garden (Flower Bloom & Bud)
| Gate Name | Target Method | RVA | Original Opcodes (Hex) | Replacement Opcodes (Hex) | Assembly / Effect |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `InstantFlowerComplete` | `UIGardenSlotDao.GetRemainBloomTime` | `0x1CE3614` | `00 28 40 f9 60 00 00 b4` | `00 00 80 52 c0 03 5f d6` | `mov w0, #0; ret` (Time to bloom = 0s) |
| `InstantFlowerBud` | `UIGardenSlotDao.GetRemainBudTime` | `0x1CE3504` | `00 20 40 f9 60 00 00 b4` | `00 00 80 52 c0 03 5f d6` | `mov w0, #0; ret` (Time to bud = 0s) |

### 3.6 Group 6: Never-Flee Insects
| Gate Name | Target Method | RVA | Original Opcodes (Hex) | Replacement Opcodes (Hex) | Assembly / Effect |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `NeverFleeInsects` | `InsectParam.Escape` | `0x24141F0` | `f6 57 bd a9 f4 4f 01 a9` | `c0 03 5f d6 1f 20 03 d5` | `ret; nop` (Neutralizes flee animation/state) |
| `InsectIsEscaped` | `InsectParam.get_IsEscaped` | `0x2414748` | `08 a8 41 b9 1f 19 00 71` | `00 00 80 52 c0 03 5f d6` | `mov w0, #0; ret` (Always returns false) |

### 3.7 Group 7: Crossover & Exclusive Fortune Cookie Shop & Purchasing
| Gate Name | Target Method | RVA | Original Opcodes (Hex) | Replacement Opcodes (Hex) | Assembly / Effect |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `CookieCampaignCheck` | `UIFortuneCookieDao.CampaignIdCheck` | `0x1C54F48` | `f6 57 bd a9 f4 4f 01 a9` | `20 00 80 52 c0 03 5f d6` | `mov w0, #1; ret` (Bypasses purchase campaign check) |
| `CookieReleaseCheck` | `UIFortuneCookieDao.ReleaseIdCheck` | `0x1C54E94` | `f4 4f be a9 fd 7b 01 a9` | `20 00 80 52 c0 03 5f d6` | `mov w0, #1; ret` (Bypasses purchase expiration check) |
| `CookiePresenterCheck` | `UIFortuneCookieShopPresenter.Check` | `0x2CA03C4` | `5f 07 00 71 04 a8 40 7a` | `0a 00 00 14 1f 20 03 d5` | `b +0x28; nop` (Bypasses shop display filter) |
| `CookieCacheBypass` | `UIFortuneCookieDao.IsExpired` | `0x1C55D80` | `40 19 00 b5 c8 bc 02 b0` | `1f 20 03 d5 c8 bc 02 b0` | `nop` (Prevents purging expired cookies) |
| `CookiePresenterEnableData` | Branch in `UIFortuneCookieShopPresenter` | `0x2C9E4DC` | `3f 04 00 71 ab 00 00 54` | `20 00 80 52 c0 03 5f d6` | `mov w0, #1; ret` (Forces cookie data active) |
| `CookiePresenterCampaignId` | `UIFortuneCookieShopPresenter.GetCampaign` | `0x2CA4714` | `f4 4f be a9 fd 7b 01 a9` | `20 00 80 52 c0 03 5f d6` | `mov w0, #1; ret` (Returns valid campaign) |
| `CookiePresenterReleaseId` | `UIFortuneCookieShopPresenter.GetRelease` | `0x2CA50F4` | `01 01 00 34 fd 7b bf a9` | `20 00 80 52 c0 03 5f d6` | `mov w0, #1; ret` (Returns valid release id) |

### 3.8 Group 8: Happy Homeroom (HH) Hacks
| Gate Name | Target Method | RVA | Original Opcodes (Hex) | Replacement Opcodes (Hex) | Assembly / Effect |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `HHStamina3` | `HHStamina.get_CurrentStamina` | `0x1BFE0E4` | `f4 4f be a9 fd 7b 01 a9` | `60 00 80 52 c0 03 5f d6` | `mov w0, #3; ret` (Always 3 stamina Golden Tickets) |
| `HHVouchers999` | `HHManager.GetVoucherStock` | `0x1BFD944` | `f6 57 bd a9 f4 4f 01 a9` | `e0 7c 80 d2 c0 03 5f d6` | `mov x0, #999; ret` (Always 999 lesson vouchers) |
| `HHTicketEnough` | `HHManager.HasEnoughTickets` | `0x1BFDB80` | `f6 57 bd a9 f4 4f 01 a9` | `20 00 80 52 c0 03 5f d6` | `mov w0, #1; ret` (Ticket requirement satisfied) |
| `HHClearGrade3` | `HHJudge.EvaluateGrade` | `0x2D4255C` | `f8 5f bc a9 f6 57 01 a9` | `60 00 80 52 c0 03 5f d6` | `mov w0, #3; ret` (Always 3 medals awarded) |
| `HHFlawless` | `HHScorePresenter.GetFlawlessState` | `0x2362B90` | `ff 03 02 d1 fc 6f 02 a9` | `40 00 80 52 c0 03 5f d6` | `mov w0, #2; ret` (Forces "Flawless" banner display) |
| `HHMaxScore1000` | `HHScorePresenter.GetCalculatedScore` | `0x2361C80` | `fd 7b bf a9 fd 03 00 91` | `00 7d 80 52 c0 03 5f d6` | `mov w0, #1000; ret` (Awards maximum points) |

### 3.9 Group 9: Shovelstrike Quarry Unlimited Daily Entries
> [!CRITICAL]
> **Map Crash Root Cause:** `StoneSaveManager.get_IsOpened` (`0x2873BB4`) and the 7 friend helper gates (`CmpsAreaLimitedMine.NeedHelpCountToFriendEntry = 0`, etc.) **MUST NEVER BE PATCHED**.
> When `get_IsOpened` returns `true` before mine state is initialized, `SetupViewMineInfo.OnSetupDefaultView` on the Map screen branches into delayed reward loaders and dereferences a null object pointer (`bl 0x2cdf8`), causing an immediate crash when the Map button is pressed.
> 
> The ticket entry counter is fully isolated from the Map screen and runs solely inside `UIMineDeparturePresenter`. Only the 4 isolated ticket gates below are used:

| Gate Name | Target Method | RVA | Original Opcodes (Hex) | Replacement Opcodes (Hex) | Assembly / Effect |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `QuarryNeverCleared` | `StoneSaveManager.IsCleared` | `0x2873C34` | `f4 4f be a9 fd 7b 01 a9` | `00 00 80 52 c0 03 5f d6` | `mov w0, #0; ret` (Quarry never marked cleared) |
| `QuarryTicketRemain` | `StoneSaveManager.GetTicketRemainEnterNum` | `0x2873C94` | `f4 4f be a9 fd 7b 01 a9` | `60 0c 80 52 c0 03 5f d6` | `mov w0, #99; ret` (Displays `Daily Uses: 99`) |
| `QuarryCanUseTicket` | `CmpsAreaLimitedMine.CanUseTicketEntry` | `0x1F76EEC` | `fd 7b bf a9 fd 03 00 91` | `20 00 80 52 c0 03 5f d6` | `mov w0, #1; ret` (Bypasses `used < 3` check) |
| `QuarryCanNotUseTicket` | `UIMineDepartureDao.CanNotUseTicketEntry` | `0x1B4574C` | `f4 4f be a9 fd 7b 01 a9` | `00 00 80 52 c0 03 5f d6` | `mov w0, #0; ret` (Prevents enter button disabling) |

### 3.10 Group 10: JIT-Free Time Travel Indirect Function Pointer Bridge
| Gate Name | Target Method | RVA | Original Opcodes (Hex) | Replacement Opcodes (Hex) | Assembly / Effect |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `UtcTime.get_Now_Bridge` | `UtcTime.get_Now` | `0x1E2B904` | `f4 4f be a9 fd 7b 01 a9 fd 43 00 91 34 d2 02 b0 88 b2 7d 39 d3 ae 02 f0` | `48 c7 02 d0 08 81 45 f9 48 00 00 b4 00 01 1f d6 00 00 80 d2 c0 03 5f d6` | Loads function pointer from `base + 0x7715B00` and executes `br x8` |

---

## 4. Time Travel Implementation Details

### 4.1 The `__DATA` Memory Bridge
In `UnityFramework`, virtual memory address `0x7715B00` belongs to section `__DATA.__data` (segment protection `VM_PROT_READ | VM_PROT_WRITE`). This address contains 32 bytes of unused zero padding directly preceding `__swift51_hooks`.

Because `__DATA` is writable at runtime without permission changes, `ReddsTools.dylib` writes its function pointer into this memory address during initialization:
```objc
static void ensureBridgeInstalled(void) {
    uintptr_t base = getUnityBase();
    if (base) {
        *(void**)(base + 0x7715B00) = (void*)&hook_UtcTime_get_Now;
    }
}
```

### 4.2 Trampoline Disassembly at `0x1E2B904`
```armasm
0x1e2b904: adrp  x8, #0x7715000       ; Compute 4KB page of base + 0x7715000
0x1e2b908: ldr   x8, [x8, #0xb00]      ; Load 64-bit address from 0x7715B00
0x1e2b90c: cbz   x8, #0x1e2b914        ; If pointer is NULL (dylib unmapped), branch to fallback
0x1e2b910: br    x8                    ; Jump directly into hook_UtcTime_get_Now
0x1e2b914: mov   x0, #0                ; Fallback return
0x1e2b918: ret
```

### 4.3 Dylib Interceptor Routine
In [`ReddsTools/Tweak.xm`](file:///f:/Progs/VIBECODE/PROJECTS/ios/games/acpcc/ReddsTools/Tweak.xm):
```objc
extern "C" int64_t hook_UtcTime_get_Now(void *method) {
    if (!g_timeTravelActive) {
        return (int64_t)time(NULL);
    }
    if (g_timeFreezeActive) {
        return g_frozenTimestamp;
    }
    return (int64_t)time(NULL) + g_timeOffsetSeconds;
}
```
All game engines, animal cycles, flower timers, and daily resets poll `UtcTime.get_Now` each frame. Modifying `g_timeOffsetSeconds` dynamically reflects across all game systems immediately.

---

## 5. In-Memory Currency & Engine Interrogation

### 5.1 Encrypted Currencies (`GuardLong` & `GuardInt`)
ACPCC protects Bells and Leaf Tokens using memory scrambling classes (`GuardLong` at `0x18020A0`, `GuardInt` at `0x180073C`). Directly writing integers into memory triggers integrity assertion crashes.

`ReddsTools.dylib` invokes the compiled IL2CPP mutators:
```objc
void writeBells(int64_t val) {
    uintptr_t base = getUnityBase();
    uintptr_t prof = findUserProfile();
    if (!prof) return;
    void *guardLongObj = *(void**)(prof + 0x28); // UserProfileEntry.bell_
    typedef void (*fn_set_value)(void *self, int64_t v, void *m);
    fn_set_value setValue = (fn_set_value)(base + 0x18020A0);
    setValue(guardLongObj, val, NULL);
}
```

### 5.2 Complete Tickets Live Inventory Read
Complete Tickets are managed by `CmpsItemStock.GetItemStockAmount` (`0x21785A4`):
1. Resolve `CmpsUserSelf` instance via static class pointer at `base + 0x73F7348`.
2. Retrieve `mItemStock` at offset `0x38`.
3. Resolve the static IL2CPP string literal `"cookie_ticket"` at `base + 0x74AE898`.
4. Call `GetItemStockAmount(itemStock, cookieTicketStr, false, NULL)`.

### 5.3 Camp Caretaker Switcher
Special NPCs (such as Isabelle, K.K. Slider, Celeste) and standard villagers are switched by writing directly to `AssistantManager.mCurrentAssistantNpcLabel`:
1. Obtain `AssistantManager` singleton from `Singleton<AssistantManagerAccessor>.get_Instance` via pointer at `base + 0x7446018`.
2. Construct an IL2CPP string representation of the target character ID (e.g., `"cmn_cat00"`).
3. Invoke `AssistantManager.SetAssistantNpcLabel` (`0x25D4B2C`).

---

## 6. Sideloading & Bundle Gotchas

1. **Bundle Resource Resolution on iOS 16+:**
   - Standard `[NSBundle bundleForClass:[self class]]` returns the framework subdirectory or a sandboxed temporary path under sideloaded installations.
   - Use `[[NSBundle mainBundle] bundlePath]` and append `/ReddsTools/characters.json` or `/ReddsTools/icons/` to ensure assets load properly across all signing frameworks (AltStore, Sideloadly, TrollStore).
2. **Mach-O `LC_LOAD_DYLIB` Insertion:**
   - Appending a load command requires modifying `ncmds` (+1) and `sizeofcmds` (+aligned length) in the Mach-O header (`buf[:32]`).
   - The command length must be padded to an 8-byte boundary.
   - The inserted command uses `@executable_path/Frameworks/ReddsTools.dylib` with `compatibility_version` and `current_version` set to `0x10000`.
3. **Quarry Map Crash Prevention:**
   - Never re-enable `StoneSaveManager.get_IsOpened` (`0x2873BB4`) in static patches. It will crash the game when the Map icon is tapped.
   - Only the 4 ticket entry gates in Group 9 must be present.
