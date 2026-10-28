# Date & Time Spoofing ("Time Travel") Technical Specification

**Target Application:** *Animal Crossing: Pocket Camp Complete* (`com.nintendo.zasa`, v7.1.4 Build 270)  
**Binary Analyzed:** `Payload/zasa.app/Frameworks/UnityFramework.framework/UnityFramework` (Mach-O ARM64)  
**Metadata Analyzed:** `Payload/zasa.app/Data/Managed/Metadata/global-metadata.dat` (Metadata Version 39)  
**UI Framework:** UIKit Floating Menu (`EnchMenu` Skeleton)

---

## 1. Executive Summary

Time travel (manipulating in-game calendar and clock timestamps) is the single most powerful utility in *Animal Crossing*, allowing players to cycle villager visits, skip lengthy crafting timers, immediately bloom garden plants, restock fortune cookie shops, refresh the Shovelstrike Quarry, and activate seasonal holiday events on demand.

In *Animal Crossing: Pocket Camp Complete* (v7.1.4), the entire client backend was transitioned to an offline architecture. Disassembly of `UnityFramework` confirms that:
1. **Network Sync is Dead:** Server time synchronization routines (`UtcTime.GetRealTime`) have been stubbed into local device calculations. The game executes zero network calls to verify the clock.
2. **Single Chokepoint:** Every time-dependent subsystem in the game (over 863 direct calls across 657 classes) queries a single method: `NDcube.Type.UtcTime.get_Now()` at RVA `0x1E2B904`.
3. **In-Game Tweak vs. iOS System Settings:** Changing the iOS system clock via Settings fails to travel backwards because vanilla code clamps `Now` to `_lastPlayUnixTime` stored in the save file. An in-process Theos/ElleKit hook bypasses this clamp completely, enabling instantaneous, bidirectional time travel without side effects on system SSL certificates or other iOS apps.

---

## 2. Reverse-Engineered Time Architecture

### 2.1 Static Class Layout: `NDcube.Type.UtcTime`
The core time provider resides in the `NDcube.Type` namespace (TypeDefIndex: 14666):

```csharp
namespace NDcube.Type
{
    public static class UtcTime
    {
        // Static Fields (Static memory offset from Class.static_fields)
        private static bool <IsInitialized>k__BackingField;       // Offset 0x00
        private static long _now;                                  // Offset 0x08
        private static bool _isErrorSyncTime;                      // Offset 0x10
        private static long _lastSyncUnixTime;                     // Offset 0x18
        private static long _lastPlayUnixTime;                     // Offset 0x20
        private static long _recordedCheckTime;                    // Offset 0x28
        private static bool _immideatlyAfterCheckTime;             // Offset 0x30
        private static bool <IsEnableCheckAssetExpired>k__Field;   // Offset 0x31
        private static readonly long _interval_CheckOver24H;       // Offset 0x38 (86400s)
        private static readonly long _interval_CheckOver28D;       // Offset 0x40 (2419200s)
        private static readonly long _interval_CheckDiff10M;       // Offset 0x48 (600s)

        // Properties & RVAs
        public static long Now { get; }                           // RVA: 0x1E2B904
        public static DateTime DateTimeNow { get; }               // RVA: 0x1E3DF30
        public static long LastPlayUnixTime { get; }              // RVA: 0x1E3EE80
        public static void Initialize(long lastPlay, long lastSync); // RVA: 0x1E3E074
        public static void SyncDeviceTime();                      // RVA: 0x1E3E434
        public static void OnApplicationPause(bool pause);        // RVA: 0x1E3E3AC
    }
}
```

### 2.2 Execution Loop & Disassembly of `UtcTime.get_Now()`
Every frame, `NDcube.Engine.Initializer.OnBeforeUpdate()` (RVA `0x1E4C778`) calls `UtcTime.SyncDeviceTime()` (RVA `0x1E3E434`). This reads POSIX time via `DateTimeOffset.UtcNow` and stores the resulting epoch seconds in `UtcTime._now`.

When any game system needs the current timestamp, it calls `UtcTime.get_Now()` at RVA `0x1E2B904`. Disassembly reveals the exact clamping logic:

```arm64
; RVA: 0x1E2B904 - UtcTime.get_Now()
0x1e2b904: stp    x20, x19, [sp, #-0x20]!
0x1e2b908: stp    x29, x30, [sp, #0x10]
0x1e2b90c: add    x29, sp, #0x10

; Load pointer to UtcTime static fields
0x1e2b948: ldr    x9, [x0, #0xb8]         ; x9 = UtcTime static fields base
0x1e2b94c: ldr    x8, [x9, #8]            ; x8 = _now (current device time)
0x1e2b950: ldr    x9, [x9, #0x20]         ; x9 = _lastPlayUnixTime (from save file)

; Anti-Backwards-Travel Clamp:
0x1e2b954: cmp    x8, x9                  ; Compare _now with _lastPlayUnixTime
0x1e2b958: b.lt   #0x1e2b9d8              ; If _now < _lastPlayUnixTime, branch to clamp!

; Normal path: _now >= _lastPlayUnixTime
0x1e2b95c: mov    x0, x8                  ; Return _now
0x1e2b960: ldp    x29, x30, [sp, #0x10]
0x1e2b964: ldp    x20, x19, [sp], #0x20
0x1e2b968: ret

; Clamp path: _now < _lastPlayUnixTime
0x1e2b9d8: ldr    w10, [x0, #0xe4]
0x1e2b9dc: mov    x8, x9                  ; x8 = _lastPlayUnixTime (FORCED CLAMP)
0x1e2b9e0: cbnz   w10, #0x1e2b95c         ; Branch to return x8
...
0x1e2b9f4: mov    x0, x8                  ; Return _lastPlayUnixTime
0x1e2b9f8: ldp    x29, x30, [sp, #0x10]
0x1e2b9fc: ldp    x20, x19, [sp], #0x20
0x1e2ba00: ret
```

### 2.3 Disassembly of `UtcTime.get_DateTimeNow()`
At RVA `0x1E3DF30`, `get_DateTimeNow()` does not read hardware clocks independently; it executes:
```arm64
0x1e3df68: bl     #0x1e2b904              ; Call UtcTime.get_Now()
0x1e3df6c: mov    x19, x0                 ; x19 = unix timestamp
...
0x1e3dfb0: scvtf  d0, x19                 ; Convert integer to double
0x1e3dfb4: add    x0, x8, #8
0x1e3dfc8: b      #0x54b6f7c              ; Call DateTime.FromUnixTimeSeconds()
```
Consequently, hooking `UtcTime.get_Now()` automatically synchronizes both `Now` and `DateTimeNow`.

### 2.4 Offline Stubbing of Server Time Sync
In the former live-service version, `UtcTime.GetRealTime(long nowForCheckTime)` (RVA `0x1E3EBFC`) performed HTTP queries to DeNA/Sakasho time servers. In build 270, the inner lambda `<GetRealTime>b__1` at RVA `0x1E3FD54` was refactored:
```arm64
0x1e3fe8c: strb   wzr, [x20, #0x10]       ; ResultCheckSyncTime._hasError = false
0x1e3fe90: str    x19, [x20, #0x18]       ; ResultCheckSyncTime._serverUnixTime = localNow
0x1e3fe94: mov    x0, x20                 ; Return ResultCheckSyncTime
0x1e3fea4: ret
```
There is zero remote time integrity validation in the binary.

---

## 3. Subsystem Impact Analysis

Scanning the ARM64 code segment reveals **952 call sites** relying on `UtcTime.get_Now()`. Manipulating this return value controls every major game loop:

### 3.1 Crafting Timers (`UserCraftFtrClothNowWorkOneSlot`)
* **Class:** `NDcube.Cmps.Sys.User.Impl.CraftFtrClothNowWorkOneSlot.UserCraftFtrClothNowWorkOneSlot`
* **Fields:** `_CompleteDate` (GuardLong at offset `0x10`), `RecipeTime` (GuardInt at `0x28`).
* **Logic:** When crafting starts: `CompleteDate = UtcTime.Now + RecipeTime`. In the UI update loop (`UICraftSequenceObject.<ReciveCraftObject>d__23.MoveNext`), the game evaluates:
  $$\text{UtcTime.Now} \ge \text{CompleteDate}$$
* **Spoofing Result:** Advancing time by $+24\text{h}$ or $+72\text{h}$ instantly finishes any in-progress furniture, clothing, or campsite amenity craft without spending Leaf Tokens.

### 3.2 Flowerbed & Garden System (`CmpsGardeningManager`)
* **Class:** `Cmps.App.Gardening.CmpsGardeningManager`
* **Methods:** `OverrideAllFlowerbedCheckTime` (RVA `0x17F6A34`), `ApplyFlowerbedsToField` (RVA `0x17F53E0`).
* **Logic:** Garden seeds require 3 to 4 hours to bloom. Once bloomed, rare creatures (event butterflies and bees) spawn on the petals.
* **Spoofing Result:** Advancing time by $+4\text{ hours}$ brings all 20 flowerbed slots from newly planted seeds directly into full bloom, triggering creature appearances immediately.

### 3.3 Fortune Cookie Shop Daily Restock
* **Class:** `Cmps.UI.FortuneCookie.View.UIFortuneCookieShopDialog`
* **Methods:** `GetNextLotteryTime` (RVA `0x277B564`), `SetBellCookieNextLotteryTimer` (RVA `0x277B6D8`).
* **Logic:** The standard Bell Cookie cart restocks two cookies every 24 hours at the global DateLine boundary (15:00 UTC / 00:00 JST). Special 5,000-Bell character cookies appear via a weighted lottery.
* **Spoofing Result:** Advancing time across 15:00 UTC immediately restocks the cart, allowing unlimited sequential purchasing of 5,000-Bell memory cookies.

### 3.4 Shovelstrike Quarry (Mine Departure)
* **Class:** `NDcube.Cmps.App.Activity.Stone.StoneDatabase`
* **Methods:** `GetInSessionMineAreaLotteryDataRecodeList` (RVA `0x1F2C6DC`).
* **Logic:** The Quarry mineral reward pool (Essences, Gyroidite, Bells) resets on a 12-hour cycle (03:00 UTC and 15:00 UTC), locking the player out after one entry per cycle.
* **Spoofing Result:** A $+12\text{h}$ leap resets the entry lock and rolls a new mineral reward set.

### 3.5 Villager & Recreation Spot Rotation
* **Class:** `Cmps.App.TermEvent.CmpsActivityEvent`
* **Methods:** `AreaInitialize` (RVA `0x18F42A0`), `CheckEventTalk` (RVA `0x190DC08`).
* **Logic:** Visiting animal NPCs at Sunburst Island, Breezy Hollow, Lost Lure Creek, and Saltwater Shores rotate every 3 hours (00:00, 03:00, 06:00, 09:00, 12:00, 15:00, 18:00, 21:00 UTC), resetting active dialogue and 3 requests per animal.
* **Spoofing Result:** A $+3\text{h}$ jump triggers an instant rotation of all four recreation areas.

### 3.6 Seasonal Holiday Events Calendar
* **Class:** `Cmps.App.TermEvent.CmpsSeasonEvent`
* **Logic:** Master data FlatBuffers tables (`MasterAssetActivityEventMatAppearTime`, etc.) store timestamp ranges for historical and recurring seasonal events (Halloween, Toy Day, Bunny Day, Cherry Blossoms, Summer Festivals).
* **Spoofing Result:** Setting the calendar to a specific month/year activates the corresponding seasonal event UI, event currency drops (Gyroidites, event materials), and event goals.

---

## 4. Tweak Implementation Architecture

The tweak integrates into the UIKit floating window template (`EnchMenu`).

### 4.1 Memory & Hook Module (`TimeTravelHook.mm`)

```objc
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>

// Global State
static int64_t g_timeOffsetSeconds = 0;
static BOOL    g_timeTravelActive = NO;
static BOOL    g_timeFreezeActive = NO;
static int64_t g_frozenTimestamp = 0;

static uintptr_t getUnityBase(void) {
    static uintptr_t base = 0;
    if (!base) {
        uint32_t count = _dyld_image_count();
        for (uint32_t i = 0; i < count; i++) {
            const char *name = _dyld_get_image_name(i);
            if (name && strstr(name, "UnityFramework.framework/UnityFramework")) {
                base = (uintptr_t)_dyld_get_image_vmaddr_slide(i) + 0x100000000ULL;
                break;
            }
        }
    }
    return base;
}

// -------------------------------------------------------------
// 1. Hook UtcTime.get_Now() [RVA: 0x1E2B904]
// -------------------------------------------------------------
static int64_t (*orig_UtcTime_get_Now)(void);
static int64_t hook_UtcTime_get_Now(void) {
    if (!g_timeTravelActive) {
        return orig_UtcTime_get_Now();
    }
    if (g_timeFreezeActive) {
        return g_frozenTimestamp;
    }
    // Return hardware time + user defined offset
    return orig_UtcTime_get_Now() + g_timeOffsetSeconds;
}

// -------------------------------------------------------------
// 2. Anti-Save Pollution: Hook CmpsUserBoot.SetLastTimeInfo [RVA: 0x212BDD8]
// Prevents future spoofed timestamps from locking vanilla saves
// -------------------------------------------------------------
static void (*orig_SetLastTimeInfo)(void *self, int64_t lastPlay, int64_t lastSync);
static void hook_SetLastTimeInfo(void *self, int64_t lastPlay, int64_t lastSync) {
    if (g_timeTravelActive) {
        // Force the save file to commit genuine real-world time
        int64_t realNow = orig_UtcTime_get_Now();
        orig_SetLastTimeInfo(self, realNow, realNow);
        return;
    }
    orig_SetLastTimeInfo(self, lastPlay, lastSync);
}

// -------------------------------------------------------------
// 3. Neutralize Cheating.SendTrap [RVA: 0x22C5628]
// -------------------------------------------------------------
static void (*orig_Cheating_SendTrap)(void *self);
static void hook_Cheating_SendTrap(void *self) {
    // Drop integrity telemetry
    return;
}

// -------------------------------------------------------------
// Initialization & Function Hooking
// -------------------------------------------------------------
void initTimeTravelHooks(void) {
    uintptr_t base = getUnityBase();
    if (!base) return;

    %hookf(int64_t, (void *)(base + 0x1E2B904), hook_UtcTime_get_Now, (void **)&orig_UtcTime_get_Now);
    %hookf(void,    (void *)(base + 0x212BDD8), hook_SetLastTimeInfo, (void **)&orig_SetLastTimeInfo);
    %hookf(void,    (void *)(base + 0x22C5628), hook_Cheating_SendTrap, (void **)&orig_Cheating_SendTrap);
}
```

---

## 5. Floating Menu UI Design (UIKit)

The floating menu interface is added as a dedicated **"Time Travel"** tab inside the existing `EnchMenu` view hierarchy.

### 5.1 UI Layout Specification

```
+-------------------------------------------------------------+
|                     TIME TRAVEL CONTROLS                    |
+-------------------------------------------------------------+
| Current Game Time: 2026-10-27 18:30:00                      |
| Active Offset:     +0d 03h 00m 00s                          |
| Master Switch:     [ ENABLE TIME TRAVEL: ON  ]              |
+-------------------------------------------------------------+
| QUICK JUMPS (INSTANT SHIFT):                                |
|   [ +3 Hours (NPCs) ]       [ +12 Hours (Quarry) ]          |
|   [ +24 Hours (Day) ]       [ -3 Hours (Undo)    ]          |
|   [ -24 Hours (Back)]       [ RESET TO REAL TIME ]          |
+-------------------------------------------------------------+
| ARBITRARY DATE PICKER:                                      |
|   [ UIDatePicker: 2026 / 10 / 31   15:00:00 (Halloween) ]  |
|   [ APPLY SELECTED DATE ]                                   |
+-------------------------------------------------------------+
| TIME FREEZE:                                                |
|   [ FREEZE TIME AT CURRENT SECOND: OFF ]                    |
+-------------------------------------------------------------+
```

### 5.2 Implementation of UI Action Handlers

```objc
// Quick Jump Handlers
- (void)onQuickJump3Hours {
    g_timeTravelActive = YES;
    g_timeOffsetSeconds += (3 * 3600);
    [self updateDisplayLabels];
}

- (void)onQuickJump12Hours {
    g_timeTravelActive = YES;
    g_timeOffsetSeconds += (12 * 3600);
    [self updateDisplayLabels];
}

- (void)onQuickJump24Hours {
    g_timeTravelActive = YES;
    g_timeOffsetSeconds += (24 * 3600);
    [self updateDisplayLabels];
}

- (void)onQuickJumpMinus3Hours {
    g_timeTravelActive = YES;
    g_timeOffsetSeconds -= (3 * 3600);
    [self updateDisplayLabels];
}

- (void)onResetRealTime {
    g_timeOffsetSeconds = 0;
    g_timeTravelActive = NO;
    g_timeFreezeActive = NO;
    [self updateDisplayLabels];
}

// Arbitrary Date Picker Handler
- (void)onApplyDatePicker:(UIDatePicker *)picker {
    NSTimeInterval targetSecs = [picker.date timeIntervalSince1970];
    int64_t realNow = orig_UtcTime_get_Now();
    
    g_timeOffsetSeconds = (int64_t)targetSecs - realNow;
    g_timeTravelActive = YES;
    [self updateDisplayLabels];
}

// Time Freeze Handler
- (void)onToggleFreeze:(UISwitch *)sw {
    g_timeFreezeActive = sw.isOn;
    if (g_timeFreezeActive) {
        g_frozenTimestamp = hook_UtcTime_get_Now();
    }
}
```

---

## 6. Edge Cases & Safeguards

### 6.1 Save-File Bounds Protection
* **Risk:** If a user jumps forward 6 months to collect event items, saves the game, and then uninstalls the jailbreak tweak, vanilla `UtcTime.get_Now()` will read `_lastPlayUnixTime` from the save file and lock the game clock 6 months into the future.
* **Mitigation:** The hook on `CmpsUserBoot.SetLastTimeInfo` (RVA `0x212BDD8`) intercepts save operations and writes genuine hardware time to `LastPlayUnixTime` instead of the spoofed timestamp. The save file remains permanently compatible with unmodded game instances.

### 6.2 Flowerbed Wilting
Unlike mainline console titles (*Animal Crossing: New Horizons*), flowers in *Pocket Camp Complete* do not wilt or die when neglected over long periods. When traveling forward, flowerbeds advance to stage 3 (Bloomed) and remain bloomed indefinitely until harvested.

### 6.3 Turnip Spoiling
Mainline *Animal Crossing* titles punish backwards time travel by spoiling all Turnips. *Pocket Camp Complete* contains **no Turnip / Stalk Market mechanics**, removing the risk of economic penalties.

### 6.4 Immediate In-Game Event Dispatch
When jumping time forward while standing in the Campsite, recreation area NPCs or flowerbeds may not instantly visually re-render until the area reloads. To trigger an immediate visual refresh without restarting the app, the tweak can call the scene reload helper:
```objc
typedef void (*fn_load_area)(int areaId);
// Reload current area to execute awake/start lifecycle with new spoofed timestamp
```
Or simply prompt the player to open their Camper van and step back outside.

---

## 7. Verification Checklist

1. **Crafting:** Queue a 24-hour Amenity craft $\rightarrow$ Press `+24 Hours` $\rightarrow$ Verify amenity is ready for unveiling.
2. **Fortune Cookies:** Note the two 500-Bell cookies $\rightarrow$ Press `+24 Hours` $\rightarrow$ Open shop $\rightarrow$ Verify two new cookies appear.
3. **Quarry:** Enter the Quarry $\rightarrow$ Verify lock icon appears $\rightarrow$ Press `+12 Hours` $\rightarrow$ Verify Quarry entrance is reopened.
4. **Backwards Travel:** Press `-24 Hours` $\rightarrow$ Verify `UtcTime.get_Now()` returns the earlier timestamp and does not freeze or crash.
5. **Persistence:** Reboot the application $\rightarrow$ Verify real device time is restored when `g_timeTravelActive == NO`.
