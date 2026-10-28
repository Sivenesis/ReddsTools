# iOS Floating Menu Feasibility Report & Technical Blueprint
**Target App:** *Animal Crossing: Pocket Camp Complete* (`com.nintendo.zasa`, v7.1.4 Build 270)  
**Environment:** Rootless Jailbroken iOS (Dopamine / Palera1n, iOS 15.0 – 16.x+, ElleKit / Substitute)  
**Reference Template:** `EnchMenu`

---

## 1. Feasibility Assessment

**Verdict: Fully Feasible (100%)**

*Animal Crossing: Pocket Camp Complete* is an optimal target for an in-process UIKit floating mod menu:
1. **Zero Server Validation & Ban Risk:** The game is 100% offline. All currencies, inventory, village friendships, and crafting timers are evaluated and committed strictly to local device storage (`UserOfflineCraft`, `UserOfflineFlowerbedOneSlot`, `NNpcLoveLevelStorage`).
2. **Exposed IL2CPP Runtime:** The main executable `UnityFramework.framework/UnityFramework` exports standard IL2CPP API symbols (`il2cpp_domain_get`, `il2cpp_class_from_name`, `il2cpp_runtime_invoke`, `il2cpp_resolve_icall`).
3. **No Kernel/Root Privilege Needed:** The floating menu template from `EnchMenu` operates entirely in-process using rootless ElleKit/Substrate hooks into `UnityAppController`, creating an overlay `UIWindow` above the Unity Metal view.

---

## 2. In-Memory Anti-Tamper & Integrity System (`GuardInt` / `GuardLong`)

A critical discovery in the reverse-engineering analysis is that ACPCC does **not** store raw 32-bit or 64-bit integers for sensitive game values. Blindly scanning or poking memory with conventional memory scanners (e.g. iGameGod / GameGem) causes crashes or rollbacks due to internal integrity checks.

### The Guard Structure
Currencies and progression stats are wrapped in specialized obfuscation classes:
- **`GuardInt`** (Used for Bells, Item Counts, Flowerbed timers, Boost Degrees):
  ```
  Offset 0x10: int32 hash
  Offset 0x14: int32 _value (Obfuscated XOR payload)
  Const: uint32 Phi = 3804763007 (0xE2C8137F)
  ```
- **`GuardLong`** (Used for Leaf Tokens, Complete Tickets, Timestamps):
  ```
  Offset 0x10: int32 hash
  Offset 0x18: int64 _value (Obfuscated XOR payload)
  ```

### Disassembly Analysis of `GuardInt.set_Value` (`0x180073C`)
```arm64
0x1800750: ldr   x8, [x0]              ; Load vtable
0x1800754: ldp   x9, x1, [x8, #0x158]  ; Virtual call to salt generator
0x1800758: blr   x9                    ; w0 = random salt
0x180075c: eor   w8, w0, w19           ; w8 = salt ^ value
0x1800760: mov   w9, #0x137f
0x1800764: movk  w9, #0xe2c8, lsl #16  ; w9 = 0xE2C8137F (Phi)
0x1800768: mul   w9, w8, w9            ; w9 = (salt ^ value) * Phi
0x180076c: eor   w9, w9, w9, asr #16   ; w9 ^= (w9 >> 16)
0x1800770: stp   w9, w8, [x20, #0x10]  ; Store [hash, _value] atomically
```

### Strategic Tweak Solution
Rather than manually calculating the mathematical hash, the tweak calls `GuardInt.set_Value(instance, newValue)` at RVA `0x180073C` and `GuardLong.set_Value(instance, newValue)` at RVA `0x18020A0` (or invokes property setters via `il2cpp_runtime_invoke`). This ensures the internal hash and salt are updated properly with zero risk of corruption.

---

## 3. High-Value Menu Features & Code References

```
+-------------------------------------------------------------------------------+
|                       ACPCC FLOATING MOD MENU BLUEPRINT                       |
+-------------------------------------------------------------------------------+
| [TAB 1: Currencies]                                                           |
|   - Bells: [ +1,000,000 ] [ Max 9,999,999 ]                                   |
|   - Leaf Tokens: [ +1,000 ] [ Max 99,999 ]                                    |
|   - Complete Tickets: [ +50 ] [ Max 999 ]                                     |
|   - Crafting Materials: [ Max All (Wood, Cotton, Steel, Essences) ]           |
+-------------------------------------------------------------------------------+
| [TAB 2: Workshop & Crafting]                                                  |
|   - Instant Crafting: [ ON / OFF ] (0s timers for furniture, clothes, tents)  |
|   - Free Crafting: [ ON / OFF ] (Bypasses material and currency costs)        |
|   - Unlock All 3 Crafting Workbenches: [ ON / OFF ]                           |
+-------------------------------------------------------------------------------+
| [TAB 3: Gardening & Events]                                                   |
|   - Instant Bloom: [ Apply to All 20 Plots ] (SecToComplete = 0)              |
|   - 100% Rare Creature Catch Rate: [ ON / OFF ] (Guaranteed Bats/Butterflies) |
|   - Force Spawn Event Creatures: [ Spawn on All Flowers ]                     |
+-------------------------------------------------------------------------------+
| [TAB 4: Fishing & Bug Catching]                                               |
|   - Auto-Bite / Instant Fish Catch: [ ON / OFF ] (No nibble wait, auto-tap)   |
|   - Never-Flee Insects: [ ON / OFF ] (Bugs never fly away when running)       |
|   - 100% Rare / Giant Fish & Bug Spawn: [ ON / OFF ]                          |
+-------------------------------------------------------------------------------+
| [TAB 5: Villagers & Friendship]                                               |
|   - Max Friendship (Favorability Level 70+): [ Target Villager / All Campsite]|
|   - Instant Request Fulfillment: [ Complete Current Animal Requests ]         |
+-------------------------------------------------------------------------------+
| [TAB 6: Shovelstrike Quarry & Cookies]                                        |
|   - Unlimited Daily Quarry Entries: [ Reset Daily Counter ]                   |
|   - All-Gold / All-Silver Rocks: [ Force High-Tier Ore Yield ]                |
|   - Fortune Cookie 5-Star Guaranteed: [ Force Spotlight Roll ]                |
+-------------------------------------------------------------------------------+
| [TAB 7: World & Utilities]                                                    |
|   - Speedhack Slider: [ 1.0x ] ====O=========== [ 10.0x ]                     |
|   - Instant Fast Travel: [ Select Destination Dropdown ]                      |
|   - Save Manager: [ Export Backup JSON ] [ Reload Profile ]                   |
+-------------------------------------------------------------------------------+
```

### Detailed Hook & Class Mapping

#### Feature 1: Currency & Material Modification
- **Target Classes:**
  - `CmpsInventoryItemBellData` (Bells)
  - `CmpsInventoryItemVirtualCurrencyData` (Leaf Tokens & Complete Tickets)
  - `CmpsItemDataMaterial` (Wood, Steel, Cotton, Paper, Preserves, Essences)
- **Implementation:**
  Traverse `UserItemStorageList` or obtain the active inventory context, then invoke `set_Value` on the respective `GuardInt` or `GuardLong` instance.

#### Feature 2: Instant & Free Crafting
- **Target Classes:**
  - `NDcube.Cmps.Craft.CraftManager`
  - `CmpsOfflineCraft` (`STORAGE_KEY = "UserOfflineCraft"`)
  - `UserOfflineCraftEntry`
- **Implementation:**
  Hook `UserOfflineCraftEntry.get_SecToComplete()` to return `0`, or hook `CmpsOfflineCraft.get_BoostDegree()` to return `999` (forcing maximum time acceleration). For free crafting, hook recipe check routines in `CraftManager` to return `true`.

#### Feature 3: Gardening Automation (Instant Bloom & 100% Catch Rate)
- **Target Classes:**
  - `UserOfflineFlowerbedOneSlotEntry` (TypeDefIndex: 1392)
  - `SceneMessageGardeningPaidCatchAnimal` / `ResultOfCatchAnimals`
- **Implementation:**
  - **Instant Bloom:** Loop through the 20 entries of `UserOfflineFlowerbedOneSlot` and set:
    `entry.SecToComplete = 0; entry.SecToBud = 0;`
  - **100% Catch Rate:** Hook `ResultOfCatchAnimals` or force `is_paid = true` in `SceneMessageGardeningPaidCatchAnimal`, which triggers Lloid's 100% guaranteed catch resolution.

#### Feature 4: Fishing & Bug Hunting Cheats
- **Target Classes:**
  - `CmpsFieldFish` (TypeDefIndex: 20166)
  - `FishBite`
  - `CmpsFieldInsect` / `InsectFlyEscape`
- **Implementation:**
  - **Instant Fish Catch:** Hook `FishBite._bite_time` to `0.0f` and force `CmpsFieldFish.isPull()` to return `true` immediately when the lure enters the water.
  - **Never-Flee Bugs:** In `InsectFlyEscape`, hook `_esc_speed` and `_mot_speed` to return `0.0f`, preventing insects from triggering flight animations regardless of running or missing a net swing.

#### Feature 5: Max Villager Friendship (Favorability)
- **Target Classes:**
  - `NNpcLoveLevelStorage` (RVA `0x20DC540`)
  - `UINpcFavorabilityDao`
- **Implementation:**
  Invoke `NNpcLoveLevelStorage.GetRecordsOrderByLovePoint()` to obtain all villager entries, then update the target villager's `LoveLevel` to maximum (e.g. 70 or 100) and trigger `UINpcFavorabilityConditionDao.Update()`.

#### Feature 6: Speedhack (Game Engine Clock)
- **Target Class:** `UnityEngine.Time`
- **RVA:** `0x1E2B618` (`set_timeScale(float value)`)
- **Implementation:**
  Call `((void(*)(float))((uintptr_t)unityBase + 0x1E2B618))(targetSpeed)` based on the slider value (1.0x – 10.0x). Instantly accelerates walking, animal dialogs, transitions, and animations.

#### Feature 7: Shovelstrike Quarry (Kouzan)
- **Target Classes:** `FieldKouzan00Scene`, `StoneSaveManager`, `StoneReward`
- **Implementation:**
  Hook `StoneSaveManager.get_TodayEnterCount()` to always return `0` (bypasses once-per-day restriction and helper request requirements). Hook `StoneReward` to force dropped item IDs to gold/silver nuggets.

---

## 4. Tweak Template & Skeleton Adaptation

The skeleton in `EnchMenu` maps cleanly to ACPCC. The necessary configuration adjustments are detailed below:

### 4.1 Rootless Theos Makefile (`Makefile`)
```makefile
export THEOS_PACKAGE_SCHEME = rootless
TARGET := iphone:clang:16.5:15.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ACPCCMenu

ACPCCMenu_FILES = Tweak.xm
ACPCCMenu_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-error
ACPCCMenu_FRAMEWORKS = UIKit QuartzCore CoreGraphics Security
ACPCCMenu_LIBRARIES = substrate

include $(THEOS_MAKE_PATH)/tweak.mk
```

### 4.2 Bundle Filter (`ACPCCMenu.plist`)
```xml
{
    Filter = {
        Bundles = ( "com.nintendo.zasa" );
    };
}
```

### 4.3 Control File (`control`)
```ini
Package: com.phuror.reddstools
Name: Redds Tools
Depends: mobilesubstrate (>= 0.9.5000)
Version: 1.0.0
Architecture: iphoneos-arm64
Description: Floating in-game mod menu for Animal Crossing: Pocket Camp Complete (Rootless).
Maintainer: PHUROR
Author: PHUROR
Section: Tweaks
```

### 4.4 Hook Lifecycle & Initialization (`Tweak.xm`)
```objc
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
#import <substrate.h>
#import "FloatIconData.h"

static uintptr_t gUnityBase = 0;

static uintptr_t getUnityBase(void) {
    if (gUnityBase) return gUnityBase;
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (name && strstr(name, "UnityFramework")) {
            gUnityBase = (uintptr_t)_dyld_get_image_vmaddr_slide(i) + 0x100000000ULL; // or vmaddr base
            break;
        }
    }
    return gUnityBase;
}

// Function pointer signatures resolved via RVA
typedef void (*fn_set_timeScale)(float);
typedef void (*fn_guardint_set_value)(void *instance, int32_t value);
typedef void (*fn_guardlong_set_value)(void *instance, int64_t value);

static void applySpeedhack(float speed) {
    uintptr_t base = getUnityBase();
    if (!base) return;
    fn_set_timeScale set_timeScale = (fn_set_timeScale)(base + 0x1E2B618);
    set_timeScale(speed);
}

// Hook Unity launch sequence
%hook UnityAppController
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    BOOL ret = %orig;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        initFloatingMenu();
    });
    return ret;
}
%end
```

---

## 5. Implementation Roadmap & Delivery Steps

1. **Step 1: Tweak Workspace Scaffolding**
   - Copy the `EnchMenu` skeleton to a new directory: `ReddsTools/`.
   - Update `Makefile`, `control`, and filter plist to target `com.nintendo.zasa`.
   - Replace the floating icon in `FloatIconData.h` with an Animal Crossing Leaf icon.

2. **Step 2: Core IL2CPP Engine Bridge**
   - Implement the `UnityFramework` base slide resolver.
   - Wire up `il2cpp_class_from_name` and property getter/setter invocations.
   - Verify `GuardInt.set_Value` (`0x180073C`) and `GuardLong.set_Value` (`0x18020A0`) in-process bindings.

3. **Step 3: Tabbed UI Construction**
   - Build the floating overlay modal with tabs:
     - Currencies & Materials
     - Crafting & Time
     - Garden & Creatures
     - Fishing & Bugs
     - Villagers & Quarry
     - World & Speedhack

4. **Step 4: Packaging & Testing on Rootless Device**
   - Build with Theos: `make package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless`.
   - Deploy `.deb` file to rootless iPhone via SSH or Filza / Sileo / Zebra.
   - Test in-game toggles in offline environment.
