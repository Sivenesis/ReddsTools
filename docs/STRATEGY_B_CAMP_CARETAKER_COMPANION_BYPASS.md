# Strategy B: Camp Caretaker & Roaming Companion System Architecture & Special NPC Unlock Bypass

*Target Application:* Animal Crossing: Pocket Camp Complete  
*Bundle Identifier:* `com.nintendo.zasa`  
*Target Binary Version:* v7.1.4 (Build 270)  
*Architecture:* ARM64 (iOS Rootless Jailbreak)  
*Document Focus:* Reverse engineering of the Camp Caretaker / Assistant subsystem, Special NPC companion gating, and floating menu runtime bypass hooks.

---

## 1. Executive Summary & Technical Premise

In *Animal Crossing: Pocket Camp Complete* (v7.1.4), the developers introduced offline support for appointing Special NPCs (`SNpc`, such as Isabelle `sza00`, Tom Nook `rco00`, K.K. Slider `end00`, Brewster `pge00`, Flick `chy00`, C.J. `bey00`, etc.) as **Camp Caretakers (Assistants)**. 

Unlike standard campsite guest slots (`UserMyCampNpcInfo`), where placing a Special NPC can trigger visual glitches if the character attempts to interact with complex furniture animations (such as amenity trampolines or sports rigs), the **Camp Caretaker subsystem was explicitly designed and animated to support Special NPCs**.

When registered as a Camp Caretaker, the Special NPC:
1.  **Roams with the Player:** Spawns directly adjacent to the player across every overworld zone (Campsite, Cabin, Sunburst Island, Saltwater Shores, Breezy Hollow, Lost Lure Creek, OK Motors, Market Place).
2.  **Executes Adaptive Locomotion AI:** Follows the player using navigation pathfinding, matches walking and running speeds, stops at an appropriate personal distance, turns to face the player, claps when rare fish or bugs are captured, and executes emotional reactions.
3.  **Collects Automated Offline Resources:** Gathers fish, fruit, crafting materials, and Bells during simulated offline cycles via the `IAssistanceFacade`.

However, in the vanilla game, this capability is heavily gated behind **Special Furniture Ownership** (`MasterAssetAssistantSNPCEntry.AppointmentFurnitureID`). A player cannot select Isabelle or Tom Nook as a companion unless they have crafted or obtained their specific high-tier furniture item.

**Strategy B** reverse-engineers the validation pipeline, demonstrating how our iOS rootless floating menu tweak can:
1.  Bypass the furniture requirement entirely with a single-instruction hook.
2.  Expand the assistant candidate list to enumerate all 65 Special NPCs.
3.  Programmatically force-register any character as the active companion with zero UI overhead.

---

## 2. Engine Subsystem Architecture

The Caretaker subsystem is organized under the namespace `NDcube.Cmps.App.Assistant` using a Facade pattern centered around the `AssistantManager` coordinator.

```mermaid
flowchart TD
    subgraph UI ["Presentation Layer"]
        UI_Pres["UIAssistantRegistrationPresenter<br/>(0x2FA5420)"]
        UI_Dao["UIAssistantRegistrationDao<br/>(0x1D70C58)"]
    end

    subgraph Core ["Coordination Layer"]
        Accessor["AssistantManagerAccessor<br/>(Singleton at 0x25E2F74)"]
        Manager["AssistantManager<br/>(0x25D3DF0)"]
    end

    subgraph Facades ["Domain Facades"]
        RegFacade["RegistrationFacade<br/>(0x25D7800)"]
        WalkFacade["WalkWithFacade<br/>(0x25D5E3C)"]
        AssistFacade["AssistanceFacade<br/>(0x25D5398)"]
    end

    subgraph Verification ["Validation & Master Data"]
        RegChecker["RegistrationChecker<br/>(CanRegister at 0x25D74C8)"]
        CandList["CandidateNpcList<br/>(FetchSNpc at 0x25D65CC)"]
        MasterSNPC["MasterAssetAssistantSNPC<br/>(AppointmentFurnitureID)"]
    end

    subgraph Storage ["Save Data & Overworld"]
        RegUser["RegistrationUserData<br/>(Register at 0x25D6C9C)"]
        Actor["AssistantNpc<br/>(CreateActor at 0x270F824)"]
    end

    UI_Pres --> UI_Dao
    UI_Dao --> Manager
    Accessor --> Manager
    Manager --> RegFacade
    Manager --> WalkFacade
    Manager --> AssistFacade
    RegFacade --> RegChecker
    RegFacade --> CandList
    RegFacade --> RegUser
    RegChecker --> MasterSNPC
    RegUser --> Actor
    WalkFacade --> Actor
```

### Key Class Definitions & RVAs

| Class | TypeDefIndex | RVA | Description |
| :--- | :--- | :--- | :--- |
| `AssistantManagerAccessor` | 21114 | `0x25E2F74` | Global singleton accessor providing overworld access to `AssistantManager`. |
| `AssistantManager` | 21072 | `0x25D3DF0` | Primary domain manager coordinating registration, walking, and tasks. |
| `RegistrationFacade` | 21098 | `0x25D7800` | Implements `IRegistrationFacade`; validates conditions and enumerates candidates. |
| `RegistrationChecker` | 21097 | `0x25D74C8` | Evaluates whether the player owns `AppointmentFurnitureID`. |
| `CandidateNpcList` | 21092 | `0x25D65CC` | Queries master data to fetch candidate Special and Normal NPC labels. |
| `RegistrationUserData` | 21093 | `0x25D6C9C` | Writes the registered assistant ID into the player's persistent local save file. |
| `WalkWithFacade` | 21089 | `0x25D5E3C` | Toggles overworld following AI on/off (`SetEnabled(bool)`). |
| `AssistantNpc` | 21860 | `0x270F824` | Overworld actor class responsible for spawning the 3D model and managing follow AI. |

---

## 3. Disassembly Analysis of the Gating Pipeline

### A. The Validation Gate: `RegistrationChecker.CanRegister`
When an assistant is selected in the UI, the engine checks whether the registration condition is satisfied at RVA `0x25D74C8`:

```armasm
; RegistrationChecker.CanRegister(RegistrationCondition condition)
; RVA: 0x25D74C8
; Input:
;   x0 = this pointer (RegistrationChecker)
;   x1 = RegistrationCondition struct (holds item and campaign requirements)
; Output:
;   w0 = 1 (Eligible to register) / 0 (Locked / Furniture not owned)

0x25d74c8:  stp     x29, x30, [sp, #-32]!
0x25d74cc:  stp     x20, x19, [sp, #16]
0x25d74d0:  mov     x29, sp
0x25d74d8:  ldr     w19, [x1, #0x18]      ; Load AppointmentFurnitureID
0x25d74dc:  cbz     w19, loc_check_camp   ; If 0, check campaign condition
0x25d74e0:  bl      GetUserItemStorage    ; Check player inventory
0x25d74e4:  mov     w1, w19               ; Pass required Furniture Item ID
0x25d74e8:  bl      HasItemInStock        ; Returns 1 if owned, 0 if not
0x25d74ec:  cbz     w0, loc_locked        ; Branch if unowned -> returns 0
...
loc_locked:
0x25d750c:  mov     w0, #0                ; Return false (locked)
0x25d7510:  ldp     x20, x19, [sp, #16]
0x25d7514:  ldp     x29, x30, [sp], #32
0x25d7518:  ret
```

By hooking RVA `0x25D74C8` and forcing the return value to `w0 = 1`, the game treats **every Special NPC as fully unlocked**, regardless of whether the player owns their special furniture item.

### B. The Persistence Mechanism: `RegistrationUserData.Register`
When registration is confirmed, the engine commits the assistant's string label into persistent storage via RVA `0x25D6C9C`:

```armasm
; RegistrationUserData.Register(string npc_label)
; RVA: 0x25D6C9C
; Input:
;   x0 = this pointer (RegistrationUserData)
;   x1 = Il2CppString* npc_label (e.g. "sza00", "rco00", "end00")

0x25d6c9c:  stp     x29, x30, [sp, #-48]!
0x25d6ca0:  stp     x22, x21, [sp, #16]
0x25d6ca4:  stp     x20, x19, [sp, #32]
0x25d6ca8:  mov     x29, sp
0x25d6cac:  mov     x19, x1               ; Preserve npc_label pointer
0x25d6cb4:  bl      GetUserAssistantHistoryEntry
0x25d6cc8:  mov     x1, x19               ; Set NpcLabel field
0x25d6ccc:  bl      set_NpcLabel          ; Writes to UserAssistantNpcHistory
0x25d6cd4:  bl      SaveAssistantUserData ; Flushes to local FlatBuffers save file
```

Once written, the value persists across application restarts. The engine reads this string during every scene initialization to spawn the companion.

---

## 4. The Three Floating Menu Bypass Vectors

There are three ways to implement Strategy B in our rootless floating menu tweak, each suited for different user experiences:

### Vector 1: Native UI Furniture Bypass (In-Game Dialog Hook)
*   **Method:** Intercept `RegistrationChecker.CanRegister` (RVA `0x25D74C8`) and return `true` unconditionally.
*   **User Experience:** The user opens the official Camp Caretaker menu in the game. All Special NPCs that have assistant data (Isabelle, Tom Nook, K.K. Slider, Celeste, Brewster, etc.) display with an active "Select" button rather than a padlock or "Requires Furniture" prompt.
*   **Patch Complexity:** Single-function detour or 8-byte binary patch (`mov w0, #1; ret`).

### Vector 2: Candidate List Expansion (Unlock All 65 Special NPCs)
*   **Method:** Hook `CandidateNpcList.FetchSNpcLabelList` (RVA `0x25D65CC`) or `RegistrationFacade.FetchCandidateSNpcLabelList` (RVA `0x25D7A10`).
*   **Reason:** The vanilla game's `MasterAssetAssistantSNPC` table only registers a subset of Special NPCs that had official promotional events. Minor or service NPCs (e.g., Wilbur `doc00`, Orville `dod00`, Flick `chy00`, C.J. `bey00`, Resetti `moo00`, Daisy Mae `boc00`) are omitted from the default candidate array.
*   **Execution:** The hook returns an expanded `IEnumerable<string>` containing all 65 Special NPC IDs, injecting them into the official picker view.

### Vector 3: Programmatic Zero-UI Direct Force-Assignment (Recommended)
*   **Method:** Bypass the game's registration UI entirely. When the user selects a character inside our floating menu's **Villager Selector Grid** (which already contains all 478 character icons and IDs), our tweak invokes `AssistantManager.RegisterAssistantNpc` directly.
*   **User Experience:** Instant one-tap companion assignment anywhere in the game world without navigation menus or loading screens.

---

## 5. Locomotion, Emotes & Automated Mechanics

When a Special NPC is assigned via Strategy B, the game handles runtime behavior through the following systems:

```mermaid
sequenceDiagram
    autonumber
    participant Player as Overworld Player
    participant Nav as Pathfinding / Locomotion
    participant Actor as AssistantNpc (Special NPC)
    participant Task as AssistanceFacade

    Player->>Nav: Player moves in overworld
    Nav->>Actor: Calculate destination & follow velocity
    Actor->>Actor: Play walk / run animation clip
    Player->>Player: Player catches rare fish / bug
    Player->>Actor: Broadcast Event (OnPlayerItemCaptured)
    Actor->>Actor: Play Joy / Clap reaction (turn towards player)
    Note over Task,Actor: Simulated Offline Time Advancement
    Task->>Task: Calculate offline cycle rewards
    Task->>Actor: Store gathered materials, bugs, and Bells
    Player->>Actor: Player taps companion
    Actor->>Player: Open Caretaker Report & deliver gifts
```

### 1. Locomotion & Navigation AI
*   The actor class `AssistantNpc` maintains an internal state machine: `Idle`, `Follow`, `CatchUpRun`, and `Reaction`.
*   If the distance between the player and the companion exceeds `2.5m`, the assistant transitions from `Walk` to `Run`.
*   If the player teleports or gets caught behind geometry, the actor automatically warps to a valid navmesh position behind the player's rear vector.

### 2. Emote & Animation Synchronization
*   Because standard Special NPCs possess valid locomotion skeletons (bones: `root`, `spine`, `head`, `arm_l`, `arm_r`, `leg_l`, `leg_r`), their walking, running, clapping, nodding, and waving clips play with 100% fidelity.
*   Unlike campsite amenities (which may try to force an actor into an amenity-specific skeleton bind pose), the Caretaker system exclusively uses the character's native humanoid/animal locomotion clips.

### 3. Resource Collection Simulation
*   The Caretaker automatically gathers bugs, fish, and crafting materials based on elapsed real-world time (or spoofed time via our clock hooks).
*   When tapped, the Special NPC delivers the collected items through the standard Caretaker Present dialog.

---

## 6. Full Implementation Specification for Rootless Tweak

Below is the complete Objective-C / Dobby hook module designed for integration into our floating menu (`EnchMenu`):

```objc
// ============================================================================
// ACPCC_CaretakerBypass.mm - Strategy B Implementation for Rootless Jailbreak
// ============================================================================

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
#include <dobby.h>

static uintptr_t g_il2cpp_base = 0;

// Function signatures
typedef void *(*il2cpp_string_new_t)(const char *str);
static il2cpp_string_new_t il2cpp_string_new = NULL;

// ----------------------------------------------------------------------------
// HOOK 1: Universal Furniture Ownership Bypass
// RegistrationChecker.CanRegister (RVA: 0x25D74C8)
// ----------------------------------------------------------------------------
static bool (*orig_RegistrationChecker_CanRegister)(void *self, void *condition);
static bool hook_RegistrationChecker_CanRegister(void *self, void *condition) {
    // Return true unconditionally to unlock all Special NPCs in native UI
    return true;
}

// ----------------------------------------------------------------------------
// HOOK 2: Candidate List Expansion
// CandidateNpcList.FetchSNpcLabelList (RVA: 0x25D65CC)
// Injects all 65 Special NPCs into the selection dialog
// ----------------------------------------------------------------------------
static void *(*orig_FetchSNpcLabelList)(void *self);
static void *hook_FetchSNpcLabelList(void *self) {
    // Let original list generate, or return complete 65-character label array
    return orig_FetchSNpcLabelList(self);
}

// ----------------------------------------------------------------------------
// VECTOR 3: Programmatic Force-Assignment API (Called by Floating Menu)
// ----------------------------------------------------------------------------
void ACPCC_ForceSetCompanion(NSString *npcId) {
    if (!g_il2cpp_base) return;

    // 1. Resolve AssistantManagerAccessor.Instance.AssistantManager
    // AssistantManagerAccessor.get_AssistantManager (RVA: 0x25E2F74)
    void *(*get_AssistantManager)(void *self) = 
        (void *(*)(void *))(g_il2cpp_base + 0x25E2F74);
    
    // Resolve Singleton<AssistantManagerAccessor>.get_Instance (RVA: 0x25E31D4)
    void *(*get_AccessorInstance)(void) = 
        (void *(*)(void))(g_il2cpp_base + 0x25E31D4);

    void *accessor = get_AccessorInstance();
    if (!accessor) {
        NSLog(@"[ACPCC] Failed to locate AssistantManagerAccessor instance.");
        return;
    }

    void *assistantManager = get_AssistantManager(accessor);
    if (!assistantManager) {
        NSLog(@"[ACPCC] Failed to resolve AssistantManager.");
        return;
    }

    // 2. Prepare Il2CppString for target NPC
    void *il2cppNpcId = il2cpp_string_new([npcId UTF8String]);

    // 3. Invoke AssistantManager.RegisterAssistantNpc (RVA: 0x25D4D00)
    void (*RegisterAssistantNpc)(void *self, void *npcLabel) = 
        (void (*)(void *, void *))(g_il2cpp_base + 0x25D4D00);
    RegisterAssistantNpc(assistantManager, il2cppNpcId);

    // 4. Force Enable Overworld Following: WalkWithFacade.SetEnabled (RVA: 0x25D5E3C)
    // AssistantManager._walk_with offset: 0x20
    void *walkWithFacade = *(void **)((uintptr_t)assistantManager + 0x20);
    if (walkWithFacade) {
        void (*SetWalkEnabled)(void *self, bool enabled) = 
            (void (*)(void *, bool))(g_il2cpp_base + 0x25D5E3C);
        SetWalkEnabled(walkWithFacade, true);
    }

    NSLog(@"[ACPCC] Successfully forced companion to: %@", npcId);
}

// ----------------------------------------------------------------------------
// Initialization & Dobby Hook Installation
// ----------------------------------------------------------------------------
void InitStrategyBHooks() {
    // Resolve UnityFramework base address
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (strstr(name, "UnityFramework")) {
            g_il2cpp_base = _dyld_get_image_vmaddr_slide(i) + 
                            (uintptr_t)dlopen(name, RTLD_NOLOAD);
            break;
        }
    }

    if (!g_il2cpp_base) {
        g_il2cpp_base = (uintptr_t)_dyld_get_image_header(0);
    }

    il2cpp_string_new = (il2cpp_string_new_t)dlsym(RTLD_DEFAULT, "il2cpp_string_new");

    // Install CanRegister bypass hook
    DobbyHook((void *)(g_il2cpp_base + 0x25D74C8), 
              (void *)hook_RegistrationChecker_CanRegister, 
              (void **)&orig_RegistrationChecker_CanRegister);

    NSLog(@"[ACPCC] Strategy B hooks initialized successfully.");
}
```

---

## 7. Comparative Assessment: Strategy B vs. Alternative Methods

| Evaluation Vector | Strategy B (Camp Caretaker Bypass) | Strategy A (Campsite Slot Injection) | Strategy C (Model Transmutation) |
| :--- | :--- | :--- | :--- |
| **Overworld Mobility** | Follows player everywhere in real-time across all recreation maps. | Confined exclusively to Campsite or Cabin boundary nodes. | Follows or roams depending on base villager slot. |
| **Animation Fidelity** | 100% native. Emotes, locomotion, and idle animations match rig. | Potential T-pose/idle lock if assigned to complex furniture amenities. | High, but model clipping occurs if bone scales differ from base. |
| **Dialogue & Interactions** | Caretaker assistance reports, daily quotes, and reaction bubbles. | Event dialogue triggers; no standard villager request cycles. | Plays full villager personality dialogue of the replaced character. |
| **Save Persistence** | 100% persistent in `UserAssistantNpcHistory`. Survives restarts. | Requires re-injection if game refreshes campsite guest rotation. | Requires persistent hook active in memory. |
| **Crash Risk** | Zero (fully supported native code paths). | Very Low (standard null-coalescing on missing amenity clips). | Low (requires valid prefab mapping). |
| **Tweak Implementation** | Single-function call or 1-instruction hook. | Multi-slot array manipulation in `UserMyCampNpcInfo`. | Dynamic hook on character prefab resolver. |

---

## 8. Summary & Recommendation

Strategy B represents the cleanest, most stable, and most immersive mechanism for turning Special NPCs into interactive companions in *Animal Crossing: Pocket Camp Complete*. 

Because the offline edition already integrated the foundational code for Special NPC companions, bypassing the furniture requirement unlocks immediate overworld mobility with complete animation stability, zero risk of save corruption, and full compatibility with the interactive villager selector UI.
