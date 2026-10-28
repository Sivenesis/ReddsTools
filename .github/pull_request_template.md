## Description
Provide a summary of the changes introduced by this pull request.

## Target Systems Affected
- [ ] Currencies & Inventory (`UserProfileEntry`, `UserOfflineMaterialBag`)
- [ ] Camp Caretaker & Companions (`AssistantManager`, `RegistrationChecker`)
- [ ] Time Travel & Date Spoofing (`UtcTime.get_Now`)
- [ ] Crafting & Workshop (`UserCraftFtrClothNowWorkOneSlotSetElement`)
- [ ] Gardening & Creature Catching (`CmpsSksGardening`)
- [ ] Fishing & Insect Hunting (`FishBite`, `CmpsFieldFish`, `CmpsFieldInsect`)
- [ ] Villagers & Campsite (`CmpsGameDebugSetting`, `UserAnimalInfo`)
- [ ] Shovelstrike Quarry (`StoneSaveManager`)
- [ ] Engine & Diagnostics (`DebugManager`, `Time.set_timeScale`)
- [ ] UI / Overlay (`RTMenuController`, `RTModalController`, `RTDraggableButton`)

## Testing & Verification
- **Device Tested:**
- **iOS Version:**
- **Jailbreak Environment:**
- **Verification Details:** (Describe test steps taken on-device)

## Checklist
- [ ] Code compiles cleanly with rootless Theos (`make package FINALPACKAGE=1`).
- [ ] No hardcoded device-specific paths, credentials, or personal keys.
- [ ] Verified that anti-cheat and telemetry hooks remain intact.
- [ ] Updated relevant documentation in `docs/` if modifying hook signatures or RVAs.
