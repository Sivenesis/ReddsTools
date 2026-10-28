# Developer Leftovers, Debug Systems & Anti-Tamper Deep Dive

**Target Application:** *Animal Crossing: Pocket Camp Complete* (`com.nintendo.zasa`, v7.1.4 Build 270)  
**Binary Analyzed:** `Payload/zasa.app/Frameworks/UnityFramework.framework/UnityFramework` (Mach-O ARM64)  
**Metadata Analyzed:** `Payload/zasa.app/Data/Managed/Metadata/global-metadata.dat` (Metadata Version 39)  
**Asset Containers Analyzed:** `Payload/zasa.app/Data/data.unity3d` (`resources.assets`)

---

## 1. Campsite Villager Force-Spawner (`CmpsGameDebugSetting`)

### 1.1 Architecture & Asset Discovery
While NDcube stripped the interactive visual developer menu from the production build, they left behind the serialized configuration asset that controls developer NPC injection:

* **Class Definition:** `NDcube.Cmps.Sys.CmpsGameDebugSetting` (TypeDefIndex: 16233)
* **Inheritance:** `Setting<CmpsGameDebugSetting>` -> `UnityEngine.ScriptableObject`
* **Asset Location:** Embedded inside `data.unity3d` -> `resources.assets` at **PathID 1531** (Total length: 152 bytes)
* **Field Layout:**
  - `0x18`: `private string[] _MyCampsiteNpcLabelArray;`
* **Methods & RVAs:**
  - `0x1FD3914`: `public static CmpsGameDebugSetting get_Settings()`
  - `0x1FD3B24`: `public static string[] get_MyCampsiteNpcLabelArray()`
  - `0x1FD39F4`: `private static CmpsGameDebugSetting CreateCmpsGameDebugSettings()`

### 1.2 Binary Asset Structure (PathID 1531)
Inspection of PathID 1531 in `resources.assets` confirms an active 8-element string array pre-populated with internal villager IDs:

```hex
0000: 00 00 00 00 00 00 00 00 00 00 00 00 01 00 00 00  |................|
0010: 01 00 00 00 ad 1a 00 00 00 00 00 00 14 00 00 00  |................|
0020: 43 6d 70 73 47 61 6d 65 44 65 62 75 67 53 65 74  |CmpsGameDebugSet|
0030: 74 69 6e 67 08 00 00 00 05 00 00 00 63 61 74 30  |ting....cat08...|
0040: 38 00 00 00 05 00 00 00 73 71 75 30 38 00 00 00  |....squ08.......|
0050: 05 00 00 00 67 6f 72 30 31 00 00 00 05 00 00 00  |....gor01.......|
0060: 70 62 72 30 30 00 00 00 05 00 00 00 6b 67 72 30  |....pbr00...kgr0|
0070: 32 00 00 00 05 00 00 00 72 68 6e 30 37 00 00 00  |2.......rhn07...|
0080: 05 00 00 00 68 69 70 30 30 00 00 00 05 00 00 00  |....hip00.......|
0090: 61 6e 74 30 31 00 00 00                          |ant01...|
```

### 1.3 Pre-Configured Villager Mapping
The 8 strings stored in the shipping asset represent the following internal animal identifiers:
1. `cat08` -> Rosie / Kiki (Cat villager series)
2. `squ08` -> Filbert / Marshal (Squirrel villager series)
3. `gor01` -> Cesar (Gorilla villager series)
4. `pbr00` -> Bluebear (Polar Bear / Cub series)
5. `kgr02` -> Carrie / Kitt (Kangaroo series)
6. `rhn07` -> Merengue (Rhino series)
7. `hip00` -> Bitty / Rocco (Hippo series)
8. `ant01` -> Antonio (Anteater series)

### 1.4 Exploitation & Modding Strategies
1. **In-Process Tweak Hook (Recommended):**
   Hook `CmpsGameDebugSetting.get_MyCampsiteNpcLabelArray()` via Theos/ElleKit to return an arbitrary list of animal label strings. When the campsite generation algorithm runs, it prioritizes or populates visitor slots with the returned IDs.
2. **Static Asset Patch:**
   Directly edit the string values at byte offset `0x38`–`0x97` of PathID 1531 inside `resources.assets` before repacking the IPA.

---

## 2. Active Unity Rendering Debugger (URP DebugUI)

### 2.1 System Architecture
In modern Unity Universal Render Pipeline (URP) games, Unity includes an internal runtime overlay called the **Rendering Debugger**. This system was **not** stripped from ACPCC and remains fully operational in the production executable.

* **Core Class:** `Unity.RenderPipelines.Core.Runtime.DebugManager`
* **Updater Class:** `UnityEngine.Rendering.DebugUpdater`
* **Touch Check Method:** `GetActionToggleDebugMenuWithTouch()` at RVA `0x5852CC0`
* **Update Loop:** `DebugUpdater.Update()` at RVA `0x585ED08`

### 2.2 Gesture Detection Mechanism
Disassembly of `GetActionToggleDebugMenuWithTouch` at RVA `0x5852CC0` reveals the exact multi-touch evaluation:

```arm64
; Call Unity Input System touch tracker
0x5852d80: mov  x0, #0
0x5852d84: bl   #0x57f1d38              ; Returns touch structure in x0, x1
0x5852d88: stp  x0, x1, [x29, #-0x40]
0x5852d90: lsr  x8, x1, #0x20           ; Extract touchCount
0x5852d94: cmp  x8, #3                  ; Compare touchCount == 3
0x5852d98: b.ne #0x5852e80              ; If touchCount != 3, branch to return false
```

### 2.3 Activation Methods
1. **Hardware Touch Gesture:**
   Touch the screen simultaneously with **three fingers** (`touchCount == 3`). Polled every frame by `DebugUpdater.Update()`.
2. **Programmatic Tweak Activation:**
   In your jailbreak tweak or PC port, set the boolean property:
   ```csharp
   DebugManager.instance.displayRuntimeUI = true;
   ```
   Or via C++ function pointer:
   ```cpp
   typedef void* (*fn_debug_get_instance)(void);
   typedef void (*fn_debug_set_display)(void *instance, bool value);
   
   void *debugMgr = ((fn_debug_get_instance)(gUnityBase + 0x58481B0))();
   ((fn_debug_set_display)(gUnityBase + 0x5853B00))(debugMgr, true);
   ```

### 2.4 Available Debugger Tabs & Diagnostics
When activated, the URP Debugger renders a floating HUD with the following capabilities:
* **Rendering & Performance:** Real-time FPS, frame duration (CPU vs GPU time), batches, draw call counts, and memory resident drawer stats.
* **Material Validation:** Highlights pixels violating PBR thresholds (albedo too dark/bright, specular invalid, metallic outside 0.0–1.0 range).
* **Lighting Inspection:** Isolates shadow cascades, reflection probes, and ambient occlusion passes.
* **Overdraw & Wireframe:** Color-coded pixel overdraw maps to spot performance bottlenecks in complex campsite layouts.

---

## 3. Anti-Cheat & Jailbreak Trap (`Cheating.SendTrap`)

### 3.1 Class & Method Details
* **Namespace:** `NDcube.Cmps.Sys.Analytics`
* **Class:** `Cheating` (TypeDefIndex: 16584)
* **Method:** `SendTrap(CmpsUserSelf self)`
* **RVA:** `0x22C5628` (Offset in `UnityFramework`: `0x22C5628`)

### 3.2 Detection Logic Disassembly
Disassembly of `SendTrap` (`0x22C5628` – `0x22C5730`) demonstrates the game's integrity scan:

```arm64
0x22c5684: cbz   x19, #0x22c57d0        ; x19 = CmpsUserSelf instance
0x22c5688: ldr   x0, [x19, #0xe0]       ; Load inventory pointer
0x22c5698: bl    #0x2187500             ; CmpsItemStock.GetItemStockDataAll
0x22c56a0: mov   x21, x0                ; x21 = Array of all item records
0x22c56a4: ldr   w8, [x0, #0x18]        ; Array length
0x22c56a8: cmp   w8, #1
0x22c56ac: b.lt  #0x22c57b0

; Loop: iterates every item in the player's stock
0x22c56bc: ldr   x0, [x23, x22, lsl #3] ; Load item record
0x22c56c8: bl    #0x232a964             ; Verify item count against master definition cap
0x22c56cc: add   w20, w0, w20
0x22c56d0: ldr   w8, [x21, #0x18]
0x22c56d4: add   x22, x22, #1
0x22c56d8: cmp   w22, w8
0x22c56dc: b.lt  #0x22c56bc

; If total items or values exceed hard boundaries:
0x22c571c: bl    #0x21e54d0             ; Log telemetry packet under EventCategory 11
```

### 3.3 Event Category 11 (`EventCategory.CheatDevice`)
In the game's event analytics enum:
```csharp
public const EventCategory Challenge = 10;
public const EventCategory CheatDevice = 11;
public const EventCategory ConsumeLeaf = 12;
```
If item amounts exceed legal storage limits (e.g. 99,999,999 wood or illegal furniture stacks), `SendTrap` logs an event under `CheatDevice`. While the offline version no longer uploads telemetry to Sakasho servers, local trap flags can cause defensive behavior or corrupted save flags.

### 3.4 Neutralization Patch
To permanently disable `SendTrap`, patch the first instruction at RVA `0x22C5628` with an immediate `ret`:

* **Target Address:** `base + 0x22C5628`
* **Original Bytes:** `stp x24, x23, [sp, #-0x40]!` (`f8 5b bc a9`)
* **Patched Bytes (ARM64 `ret`):** `c0 03 5f d6`
* **Theos / Logos Implementation:**
  ```objc
  %hookf(void, (uintptr_t)getUnityBase() + 0x22C5628, void *self) {
      // Do nothing - neutralize cheat trap
      return;
  }
  ```
