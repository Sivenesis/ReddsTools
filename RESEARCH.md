# Technical Research & Reverse Engineering Specification: ReddsTools

**Document Target Audience:** Reverse engineers, AI coding agents, and security researchers.  
**Target Application:** *Animal Crossing: Pocket Camp Complete* (`com.nintendo.zasa`, v7.1.4 Build 270, Mach-O ARM64)  
**Execution Environment:** Rootless Jailbroken iOS (iOS 15.0 – 16.x+, ElleKit / Cydia Substrate, Dopamine / Palera1n)  
**Architecture:** In-Process UIKit Overlay with IL2CPP Runtime Hooks, Native Function Invocation & Instruction Patching  

---

## 1. Executive Summary & System Model

*Animal Crossing: Pocket Camp Complete* (ACPCC v7.1.4) represents a complete transition from Nintendo's legacy live-service game (which relied on Sakasho backend APIs) to a standalone, 100% offline single-player client. 

Because all server validation layers were stripped:
1. **Local State Authority:** All currency balances, craft queues, friendship states, gardening timers, inventory bags, and game calendar systems exist exclusively within local device memory and local serialized save files (`com.nintendo.zasa.plist` and local SQLite/FlatBuffer databases).
2. **Unified Time Chokepoint:** Every calendar, seasonal event, plant growth, quarry restock, and visitor rotation queries a single static chokepoint: `NDcube.Type.UtcTime.get_Now()` (RVA `0x1E2B904`).
3. **In-Process Delivery:** Rather than using network interception or external daemon processes, full game state modification is achieved via an in-process UIKit overlay library dynamically injected into `UnityFramework` using ElleKit/Substrate hooks into `UnityAppController`.

---

## 2. Reverse Engineering Pipeline & Toolchain

The reverse engineering methodology utilized to develop ReddsTools consisted of four phases:

### Phase 1: Binary & Metadata Extraction
1. The decrypted iOS application archive (`.ipa`) was unpacked to inspect the application bundle (`Payload/zasa.app`).
2. Main engine binary located at `Frameworks/UnityFramework.framework/UnityFramework` (Mach-O ARM64).
3. Managed metadata located at `Data/Managed/Metadata/global-metadata.dat` (Metadata version 39).
4. Asset bundles analyzed in `Data/data.unity3d` (`resources.assets`).

### Phase 2: Disassembly & IL2CPP Metadata Reconstruction
1. Executed `Il2CppDumper` against `UnityFramework` and `global-metadata.dat` to extract:
   - `dump.cs`: Type definitions, field offsets, property getters/setters, and Relative Virtual Addresses (RVAs).
   - `script.json`: Function boundaries and symbol maps.
   - `il2cpp.h`: C/C++ structural headers for native bridge compilation.
2. Cross-referenced decompiled C# classes in Ghidra / IDA Pro / Hopper to determine ARM64 instruction calling conventions (AAPCS64: `x0` = `this`, `x1` = first argument or `MethodInfo*`, return value in `x0` or `w0`).

### Phase 3: Runtime Dynamic Analysis
1. Located base load address slide dynamically via `_dyld_get_image_vmaddr_slide` for `UnityFramework`.
2. Verified live memory regions using `mach_vm_region` to ensure pointer dereferences reside in readable/writable address space before dereferencing (`ptrOK` validation).
3. Intercepted game telemetry and logging functions (`Cheating.SendTrap`).

### Phase 4: Asset Extraction & Character Database Construction
1. Reverse-engineered internal flatbuffer schemas and serialized ScriptableObjects.
2. Extracted all 478 character metadata entries (35 animal species + 65 Special NPCs) into a structured JSON database (`characters.json`).
3. Extracted 478 original character avatar icons into PNG assets bundled into the rootless filesystem (`layout/Library/Application Support/ReddsTools/`).

---

## 3. Anti-Tamper & Obfuscation Mechanisms

### 3.1 `GuardInt` and `GuardLong` Integrity Hashing
Standard memory scanners (e.g. iGameGod, GameGem, Cheat Engine) fail when modifying numeric values because ACPCC wraps sensitive integer fields in obfuscated structures:
- `NDcube.Core.Type.GuardInt` (32-bit integer)
- `NDcube.Core.Type.GuardLong` (64-bit integer)
- `NDcube.Core.Type.GuardShort` (16-bit integer)
- `NDcube.Core.Type.GuardUint` (32-bit unsigned integer)

#### Internal Mathematical Representation
```
Value = (salt ^ _value) * Phi
Phi   = 0xE2C8137F (Golden Ratio 32-bit prime multiplier)
```
Directly overwriting the raw `_value` field without recalculating `salt` triggers internal integrity assertions, resulting in game engine panics or state rollbacks on save commit.

#### Solution: IL2CPP Setter Invocation
Rather than brute-forcing the inverse hash, ReddsTools calls the compiled internal setters exposed in `UnityFramework`:
- `GuardInt.set_Value`: RVA `0x180073C`
- `GuardLong.set_Value`: RVA `0x18020A0`
- `GuardShort.set_Value`: RVA `0x1803ADC`
- `GuardUint.set_Value`: RVA `0x1806A44`

When updating Bells or Leaf Tokens, ReddsTools retrieves the property pointer, invokes the native setter with the desired balance, and allows the game's native assembly to compute the appropriate salt and encrypted values.

### 3.2 Telemetry Neutralization: `Cheating.SendTrap`
ACPCC includes an internal anti-tamper trap:
- **Class:** `NDcube.Cmps.Sys.Analytics.Cheating`
- **Method:** `SendTrap(CmpsUserSelf self)`
- **RVA:** `0x22C5628`
- **Behavior:** Inspects inventory quantities against master table caps; if an overflow is detected, dispatches telemetry event `EventCategory.CheatDevice` (11).

#### Solution: Memory Gate Instruction Patch & Substrate Hook
ReddsTools applies a two-tier defense:
1. **Memory Gate (Instruction Patch):** Overwrites the function prologue at `0x22C5628` with ARM64 opcode `ret; nop`:
   ```hex
   C0 03 5F D6   ; ret
   1F 20 03 D5   ; nop
   ```
2. **Cydia Substrate Hook:** Intercepts `SendTrap` and replaces the implementation with an empty stub function, ensuring no telemetry payload can execute.

---

## 4. Deep Dive: Core Subsystem Reverse Engineering

### 4.1 Bidirectional Time Travel Engine
In vanilla ACPCC, changing the iOS system clock via Settings causes irreversible desynchronization. If the user moves time backwards, `CmpsUserBoot` compares `Now` with `_lastPlayUnixTime` stored in the save file. If `Now < _lastPlayUnixTime`, the game clamps the clock forward.

#### Disassembly Findings
Decompilation of `UnityFramework` showed that over 863 time-dependent functions query a single routine:
```csharp
namespace NDcube.Type {
    public static class UtcTime {
        public static long get_Now();         // RVA 0x1E2B904
        public static DateTime get_DateTimeNow(); // RVA 0x1E3DF30
    }
}
```

#### Hook Implementation (`Tweak.xm`)
```objc
static int64_t (*orig_UtcTime_get_Now)(void *method) = NULL;
static int64_t hook_UtcTime_get_Now(void *method) {
    if (!gTimeTravelEnabled) {
        return orig_UtcTime_get_Now ? orig_UtcTime_get_Now(method) : (int64_t)time(NULL);
    }
    if (gClockFrozen) {
        return gFrozenTimestamp;
    }
    int64_t realNow = orig_UtcTime_get_Now ? orig_UtcTime_get_Now(method) : (int64_t)time(NULL);
    return realNow + gTimeTravelOffsetSeconds;
}
```

#### Anti-Save-Pollution Protection
To prevent spoofed future timestamps from poisoning the player's persistent save, ReddsTools hooks save-commit chokepoint `NDcube.Cmps.Sys.User.CmpsUserBoot.SetLastTimeInfo` (RVA `0x212BDD8`):
```objc
static void (*orig_SetLastTimeInfo)(void *self, int64_t timeVal, void *method) = NULL;
static void hook_SetLastTimeInfo(void *self, int64_t timeVal, void *method) {
    // Force write genuine POSIX hardware time instead of spoofed future time
    int64_t trueHardwareTime = (int64_t)time(NULL);
    if (orig_SetLastTimeInfo) orig_SetLastTimeInfo(self, trueHardwareTime, method);
}
```
If the tweak is disabled or removed, the player's save remains in perfect sync with real-world time.

---

### 4.2 Camp Caretaker & Roaming Companion Bypass (Strategy B)
In vanilla ACPCC, players can appoint normal animal villagers to walk with them. However, appointing **Special NPCs** (such as Isabelle, Tom Nook, Brewster, Celeste, Redd) is restricted:
- Special NPCs require crafting and owning high-tier furniture items (`AppointmentFurnitureID`).
- Attempting to place Special NPCs into standard campsite visitor slots (`UserMyCampNpcInfo`) triggers skeleton rig errors because Special NPCs lack standard interactive furniture animations.

#### The Discovery: The Assistant Subsystem Supports Special NPCs
The **Camp Caretaker (Assistant)** subsystem (`NDcube.Cmps.App.Assistant`) was engineered specifically to handle Special NPCs:
- Special NPCs have full walking, running, idle, reaction, and clapping animation blends.
- Overworld following locomotion AI (`WalkWithFacade`) operates identically for villagers and Special NPCs.

#### Validation Gating Chokepoint
The furniture ownership gate resides in `RegistrationChecker`:
- **Class:** `NDcube.Cmps.App.Assistant.Registration.RegistrationChecker`
- **Method:** `CanRegister(int snpcId)`
- **RVA:** `0x25D74C8`
- **Assembly Logic:** Reads player inventory for `AppointmentFurnitureID`; returns `0` (`false`) if not found.

#### Solution: The Memory Gate
ReddsTools patches `0x25D74C8` with:
```hex
20 00 80 52   ; mov w0, #1
C0 03 5F D6   ; ret
```
Additionally, `AssistantManager.RegisterAssistantNpc` (RVA `0x25D46FC`) is called directly with any character identifier (e.g. `fox00` for Redd, `sza00` for Isabelle, `rco00` for Tom Nook), bypassing all menu checks.

---

### 4.3 Memory Gating Mechanics (`applyGate`)
A "Memory Gate" is ReddsTools' term for an in-memory instruction patch that safely toggles between vanilla machine code and an optimized override without rebooting the app.

#### Implementation Pattern
```objc
typedef struct {
    uintptr_t rva;
    uint32_t patchOpcodes[4];
    uint32_t origOpcodes[4];
    size_t length;
    BOOL isPatched;
} MemoryGate;

static void applyGate(MemoryGate *gate, BOOL enable) {
    uintptr_t base = getUnityFrameworkBase();
    void *targetAddr = (void *)(base + gate->rva);
    
    mach_port_t task = mach_task_self();
    vm_prot_t origProt;
    
    // Make memory page read-write-execute
    vm_protect(task, (vm_address_t)targetAddr, gate->length, FALSE, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
    
    if (enable && !gate->isPatched) {
        memcpy(gate->origOpcodes, targetAddr, gate->length);
        memcpy(targetAddr, gate->patchOpcodes, gate->length);
        gate->isPatched = YES;
    } else if (!enable && gate->isPatched) {
        memcpy(targetAddr, gate->origOpcodes, gate->length);
        gate->isPatched = NO;
    }
    
    // Restore memory protection to read-execute
    vm_protect(task, (vm_address_t)targetAddr, gate->length, FALSE, VM_PROT_READ | VM_PROT_EXECUTE);
    
    // Invalidate ARM64 instruction cache
    sys_icache_invalidate(targetAddr, gate->length);
}
```

#### Complete Memory Gates Specification
| Target Subsystem | Method | RVA | Patch (ARM64) | Effect |
| :--- | :--- | :--- | :--- | :--- |
| Crafting Complete Date | `UserCraftFtrClothNowWorkOneSlotSetElement.get_CompleteDate` | `0x29AB41C` | `mov x0, #0; ret` | Instant crafting completion |
| Crafting Recipe Time | `UserCraftFtrClothNowWorkOneSlotSetElement.get_RecipeTime` | `0x29AB5B4` | `mov w0, #0; ret` | Zero crafting duration |
| Flowerbed Growth Secs | `UserOfflineFlowerbedOneSlotEntry.get_SecToComplete` | `0x1CE3614` | `mov w0, #0; ret` | Instant flower bloom |
| Flowerbed Bud Secs | `UserOfflineFlowerbedOneSlotEntry.get_SecToBud` | `0x1CE3504` | `mov w0, #0; ret` | Instant bud generation |
| Fish Pull Status | `CmpsFieldFish.isPull` | `0x23F7E24` | `mov w0, #1; ret` | Immediate strike detection |
| Insect Reaction Escape | `CmpsFieldInsect.ReactionEscape` | `0x24141F0` | `ret; nop` | Prevents insect flee AI |
| Insect Escaped Check | `CmpsFieldInsect.IsEscaped` | `0x2414748` | `mov w0, #0; ret` | Forces catch availability |
| Quarry Open State | `StoneSaveManager.get_IsOpened` | `0x2873BB4` | `mov w0, #1; ret` | Quarry always accessible |
| Quarry Clear Flag | `StoneSaveManager.IsCleared` | `0x2873C34` | `mov w0, #0; ret` | Bypasses once-per-day lock |
| Quarry Ticket Count | `StoneSaveManager.GetTicketRemainEnterNum` | `0x2873C94` | `mov w0, #99; ret` | Unlimited entry permits |
| Quarry Friend Bypass | `StoneSaveManager.IsEntryByFriend` | `0x2874048` | `mov w0, #1; ret` | Free entry without friends |
| Assistant Ownership | `RegistrationChecker.CanRegister` | `0x25D74C8` | `mov w0, #1; ret` | Unlocks all 65 Special NPCs |
| Anti-Cheat Trap | `Cheating.SendTrap` | `0x22C5628` | `ret; nop` | Neutralizes telemetry logging |

---

### 4.4 Gardening & 100% Creature Catch Rate Rerouting
In gardening events, rare creatures (butterflies, bees) have catch rates dictated by master tables (often 40% – 60%). When a player uses Lloid's paid assistance, the game calls `PaidCatch`, which forces a 100% success rate.

#### Hook Implementation
```objc
static void (*orig_Catch)(void *self, void *creatureSlot, void *method) = NULL;
static void hook_Catch(void *self, void *creatureSlot, void *method) {
    if (gCatchAlways100Percent) {
        // Resolve PaidCatch address: RVA 0x2B43DDC
        uintptr_t base = getUnityFrameworkBase();
        typedef void (*fn_PaidCatch)(void*, void*, void*);
        fn_PaidCatch paidCatch = (fn_PaidCatch)(base + 0x2B43DDC);
        if (paidCatch) {
            paidCatch(self, creatureSlot, method);
            return;
        }
    }
    if (orig_Catch) orig_Catch(self, creatureSlot, method);
}
```

---

### 4.5 Fishing Auto-Bite & Extended Bite Window
Vanilla fishing involves a randomized nibble loop (1 to 5 nibbles) governed by `_bite_time` in `FishBite.OnStart`:
1. **Auto-Bite (`FishPick.OnStart` RVA `0x28A1854`):** Hooks the lure attraction start, resetting nibble countdown so the fish immediately strikes on first contact.
2. **Extended Bite Window (`FishBite.OnStart` RVA `0x28A0A94`):** Extends the reaction window from the standard 0.8s to 60.0s, ensuring the fish never escapes if the player delays tapping.

---

### 4.6 Native Unity Engine Utilities
1. **Time Scale Multiplier:**
   - Invokes `UnityEngine.Time.set_timeScale` (RVA `0x1E2B618`) with float values between `1.0f` and `10.0f` to accelerate game animations, text dialogue scroll, and transitions.
2. **Universal Render Pipeline (URP) Diagnostics Overlay:**
   - Retrieves the URP DebugManager singleton: `DebugManager.get_instance()` (RVA `0x58481B0`).
   - Invokes `set_displayRuntimeUI(true)` (RVA `0x5856A90`) and `set_enableRuntimeUI(true)` (RVA `0x5856A64`) to expose native frame performance graphs, draw call counters, and shader diagnostics directly in the game viewport.

---

## 5. UI Overlay Architecture

```
UnityAppController (Game Engine Root)
 └── UIWindow (Native Metal Engine Surface)
      └── UIWindow (ReddsTools Overlay Window, windowLevel = UIWindowLevelAlert + 100)
           ├── RTDraggableButton (Floating Redd avatar icon)
           │    ├── UIPanGestureRecognizer (Free-drag with edge snapping)
           │    ├── UITapGestureRecognizer (Expand/collapse menu)
           │    └── UILongPressGestureRecognizer (Diagnostics modal)
           │
           ├── RTMenuController (Main Modification Panel)
           │    ├── UIVisualEffectView (Frosted glass blur)
           │    ├── UISegmentedControl (Category tabs)
           │    ├── UIScrollView (Tab views & control rows)
           │    └── UIDatePicker (Interactive calendar manipulation)
           │
           └── RTModalController (Character Selection Modal)
                ├── UISearchBar (Real-time 478 character filtering)
                ├── UISegmentedControl (All / Special / Villagers)
                └── UICollectionView (Lazy-loaded 478 icon grid with NSCache)
```

### Safety & Crash Prevention Invariants
1. **UIKit Main Thread Enforcement:** All UI operations, modal transitions, and button state updates are dispatched to `dispatch_get_main_queue()`.
2. **Pointer Validation (`ptrOK`):** Before dereferencing any engine pointer captured during lifecycle hooks, `ptrOK` inspects `mach_vm_region` to confirm valid allocated memory space.
3. **Lazy Asset Caching:** All 478 character icons are loaded on-demand from `/var/jb/Library/Application Support/ReddsTools/icons/` into an `NSCache<NSString*, UIImage*>` to prevent memory pressure warnings from the OS.

---

## 6. Guidelines for AI Agents & Developers Maintaining This Codebase

When maintaining, updating, or extending ReddsTools for future game updates:

1. **RVA Offset Updating:**
   - When Nintendo releases an updated build of ACPCC, RVAs will shift.
   - Do NOT blindly reuse old RVAs. Run `Il2CppDumper` against the new `UnityFramework` and search for the method signatures documented in Section 4.
   - Update the RVA constants at the top of [`Tweak.xm`](Tweak.xm).
2. **Preserve `Guard` Setters:**
   - Never write raw integer primitives to inventory or currency balances. Always invoke the respective `GuardInt.set_Value` or `GuardLong.set_Value` routines.
3. **Preserve Anti-Save-Pollution:**
   - Ensure `hook_SetLastTimeInfo` continues to intercept save writes, committing real hardware epoch timestamps rather than spoofed calendar values.
4. **Rootless Directory Structure:**
   - Maintain the rootless filesystem prefix (`/var/jb`). Never hardcode absolute `/Library` paths without falling back to `/var/jb/Library`.
