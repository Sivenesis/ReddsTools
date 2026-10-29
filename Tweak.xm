// ==============================================================================
// REDDS TOOLS - Floating Mod Menu for Animal Crossing: Pocket Camp Complete
// Target: com.nintendo.zasa (v7.1.4 Build 270, arm64)
// Created by VibeCode
// ==============================================================================

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <mach/mach.h>
#import <libkern/OSCacheControl.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <string.h>
#import <math.h>
#import <time.h>
#ifndef JAILED
#import <substrate.h>
#endif
#import "FloatIconData.h"
#import "EmbeddedVillagersData.h"

// Layout Constants
static const CGFloat PW = 320.0;
static const CGFloat ROWH = 38.0;
static const CGFloat HDRH = 34.0;
static const CGFloat HEADERBAR = 46.0;
static const CGFloat STATUSH = 32.0;
static const CGFloat PANEL_MARGIN = 24.0;

// UI Styling
static UIColor *bgCol(void) {
    return [UIColor colorWithRed:0.08 green:0.09 blue:0.11 alpha:0.96];
}
static UIColor *borderCol(void) {
    return [UIColor colorWithRed:0.88 green:0.45 blue:0.22 alpha:0.85]; // Redd's Signature Orange
}
static UIColor *sectionHeaderBgCol(void) {
    return [UIColor colorWithRed:0.14 green:0.16 blue:0.19 alpha:1.0];
}
static UIColor *accentOrangeCol(void) {
    return [UIColor colorWithRed:0.88 green:0.45 blue:0.22 alpha:1.0];
}
static UIColor *buttonBgCol(void) {
    return [UIColor colorWithWhite:0.18 alpha:1.0];
}

// ============================ Preferences Helpers ============================
static void saveBool(NSString *k, bool v) {
    [[NSUserDefaults standardUserDefaults] setBool:v forKey:k];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
static bool getSavedBool(NSString *k, bool d) {
    id o = [[NSUserDefaults standardUserDefaults] objectForKey:k];
    return o ? [o boolValue] : d;
}
static void saveInt(NSString *k, int v) {
    [[NSUserDefaults standardUserDefaults] setInteger:v forKey:k];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
static int getSavedInt(NSString *k, int d) {
    id o = [[NSUserDefaults standardUserDefaults] objectForKey:k];
    return o ? [o intValue] : d;
}
static void saveInt64(NSString *k, int64_t v) {
    [[NSUserDefaults standardUserDefaults] setObject:@(v) forKey:k];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
static int64_t getSavedInt64(NSString *k, int64_t d) {
    id o = [[NSUserDefaults standardUserDefaults] objectForKey:k];
    return o ? [o longLongValue] : d;
}
static void saveFloat(NSString *k, float v) {
    [[NSUserDefaults standardUserDefaults] setFloat:v forKey:k];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
static float getSavedFloat(NSString *k, float d) {
    id o = [[NSUserDefaults standardUserDefaults] objectForKey:k];
    return o ? [o floatValue] : d;
}

// ============================ IL2CPP Runtime Symbols ============================
typedef void* (*fn_domain_get)(void);
typedef void** (*fn_domain_assemblies)(void*, size_t*);
typedef void* (*fn_assembly_image)(void*);
typedef const char* (*fn_image_name)(void*);
typedef void* (*fn_class_from_name)(void*, const char*, const char*);

static uintptr_t gUnityBase = 0;

static uintptr_t getUnityBase(void) {
    if (gUnityBase) return gUnityBase;
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (name && strstr(name, "UnityFramework")) {
            const struct mach_header_64 *header = (const struct mach_header_64 *)_dyld_get_image_header(i);
            gUnityBase = (uintptr_t)header;
            break;
        }
    }
    return gUnityBase;
}

static inline bool ptrOK(uintptr_t p) {
    return p >= 0x100000000ULL && p <= 0x7FFFFFFFFFULL;
}

static void *il2cppClassFromName(const char *ns, const char *name) {
    fn_domain_get        dg  = (fn_domain_get)        dlsym(RTLD_DEFAULT, "il2cpp_domain_get");
    fn_domain_assemblies da  = (fn_domain_assemblies) dlsym(RTLD_DEFAULT, "il2cpp_domain_get_assemblies");
    fn_assembly_image    ai  = (fn_assembly_image)    dlsym(RTLD_DEFAULT, "il2cpp_assembly_get_image");
    fn_image_name        inm = (fn_image_name)        dlsym(RTLD_DEFAULT, "il2cpp_image_get_name");
    fn_class_from_name   cfn = (fn_class_from_name)   dlsym(RTLD_DEFAULT, "il2cpp_class_from_name");
    if (!dg || !da || !ai || !cfn) return NULL;
    void *dom = dg(); if (!dom) return NULL;
    size_t n = 0; void **asms = da(dom, &n);
    if (!asms) return NULL;
    for (size_t i = 0; i < n; i++) {
        void *img = ai(asms[i]);
        if (!img) continue;
        const char *imn = inm ? inm(img) : NULL;
        if (imn && strstr(imn, "Assembly-CSharp") && !strstr(imn, "firstpass")) {
            void *c = cfn(img, ns, name);
            if (c) return c;
        }
    }
    return NULL;
}

// ============================ Memory Patching Engine ============================
static bool patchMemory(uintptr_t addr, const uint8_t *bytes, size_t len) {
    if (!addr || !bytes || len == 0) return false;
    vm_address_t page_start = addr & ~PAGE_MASK;
    vm_size_t page_size = (((addr + len) - 1) & ~PAGE_MASK) - page_start + PAGE_SIZE;

    kern_return_t kr = vm_protect(mach_task_self(), page_start, page_size, FALSE, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
    if (kr != KERN_SUCCESS) return false;

    memcpy((void*)addr, bytes, len);

    kr = vm_protect(mach_task_self(), page_start, page_size, FALSE, VM_PROT_READ | VM_PROT_EXECUTE);
    sys_icache_invalidate((void*)addr, len);
    return (kr == KERN_SUCCESS);
}

typedef struct {
    const char *name;
    uintptr_t rva;
    uint8_t orig[8];
    uint8_t patch[8];
    size_t len;
} MemoryGate;

// Patch gates:
// 1. Instant Craft Completion: UserCraftFtrClothNowWorkOneSlotSetElement.get_CompleteDate (0x29AB41C) -> mov x0, #0; ret
static MemoryGate gGateCraftComplete = {
    "InstantCraftComplete", 0x29AB41C,
    { 0x00, 0x08, 0x40, 0xf9, 0x60, 0x00, 0x00, 0xb4 },
    { 0x00, 0x00, 0x80, 0xd2, 0xc0, 0x03, 0x5f, 0xd6 }, 8
};
// 2. 0s Recipe Time: UserCraftFtrClothNowWorkOneSlotSetElement.get_RecipeTime (0x29AB5B4) -> mov w0, #0; ret
static MemoryGate gGateCraftRecipeTime = {
    "InstantRecipeTime", 0x29AB5B4,
    { 0x00, 0x14, 0x40, 0xf9, 0x60, 0x00, 0x00, 0xb4 },
    { 0x00, 0x00, 0x80, 0x52, 0xc0, 0x03, 0x5f, 0xd6 }, 8
};
// 3. Instant Flower Bloom: UserOfflineFlowerbedOneSlotEntry.get_SecToComplete (0x1CE3614) -> mov w0, #0; ret
static MemoryGate gGateFlowerComplete = {
    "InstantFlowerComplete", 0x1CE3614,
    { 0x00, 0x28, 0x40, 0xf9, 0x60, 0x00, 0x00, 0xb4 },
    { 0x00, 0x00, 0x80, 0x52, 0xc0, 0x03, 0x5f, 0xd6 }, 8
};
// 4. Instant Flower Bud: UserOfflineFlowerbedOneSlotEntry.get_SecToBud (0x1CE3504) -> mov w0, #0; ret
static MemoryGate gGateFlowerBud = {
    "InstantFlowerBud", 0x1CE3504,
    { 0x00, 0x20, 0x40, 0xf9, 0x60, 0x00, 0x00, 0xb4 },
    { 0x00, 0x00, 0x80, 0x52, 0xc0, 0x03, 0x5f, 0xd6 }, 8
};
// 5. Never-Flee Insects: CmpsFieldInsect.ReactionEscape (0x24141F0) -> ret; nop
static MemoryGate gGateInsectEscape = {
    "NeverFleeInsects", 0x24141F0,
    { 0xf6, 0x57, 0xbd, 0xa9, 0xf4, 0x4f, 0x01, 0xa9 },
    { 0xc0, 0x03, 0x5f, 0xd6, 0x1f, 0x20, 0x03, 0xd5 }, 8
};
// 6. Never Escaped State: CmpsFieldInsect.IsEscaped (0x2414748) -> mov w0, #0; ret
static MemoryGate gGateInsectIsEscaped = {
    "InsectIsEscaped", 0x2414748,
    { 0x08, 0xa8, 0x41, 0xb9, 0x1f, 0x19, 0x00, 0x71 },
    { 0x00, 0x00, 0x80, 0x52, 0xc0, 0x03, 0x5f, 0xd6 }, 8
};
// 8. Shovelstrike Quarry Always Opened: StoneSaveManager.get_IsOpened (0x2873BB4) -> mov w0, #1; ret
static MemoryGate gGateQuarryOpened = {
    "QuarryAlwaysOpened", 0x2873BB4,
    { 0xf4, 0x4f, 0xbe, 0xa9, 0xfd, 0x7b, 0x01, 0xa9 },
    { 0x20, 0x00, 0x80, 0x52, 0xc0, 0x03, 0x5f, 0xd6 }, 8
};
// 9. Unlimited Daily Quarry Entries: StoneSaveManager.IsCleared (0x2873C34) -> mov w0, #0; ret
static MemoryGate gGateQuarryCleared = {
    "QuarryNeverCleared", 0x2873C34,
    { 0xf4, 0x4f, 0xbe, 0xa9, 0xfd, 0x7b, 0x01, 0xa9 },
    { 0x00, 0x00, 0x80, 0x52, 0xc0, 0x03, 0x5f, 0xd6 }, 8
};
// 10. Quarry Ticket Enter Count: StoneSaveManager.GetTicketRemainEnterNum (0x2873C94) -> mov w0, #99; ret
static MemoryGate gGateQuarryTickets = {
    "QuarryTicketRemain", 0x2873C94,
    { 0xf4, 0x4f, 0xbe, 0xa9, 0xfd, 0x7b, 0x01, 0xa9 },
    { 0x60, 0x0c, 0x80, 0x52, 0xc0, 0x03, 0x5f, 0xd6 }, 8
};
// 11. Quarry Free Entry: UIMineDepartureDao.GetFriendCount (0x1B45508) -> mov w0, #3; ret
static MemoryGate gGateQuarryFriendCount = {
    "QuarryFriendCount3", 0x1B45508,
    { 0xf4, 0x4f, 0xbe, 0xa9, 0xfd, 0x7b, 0x01, 0xa9 },
    { 0x60, 0x00, 0x80, 0x52, 0xc0, 0x03, 0x5f, 0xd6 }, 8
};
// 12. Quarry Free Entry: UIMineDepartureDao.IsFriendEnable (0x1B45628) -> mov w0, #1; ret
static MemoryGate gGateQuarryFriendEnable = {
    "QuarryFriendEnable", 0x1B45628,
    { 0xf4, 0x4f, 0xbe, 0xa9, 0xfd, 0x7b, 0x01, 0xa9 },
    { 0x20, 0x00, 0x80, 0x52, 0xc0, 0x03, 0x5f, 0xd6 }, 8
};
// 13. Quarry Free Entry: UIMineDepartureDao.IsCloseFriendButton (0x1B456BC) -> mov w0, #0; ret
static MemoryGate gGateQuarryFriendClosed = {
    "QuarryFriendNotClosed", 0x1B456BC,
    { 0xf4, 0x4f, 0xbe, 0xa9, 0xfd, 0x7b, 0x01, 0xa9 },
    { 0x00, 0x00, 0x80, 0x52, 0xc0, 0x03, 0x5f, 0xd6 }, 8
};
// 14. Quarry Free Entry: CmpsAreaLimitedMine.NeedHelpCountToFriendEntry (0x1F76A98) -> mov w0, #0; ret
static MemoryGate gGateQuarryNeedHelp = {
    "QuarryNeedHelp0", 0x1F76A98,
    { 0xfd, 0x7b, 0xbf, 0xa9, 0xfd, 0x03, 0x00, 0x91 },
    { 0x00, 0x00, 0x80, 0x52, 0xc0, 0x03, 0x5f, 0xd6 }, 8
};
// 15. Quarry Free Entry: CmpsAreaLimitedMine.CanUseFriendHelpEntry (0x1F76D6C) -> mov w0, #1; ret
static MemoryGate gGateQuarryCanUseHelp = {
    "QuarryCanUseHelp1", 0x1F76D6C,
    { 0xf4, 0x4f, 0xbe, 0xa9, 0xfd, 0x7b, 0x01, 0xa9 },
    { 0x20, 0x00, 0x80, 0x52, 0xc0, 0x03, 0x5f, 0xd6 }, 8
};
// 16. Quarry Free Entry: CmpsAreaLimitedMine.GetCurrentHelpCount (0x1F76AB4) -> mov w0, #3; ret
static MemoryGate gGateQuarryCurrentHelp = {
    "QuarryCurrentHelp3", 0x1F76AB4,
    { 0xf4, 0x4f, 0xbe, 0xa9, 0xfd, 0x7b, 0x01, 0xa9 },
    { 0x60, 0x00, 0x80, 0x52, 0xc0, 0x03, 0x5f, 0xd6 }, 8
};
// 17. Quarry Free Entry: UIMineDepartureDao.GetRemainFriendHelpEntryCount (0x1B45590) -> mov w0, #1; ret
static MemoryGate gGateQuarryRemainHelp = {
    "QuarryRemainHelp1", 0x1B45590,
    { 0xf4, 0x4f, 0xbe, 0xa9, 0xfd, 0x7b, 0x01, 0xa9 },
    { 0x20, 0x00, 0x80, 0x52, 0xc0, 0x03, 0x5f, 0xd6 }, 8
};
// 12. Anti-Cheat CheatDevice Trap Neutralization: Cheating.SendTrap (0x22C5628) -> ret; nop
static MemoryGate gGateNeutralizeSendTrap = {
    "NeutralizeSendTrap", 0x22C5628,
    { 0xf8, 0x5f, 0xbc, 0xa9, 0xf6, 0x57, 0x01, 0xa9 },
    { 0xc0, 0x03, 0x5f, 0xd6, 0x1f, 0x20, 0x03, 0xd5 }, 8
};
// 13. Camp Caretaker Furniture Bypass: RegistrationChecker.CanRegister (0x25D74C8) -> mov w0, #1; ret
static MemoryGate gGateUnlockAllAssistants = {
    "UnlockAllAssistants", 0x25D74C8,
    { 0xf6, 0x57, 0xbd, 0xa9, 0xf4, 0x4f, 0x01, 0xa9 },
    { 0x20, 0x00, 0x80, 0x52, 0xc0, 0x03, 0x5f, 0xd6 }, 8
};

// ============================ Fortune Cookies Gates ============================
// 18. Fortune Cookie Shop Campaign Bypass: UIFortuneCookieDao.CampaignIdCheck (0x1C54F48) -> mov w0, #1; ret
static MemoryGate gGateCookieCampaignCheck = {
    "CookieCampaignCheck", 0x1C54F48,
    { 0xf6, 0x57, 0xbd, 0xa9, 0xf4, 0x4f, 0x01, 0xa9 },
    { 0x20, 0x00, 0x80, 0x52, 0xc0, 0x03, 0x5f, 0xd6 }, 8
};
// 19. Fortune Cookie Shop Release Bypass: UIFortuneCookieDao.ReleaseIdCheck (0x1C54E94) -> mov w0, #1; ret
static MemoryGate gGateCookieReleaseCheck = {
    "CookieReleaseCheck", 0x1C54E94,
    { 0xf4, 0x4f, 0xbe, 0xa9, 0xfd, 0x7b, 0x01, 0xa9 },
    { 0x20, 0x00, 0x80, 0x52, 0xc0, 0x03, 0x5f, 0xd6 }, 8
};
// 20. Fortune Cookie Presenter Ticket List Check Bypass: UIFortuneCookieViewModelPresenter.CreateTicketCookieViewModelList (0x2CA03C4) -> b #0x2ca03ec; nop
static MemoryGate gGateCookiePresenterCheck = {
    "CookiePresenterCheck", 0x2CA03C4,
    { 0x5f, 0x07, 0x00, 0x71, 0x04, 0xa8, 0x40, 0x7a },
    { 0x0a, 0x00, 0x00, 0x14, 0x1f, 0x20, 0x03, 0xd5 }, 8
};
// 21. Fortune Cookie Dao Cache Stale Bypass: UIFortuneCookieDao.GetCampaignListAndShopAppearanceDataCache (0x1C55D80) -> nop; adrp x8, #0x73ee000
static MemoryGate gGateCookieCacheBypass = {
    "CookieCacheBypass", 0x1C55D80,
    { 0x40, 0x19, 0x00, 0xb5, 0xc8, 0xbc, 0x02, 0xb0 },
    { 0x1f, 0x20, 0x03, 0xd5, 0xc8, 0xbc, 0x02, 0xb0 }, 8
};
// 22. Fortune Cookie Presenter IsCheckEnableData: UIFortuneCookieViewModelPresenter.IsCheckEnableData (0x2C9E4DC) -> mov w0, #1; ret
static MemoryGate gGateCookiePresenterEnableData = {
    "CookiePresenterEnableData", 0x2C9E4DC,
    { 0x3f, 0x04, 0x00, 0x71, 0xab, 0x00, 0x00, 0x54 },
    { 0x20, 0x00, 0x80, 0x52, 0xc0, 0x03, 0x5f, 0xd6 }, 8
};
// 23. Fortune Cookie Presenter CampaignIdCheck: UIFortuneCookieViewModelPresenter.IsCheckEnableCampaignID (0x2CA4714) -> mov w0, #1; ret
static MemoryGate gGateCookiePresenterCampaignId = {
    "CookiePresenterCampaignId", 0x2CA4714,
    { 0xf4, 0x4f, 0xbe, 0xa9, 0xfd, 0x7b, 0x01, 0xa9 },
    { 0x20, 0x00, 0x80, 0x52, 0xc0, 0x03, 0x5f, 0xd6 }, 8
};
// 24. Fortune Cookie Presenter ReleaseIdCheck: UIFortuneCookieViewModelPresenter.IsCheckEnableReleaseId (0x2CA50F4) -> mov w0, #1; ret
static MemoryGate gGateCookiePresenterReleaseId = {
    "CookiePresenterReleaseId", 0x2CA50F4,
    { 0x01, 0x01, 0x00, 0x34, 0xfd, 0x7b, 0xbf, 0xa9 },
    { 0x20, 0x00, 0x80, 0x52, 0xc0, 0x03, 0x5f, 0xd6 }, 8
};

// ============================ Catalog & Crossovers Gates ============================
// 25. Master Catalog Visibility: MasterAssetItemCatalogEntry.get_IsOnCatalog (0x2951B30) -> mov w0, #1; ret
static MemoryGate gGateCatalogIsOnCatalog = {
    "CatalogIsOnCatalog", 0x2951B30,
    { 0x00, 0x14, 0x40, 0xf9, 0x60, 0x00, 0x00, 0xb4 },
    { 0x20, 0x00, 0x80, 0x52, 0xc0, 0x03, 0x5f, 0xd6 }, 8
};
// 26. Regular Catalog Release Gate: UIBookDao.IsValidItem (0x2EDC784) -> mov w0, #1; ret
static MemoryGate gGateCatalogBookIsValidItem = {
    "CatalogBookIsValidItem", 0x2EDC784,
    { 0xff, 0x03, 0x01, 0xd1, 0xf6, 0x57, 0x01, 0xa9 },
    { 0x20, 0x00, 0x80, 0x52, 0xc0, 0x03, 0x5f, 0xd6 }, 8
};
// 27. Complete Catalog Release Gate: UICatalogCompleteListDao.IsValidItem (0x2EE4D10) -> mov w0, #1; ret
static MemoryGate gGateCatalogCompleteIsValidItem = {
    "CatalogCompleteIsValidItem", 0x2EE4D10,
    { 0xff, 0x03, 0x01, 0xd1, 0xf6, 0x57, 0x01, 0xa9 },
    { 0x20, 0x00, 0x80, 0x52, 0xc0, 0x03, 0x5f, 0xd6 }, 8
};
// 28. Complete Catalog Allow Cookies: UIBookDao.<FetchAllItems>d__27$$MoveNext (0x2EE09E4) -> nop
static MemoryGate gGateCatalogCompleteAllowCookies = {
    "CatalogCompleteAllowCookies", 0x2EE09E4,
    { 0xc0, 0x1a, 0x00, 0x54 },
    { 0x1f, 0x20, 0x03, 0xd5 }, 4
};
// 29. IsIgnoreItem Bypass: UIBookLargeCategoryHelper.IsIgnoreItem (0x2E76AE8) -> mov w0, #0; ret
static MemoryGate gGateCatalogIgnore = {
    "CatalogIgnoreBypass", 0x2E76AE8,
    { 0xf6, 0x57, 0xbd, 0xa9, 0xf4, 0x4f, 0x01, 0xa9 },
    { 0x00, 0x00, 0x80, 0x52, 0xc0, 0x03, 0x5f, 0xd6 }, 8
};

// ============================ Happy Homeroom Gates ============================
// 22. HH Infinite Daily Tickets: UIFurniturePuzzleCommonDao.GetStaminaNum (0x1BFE0E4) -> mov w0, #3; ret
static MemoryGate gGateHHStamina = {
    "HHStamina3", 0x1BFE0E4,
    { 0xf4, 0x4f, 0xbe, 0xa9, 0xfd, 0x7b, 0x01, 0xa9 },
    { 0x60, 0x00, 0x80, 0x52, 0xc0, 0x03, 0x5f, 0xd6 }, 8
};
// 23. HH Infinite Golden Vouchers: UIFurniturePuzzleCommonDao.GetHaveTicketNum (0x1BFD944) -> mov x0, #999; ret
static MemoryGate gGateHHVouchers = {
    "HHVouchers999", 0x1BFD944,
    { 0xf6, 0x57, 0xbd, 0xa9, 0xf4, 0x4f, 0x01, 0xa9 },
    { 0xe0, 0x7c, 0x80, 0xd2, 0xc0, 0x03, 0x5f, 0xd6 }, 8
};
// 24. HH Ticket Sufficiency: UIFurniturePuzzleCommonDao.IsEnoughLeafTicket (0x1BFDB80) -> mov w0, #1; ret
static MemoryGate gGateHHTicketEnough = {
    "HHTicketEnough", 0x1BFDB80,
    { 0xf6, 0x57, 0xbd, 0xa9, 0xf4, 0x4f, 0x01, 0xa9 },
    { 0x20, 0x00, 0x80, 0x52, 0xc0, 0x03, 0x5f, 0xd6 }, 8
};
// 25. HH Auto-Pass 3 Medals: UIStateFurniturePuzzleScoreDirection.GetClearGrade (0x2D4255C) -> mov w0, #3; ret
static MemoryGate gGateHHClearGrade3 = {
    "HHClearGrade3", 0x2D4255C,
    { 0xf8, 0x5f, 0xbc, 0xa9, 0xf6, 0x57, 0x01, 0xa9 },
    { 0x60, 0x00, 0x80, 0x52, 0xc0, 0x03, 0x5f, 0xd6 }, 8
};
// 26. HH Universal Flawless Reaction: CmpsFurniturePuzzleQuestionScoreParameter.GetEffectType (0x2362B90) -> mov w0, #2; ret
static MemoryGate gGateHHFlawless = {
    "HHFlawless", 0x2362B90,
    { 0xff, 0x03, 0x02, 0xd1, 0xfc, 0x6f, 0x02, 0xa9 },
    { 0x40, 0x00, 0x80, 0x52, 0xc0, 0x03, 0x5f, 0xd6 }, 8
};
// 27. HH Universal Max Score: CmpsFurniturePuzzleQuestionScoreParameter.GetBasicTotalScore (0x2361C80) -> mov w0, #1000; ret
static MemoryGate gGateHHMaxScore = {
    "HHMaxScore1000", 0x2361C80,
    { 0xfd, 0x7b, 0xbf, 0xa9, 0xfd, 0x03, 0x00, 0x91 },
    { 0x00, 0x7d, 0x80, 0x52, 0xc0, 0x03, 0x5f, 0xd6 }, 8
};

static bool applyGate(MemoryGate *gate, bool enable) {
#ifdef JAILED
    // In Jailed mode, all memory gates are statically patched into the binary on disk!
    return true;
#else
    uintptr_t base = getUnityBase();
    if (!base) return false;
    uintptr_t target = base + gate->rva;
    const uint8_t *bytes = enable ? gate->patch : gate->orig;
    return patchMemory(target, bytes, gate->len);
#endif
}

static void applyCatalogGates(bool enable) {
    applyGate(&gGateCatalogIsOnCatalog, enable);
    applyGate(&gGateCatalogBookIsValidItem, enable);
    applyGate(&gGateCatalogCompleteIsValidItem, enable);
    applyGate(&gGateCatalogCompleteAllowCookies, enable);
    applyGate(&gGateCatalogIgnore, enable);
}

// ============================ Substrate Hooks ============================
// 1. Gardening 100% Creature Catch Hook
static bool gCatchRate100On = false;
static void *(*orig_Catch)(void *sequentialIDs) = NULL;
static void *hook_Catch(void *sequentialIDs) {
    if (gCatchRate100On) {
        uintptr_t base = getUnityBase();
        if (base) {
            typedef void *(*fn_PaidCatch)(void *);
            fn_PaidCatch paidCatch = (fn_PaidCatch)(base + 0x2B43DDC);
            return paidCatch(sequentialIDs);
        }
    }
    return orig_Catch(sequentialIDs);
}

// 2. Fishing Auto-Bite Hooks
static bool gInstantFishBiteOn = false;

// FishPick.OnStart (0x28A1854): Remove nibbles/feints so fish bites on first contact
static void (*orig_FishPick_OnStart)(void *self) = NULL;
static void hook_FishPick_OnStart(void *self) {
    if (orig_FishPick_OnStart) orig_FishPick_OnStart(self);
    if (gInstantFishBiteOn && self) {
        *(int32_t*)((uintptr_t)self + 0xB8) = 0; // _pick_feint = 0 (bites on first contact, no nibble delay)
    }
}

// FishBite.OnStart (0x28A0A94): Extend bite window to 60s so fish never escapes
static void (*orig_FishBite_OnStart)(void *self) = NULL;
static void hook_FishBite_OnStart(void *self) {
    if (orig_FishBite_OnStart) orig_FishBite_OnStart(self);
    if (gInstantFishBiteOn && self) {
        *(float*)((uintptr_t)self + 0x58) = 60.0f; // _bite_time = 60.0s (never flees while biting)
    }
}

// 3. Campsite Villager Force-Spawner Hook (CmpsGameDebugSetting.get_MyCampsiteNpcLabelArray @ 0x1FD3B24)
static bool gForceCampsiteNpcOn = false;
static int gCampsitePreset = 0; // 0 = Developer 8, 1 = Fan Favorites
static void *(*orig_get_MyCampsiteNpcLabelArray)(void *method) = NULL;

static const char *kPresetDeveloper8[] = {
    "cat08", "squ08", "gor01", "pbr00", "kgr02", "rhn07", "hip00", "ant01"
};
static const char *kPresetFavorites[] = {
    "cat08", "squ08", "brd06", "bea01", "flg03", "wol00", "der00", "dog00"
};

static void *hook_get_MyCampsiteNpcLabelArray(void *method) {
    void *ret = orig_get_MyCampsiteNpcLabelArray(method);
    if (!gForceCampsiteNpcOn || !ret) return ret;

    typedef void* (*fn_il2cpp_string_new)(const char*);
    static fn_il2cpp_string_new s_strNew = NULL;
    if (!s_strNew) s_strNew = (fn_il2cpp_string_new)dlsym(RTLD_DEFAULT, "il2cpp_string_new");
    if (!s_strNew) return ret;

    uintptr_t arrLen = *(uintptr_t*)((uintptr_t)ret + 0x18);
    void **items = (void**)((uintptr_t)ret + 0x20);

    const char **activePreset = (gCampsitePreset == 1) ? kPresetFavorites : kPresetDeveloper8;
    int presetCount = 8;

    for (uintptr_t i = 0; i < arrLen && i < (uintptr_t)presetCount; i++) {
        items[i] = s_strNew(activePreset[i]);
    }
    return ret;
}

// 4. Anti-Cheat Trap Neutralization Hook (Cheating.SendTrap @ 0x22C5628)
static void (*orig_Cheating_SendTrap)(void *self) = NULL;
static void hook_Cheating_SendTrap(void *self) {
    // Completely neutralized - suppress EventCategory.CheatDevice (11) logging
    return;
}

// 5. UtcTime.get_Now (0x1E2B904) - Time Travel & Clock Spoofing Hook
static int64_t g_timeOffsetSeconds = 0;
static bool    g_timeTravelActive = false;
static bool    g_timeFreezeActive = false;
static int64_t g_frozenTimestamp = 0;

static int64_t (*orig_UtcTime_get_Now)(void *method) = NULL;
extern "C" int64_t hook_UtcTime_get_Now(void *method) {
    if (!g_timeTravelActive) {
        return orig_UtcTime_get_Now ? orig_UtcTime_get_Now(method) : (int64_t)time(NULL);
    }
    if (g_timeFreezeActive) {
        return g_frozenTimestamp;
    }
    return (int64_t)time(NULL) + g_timeOffsetSeconds;
}

static void ensureBridgeInstalled(void) {
    uintptr_t base = getUnityBase();
    if (base) {
        *(void**)(base + 0x7715B00) = (void*)&hook_UtcTime_get_Now;
    }
}

// 6. CmpsUserBoot.SetLastTimeInfo (0x212BDD8) - Anti-Save-Pollution Hook
static void (*orig_SetLastTimeInfo)(void *self, int64_t lastPlay, int64_t lastSync, void *method) = NULL;
static void hook_SetLastTimeInfo(void *self, int64_t lastPlay, int64_t lastSync, void *method) {
    if (g_timeTravelActive) {
        int64_t realNow = (int64_t)time(NULL);
        if (orig_SetLastTimeInfo) orig_SetLastTimeInfo(self, realNow, realNow, method);
        return;
    }
    if (orig_SetLastTimeInfo) orig_SetLastTimeInfo(self, lastPlay, lastSync, method);
}

// 7. Strategy B: RegistrationChecker.CanRegister (0x25D74C8) - Special Furniture Ownership Bypass
static bool gUnlockAllAssistantsOn = true;
static bool (*orig_RegistrationChecker_CanRegister)(void *self, void *condition, void *method) = NULL;
static bool hook_RegistrationChecker_CanRegister(void *self, void *condition, void *method) {
    if (gUnlockAllAssistantsOn) {
        return true;
    }
    return orig_RegistrationChecker_CanRegister ? orig_RegistrationChecker_CanRegister(self, condition, method) : true;
}

static bool isBlacklistedCompanion(NSString *npcId) {
    if (!npcId.length) return false;
    static NSSet<NSString*> *sBlacklist = nil;
    if (!sBlacklist) {
        sBlacklist = [NSSet setWithObjects:
            @"mka00", // Blanca (crashes game immediately)
            @"ttl00", // Tortimer (crashes game immediately)
            @"olc00", // Copper (crashes game immediately)
            @"plc00", // Copper (crashes game immediately)
            @"pla00", // Booker (same police desk rig as Copper)
            @"hnw00", // Lloyd (crashes game on map change)
            nil
        ];
    }
    return [sBlacklist containsObject:npcId];
}

// 8. Capture AssistantManager on startup: AssistantManager..ctor (0x25D3DF0)
static void *sCachedAssistantManager = NULL;
static bool forceSetCompanion(NSString *npcId);

static void (*orig_AssistantManager_ctor)(void *self, void *method) = NULL;
static void hook_AssistantManager_ctor(void *self, void *method) {
    if (orig_AssistantManager_ctor) orig_AssistantManager_ctor(self, method);
    if (self && ptrOK((uintptr_t)self)) {
        sCachedAssistantManager = self;
        if (getSavedBool(@"Pref_EmergencySafeBobPending", false)) {
            saveBool(@"Pref_EmergencySafeBobPending", false);
            dispatch_async(dispatch_get_main_queue(), ^{
                forceSetCompanion(@"cat00");
                NSLog(@"[ReddsTools] Executed deferred emergency appointment of Bob (cat00)!");
            });
        }
    }
}

// 9. Capture AssistantManager via GetAssistantNpcLabel (0x25D4A40) & Auto-Sanitize Crashing NPCs
static void* (*orig_AssistantManager_GetAssistantNpcLabel)(void *self, void *method) = NULL;
static void* hook_AssistantManager_GetAssistantNpcLabel(void *self, void *method) {
    if (self && ptrOK((uintptr_t)self)) sCachedAssistantManager = self;
    void *res = orig_AssistantManager_GetAssistantNpcLabel ? orig_AssistantManager_GetAssistantNpcLabel(self, method) : NULL;
    if (res && ptrOK((uintptr_t)res)) {
        int32_t len = *(int32_t*)((uintptr_t)res + 0x10);
        if (len > 0 && len <= 32) {
            const unichar *chars = (const unichar*)((uintptr_t)res + 0x14);
            NSString *label = [NSString stringWithCharacters:chars length:len];
            if (isBlacklistedCompanion(label)) {
                NSLog(@"[ReddsTools] Intercepted crashing companion '%@'! Auto-replacing with Bob (cat00).", label);
                dispatch_async(dispatch_get_main_queue(), ^{
                    forceSetCompanion(@"cat00");
                });
                typedef void* (*fn_str_new)(const char*);
                static fn_str_new s_new = NULL;
                if (!s_new) s_new = (fn_str_new)dlsym(RTLD_DEFAULT, "il2cpp_string_new");
                if (s_new) return s_new("cat00");
            }
        }
    }
    return res;
}

// ============================ Camp Caretaker & Companion Engine ============================
static void *findAssistantManager(void) {
    if (sCachedAssistantManager && ptrOK((uintptr_t)sCachedAssistantManager)) {
        return sCachedAssistantManager;
    }
    uintptr_t base = getUnityBase();
    if (!base) return NULL;

    // Strategy 1: Invocation of Singleton<AssistantManagerAccessor>.get_Instance() via MethodInfo at base + 0x7446018
    void **pGetInstMethod = (void**)(base + 0x7446018);
    if (ptrOK((uintptr_t)pGetInstMethod)) {
        void *methodInfo = *pGetInstMethod;
        if (methodInfo && ptrOK((uintptr_t)methodInfo)) {
            typedef void* (*fn_get_instance)(void *method);
            fn_get_instance getInst = (fn_get_instance)(base + 0x4281938);
            void *accessor = getInst(methodInfo);
            if (accessor && ptrOK((uintptr_t)accessor)) {
                void *mgr = *(void**)((char*)accessor + 0x10);
                if (mgr && ptrOK((uintptr_t)mgr)) {
                    sCachedAssistantManager = mgr;
                    return mgr;
                }
            }
        }
    }

    // Strategy 2: Direct resolution via Singleton<AssistantManagerAccessor> TypeInfo pointer at base + 0x7401150
    void **pSingletonTypeInfo = (void**)(base + 0x7401150);
    if (ptrOK((uintptr_t)pSingletonTypeInfo)) {
        void *singletonKlass = *pSingletonTypeInfo;
        if (singletonKlass && ptrOK((uintptr_t)singletonKlass)) {
            void *staticFields = *(void**)((char*)singletonKlass + 0xB8);
            if (staticFields && ptrOK((uintptr_t)staticFields)) {
                void *accessor = *(void**)staticFields;
                if (accessor && ptrOK((uintptr_t)accessor)) {
                    void *mgr = *(void**)((char*)accessor + 0x10);
                    if (mgr && ptrOK((uintptr_t)mgr)) {
                        sCachedAssistantManager = mgr;
                        return mgr;
                    }
                }
            }
        }
    }

    // Strategy 3: Dynamic reflection via IL2CPP class hierarchy
    void *klass = il2cppClassFromName("NDcube.Cmps.App.Scene", "AssistantManagerAccessor");
    if (klass) {
        // Base class Singleton<AssistantManagerAccessor> at offset 0x58
        void *parentKlass = *(void**)((char*)klass + 0x58);
        if (!parentKlass) {
            typedef void* (*fn_get_parent)(void*);
            fn_get_parent getParent = (fn_get_parent)dlsym(RTLD_DEFAULT, "il2cpp_class_get_parent");
            if (getParent) parentKlass = getParent(klass);
        }
        if (parentKlass && ptrOK((uintptr_t)parentKlass)) {
            typedef void (*fn_runtime_init)(void*);
            fn_runtime_init rti = (fn_runtime_init)dlsym(RTLD_DEFAULT, "il2cpp_runtime_class_init");
            if (rti) rti(parentKlass);

            void *staticFields = *(void**)((char*)parentKlass + 0xB8);
            if (staticFields && ptrOK((uintptr_t)staticFields)) {
                void *accessor = *(void**)staticFields;
                if (accessor && ptrOK((uintptr_t)accessor)) {
                    void *mgr = *(void**)((char*)accessor + 0x10);
                    if (mgr && ptrOK((uintptr_t)mgr)) {
                        sCachedAssistantManager = mgr;
                        return mgr;
                    }
                }
            }
        }
    }

    return NULL;
}

static NSString *getCurrentCompanionId(void) {
    uintptr_t base = getUnityBase();
    if (!base) return nil;
    void *mgr = findAssistantManager();
    if (!mgr) return nil;

    typedef void* (*fn_get_label)(void *self, void *method);
    fn_get_label getLabel = (fn_get_label)(base + 0x25D4A40);
    void *il2cppStr = getLabel(mgr, NULL);
    if (!il2cppStr || !ptrOK((uintptr_t)il2cppStr)) return nil;

    int32_t len = *(int32_t*)((uintptr_t)il2cppStr + 0x10);
    if (len <= 0 || len > 32) return nil;
    const unichar *chars = (const unichar*)((uintptr_t)il2cppStr + 0x14);
    return [NSString stringWithCharacters:chars length:len];
}

static bool forceSetCompanion(NSString *npcId) {
    if (!npcId.length) return false;
    if (isBlacklistedCompanion(npcId)) {
        NSLog(@"[ReddsTools] Refusing to set blacklisted companion '%@'.", npcId);
        return false;
    }
    uintptr_t base = getUnityBase();
    if (!base) return false;
    void *mgr = findAssistantManager();
    if (!mgr) return false;

    typedef void* (*fn_il2cpp_string_new)(const char*);
    static fn_il2cpp_string_new s_strNew = NULL;
    if (!s_strNew) {
        s_strNew = (fn_il2cpp_string_new)dlsym(RTLD_DEFAULT, "il2cpp_string_new");
        if (!s_strNew) s_strNew = (fn_il2cpp_string_new)(base + 0x2abe4);
    }
    if (!s_strNew) return false;

    void *il2cppStr = s_strNew([npcId UTF8String]);
    if (!il2cppStr) return false;

    // 1. Invoke AssistantManager.RegisterAssistantNpc at 0x25D46FC
    typedef void (*fn_reg)(void *self, void *label, void *method);
    fn_reg regFunc = (fn_reg)(base + 0x25D46FC);
    regFunc(mgr, il2cppStr, NULL);

    // 2. Invoke AssistantManager.SetWalkWithEnabled(true) at 0x25D5960
    typedef void (*fn_walk)(void *self, bool enabled, void *method);
    fn_walk walkFunc = (fn_walk)(base + 0x25D5960);
    walkFunc(mgr, true, NULL);

    // 3. Save assistant state so it persists cleanly across map changes
    typedef void* (*fn_save)(void *self, void *method);
    fn_save saveFunc = (fn_save)(base + 0x25D58E4);
    if (saveFunc) saveFunc(mgr, NULL);

    return true;
}

static bool dismissCompanion(void) {
    uintptr_t base = getUnityBase();
    if (!base) return false;
    void *mgr = findAssistantManager();
    if (!mgr) return false;

    typedef void (*fn_unreg)(void *self, void *method);
    fn_unreg unregFunc = (fn_unreg)(base + 0x25D4DB8);
    unregFunc(mgr, NULL);

    typedef void* (*fn_save)(void *self, void *method);
    fn_save saveFunc = (fn_save)(base + 0x25D58E4);
    if (saveFunc) saveFunc(mgr, NULL);

    return true;
}

static bool setCompanionWalkWith(bool enabled) {
    uintptr_t base = getUnityBase();
    if (!base) return false;
    void *mgr = findAssistantManager();
    if (!mgr) return false;

    typedef void (*fn_walk)(void *self, bool enabled, void *method);
    fn_walk walkFunc = (fn_walk)(base + 0x25D5960);
    walkFunc(mgr, enabled, NULL);
    return true;
}

// ============================ Villager & Character Dataset Model ============================

@interface ACPCCVillager : NSObject
@property (nonatomic, copy) NSString *villagerId;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *category;
@property (nonatomic, copy) NSString *species;
@property (nonatomic, copy) NSString *iconFilename;
@property (nonatomic, strong) UIImage *iconImage;
@end

@implementation ACPCCVillager

static NSCache<NSString*, UIImage*> *sVillagerIconCache = nil;

+ (NSString*)resourceDirectory {
    static NSString *sDir = nil;
    if (!sDir) {
        NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
        NSArray *candidates = @[
            [bundlePath stringByAppendingPathComponent:@"ReddsTools"],
            [bundlePath stringByAppendingPathComponent:@"Frameworks/ReddsTools.dylib"],
            [bundlePath stringByAppendingPathComponent:@"Library/Application Support/ReddsTools"],
            bundlePath ?: @"",
            @"/var/jb/Library/Application Support/ReddsTools",
            @"/Library/Application Support/ReddsTools",
            @"f:/Progs/VIBECODE/PROJECTS/ios/games/acpcc/villagers"
        ];
        for (NSString *p in candidates) {
            if (!p || p.length == 0) continue;
            NSString *jsonPath = [p stringByAppendingPathComponent:@"characters.json"];
            if ([[NSFileManager defaultManager] fileExistsAtPath:jsonPath]) {
                sDir = p;
                break;
            }
        }
        if (!sDir) sDir = [bundlePath stringByAppendingPathComponent:@"ReddsTools"];
    }
    return sDir;
}

+ (NSArray<ACPCCVillager*>*)loadAllVillagers {
    static NSArray<ACPCCVillager*> *sAllVillagers = nil;
    if (sAllVillagers && sAllVillagers.count > 0) return sAllVillagers;

    NSString *dir = [self resourceDirectory];
    NSString *jsonPath = [dir stringByAppendingPathComponent:@"characters.json"];
    NSData *data = [NSData dataWithContentsOfFile:jsonPath];
    if (!data || data.length == 0) {
        data = [[NSData alloc] initWithBase64EncodedString:kEmbeddedCharactersJsonBase64 options:0];
    }
    if (!data || data.length == 0) return @[];

    NSArray *raw = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (!raw || ![raw isKindOfClass:[NSArray class]]) return @[];

    NSMutableArray *list = [NSMutableArray arrayWithCapacity:raw.count];
    for (NSDictionary *d in raw) {
        NSString *vId = d[@"id"];
        if (isBlacklistedCompanion(vId)) {
            continue;
        }
        ACPCCVillager *v = [ACPCCVillager new];
        v.villagerId = vId;
        v.name = d[@"name"];
        v.category = d[@"category"];
        v.species = d[@"species"];
        v.iconFilename = d[@"icon"];
        [list addObject:v];
    }
    sAllVillagers = [list copy];
    return sAllVillagers;
}

- (UIImage*)iconImage {
    if (_iconImage) return _iconImage;
    if (!sVillagerIconCache) sVillagerIconCache = [NSCache new];

    UIImage *cached = [sVillagerIconCache objectForKey:self.iconFilename ?: @""];
    if (cached) {
        _iconImage = cached;
        return _iconImage;
    }

    NSString *dir = [[ACPCCVillager resourceDirectory] stringByAppendingPathComponent:@"icons"];
    NSString *fullPath = [dir stringByAppendingPathComponent:self.iconFilename ?: @""];
    UIImage *img = [UIImage imageWithContentsOfFile:fullPath];
    if (img) {
        [sVillagerIconCache setObject:img forKey:self.iconFilename];
        _iconImage = img;
    }
    return _iconImage;
}

@end

// ============================ Villager Grid Cell & Selector Modal ============================

@interface ReddsVillagerCell : UICollectionViewCell
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *badgeLabel;
@end

@implementation ReddsVillagerCell

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [UIColor colorWithWhite:0.12 alpha:0.8];
        self.layer.cornerRadius = 8;
        self.layer.borderWidth = 1.0;
        self.layer.borderColor = [UIColor colorWithWhite:0.25 alpha:1.0].CGColor;
        self.clipsToBounds = YES;

        CGFloat w = frame.size.width;
        _iconView = [[UIImageView alloc] initWithFrame:CGRectMake((w - 46) / 2.0, 5, 46, 46)];
        _iconView.contentMode = UIViewContentModeScaleAspectFit;
        _iconView.layer.cornerRadius = 23;
        _iconView.layer.masksToBounds = YES;
        _iconView.layer.borderWidth = 1.0;
        _iconView.layer.borderColor = [UIColor colorWithWhite:0.35 alpha:1.0].CGColor;
        [self.contentView addSubview:_iconView];

        _nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(2, 53, w - 4, 16)];
        _nameLabel.font = [UIFont boldSystemFontOfSize:10.5];
        _nameLabel.textColor = [UIColor whiteColor];
        _nameLabel.textAlignment = NSTextAlignmentCenter;
        _nameLabel.adjustsFontSizeToFitWidth = YES;
        _nameLabel.minimumScaleFactor = 0.75;
        [self.contentView addSubview:_nameLabel];

        _badgeLabel = [[UILabel alloc] initWithFrame:CGRectMake(2, 69, w - 4, 14)];
        _badgeLabel.font = [UIFont systemFontOfSize:9.0];
        _badgeLabel.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
        _badgeLabel.textAlignment = NSTextAlignmentCenter;
        _badgeLabel.adjustsFontSizeToFitWidth = YES;
        _badgeLabel.minimumScaleFactor = 0.7;
        [self.contentView addSubview:_badgeLabel];
    }
    return self;
}

- (void)configureWithVillager:(ACPCCVillager*)v isSelected:(BOOL)isSelected {
    self.nameLabel.text = v.name ?: v.villagerId;
    self.badgeLabel.text = [NSString stringWithFormat:@"[%@]", v.villagerId];
    UIImage *img = v.iconImage;
    if (img) {
        self.iconView.image = img;
        self.iconView.backgroundColor = [UIColor clearColor];
    } else {
        self.iconView.image = nil;
        self.iconView.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1.0];
    }

    if (isSelected) {
        self.layer.borderColor = accentOrangeCol().CGColor;
        self.layer.borderWidth = 2.0;
        self.backgroundColor = [UIColor colorWithRed:0.88 green:0.45 blue:0.22 alpha:0.25];
        self.nameLabel.textColor = accentOrangeCol();
    } else {
        self.layer.borderColor = [UIColor colorWithWhite:0.25 alpha:1.0].CGColor;
        self.layer.borderWidth = 1.0;
        self.backgroundColor = [UIColor colorWithWhite:0.12 alpha:0.8];
        self.nameLabel.textColor = [UIColor whiteColor];
    }
}

@end

@interface ReddsVillagerSelectorModal : UIView <UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UISearchBarDelegate>
@property (nonatomic, strong) UIView *container;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIButton *closeBtn;
@property (nonatomic, strong) UISegmentedControl *segmentedControl;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) UILabel *countLabel;

@property (nonatomic, strong) NSArray<ACPCCVillager*> *allVillagers;
@property (nonatomic, strong) NSArray<ACPCCVillager*> *filteredVillagers;
@property (nonatomic, copy) NSString *selectedVillagerId;
@property (nonatomic, copy) void (^onSelectVillager)(ACPCCVillager *villager);
@property (nonatomic, copy) void (^onCloseModal)(void);
@end

@implementation ReddsVillagerSelectorModal

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.65];
        self.userInteractionEnabled = YES;

        CGFloat cw = MIN(frame.size.width - 24, 380);
        CGFloat ch = MIN(frame.size.height - 60, 580);
        _container = [[UIView alloc] initWithFrame:CGRectMake((frame.size.width - cw) / 2.0, (frame.size.height - ch) / 2.0, cw, ch)];
        _container.backgroundColor = bgCol();
        _container.layer.cornerRadius = 16;
        _container.layer.borderWidth = 1.5;
        _container.layer.borderColor = borderCol().CGColor;
        _container.clipsToBounds = YES;
        [self addSubview:_container];

        _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(14, 10, cw - 60, 24)];
        _titleLabel.text = @"SELECT ROAMING COMPANION";
        _titleLabel.textColor = [UIColor whiteColor];
        _titleLabel.font = [UIFont boldSystemFontOfSize:14];
        [_container addSubview:_titleLabel];

        _closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        _closeBtn.frame = CGRectMake(cw - 36, 7, 30, 30);
        [_closeBtn setTitle:@"X" forState:UIControlStateNormal];
        _closeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:18];
        [_closeBtn setTitleColor:[UIColor colorWithWhite:0.85 alpha:1.0] forState:UIControlStateNormal];
        [_closeBtn addTarget:self action:@selector(onClose) forControlEvents:UIControlEventTouchUpInside];
        [_container addSubview:_closeBtn];

        NSArray *segItems = @[@"All", @"Special", @"Villagers"];
        _segmentedControl = [[UISegmentedControl alloc] initWithItems:segItems];
        _segmentedControl.frame = CGRectMake(12, 40, cw - 24, 30);
        _segmentedControl.selectedSegmentIndex = 0;
        _segmentedControl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1.0];
        _segmentedControl.selectedSegmentTintColor = accentOrangeCol();
        [_segmentedControl setTitleTextAttributes:@{NSForegroundColorAttributeName:[UIColor whiteColor], NSFontAttributeName:[UIFont boldSystemFontOfSize:11.5]} forState:UIControlStateNormal];
        [_segmentedControl addTarget:self action:@selector(onFilterChanged) forControlEvents:UIControlEventValueChanged];
        [_container addSubview:_segmentedControl];

        _searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(6, 74, cw - 12, 40)];
        _searchBar.placeholder = @"Search by name, ID, or species...";
        _searchBar.searchBarStyle = UISearchBarStyleMinimal;
        _searchBar.barStyle = UIBarStyleBlack;
        _searchBar.tintColor = accentOrangeCol();
        _searchBar.delegate = self;
        if (@available(iOS 13.0, *)) {
            _searchBar.searchTextField.textColor = [UIColor whiteColor];
            _searchBar.searchTextField.font = [UIFont systemFontOfSize:12.5];
            _searchBar.searchTextField.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1.0];
        }
        [_container addSubview:_searchBar];

        _countLabel = [[UILabel alloc] initWithFrame:CGRectMake(14, 116, cw - 28, 16)];
        _countLabel.font = [UIFont systemFontOfSize:10.5];
        _countLabel.textColor = [UIColor colorWithWhite:0.55 alpha:1.0];
        _countLabel.text = @"Showing characters...";
        [_container addSubview:_countLabel];

        UICollectionViewFlowLayout *layout = [UICollectionViewFlowLayout new];
        layout.itemSize = CGSizeMake(74, 90);
        layout.minimumInteritemSpacing = 6;
        layout.minimumLineSpacing = 8;
        layout.sectionInset = UIEdgeInsetsMake(4, 6, 12, 6);

        _collectionView = [[UICollectionView alloc] initWithFrame:CGRectMake(6, 136, cw - 12, ch - 144) collectionViewLayout:layout];
        _collectionView.backgroundColor = [UIColor clearColor];
        _collectionView.dataSource = self;
        _collectionView.delegate = self;
        _collectionView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
        [_collectionView registerClass:[ReddsVillagerCell class] forCellWithReuseIdentifier:@"ReddsVillagerCell"];
        [_container addSubview:_collectionView];

        UITapGestureRecognizer *outsideTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onOutsideTap:)];
        outsideTap.cancelsTouchesInView = NO;
        [self addGestureRecognizer:outsideTap];

        _allVillagers = [ACPCCVillager loadAllVillagers];
        _filteredVillagers = _allVillagers;

        NSInteger total = _allVillagers.count;
        NSInteger spec = 0;
        for (ACPCCVillager *v in _allVillagers) {
            if ([v.category isEqualToString:@"Special NPC"]) spec++;
        }
        NSInteger reg = total - spec;
        [_segmentedControl setTitle:[NSString stringWithFormat:@"All (%ld)", (long)total] forSegmentAtIndex:0];
        [_segmentedControl setTitle:[NSString stringWithFormat:@"Special (%ld)", (long)spec] forSegmentAtIndex:1];
        [_segmentedControl setTitle:[NSString stringWithFormat:@"Villagers (%ld)", (long)reg] forSegmentAtIndex:2];
        _countLabel.text = [NSString stringWithFormat:@"Showing %ld characters", (long)total];
    }
    return self;
}

- (void)onOutsideTap:(UITapGestureRecognizer*)g {
    CGPoint p = [g locationInView:self];
    if (!CGRectContainsPoint(self.container.frame, p)) {
        [self onClose];
    }
}

- (void)onClose {
    [self.searchBar resignFirstResponder];
    [UIView animateWithDuration:0.2 animations:^{
        self.alpha = 0.0;
    } completion:^(BOOL finished) {
        self.hidden = YES;
        if (self.onCloseModal) {
            self.onCloseModal();
        }
    }];
}

- (void)refreshData {
    self.allVillagers = [ACPCCVillager loadAllVillagers];
    NSInteger total = self.allVillagers.count;
    NSInteger spec = 0;
    for (ACPCCVillager *v in self.allVillagers) {
        if ([v.category isEqualToString:@"Special NPC"]) spec++;
    }
    NSInteger reg = total - spec;
    [self.segmentedControl setTitle:[NSString stringWithFormat:@"All (%ld)", (long)total] forSegmentAtIndex:0];
    [self.segmentedControl setTitle:[NSString stringWithFormat:@"Special (%ld)", (long)spec] forSegmentAtIndex:1];
    [self.segmentedControl setTitle:[NSString stringWithFormat:@"Villagers (%ld)", (long)reg] forSegmentAtIndex:2];
    [self filterContent];
}

- (void)onFilterChanged {
    [self filterContent];
}

- (void)filterContent {
    NSInteger seg = self.segmentedControl.selectedSegmentIndex;
    NSString *search = [self.searchBar.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    NSMutableArray *res = [NSMutableArray arrayWithCapacity:self.allVillagers.count];
    for (ACPCCVillager *v in self.allVillagers) {
        if (seg == 1 && ![v.category isEqualToString:@"Special NPC"]) continue;
        if (seg == 2 && [v.category isEqualToString:@"Special NPC"]) continue;

        if (search.length > 0) {
            BOOL matchName = [v.name rangeOfString:search options:NSCaseInsensitiveSearch].location != NSNotFound;
            BOOL matchId = [v.villagerId rangeOfString:search options:NSCaseInsensitiveSearch].location != NSNotFound;
            BOOL matchSpecies = [v.species rangeOfString:search options:NSCaseInsensitiveSearch].location != NSNotFound;
            if (!matchName && !matchId && !matchSpecies) continue;
        }
        [res addObject:v];
    }

    self.filteredVillagers = [res copy];
    self.countLabel.text = [NSString stringWithFormat:@"Showing %lu characters", (unsigned long)self.filteredVillagers.count];
    [self.collectionView reloadData];
}

// SearchBar Delegate
- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    [self filterContent];
}
- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

// CollectionView DataSource & Delegate
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.filteredVillagers.count;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    ReddsVillagerCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"ReddsVillagerCell" forIndexPath:indexPath];
    ACPCCVillager *v = self.filteredVillagers[indexPath.item];
    BOOL isSel = [v.villagerId isEqualToString:self.selectedVillagerId ?: @""];
    [cell configureWithVillager:v isSelected:isSel];
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    ACPCCVillager *v = self.filteredVillagers[indexPath.item];
    self.selectedVillagerId = v.villagerId;
    [self.collectionView reloadData];

    if (self.onSelectVillager) {
        self.onSelectVillager(v);
    }
    [self onClose];
}

@end

// ============================ ScrollView with Gesture Passthrough ============================
@interface ReddsScrollView : UIScrollView
@end

@implementation ReddsScrollView
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.canCancelContentTouches = YES;
        self.delaysContentTouches = YES;
    }
    return self;
}

- (BOOL)touchesShouldCancelInContentView:(UIView *)view {
    if ([view isKindOfClass:UISlider.class]) {
        return NO;
    }
    return YES;
}
@end

// ============================ Lightweight FPS & Performance HUD ============================
@interface ReddsFpsHud : UIView
@property (nonatomic, strong) UILabel *label;
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, assign) CFTimeInterval lastTimestamp;
@property (nonatomic, assign) NSInteger frameCount;
- (void)start;
- (void)stop;
@end

@implementation ReddsFpsHud
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.88];
        self.layer.cornerRadius = 13;
        self.layer.masksToBounds = YES;
        self.layer.borderWidth = 1.0;
        self.layer.borderColor = [UIColor colorWithRed:0.2 green:0.85 blue:0.45 alpha:0.85].CGColor;
        
        self.label = [[UILabel alloc] initWithFrame:self.bounds];
        self.label.font = [UIFont monospacedDigitSystemFontOfSize:11 weight:UIFontWeightBold];
        self.label.textColor = [UIColor colorWithRed:0.2 green:0.9 blue:0.4 alpha:1.0];
        self.label.textAlignment = NSTextAlignmentCenter;
        self.label.text = @"-- FPS | -- MB";
        [self addSubview:self.label];
        
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(onPan:)];
        [self addGestureRecognizer:pan];
        self.userInteractionEnabled = YES;
    }
    return self;
}

- (void)start {
    if (self.displayLink) return;
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(onTick:)];
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    self.lastTimestamp = 0;
    self.frameCount = 0;
}

- (void)stop {
    [self.displayLink invalidate];
    self.displayLink = nil;
}

- (void)onTick:(CADisplayLink *)link {
    if (self.lastTimestamp == 0) {
        self.lastTimestamp = link.timestamp;
        return;
    }
    self.frameCount++;
    CFTimeInterval elapsed = link.timestamp - self.lastTimestamp;
    if (elapsed >= 0.5) {
        double fps = (double)self.frameCount / elapsed;
        double ms = (1000.0 / (fps > 0 ? fps : 60.0));
        
        mach_task_basic_info_data_t taskInfo;
        mach_msg_type_number_t infoCount = MACH_TASK_BASIC_INFO_COUNT;
        kern_return_t kr = task_info(mach_task_self(), MACH_TASK_BASIC_INFO, (task_info_t)&taskInfo, &infoCount);
        double memMB = (kr == KERN_SUCCESS) ? (taskInfo.resident_size / (1024.0 * 1024.0)) : 0;
        
        self.label.text = [NSString stringWithFormat:@"%.0f FPS (%.1fms) | %.0fMB", fps, ms, memMB];
        if (fps >= 55) {
            self.label.textColor = [UIColor colorWithRed:0.2 green:0.9 blue:0.4 alpha:1.0];
        } else if (fps >= 30) {
            self.label.textColor = [UIColor colorWithRed:0.96 green:0.7 blue:0.2 alpha:1.0];
        } else {
            self.label.textColor = [UIColor colorWithRed:0.95 green:0.3 blue:0.3 alpha:1.0];
        }
        
        self.frameCount = 0;
        self.lastTimestamp = link.timestamp;
    }
}

- (void)onPan:(UIPanGestureRecognizer *)g {
    CGPoint t = [g translationInView:self.superview];
    self.center = CGPointMake(self.center.x + t.x, self.center.y + t.y);
    [g setTranslation:CGPointZero inView:self.superview];
}
@end

// ============================ In-Memory Profile & State ============================
static uintptr_t sLiveUserProfile = 0;
static int64_t (*orig_UserProfileEntry_get_Bell)(void *self, void *method) = NULL;
static int64_t hook_UserProfileEntry_get_Bell(void *self, void *method) {
    if (self && ptrOK((uintptr_t)self)) sLiveUserProfile = (uintptr_t)self;
    return orig_UserProfileEntry_get_Bell ? orig_UserProfileEntry_get_Bell(self, method) : 0;
}

static int64_t (*orig_UserProfileEntry_get_NewLeafTicket)(void *self, void *method) = NULL;
static int64_t hook_UserProfileEntry_get_NewLeafTicket(void *self, void *method) {
    if (self && ptrOK((uintptr_t)self)) sLiveUserProfile = (uintptr_t)self;
    return orig_UserProfileEntry_get_NewLeafTicket ? orig_UserProfileEntry_get_NewLeafTicket(self, method) : 0;
}


static void *sLiveUserSelf = NULL;
static void *sLiveItemStock = NULL;
static void* findItemStock(void);

static uintptr_t findUserProfile(void) {
    if (sLiveUserProfile && ptrOK(sLiveUserProfile)) {
        return sLiveUserProfile;
    }
    uintptr_t base = getUnityBase();
    if (!base) return 0;
    void *itemStock = findItemStock();
    if (sLiveUserSelf && ptrOK((uintptr_t)sLiveUserSelf)) {
        void *prof = *(void**)((char*)sLiveUserSelf + 0xA0);
        if (prof && ptrOK((uintptr_t)prof)) {
            sLiveUserProfile = (uintptr_t)prof;
            return sLiveUserProfile;
        }
    }
    return 0;
}

static int64_t readBells(void) {
    uintptr_t base = getUnityBase();
    if (!base) return -1;
    uintptr_t prof = findUserProfile();
    if (!prof) return -1;

#ifdef JAILED
    typedef int64_t (*fn_cmps_get_bell)(void*);
    fn_cmps_get_bell get_Bell = (fn_cmps_get_bell)(base + 0x21A0144);
    return get_Bell((void*)prof);
#else
    typedef int64_t (*fn_get_bell)(void*, void*);
    fn_get_bell get_Bell = orig_UserProfileEntry_get_Bell ?: (fn_get_bell)(base + 0x1DF5ED4);
    return get_Bell((void*)prof, NULL);
#endif
}

static bool writeBells(int64_t val) {
    uintptr_t base = getUnityBase();
    if (!base) return false;
    uintptr_t prof = findUserProfile();
    if (!prof) return false;

#ifdef JAILED
    typedef void (*fn_cmps_set_bell)(void*, int64_t);
    fn_cmps_set_bell set_Bell = (fn_cmps_set_bell)(base + 0x21A0160);
    set_Bell((void*)prof, val);
    return true;
#else
    typedef void (*fn_set_bell)(void*, int64_t, void*);
    fn_set_bell set_Bell = (fn_set_bell)(base + 0x1DF5EE8);
    set_Bell((void*)prof, val, NULL);
    return true;
#endif
}

static int64_t readLeafTokens(void) {
    uintptr_t base = getUnityBase();
    if (!base) return -1;
    uintptr_t prof = findUserProfile();
    if (!prof) return -1;

#ifdef JAILED
    typedef int64_t (*fn_cmps_get_token)(void*);
    fn_cmps_get_token get_Token = (fn_cmps_get_token)(base + 0x21A0268);
    return get_Token((void*)prof);
#else
    typedef int64_t (*fn_get_token)(void*, void*);
    fn_get_token get_Token = orig_UserProfileEntry_get_NewLeafTicket ?: (fn_get_token)(base + 0x1DF617C);
    return get_Token((void*)prof, NULL);
#endif
}

static bool writeLeafTokens(int64_t val) {
    uintptr_t base = getUnityBase();
    if (!base) return false;
    uintptr_t prof = findUserProfile();
    if (!prof) return false;

#ifdef JAILED
    typedef void (*fn_cmps_set_token)(void*, int64_t);
    fn_cmps_set_token set_Token = (fn_cmps_set_token)(base + 0x21A0284);
    set_Token((void*)prof, val);
    return true;
#else
    typedef void (*fn_set_token)(void*, int64_t, void*);
    fn_set_token set_Token = (fn_set_token)(base + 0x1DF6190);
    set_Token((void*)prof, val, NULL);
    return true;
#endif
}



static int32_t (*orig_CmpsItemStock_GetItemStockAmount)(void *self, void *label, bool is_only_disposable, void *method) = NULL;
static int32_t hook_CmpsItemStock_GetItemStockAmount(void *self, void *label, bool is_only_disposable, void *method) {
    if (self && ptrOK((uintptr_t)self)) sLiveItemStock = self;
    return orig_CmpsItemStock_GetItemStockAmount ? orig_CmpsItemStock_GetItemStockAmount(self, label, is_only_disposable, method) : 0;
}

static void* (*orig_CmpsUserSelf_get_Instance)(void *method) = NULL;
static void* hook_CmpsUserSelf_get_Instance(void *method) {
    void *ret = orig_CmpsUserSelf_get_Instance ? orig_CmpsUserSelf_get_Instance(method) : NULL;
    if (ret && ptrOK((uintptr_t)ret)) {
        sLiveUserSelf = ret;
        void *st = *(void**)((char*)ret + 0xE0);
        if (st && ptrOK((uintptr_t)st)) sLiveItemStock = st;
    }
    return ret;
}

static void* findItemStock(void) {
    if (sLiveItemStock && ptrOK((uintptr_t)sLiveItemStock)) {
        return sLiveItemStock;
    }
    if (sLiveUserSelf && ptrOK((uintptr_t)sLiveUserSelf)) {
        void *st = *(void**)((char*)sLiveUserSelf + 0xE0);
        if (st && ptrOK((uintptr_t)st)) {
            sLiveItemStock = st;
            return st;
        }
    }
    uintptr_t base = getUnityBase();
    if (!base) return NULL;

    // Strategy 1: Direct pointer dereference via CmpsUserSelf_TypeInfo at base + 0x73F7348
    void **pUserSelfTypeInfo = (void**)(base + 0x73F7348);
    if (ptrOK((uintptr_t)pUserSelfTypeInfo) && *pUserSelfTypeInfo && ptrOK((uintptr_t)*pUserSelfTypeInfo)) {
        void *klass = *pUserSelfTypeInfo;
        void *staticFields = *(void**)((char*)klass + 0xB8);
        if (staticFields && ptrOK((uintptr_t)staticFields)) {
            void *userSelf = *(void**)((char*)staticFields + 8);
            if (userSelf && ptrOK((uintptr_t)userSelf)) {
                sLiveUserSelf = userSelf;
                void *st = *(void**)((char*)userSelf + 0xE0);
                if (st && ptrOK((uintptr_t)st)) {
                    sLiveItemStock = st;
                    return st;
                }
            }
        }
    }

    // Strategy 2: Call CmpsUserSelf.get_Instance() at base + 0x2126194
    typedef void* (*fn_get_user_self)(void*);
    fn_get_user_self getUserSelf = (fn_get_user_self)(base + 0x2126194);
    void *userSelf = getUserSelf ? getUserSelf(NULL) : NULL;
    if (!userSelf) {
        typedef void* (*fn_get_area_mgr)(void);
        fn_get_area_mgr getAreaMgr = (fn_get_area_mgr)(base + 0x1F66594);
        void *areaMgr = getAreaMgr ? getAreaMgr() : NULL;
        if (areaMgr) {
            userSelf = *(void**)((char*)areaMgr + 0x80);
        }
    }
    if (userSelf && ptrOK((uintptr_t)userSelf)) {
        sLiveUserSelf = userSelf;
        void *st = *(void**)((char*)userSelf + 0xE0);
        if (st && ptrOK((uintptr_t)st)) {
            sLiveItemStock = st;
            return st;
        }
    }
    return NULL;
}

static int32_t readCompleteTickets(void) {
    uintptr_t base = getUnityBase();
    if (!base) return -1;
    void *itemStock = findItemStock();
    if (!itemStock) return -1;

    // Direct global pointer to IL2CPP string "cookie_ticket" at base + 0x74AE898
    void *strObj = *(void**)(base + 0x74AE898);
    if (!strObj) {
        typedef void* (*fn_il2cpp_string_new)(const char*);
        static fn_il2cpp_string_new s_strNew = NULL;
        if (!s_strNew) {
            s_strNew = (fn_il2cpp_string_new)dlsym(RTLD_DEFAULT, "il2cpp_string_new");
            if (!s_strNew) s_strNew = (fn_il2cpp_string_new)(base + 0x2abe4);
        }
        if (s_strNew) strObj = s_strNew("cookie_ticket");
    }

    typedef int32_t (*fn_GetItemStockAmount)(void *itemStock, void *labelStr, bool is_only_disposable, void *method);
    fn_GetItemStockAmount getItemStockAmount = (fn_GetItemStockAmount)(base + 0x21785A4);
    if (getItemStockAmount && strObj) {
        int32_t amt = getItemStockAmount(itemStock, strObj, false, NULL);
        if (amt >= 0) return amt;
    }

    void *storageList = *(void**)((char*)itemStock + 0x50);
    if (storageList) {
        void *listObj = *(void**)((char*)storageList + 0x28);
        if (listObj) {
            int32_t count = *(int32_t*)((char*)listObj + 0x18);
            void *itemsArray = *(void**)((char*)listObj + 0x10);
            if (itemsArray && count > 0) {
                typedef int32_t (*fn_ItemOneSlot_GetNum)(void *slot, void *method);
                fn_ItemOneSlot_GetNum getNum = (fn_ItemOneSlot_GetNum)(base + 0x2228E90);
                void **slots = (void**)((char*)itemsArray + 0x20);
                for (int i = 0; i < count; i++) {
                    void *slot = slots[i];
                    if (!slot) continue;
                    void *labelStr = *(void**)((char*)slot + 0x38);
                    if (!labelStr) continue;
                    int32_t strLen = *(int32_t*)((char*)labelStr + 0x10);
                    const uint16_t *chars = (const uint16_t*)((char*)labelStr + 0x14);
                    if (strLen == 13 &&
                        chars[0] == 'c' && chars[1] == 'o' && chars[2] == 'o' && chars[3] == 'k' &&
                        chars[4] == 'i' && chars[5] == 'e' && chars[6] == '_' && chars[7] == 't' &&
                        chars[8] == 'i' && chars[9] == 'c' && chars[10] == 'k' && chars[11] == 'e' && chars[12] == 't') {
                        return getNum ? getNum(slot, NULL) : 0;
                    }
                }
            }
        }
    }
    return 0;
}

static bool writeCompleteTickets(int32_t targetVal) {
    if (targetVal < 0) targetVal = 0;
    if (targetVal > 9999) targetVal = 9999;

    uintptr_t base = getUnityBase();
    if (!base) return false;
    void *itemStock = findItemStock();
    if (!itemStock) return false;

    void *strObj = *(void**)(base + 0x74AE898);
    typedef void* (*fn_il2cpp_string_new)(const char*);
    static fn_il2cpp_string_new s_il2cpp_string_new = NULL;
    if (!s_il2cpp_string_new) {
        s_il2cpp_string_new = (fn_il2cpp_string_new)dlsym(RTLD_DEFAULT, "il2cpp_string_new");
        if (!s_il2cpp_string_new) s_il2cpp_string_new = (fn_il2cpp_string_new)(base + 0x2abe4);
    }
    if (!strObj && s_il2cpp_string_new) {
        strObj = s_il2cpp_string_new("cookie_ticket");
    }

    typedef void (*fn_ItemOneSlot_SetNum)(void *slot, int32_t num, void *method);
    fn_ItemOneSlot_SetNum setNum = (fn_ItemOneSlot_SetNum)(base + 0x222F1C0);

    typedef void* (*fn_CmpsItemData_Get)(void *label, void *method);
    fn_CmpsItemData_Get getItemData = (fn_CmpsItemData_Get)(base + 0x20CB368);

    typedef bool (*fn_updateItemStockNum)(void *itemStock, void *slot, void *itemData, int32_t num, void *method);
    fn_updateItemStockNum updateStockNum = (fn_updateItemStockNum)(base + 0x2184D80);

    typedef void* (*fn_CmpsItemStock_AddItemForce)(void *thiz, void *itemLabel, int32_t amount, void *routeParam, int64_t date, bool isChecked, void *otherData, void *method);
    fn_CmpsItemStock_AddItemForce addItemForce = (fn_CmpsItemStock_AddItemForce)(base + 0x21871F8);

    void *storageList = *(void**)((char*)itemStock + 0x50);
    void *listObj = storageList ? *(void**)((char*)storageList + 0x28) : NULL;
    int32_t count = listObj ? *(int32_t*)((char*)listObj + 0x18) : 0;
    void *itemsArray = listObj ? *(void**)((char*)listObj + 0x10) : NULL;

    bool found = false;
    if (itemsArray && count > 0) {
        void **slots = (void**)((char*)itemsArray + 0x20);
        for (int i = 0; i < count; i++) {
            void *slot = slots[i];
            if (!slot) continue;
            void *labelStr = *(void**)((char*)slot + 0x38);
            if (!labelStr) continue;
            int32_t strLen = *(int32_t*)((char*)labelStr + 0x10);
            const uint16_t *chars = (const uint16_t*)((char*)labelStr + 0x14);
            if (strLen == 13 &&
                chars[0] == 'c' && chars[1] == 'o' && chars[2] == 'o' && chars[3] == 'k' &&
                chars[4] == 'i' && chars[5] == 'e' && chars[6] == '_' && chars[7] == 't' &&
                chars[8] == 'i' && chars[9] == 'c' && chars[10] == 'k' && chars[11] == 'e' && chars[12] == 't') {
                found = true;
                void *itemData = getItemData ? getItemData(labelStr, NULL) : NULL;
                bool success = false;
                if (updateStockNum && itemData) {
                    success = updateStockNum(itemStock, slot, itemData, targetVal, NULL);
                }
                if (!success && setNum) {
                    setNum(slot, targetVal, NULL);
                }
                break;
            }
        }
    }

    if (!found && strObj && addItemForce) {
        addItemForce(itemStock, strObj, targetVal, NULL, 0, false, NULL, NULL);
    }
    return true;
}

// Bulk Material Stack Editor
static int maxAllMaterials(int32_t amount) {
    uintptr_t base = getUnityBase();
    if (!base) return 0;

    void *itemStock = findItemStock();
    if (!itemStock) return 0;

    void *storageList = *(void**)((char*)itemStock + 0x50);
    if (!storageList) return 0;

    void *listObj = *(void**)((char*)storageList + 0x28);
    if (!listObj) return 0;

    int32_t count = *(int32_t*)((char*)listObj + 0x18);
    void *itemsArray = *(void**)((char*)listObj + 0x10);
    if (!itemsArray || count <= 0) return 0;

    typedef void (*fn_ItemOneSlot_SetNum)(void *slot, int32_t num, void *method);
    fn_ItemOneSlot_SetNum setNum = (fn_ItemOneSlot_SetNum)(base + 0x222F1C0);

    typedef void* (*fn_CmpsItemData_Get)(void *label, void *method);
    fn_CmpsItemData_Get getItemData = (fn_CmpsItemData_Get)(base + 0x20CB368);

    typedef bool (*fn_updateItemStockNum)(void *itemStock, void *slot, void *itemData, int32_t num, void *method);
    fn_updateItemStockNum updateStockNum = (fn_updateItemStockNum)(base + 0x2184D80);

    typedef void* (*fn_CmpsItemStock_AddItemForce)(void *thiz, void *itemLabel, int32_t amount, void *routeParam, int64_t date, bool isChecked, void *otherData, void *method);
    fn_CmpsItemStock_AddItemForce addItemForce = (fn_CmpsItemStock_AddItemForce)(base + 0x21871F8);

    typedef void* (*fn_il2cpp_string_new)(const char*);
    static fn_il2cpp_string_new s_il2cpp_string_new = NULL;
    if (!s_il2cpp_string_new) {
        s_il2cpp_string_new = (fn_il2cpp_string_new)dlsym(RTLD_DEFAULT, "il2cpp_string_new");
    }

    NSMutableSet<NSString*> *updatedLabels = [NSMutableSet set];
    int modifiedCount = 0;

    void **slots = (void**)((char*)itemsArray + 0x20);
    for (int i = 0; i < count; i++) {
        void *slot = slots[i];
        if (!slot) continue;

        void *labelStr = *(void**)((char*)slot + 0x38);
        if (!labelStr) continue;

        int32_t strLen = *(int32_t*)((char*)labelStr + 0x10);
        const uint16_t *chars = (const uint16_t*)((char*)labelStr + 0x14);
        if (strLen < 9) continue;

        // Check if label starts with "material_"
        if (chars[0] == 'm' && chars[1] == 'a' && chars[2] == 't' &&
            chars[3] == 'e' && chars[4] == 'r' && chars[5] == 'i' &&
            chars[6] == 'a' && chars[7] == 'l' && chars[8] == '_') {

            NSString *nsLabel = [NSString stringWithCharacters:chars length:strLen];
            [updatedLabels addObject:nsLabel];

            void *itemData = getItemData ? getItemData(labelStr, NULL) : NULL;
            bool success = false;
            if (updateStockNum && itemData) {
                success = updateStockNum(itemStock, slot, itemData, amount, NULL);
            }
            if (!success && setNum) {
                setNum(slot, amount, NULL);
            }
            modifiedCount++;
        }
    }

    // ACPCC crafting materials: unlock and max any unowned materials via AddItemForce
    static const char *kAllMaterialLabels[] = {
        // 5 Basic Crafting Materials:
        "material_key00", "material_huwahuwa00", "material_katikati00",
        "material_mogumogu00", "material_perapera00",
        // 11 Essences:
        "material_ntl00", "material_fan00", "material_spt00", "material_coo00",
        "material_pub00", "material_pop00", "material_ori00", "material_ggs00",
        "material_mdn00", "material_old00", "material_cnt00",
        // Special Materials:
        "material_pikapika00", "material_friend00", "material_fukkoku00",
        "material_furniturepuzzle00", "material_Treasure00", "material_tre00_00",
        // Event Materials:
        "material_2010_00", "material_2030_00", "material_2070_00",
        "material_2120_00", "material_2140_00", "material_2450_00",
        "material_2560_00", "material_2650_00", "material_2730_00",
        "material_2880_00", "material_2890_00", "material_2970_00",
        "material_3000_00", "material_3040_00", "material_3210_00",
        "material_3280_00", "material_3310_00", "material_3490_00",
        "material_3550_00", "material_3560_00", "material_3840_00",
        "material_3990_00", "material_4280_00"
    };

    if (s_il2cpp_string_new && addItemForce) {
        size_t totalMats = sizeof(kAllMaterialLabels) / sizeof(kAllMaterialLabels[0]);
        for (size_t k = 0; k < totalMats; k++) {
            const char *matName = kAllMaterialLabels[k];
            NSString *nsMat = [NSString stringWithUTF8String:matName];
            if (![updatedLabels containsObject:nsMat]) {
                void *il2cppStr = s_il2cpp_string_new(matName);
                if (il2cppStr) {
                    addItemForce(itemStock, il2cppStr, amount, NULL, 0, false, NULL, NULL);
                    modifiedCount++;
                }
            }
        }
    }

    return modifiedCount;
}


// Instant Flowerbed Bloomer
static int instantBloomAllPlots(void) {
    uintptr_t base = getUnityBase();
    if (!base) return 0;
    void *klass = il2cppClassFromName("CmpsDeNA.Dao.PlayerData", "UserOfflineFlowerbedOneSlotEntry");
    if (!klass) return 0;

    typedef void (*fn_set_sec)(void*, int32_t);
    fn_set_sec setSecToComplete = (fn_set_sec)(base + 0x1CE3628);
    fn_set_sec setSecToBud = (fn_set_sec)(base + 0x1CE3518);

    int count = 0;
    task_t task = mach_task_self();
    vm_address_t addr = 0x100000000UL;
    while (true) {
        vm_size_t size = 0;
        vm_region_basic_info_data_64_t info;
        mach_msg_type_number_t cnt = VM_REGION_BASIC_INFO_COUNT_64;
        mach_port_t obj;
        kern_return_t kr = vm_region_64(task, &addr, &size, VM_REGION_BASIC_INFO_64, (vm_region_info_t)&info, &cnt, &obj);
        if (kr != KERN_SUCCESS) break;

        if ((info.protection & VM_PROT_READ) && (info.protection & VM_PROT_WRITE) && !(info.protection & VM_PROT_EXECUTE)) {
            uintptr_t *ptr = (uintptr_t*)addr;
            uintptr_t *end = (uintptr_t*)(addr + size);
            while (ptr + 10 < end) {
                if (*ptr == (uintptr_t)klass) {
                    void *entry = (void*)ptr;
                    setSecToComplete(entry, 0);
                    setSecToBud(entry, 0);
                    count++;
                }
                ptr += 2;
            }
        }
        addr += size;
    }
    return count;
}

// Villager Max Friendship
static int maxAllFriendship(int level) {
    uintptr_t base = getUnityBase();
    if (!base) return 0;
    void *klass = il2cppClassFromName("CmpsDeNA.Dao.PlayerData", "UserAnimalInfoOneSlotEntry");
    if (!klass) return 0;

    typedef void (*fn_set_heart)(void*, int32_t);
    fn_set_heart setHeart = (fn_set_heart)(base + 0x1994CD4);
    fn_set_heart setHeartMax = (fn_set_heart)(base + 0x1994D58);

    int count = 0;
    task_t task = mach_task_self();
    vm_address_t addr = 0x100000000UL;
    while (true) {
        vm_size_t size = 0;
        vm_region_basic_info_data_64_t info;
        mach_msg_type_number_t cnt = VM_REGION_BASIC_INFO_COUNT_64;
        mach_port_t obj;
        kern_return_t kr = vm_region_64(task, &addr, &size, VM_REGION_BASIC_INFO_64, (vm_region_info_t)&info, &cnt, &obj);
        if (kr != KERN_SUCCESS) break;

        if ((info.protection & VM_PROT_READ) && (info.protection & VM_PROT_WRITE) && !(info.protection & VM_PROT_EXECUTE)) {
            uintptr_t *ptr = (uintptr_t*)addr;
            uintptr_t *end = (uintptr_t*)(addr + size);
            while (ptr + 10 < end) {
                if (*ptr == (uintptr_t)klass) {
                    void *entry = (void*)ptr;
                    setHeart(entry, level);
                    setHeartMax(entry, level);
                    count++;
                }
                ptr += 2;
            }
        }
        addr += size;
    }
    return count;
}

// Fulfill Animal Requests
static int completeAllAnimalRequests(void) {
    uintptr_t base = getUnityBase();
    if (!base) return 0;
    void *klass = il2cppClassFromName("CmpsDeNA.Dao.PlayerData", "UserAnimalInfoOneSlotEntry");
    if (!klass) return 0;

    typedef void (*fn_set_bool)(void*, bool);
    fn_set_bool setReqDone = (fn_set_bool)(base + 0x1994DE8);
    fn_set_bool setCampReqDone = (fn_set_bool)(base + 0x1994E68);

    int count = 0;
    task_t task = mach_task_self();
    vm_address_t addr = 0x100000000UL;
    while (true) {
        vm_size_t size = 0;
        vm_region_basic_info_data_64_t info;
        mach_msg_type_number_t cnt = VM_REGION_BASIC_INFO_COUNT_64;
        mach_port_t obj;
        kern_return_t kr = vm_region_64(task, &addr, &size, VM_REGION_BASIC_INFO_64, (vm_region_info_t)&info, &cnt, &obj);
        if (kr != KERN_SUCCESS) break;

        if ((info.protection & VM_PROT_READ) && (info.protection & VM_PROT_WRITE) && !(info.protection & VM_PROT_EXECUTE)) {
            uintptr_t *ptr = (uintptr_t*)addr;
            uintptr_t *end = (uintptr_t*)(addr + size);
            while (ptr + 10 < end) {
                if (*ptr == (uintptr_t)klass) {
                    void *entry = (void*)ptr;
                    setReqDone(entry, true);
                    setCampReqDone(entry, true);
                    count++;
                }
                ptr += 2;
            }
        }
        addr += size;
    }
    return count;
}

// Engine Speed Multiplier
static void applySpeedhack(float speed) {
    uintptr_t base = getUnityBase();
    if (!base) return;
    typedef void (*fn_set_timeScale)(float);
    fn_set_timeScale set_timeScale = (fn_set_timeScale)(base + 0x1E2B618);
    set_timeScale(speed);
}

// ============================ Menu UI Architecture ============================

@interface MenuSection : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, strong) UIView *headerBtn;
@property (nonatomic, strong) UILabel *arrowLbl;
@property (nonatomic, strong) NSMutableArray<UIView*> *rows;
@property (nonatomic, assign) BOOL isCollapsed;
@end

@implementation MenuSection
@end

@interface ReddsToolsMenu : NSObject
@property (nonatomic, strong) UIView *icon;
@property (nonatomic, strong) UIView *panel;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIButton *applyBtn, *closeBtn;
@property (nonatomic, strong) ReddsScrollView *scroll;
@property (nonatomic, strong) ReddsFpsHud *fpsHud;
@property (nonatomic, strong) UILabel *status;
@property (nonatomic, strong) NSMutableArray<MenuSection*> *sections;

// Controls - Currencies & Materials
@property (nonatomic, strong) UITextField *bellsField;
@property (nonatomic, strong) UITextField *leafTokensField;
@property (nonatomic, strong) UITextField *completeTicketsField;
@property (nonatomic, strong) UISwitch *currencyFreezeSwitch;

// Controls - Camp Caretaker & Companion (Strategy B)
@property (nonatomic, strong) UIImageView *companionAvatarView;
@property (nonatomic, strong) UILabel *companionNameLabel;
@property (nonatomic, strong) UILabel *companionStatusLabel;
@property (nonatomic, strong) UISwitch *bypassFurnitureSwitch;
@property (nonatomic, strong) UISwitch *companionWalkSwitch;
@property (nonatomic, strong) ReddsVillagerSelectorModal *villagerModal;

// Controls - Time Travel & Date Spoofer
@property (nonatomic, strong) UISwitch *timeTravelMasterSwitch;
@property (nonatomic, strong) UISwitch *timeFreezeSwitch;
@property (nonatomic, strong) UILabel *gameTimeDisplayLabel;
@property (nonatomic, strong) UILabel *offsetDisplayLabel;
@property (nonatomic, strong) UIDatePicker *datePicker;
@property (nonatomic, strong) NSTimer *clockTickTimer;

// Controls - Workshop & Events
@property (nonatomic, strong) UISwitch *instantCraftSwitch;
@property (nonatomic, strong) UISwitch *instantBloomSwitch;
@property (nonatomic, strong) UISwitch *rareCatchRateSwitch;
@property (nonatomic, strong) UISwitch *fishBiteSwitch;
@property (nonatomic, strong) UISwitch *fishPullSwitch;
@property (nonatomic, strong) UISwitch *neverFleeInsectsSwitch;
@property (nonatomic, strong) UISwitch *forceCampsiteNpcSwitch;
@property (nonatomic, strong) UIButton *campsitePresetBtn;
@property (nonatomic, strong) UISwitch *unlimitedQuarrySwitch;
@property (nonatomic, strong) UISwitch *freeFriendQuarrySwitch;
@property (nonatomic, strong) UISlider *speedSlider;
@property (nonatomic, strong) UILabel *speedLabel;
@property (nonatomic, strong) UISwitch *urpDebuggerSwitch;

// Crossover & HH Toggles
@property (nonatomic, strong) UISwitch *crossoverCookiesSwitch;
@property (nonatomic, strong) UISwitch *fullCatalogSwitch;
@property (nonatomic, strong) UISwitch *hhInfiniteTicketsSwitch;
@property (nonatomic, strong) UISwitch *hhAutoPassSwitch;
@property (nonatomic, strong) UISwitch *hhUniversalFlawlessSwitch;

// Currency Freeze state
@property (nonatomic, assign) int64_t frozenBells;
@property (nonatomic, assign) int64_t frozenTokens;
@property (nonatomic, assign) int32_t frozenTickets;
@property (nonatomic, strong) NSTimer *freezeTimer;

// Settings / Diagnostics Panel
@property (nonatomic, strong) UIView *settingsPanel;
@property (nonatomic, strong) UIView *debugPanel;
@property (nonatomic, strong) UILabel *diagnosticsLabel;

// Dedicated Overlay Window
@property (nonatomic, strong) UIWindow *overlayWindow;
@property (nonatomic, assign) BOOL isAttached;
- (void)attachToScene:(UIWindowScene *)scene;
- (void)updateIconOpacity;
- (UIView*)infoRow:(NSString*)text;
@end

static ReddsToolsMenu *gMenu = nil;

@interface ReddsOverlayWindow : UIWindow
@end

@implementation ReddsOverlayWindow
- (instancetype)initWithWindowScene:(UIWindowScene *)scene {
    if ((self = [super initWithWindowScene:scene])) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit {
    self.backgroundColor = [UIColor clearColor];
    self.windowLevel = UIWindowLevelAlert + 1000.0;
    self.userInteractionEnabled = YES;
    self.hidden = NO;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hitView = [super hitTest:point withEvent:event];
    if (hitView == self || hitView == self.rootViewController.view) {
        return nil;
    }
    return hitView;
}
@end

@interface ReddsOverlayViewController : UIViewController
@end

@implementation ReddsOverlayViewController
- (BOOL)shouldAutorotate { return YES; }
- (UIInterfaceOrientationMask)supportedInterfaceOrientations { return UIInterfaceOrientationMaskAll; }
- (BOOL)prefersStatusBarHidden { return YES; }
- (void)loadView {
    UIView *v = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    v.backgroundColor = [UIColor clearColor];
    v.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.view = v;
}
@end

static UIWindow *keyWindow(void) {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes)
        if ([scene isKindOfClass:UIWindowScene.class])
            for (UIWindow *w in ((UIWindowScene*)scene).windows) if (w.isKeyWindow) return w;
    for (UIWindow *w in UIApplication.sharedApplication.windows) if (w.isKeyWindow) return w;
    return UIApplication.sharedApplication.windows.firstObject;
}

static void darkPlaceholder(UITextField *tf, NSString *t) {
    tf.attributedPlaceholder = [[NSAttributedString alloc] initWithString:(t ?: @"")
        attributes:@{ NSForegroundColorAttributeName:[UIColor colorWithWhite:0.5 alpha:1.0] }];
}

@implementation ReddsToolsMenu

- (instancetype)init {
    if ((self = [super init])) {
        _sections = [NSMutableArray array];
        _frozenBells = -1;
        _frozenTokens = -1;
        _frozenTickets = -1;
    }
    return self;
}

- (void)attachToScene:(UIWindowScene *)scene {
    if (self.isAttached && self.overlayWindow) return;

    CGRect screenBounds = [UIScreen mainScreen].bounds;
    if (screenBounds.size.width <= 0 || screenBounds.size.height <= 0) {
        screenBounds = CGRectMake(0, 0, 393, 852);
    }

    if (@available(iOS 13.0, *)) {
        if (scene) {
            self.overlayWindow = [[ReddsOverlayWindow alloc] initWithWindowScene:scene];
        } else {
            self.overlayWindow = [[ReddsOverlayWindow alloc] initWithFrame:screenBounds];
        }
    } else {
        self.overlayWindow = [[ReddsOverlayWindow alloc] initWithFrame:screenBounds];
    }
    self.overlayWindow.frame = screenBounds;
    self.overlayWindow.rootViewController = [ReddsOverlayViewController new];
    [self.overlayWindow makeKeyAndVisible];
    self.overlayWindow.hidden = NO;

    UIView *rootView = self.overlayWindow.rootViewController.view;

    // Floating circular launcher: Redd character avatar on the left center of the screen
    CGFloat btnSize = 58.0;
    CGFloat iconX = 6.0;
    CGFloat cy = screenBounds.size.height / 2.0;

    self.icon = [[UIView alloc] initWithFrame:CGRectMake(iconX, cy - btnSize / 2.0, btnSize, btnSize)];
    self.icon.backgroundColor = [UIColor colorWithRed:0.08 green:0.11 blue:0.15 alpha:0.95];
    self.icon.layer.cornerRadius = btnSize / 2.0;
    self.icon.layer.masksToBounds = NO;
    self.icon.layer.borderWidth = 2.5;
    self.icon.layer.borderColor = [UIColor colorWithRed:0.96 green:0.65 blue:0.14 alpha:1.0].CGColor;
    self.icon.layer.shadowColor = [UIColor blackColor].CGColor;
    self.icon.layer.shadowOffset = CGSizeMake(0, 3);
    self.icon.layer.shadowOpacity = 0.7;
    self.icon.layer.shadowRadius = 5.0;
    self.icon.alpha = 0.20; // 20% opaque
    self.icon.userInteractionEnabled = YES;
    self.icon.clipsToBounds = NO;

    NSData *imgData = [[NSData alloc] initWithBase64EncodedString:kFloatIconBase64 options:NSDataBase64DecodingIgnoreUnknownCharacters];
    UIImage *img = [UIImage imageWithData:imgData];
    UIImageView *iv = [[UIImageView alloc] initWithFrame:self.icon.bounds];
    iv.image = img;
    iv.contentMode = UIViewContentModeScaleAspectFit;
    iv.layer.cornerRadius = btnSize / 2.0;
    iv.layer.masksToBounds = YES;
    iv.clipsToBounds = YES;
    [self.icon addSubview:iv];

    [rootView addSubview:self.icon];

    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTap)];
    singleTap.numberOfTapsRequired = 1;

    UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onEmergencySafeBob)];
    doubleTap.numberOfTapsRequired = 2;
    [singleTap requireGestureRecognizerToFail:doubleTap];

    [self.icon addGestureRecognizer:singleTap];
    [self.icon addGestureRecognizer:doubleTap];
    [self.icon addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(onIconPan:)]];
    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(onLongPress:)];
    lp.minimumPressDuration = 0.5;
    [self.icon addGestureRecognizer:lp];

    [self buildPanel:rootView];
    [self buildSettingsPanel:rootView];
    [self buildDebugPanel:rootView];

    // Load saved preferences
    [self applySavedPreferences];

    self.isAttached = YES;

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onRotate)
        name:UIApplicationDidChangeStatusBarOrientationNotification object:nil];
}

- (void)attach {
    [self attachToScene:nil];
}

- (void)applySavedPreferences {
    // 1. Permanently Neutralize Cheating.SendTrap anti-cheat telemetry
    applyGate(&gGateNeutralizeSendTrap, true);

    // 2. Strategy B: Unlock All Assistants (Bypass Special Furniture Ownership)
    bool bypassFurn = getSavedBool(@"Pref_BypassFurniture", false);
    applyGate(&gGateUnlockAllAssistants, bypassFurn);
    gUnlockAllAssistantsOn = bypassFurn;

    // 3. Restore Time Travel settings
    g_timeTravelActive = getSavedBool(@"Pref_TimeTravelActive", false);
    g_timeFreezeActive = getSavedBool(@"Pref_TimeFreezeActive", false);
    g_timeOffsetSeconds = getSavedInt64(@"Pref_TimeTravelOffset", 0);
    if (g_timeFreezeActive) {
        g_frozenTimestamp = (int64_t)time(NULL) + g_timeOffsetSeconds;
    }

    if (getSavedBool(@"Pref_InstantCraft", false)) {
        applyGate(&gGateCraftComplete, true);
        applyGate(&gGateCraftRecipeTime, true);
    }
    if (getSavedBool(@"Pref_InstantBloom", false)) {
        applyGate(&gGateFlowerComplete, true);
        applyGate(&gGateFlowerBud, true);
    }
    if (getSavedBool(@"Pref_RareCatch100", false)) {
        gCatchRate100On = true;
    }
    if (getSavedBool(@"Pref_FishBite", false)) {
        gInstantFishBiteOn = true;
    }
    if (getSavedBool(@"Pref_NeverFleeInsects", false)) {
        applyGate(&gGateInsectEscape, true);
        applyGate(&gGateInsectIsEscaped, true);
    }
    if (getSavedBool(@"Pref_ForceCampsiteNpc", false)) {
        gForceCampsiteNpcOn = true;
    }
    gCampsitePreset = getSavedInt(@"Pref_CampsitePreset", 0);
    if (getSavedBool(@"Pref_UnlimitedQuarry", false)) {
        applyGate(&gGateQuarryOpened, true);
        applyGate(&gGateQuarryCleared, true);
        applyGate(&gGateQuarryTickets, true);
    }
    if (getSavedBool(@"Pref_FreeFriendQuarry", false)) {
        applyGate(&gGateQuarryFriendCount, true);
        applyGate(&gGateQuarryFriendEnable, true);
        applyGate(&gGateQuarryFriendClosed, true);
        applyGate(&gGateQuarryNeedHelp, true);
        applyGate(&gGateQuarryCanUseHelp, true);
        applyGate(&gGateQuarryCurrentHelp, true);
        applyGate(&gGateQuarryRemainHelp, true);
        applyGate(&gGateQuarryOpened, true);
        applyGate(&gGateQuarryCleared, true);
    }
    float speed = getSavedFloat(@"Pref_Speedhack", 1.0f);
    if (speed > 1.01f) {
        applySpeedhack(speed);
    }
    if (getSavedBool(@"Pref_CrossoverCookies", false)) {
        applyGate(&gGateCookieCampaignCheck, true);
        applyGate(&gGateCookieReleaseCheck, true);
        applyGate(&gGateCookiePresenterCheck, true);
        applyGate(&gGateCookieCacheBypass, true);
        applyGate(&gGateCookiePresenterEnableData, true);
        applyGate(&gGateCookiePresenterCampaignId, true);
        applyGate(&gGateCookiePresenterReleaseId, true);
    }
    if (getSavedBool(@"Pref_FullCatalog", false) || getSavedBool(@"Pref_CrossoverCatalog", false) || getSavedBool(@"Pref_SeasonalItems", false)) {
        applyCatalogGates(true);
    }
    if (getSavedBool(@"Pref_HHInfiniteTickets", false)) {
        applyGate(&gGateHHStamina, true);
        applyGate(&gGateHHVouchers, true);
        applyGate(&gGateHHTicketEnough, true);
    }
    if (getSavedBool(@"Pref_HHAutoPass", false)) {
        applyGate(&gGateHHClearGrade3, true);
    }
    if (getSavedBool(@"Pref_HHUniversalFlawless", false)) {
        applyGate(&gGateHHFlawless, true);
        applyGate(&gGateHHMaxScore, true);
    }
    if (getSavedBool(@"Pref_FpsHud", false)) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (self.urpDebuggerSwitch && self.urpDebuggerSwitch.isOn) {
                [self onToggleFpsHud:self.urpDebuggerSwitch];
            }
        });
    }
}

- (void)onRotate {
    if (self.overlayWindow) {
        self.overlayWindow.frame = [UIScreen mainScreen].bounds;
        if (self.overlayWindow.rootViewController.view) {
            self.overlayWindow.rootViewController.view.frame = [UIScreen mainScreen].bounds;
        }
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.panel && !self.panel.hidden) [self layoutPanel];
    });
}

- (void)updateIconOpacity {
    BOOL menuOpen = self.panel && !self.panel.hidden;
    BOOL settingsOpen = self.settingsPanel && !self.settingsPanel.hidden;
    BOOL debugOpen = self.debugPanel && !self.debugPanel.hidden;
    BOOL villagerModalOpen = self.villagerModal && !self.villagerModal.hidden && (self.villagerModal.alpha > 0.05);
    BOOL anyOpen = menuOpen || settingsOpen || debugOpen || villagerModalOpen;
    self.icon.alpha = anyOpen ? 1.0 : 0.20;
}

- (void)onIconPan:(UIPanGestureRecognizer*)g {
    CGPoint t = [g translationInView:self.icon.superview];
    self.icon.center = CGPointMake(self.icon.center.x + t.x, self.icon.center.y + t.y);
    [g setTranslation:CGPointZero inView:self.icon.superview];
    if (g.state == UIGestureRecognizerStateBegan) {
        self.icon.alpha = 0.80;
    } else if (g.state == UIGestureRecognizerStateEnded || g.state == UIGestureRecognizerStateCancelled) {
        [self updateIconOpacity];
    }
}

- (void)onPanelDrag:(UIPanGestureRecognizer*)g {
    CGPoint t = [g translationInView:self.panel.superview];
    self.panel.center = CGPointMake(self.panel.center.x + t.x, self.panel.center.y + t.y);
    [g setTranslation:CGPointZero inView:self.panel.superview];
}

- (void)onTap {
    BOOL show = self.panel.hidden;
    if (show) {
        [self layoutPanel];
        [self refresh];
        [self startClockTimer];
    } else {
        [self stopClockTimer];
    }
    self.panel.hidden = !show;
    [self updateIconOpacity];
    if (!show) [self.panel endEditing:YES];
}

- (UIToolbar*)kbBar {
    UIToolbar *tb = [[UIToolbar alloc] initWithFrame:CGRectMake(0,0,320,42)];
    tb.barStyle = UIBarStyleBlack;
    UIBarButtonItem *done = [[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonItemStylePlain target:self action:@selector(dismissKb)];
    UIBarButtonItem *flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *ap = [[UIBarButtonItem alloc] initWithTitle:@"Apply" style:UIBarButtonItemStyleDone target:self action:@selector(onApplyKb)];
    tb.items = @[done, flex, ap];
    return tb;
}

- (void)dismissKb { [self.panel endEditing:YES]; }
- (void)onApplyKb { [self onApply]; [self.panel endEditing:YES]; }

// Section helper
- (MenuSection*)addSection:(NSString*)title collapsed:(BOOL)collapsed {
    MenuSection *sec = [MenuSection new];
    sec.title = title;
    sec.isCollapsed = collapsed;
    sec.rows = [NSMutableArray array];

    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, PW, HDRH)];
    headerView.backgroundColor = sectionHeaderBgCol();
    headerView.layer.cornerRadius = 6;
    headerView.layer.borderWidth = 0.5;
    headerView.layer.borderColor = [UIColor colorWithWhite:0.25 alpha:1.0].CGColor;
    headerView.userInteractionEnabled = YES;

    UILabel *arrow = [[UILabel alloc] initWithFrame:CGRectMake(10, 0, 20, HDRH)];
    arrow.text = collapsed ? @"▶" : @"▼";
    arrow.textColor = accentOrangeCol();
    arrow.font = [UIFont systemFontOfSize:11];
    arrow.userInteractionEnabled = NO;
    [headerView addSubview:arrow];
    sec.arrowLbl = arrow;

    UILabel *titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(32, 0, PW - 42, HDRH)];
    titleLbl.text = title;
    titleLbl.textColor = [UIColor colorWithWhite:0.95 alpha:1.0];
    titleLbl.font = [UIFont boldSystemFontOfSize:13];
    titleLbl.userInteractionEnabled = NO;
    [headerView addSubview:titleLbl];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onSectionHeaderTap:)];
    tap.cancelsTouchesInView = NO;
    tap.delaysTouchesBegan = NO;
    tap.delaysTouchesEnded = NO;
    [headerView addGestureRecognizer:tap];
    sec.headerBtn = headerView;

    [self.sections addObject:sec];
    [self.scroll addSubview:headerView];
    return sec;
}

- (void)addRow:(UIView*)row toSection:(MenuSection*)sec {
    row.hidden = sec.isCollapsed;
    [sec.rows addObject:row];
    [self.scroll addSubview:row];
}

- (void)onSectionHeaderTap:(UITapGestureRecognizer*)g {
    UIView *header = g.view;
    for (MenuSection *sec in self.sections) {
        if (sec.headerBtn == header) {
            sec.isCollapsed = !sec.isCollapsed;
            sec.arrowLbl.text = sec.isCollapsed ? @"▶" : @"▼";
            for (UIView *r in sec.rows) {
                r.hidden = sec.isCollapsed;
            }
            [self layoutPanel];
            break;
        }
    }
}

// Row builder: Toggle Switch
- (UIView*)toggleRow:(NSString*)label sel:(SEL)sel on:(BOOL)on out:(UISwitch**)out {
    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(0, 0, PW, ROWH)];
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(14, 3, PW - 80, 32)];
    l.text = label;
    l.textColor = [UIColor whiteColor];
    l.font = [UIFont systemFontOfSize:13.5];
    l.adjustsFontSizeToFitWidth = YES;
    l.minimumScaleFactor = 0.8;
    [row addSubview:l];

    UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(PW - 64, 3, 50, 32)];
    sw.on = on;
    sw.onTintColor = accentOrangeCol();
    sw.thumbTintColor = [UIColor whiteColor];
    [sw addTarget:self action:sel forControlEvents:UIControlEventValueChanged];
    [row addSubview:sw];
    if (out) *out = sw;
    return row;
}

// Row builder: Button
- (UIView*)buttonRow:(NSString*)title sel:(SEL)sel {
    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(0, 0, PW, ROWH)];
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.frame = CGRectMake(14, 3, PW - 28, 32);
    btn.backgroundColor = buttonBgCol();
    btn.layer.cornerRadius = 6;
    btn.layer.borderWidth = 1.0;
    btn.layer.borderColor = [UIColor colorWithWhite:0.32 alpha:1.0].CGColor;
    [btn setTitle:title forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    [btn addTarget:self action:sel forControlEvents:UIControlEventTouchUpInside];
    [row addSubview:btn];
    return row;
}

// Row builder: Action Textfield + Buttons
- (UIView*)currencyRow:(NSString*)label placeholder:(NSString*)ph outTf:(UITextField**)outTf plusSel:(SEL)plusSel maxSel:(SEL)maxSel {
    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(0, 0, PW, ROWH)];
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(14, 3, 110, 32)];
    l.text = label;
    l.textColor = [UIColor whiteColor];
    l.font = [UIFont systemFontOfSize:13.0];
    l.adjustsFontSizeToFitWidth = YES;
    l.minimumScaleFactor = 0.8;
    [row addSubview:l];

    CGFloat tfW = 86.0;
    UITextField *tf = [[UITextField alloc] initWithFrame:CGRectMake(126, 3, tfW, 32)];
    tf.borderStyle = UITextBorderStyleNone;
    tf.layer.cornerRadius = 6;
    tf.layer.borderWidth = 1.0;
    tf.layer.borderColor = [UIColor colorWithWhite:0.25 alpha:1.0].CGColor;
    tf.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1.0];
    tf.textColor = [UIColor whiteColor];
    tf.keyboardType = UIKeyboardTypeNumberPad;
    tf.keyboardAppearance = UIKeyboardAppearanceDark;
    tf.font = [UIFont systemFontOfSize:13];
    tf.inputAccessoryView = [self kbBar];

    UIView *padView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 8, 32)];
    tf.leftView = padView;
    tf.leftViewMode = UITextFieldViewModeAlways;
    darkPlaceholder(tf, ph);
    [row addSubview:tf];
    if (outTf) *outTf = tf;

    UIButton *pBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    pBtn.frame = CGRectMake(218, 3, 44, 32);
    pBtn.backgroundColor = buttonBgCol();
    pBtn.layer.cornerRadius = 6;
    pBtn.layer.borderWidth = 1.0;
    pBtn.layer.borderColor = [UIColor colorWithWhite:0.35 alpha:1.0].CGColor;
    [pBtn setTitle:@"+Add" forState:UIControlStateNormal];
    [pBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    pBtn.titleLabel.font = [UIFont boldSystemFontOfSize:11];
    [pBtn addTarget:self action:plusSel forControlEvents:UIControlEventTouchUpInside];
    [row addSubview:pBtn];

    UIButton *mBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    mBtn.frame = CGRectMake(268, 3, 44, 32);
    mBtn.backgroundColor = buttonBgCol();
    mBtn.layer.cornerRadius = 6;
    mBtn.layer.borderWidth = 1.0;
    mBtn.layer.borderColor = [UIColor colorWithWhite:0.35 alpha:1.0].CGColor;
    [mBtn setTitle:@"Max" forState:UIControlStateNormal];
    [mBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    mBtn.titleLabel.font = [UIFont boldSystemFontOfSize:11];
    [mBtn addTarget:self action:maxSel forControlEvents:UIControlEventTouchUpInside];
    [row addSubview:mBtn];

    return row;
}

// Row builder: Slider
- (UIView*)sliderRowWithTitle:(NSString*)title min:(float)min max:(float)max value:(float)val outSlider:(UISlider**)outSlider outLabel:(UILabel**)outLabel sel:(SEL)sel {
    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(0, 0, PW, ROWH + 10)];
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(14, 2, 180, 20)];
    l.text = [NSString stringWithFormat:@"%@: %.1fx", title, val];
    l.textColor = [UIColor whiteColor];
    l.font = [UIFont systemFontOfSize:13];
    [row addSubview:l];
    if (outLabel) *outLabel = l;

    UISlider *sl = [[UISlider alloc] initWithFrame:CGRectMake(14, 22, PW - 28, 24)];
    sl.minimumValue = min;
    sl.maximumValue = max;
    sl.value = val;
    sl.minimumTrackTintColor = accentOrangeCol();
    sl.maximumTrackTintColor = [UIColor colorWithWhite:0.25 alpha:1.0];
    [sl addTarget:self action:sel forControlEvents:UIControlEventValueChanged];
    [row addSubview:sl];
    if (outSlider) *outSlider = sl;

    return row;
}

// Row builder: Custom Mini Button
- (UIButton*)makeMiniButton:(NSString*)title frame:(CGRect)frame sel:(SEL)sel {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.frame = frame;
    btn.backgroundColor = buttonBgCol();
    btn.layer.cornerRadius = 6;
    btn.layer.borderWidth = 1.0;
    btn.layer.borderColor = [UIColor colorWithWhite:0.32 alpha:1.0].CGColor;
    [btn setTitle:title forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont boldSystemFontOfSize:11];
    btn.titleLabel.adjustsFontSizeToFitWidth = YES;
    btn.titleLabel.minimumScaleFactor = 0.75;
    [btn addTarget:self action:sel forControlEvents:UIControlEventTouchUpInside];
    return btn;
}

// Row builder: Two Buttons side-by-side
- (UIView*)twoButtonRow:(NSString*)t1 sel1:(SEL)s1 title2:(NSString*)t2 sel2:(SEL)s2 {
    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(0, 0, PW, ROWH)];
    CGFloat totalW = PW - 28.0;
    CGFloat gap = 8.0;
    CGFloat btnW = (totalW - gap) / 2.0;

    UIButton *b1 = [self makeMiniButton:t1 frame:CGRectMake(14, 3, btnW, 32) sel:s1];
    b1.backgroundColor = [UIColor colorWithRed:0.2 green:0.4 blue:0.25 alpha:1.0];
    b1.layer.borderColor = [UIColor colorWithRed:0.3 green:0.6 blue:0.35 alpha:1.0].CGColor;
    [row addSubview:b1];

    UIButton *b2 = [self makeMiniButton:t2 frame:CGRectMake(14 + btnW + gap, 3, btnW, 32) sel:s2];
    [row addSubview:b2];

    return row;
}

// Row builder: Three Buttons side-by-side
- (UIView*)threeButtonRow:(NSString*)t1 sel1:(SEL)s1 title2:(NSString*)t2 sel2:(SEL)s2 title3:(NSString*)t3 sel3:(SEL)s3 {
    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(0, 0, PW, ROWH)];
    CGFloat totalW = PW - 28.0;
    CGFloat gap = 6.0;
    CGFloat btnW = (totalW - 2 * gap) / 3.0;

    CGFloat x = 14.0;
    UIButton *b1 = [self makeMiniButton:t1 frame:CGRectMake(x, 3, btnW, 32) sel:s1];
    [row addSubview:b1];
    x += btnW + gap;

    UIButton *b2 = [self makeMiniButton:t2 frame:CGRectMake(x, 3, btnW, 32) sel:s2];
    [row addSubview:b2];
    x += btnW + gap;

    UIButton *b3 = [self makeMiniButton:t3 frame:CGRectMake(x, 3, btnW, 32) sel:s3];
    [row addSubview:b3];

    return row;
}

// Row builder: Four Buttons side-by-side
- (UIView*)fourButtonRow:(NSString*)t1 sel1:(SEL)s1 title2:(NSString*)t2 sel2:(SEL)s2 title3:(NSString*)t3 sel3:(SEL)s3 title4:(NSString*)t4 sel4:(SEL)s4 {
    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(0, 0, PW, ROWH)];
    CGFloat totalW = PW - 28.0;
    CGFloat gap = 4.0;
    CGFloat btnW = (totalW - 3 * gap) / 4.0;

    CGFloat x = 14.0;
    UIButton *b1 = [self makeMiniButton:t1 frame:CGRectMake(x, 3, btnW, 32) sel:s1];
    [row addSubview:b1];
    x += btnW + gap;

    UIButton *b2 = [self makeMiniButton:t2 frame:CGRectMake(x, 3, btnW, 32) sel:s2];
    [row addSubview:b2];
    x += btnW + gap;

    UIButton *b3 = [self makeMiniButton:t3 frame:CGRectMake(x, 3, btnW, 32) sel:s3];
    [row addSubview:b3];
    x += btnW + gap;

    UIButton *b4 = [self makeMiniButton:t4 frame:CGRectMake(x, 3, btnW, 32) sel:s4];
    [row addSubview:b4];

    return row;
}

// Row builder: Five Buttons side-by-side
- (UIView*)fiveButtonRow:(NSString*)t1 sel1:(SEL)s1 title2:(NSString*)t2 sel2:(SEL)s2 title3:(NSString*)t3 sel3:(SEL)s3 title4:(NSString*)t4 sel4:(SEL)s4 title5:(NSString*)t5 sel5:(SEL)s5 {
    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(0, 0, PW, ROWH)];
    CGFloat totalW = PW - 28.0;
    CGFloat gap = 3.0;
    CGFloat btnW = (totalW - 4 * gap) / 5.0;

    CGFloat x = 14.0;
    UIButton *b1 = [self makeMiniButton:t1 frame:CGRectMake(x, 3, btnW, 32) sel:s1];
    b1.titleLabel.font = [UIFont boldSystemFontOfSize:10.0];
    [row addSubview:b1];
    x += btnW + gap;

    UIButton *b2 = [self makeMiniButton:t2 frame:CGRectMake(x, 3, btnW, 32) sel:s2];
    b2.titleLabel.font = [UIFont boldSystemFontOfSize:10.0];
    [row addSubview:b2];
    x += btnW + gap;

    UIButton *b3 = [self makeMiniButton:t3 frame:CGRectMake(x, 3, btnW, 32) sel:s3];
    b3.titleLabel.font = [UIFont boldSystemFontOfSize:10.0];
    [row addSubview:b3];
    x += btnW + gap;

    UIButton *b4 = [self makeMiniButton:t4 frame:CGRectMake(x, 3, btnW, 32) sel:s4];
    b4.titleLabel.font = [UIFont boldSystemFontOfSize:10.0];
    [row addSubview:b4];
    x += btnW + gap;

    UIButton *b5 = [self makeMiniButton:t5 frame:CGRectMake(x, 3, btnW, 32) sel:s5];
    b5.titleLabel.font = [UIFont boldSystemFontOfSize:10.0];
    [row addSubview:b5];

    return row;
}

// Row builder: Info Text Label
- (UIView*)infoRow:(NSString*)text {
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(14, 2, PW - 28, 0)];
    l.text = text;
    l.textColor = [UIColor colorWithWhite:0.65 alpha:1.0];
    l.font = [UIFont systemFontOfSize:11.0];
    l.numberOfLines = 0;
    l.lineBreakMode = NSLineBreakByWordWrapping;
    CGSize maxSize = CGSizeMake(PW - 28, CGFLOAT_MAX);
    CGSize textSize = [l sizeThatFits:maxSize];
    CGFloat h = MAX(22.0, textSize.height + 4.0);
    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(0, 0, PW, h)];
    l.frame = CGRectMake(14, 2, PW - 28, textSize.height);
    [row addSubview:l];
    return row;
}

// Row builder: Time Travel Status Card
- (UIView*)timeDisplayRow {
    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(0, 0, PW, ROWH + 16)];

    UIView *card = [[UIView alloc] initWithFrame:CGRectMake(14, 2, PW - 28, ROWH + 12)];
    card.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1.0];
    card.layer.cornerRadius = 6;
    card.layer.borderWidth = 0.5;
    card.layer.borderColor = [UIColor colorWithWhite:0.25 alpha:1.0].CGColor;

    UILabel *l1 = [[UILabel alloc] initWithFrame:CGRectMake(8, 3, card.bounds.size.width - 16, 20)];
    l1.textColor = [UIColor whiteColor];
    l1.font = [UIFont boldSystemFontOfSize:12.5];
    l1.adjustsFontSizeToFitWidth = YES;
    l1.minimumScaleFactor = 0.75;
    l1.text = @"Game Time: Loading...";
    [card addSubview:l1];
    self.gameTimeDisplayLabel = l1;

    UILabel *l2 = [[UILabel alloc] initWithFrame:CGRectMake(8, 24, card.bounds.size.width - 16, 18)];
    l2.textColor = accentOrangeCol();
    l2.font = [UIFont systemFontOfSize:11];
    l2.adjustsFontSizeToFitWidth = YES;
    l2.minimumScaleFactor = 0.75;
    l2.text = @"Offset: None (Real Time)";
    [card addSubview:l2];
    self.offsetDisplayLabel = l2;

    [row addSubview:card];
    return row;
}

// Row builder: Companion Status Card
- (UIView*)companionCardRow {
    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(0, 0, PW, ROWH + 20)];

    UIView *card = [[UIView alloc] initWithFrame:CGRectMake(14, 2, PW - 28, ROWH + 16)];
    card.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1.0];
    card.layer.cornerRadius = 8;
    card.layer.borderWidth = 0.5;
    card.layer.borderColor = [UIColor colorWithWhite:0.25 alpha:1.0].CGColor;
    card.userInteractionEnabled = YES;
    UITapGestureRecognizer *cardTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onOpenVillagerSelector)];
    [card addGestureRecognizer:cardTap];

    self.companionAvatarView = [[UIImageView alloc] initWithFrame:CGRectMake(8, (card.bounds.size.height - 40) / 2.0, 40, 40)];
    self.companionAvatarView.layer.cornerRadius = 20;
    self.companionAvatarView.layer.masksToBounds = YES;
    self.companionAvatarView.layer.borderWidth = 1.0;
    self.companionAvatarView.layer.borderColor = accentOrangeCol().CGColor;
    self.companionAvatarView.contentMode = UIViewContentModeScaleAspectFit;
    NSData *d = [[NSData alloc] initWithBase64EncodedString:kFloatIconBase64 options:0];
    self.companionAvatarView.image = [UIImage imageWithData:d];
    [card addSubview:self.companionAvatarView];

    CGFloat textX = 56;
    CGFloat textW = card.bounds.size.width - textX - 8;

    self.companionNameLabel = [[UILabel alloc] initWithFrame:CGRectMake(textX, 6, textW, 20)];
    self.companionNameLabel.font = [UIFont boldSystemFontOfSize:13];
    self.companionNameLabel.textColor = [UIColor whiteColor];
    self.companionNameLabel.text = @"Active: None (Not Assigned)";
    self.companionNameLabel.adjustsFontSizeToFitWidth = YES;
    self.companionNameLabel.minimumScaleFactor = 0.8;
    [card addSubview:self.companionNameLabel];

    self.companionStatusLabel = [[UILabel alloc] initWithFrame:CGRectMake(textX, 28, textW, 18)];
    self.companionStatusLabel.font = [UIFont systemFontOfSize:10.5];
    self.companionStatusLabel.textColor = accentOrangeCol();
    self.companionStatusLabel.text = @"Mode: Roaming AI | Furniture: Bypassed";
    self.companionStatusLabel.adjustsFontSizeToFitWidth = YES;
    self.companionStatusLabel.minimumScaleFactor = 0.8;
    [card addSubview:self.companionStatusLabel];

    [row addSubview:card];
    return row;
}

// Row builder: Compact Date & Time Picker
- (UIView*)datePickerRow {
    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(0, 0, PW, ROWH + 4)];
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(14, 4, 80, 32)];
    l.text = @"Date/Time:";
    l.textColor = [UIColor whiteColor];
    l.font = [UIFont systemFontOfSize:13.0];
    [row addSubview:l];

    UIDatePicker *dp = [[UIDatePicker alloc] initWithFrame:CGRectMake(98, 4, PW - 98 - 16, 32)];
    dp.datePickerMode = UIDatePickerModeDateAndTime;
    if (@available(iOS 14.0, *)) {
        dp.preferredDatePickerStyle = UIDatePickerStyleCompact;
    }
    dp.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    int64_t cur = hook_UtcTime_get_Now(NULL);
    dp.date = [NSDate dateWithTimeIntervalSince1970:cur];
    [dp addTarget:self action:@selector(onDatePickerValueChanged:) forControlEvents:UIControlEventValueChanged];
    [row addSubview:dp];
    self.datePicker = dp;
    return row;
}

// Build Main Menu Panel
- (void)buildPanel:(UIView*)parentView {
    self.panel = [[UIView alloc] initWithFrame:CGRectMake(0, 0, PW, 300)];
    self.panel.backgroundColor = bgCol();
    self.panel.layer.cornerRadius = 14;
    self.panel.layer.borderWidth = 1.5;
    self.panel.layer.borderColor = borderCol().CGColor;
    self.panel.hidden = YES;
    [parentView addSubview:self.panel];

    // Header Title
    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(14, 8, PW - 130, 30)];
#ifdef LITE_MODE
    self.titleLabel.text = @"Redds Tools v1.5.0 (Lite)";
#else
    self.titleLabel.text = @"Redds Tools v1.5.0";
#endif
    self.titleLabel.textColor = [UIColor whiteColor];
    self.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    self.titleLabel.userInteractionEnabled = YES;
    [self.titleLabel addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(onPanelDrag:)]];
    [self.panel addSubview:self.titleLabel];

    // Apply Button
    self.applyBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.applyBtn.backgroundColor = accentOrangeCol();
    self.applyBtn.layer.cornerRadius = 6;
    self.applyBtn.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    [self.applyBtn setTitle:@"Apply" forState:UIControlStateNormal];
    [self.applyBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.applyBtn addTarget:self action:@selector(onApply) forControlEvents:UIControlEventTouchUpInside];
    [self.panel addSubview:self.applyBtn];

    // Close Button
    self.closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.closeBtn setTitle:@"X" forState:UIControlStateNormal];
    self.closeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    [self.closeBtn setTitleColor:[UIColor colorWithWhite:0.85 alpha:1.0] forState:UIControlStateNormal];
    [self.closeBtn addTarget:self action:@selector(onTap) forControlEvents:UIControlEventTouchUpInside];
    [self.panel addSubview:self.closeBtn];

    // Scrollable Content with Header Touch Cancellation
    self.scroll = [[ReddsScrollView alloc] initWithFrame:CGRectMake(0, HEADERBAR, PW, 200)];
    self.scroll.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    self.scroll.canCancelContentTouches = YES;
    self.scroll.delaysContentTouches = YES;
    [self.panel addSubview:self.scroll];

    // 1. CURRENCIES
    MenuSection *secCurr = [self addSection:@"CURRENCIES" collapsed:YES];
    UITextField *bTf = nil, *ltTf = nil, *ctTf = nil;
    UIView *bRow = [self currencyRow:@"Bells" placeholder:@"e.g. 9999999" outTf:&bTf plusSel:@selector(onAddBells1M) maxSel:@selector(onMaxBells)];
    self.bellsField = bTf;
    [self addRow:bRow toSection:secCurr];

    UIView *ltRow = [self currencyRow:@"Leaf Tokens" placeholder:@"e.g. 99999" outTf:&ltTf plusSel:@selector(onAddLeafTokens1K) maxSel:@selector(onMaxLeafTokens)];
    self.leafTokensField = ltTf;
    [self addRow:ltRow toSection:secCurr];

    UIView *ctRow = [self currencyRow:@"Complete Tickets" placeholder:@"e.g. 9999" outTf:&ctTf plusSel:@selector(onAddCompleteTickets100) maxSel:@selector(onMaxCompleteTickets)];
    self.completeTicketsField = ctTf;
    [self addRow:ctRow toSection:secCurr];

    UISwitch *curFreezeSw = nil;
    UIView *curFreezeRow = [self toggleRow:@"Currency Freeze" sel:@selector(onCurrencyFreeze:) on:getSavedBool(@"Pref_CurrencyFreeze", false) out:&curFreezeSw];
    self.currencyFreezeSwitch = curFreezeSw;
    [self addRow:curFreezeRow toSection:secCurr];

    [self addRow:[self buttonRow:@"Max All Crafting Materials (x9999)" sel:@selector(onMaxMaterials)] toSection:secCurr];

#ifndef LITE_MODE
    // 2. FORTUNE COOKIES
    MenuSection *secCookies = [self addSection:@"FORTUNE COOKIES" collapsed:YES];
    UISwitch *cookieShopSw = nil;
    UIView *cookieShopRow = [self toggleRow:@"Unlock Crossover Cookies (Shop)"
                                        sel:@selector(onToggleCrossoverCookies:)
                                         on:getSavedBool(@"Pref_CrossoverCookies", false)
                                        out:&cookieShopSw];
    self.crossoverCookiesSwitch = cookieShopSw;
    [self addRow:cookieShopRow toSection:secCookies];
    [self addRow:[self infoRow:@"Unlocks Sanrio & Splatoon cookies in the Fortune Cookie Shop."] toSection:secCookies];

    // 3. EXCLUSIVE SHOPS & CROSSOVERS
    MenuSection *secCatalog = [self addSection:@"EXCLUSIVE SHOPS & CROSSOVERS" collapsed:YES];
    UISwitch *fullCatSw = nil;
    UIView *fullCatRow = [self toggleRow:@"Unlock Full Catalog"
                                     sel:@selector(onToggleFullCatalog:)
                                      on:(getSavedBool(@"Pref_FullCatalog", false) || getSavedBool(@"Pref_CrossoverCatalog", false) || getSavedBool(@"Pref_SeasonalItems", false))
                                     out:&fullCatSw];
    self.fullCatalogSwitch = fullCatSw;
    [self addRow:fullCatRow toSection:secCatalog];
    [self addRow:[self infoRow:@"Unlocks all crossovers & Complete Ticket items."] toSection:secCatalog];

    // 4. HAPPY HOMEROOM
    MenuSection *secHH = [self addSection:@"HAPPY HOMEROOM" collapsed:YES];
    UISwitch *hhTicketsSw = nil;
    UIView *hhTicketsRow = [self toggleRow:@"Infinite Tickets & Free Vouchers"
                                       sel:@selector(onToggleHHInfiniteTickets:)
                                        on:getSavedBool(@"Pref_HHInfiniteTickets", false)
                                       out:&hhTicketsSw];
    self.hhInfiniteTicketsSwitch = hhTicketsSw;
    [self addRow:hhTicketsRow toSection:secHH];

    UISwitch *hhAutoPassSw = nil;
    UIView *hhAutoPassRow = [self toggleRow:@"Auto-Pass 3 Medals (Instant Win)"
                                        sel:@selector(onToggleHHAutoPass:)
                                         on:getSavedBool(@"Pref_HHAutoPass", false)
                                        out:&hhAutoPassSw];
    self.hhAutoPassSwitch = hhAutoPassSw;
    [self addRow:hhAutoPassRow toSection:secHH];

    UISwitch *hhFlawlessSw = nil;
    UIView *hhFlawlessRow = [self toggleRow:@"Universal Furniture (Flawless)"
                                        sel:@selector(onToggleHHUniversalFlawless:)
                                         on:getSavedBool(@"Pref_HHUniversalFlawless", false)
                                        out:&hhFlawlessSw];
    self.hhUniversalFlawlessSwitch = hhFlawlessSw;
    [self addRow:hhFlawlessRow toSection:secHH];
#endif

    // 5. CAMP CARETAKER
    MenuSection *secCompanion = [self addSection:@"CAMP CARETAKER" collapsed:YES];
    [self addRow:[self companionCardRow] toSection:secCompanion];

    UIView *browseRow = [self buttonRow:@"Browse All Characters..." sel:@selector(onOpenVillagerSelector)];
    UIButton *browseBtn = (UIButton*)[browseRow.subviews firstObject];
    browseBtn.backgroundColor = [UIColor colorWithRed:0.18 green:0.55 blue:0.24 alpha:1.0]; // Wide Green Button
    browseBtn.layer.borderColor = [UIColor colorWithRed:0.28 green:0.75 blue:0.35 alpha:1.0].CGColor;
    browseBtn.layer.borderWidth = 1.0;
    [self addRow:browseRow toSection:secCompanion];

    // 8 quick buttons:
    // Row 1: Isabelle, Labelle, Harriet, Reese
    [self addRow:[self fourButtonRow:@"Isabelle" sel1:@selector(onQuickIsabelle)
                              title2:@"Labelle" sel2:@selector(onQuickLabelle)
                              title3:@"Harriet" sel3:@selector(onQuickHarriet)
                              title4:@"Reese" sel4:@selector(onQuickReese)] toSection:secCompanion];

    // Row 2: Tom Nook, Brewster, Blathers, DJ KK, KK
    [self addRow:[self fiveButtonRow:@"Tom Nook" sel1:@selector(onQuickTomNook)
                              title2:@"Brewster" sel2:@selector(onQuickBrewster)
                              title3:@"Blathers" sel3:@selector(onQuickBlathers)
                              title4:@"DJ KK" sel4:@selector(onQuickDJKK)
                              title5:@"KK" sel5:@selector(onQuickKK)] toSection:secCompanion];

#ifndef LITE_MODE
    UISwitch *bypassSw = nil;
    UIView *bypassRow = [self toggleRow:@"Bypass Furniture Requirement" sel:@selector(onToggleBypassFurniture:) on:getSavedBool(@"Pref_BypassFurniture", false) out:&bypassSw];
    self.bypassFurnitureSwitch = bypassSw;
    [self addRow:bypassRow toSection:secCompanion];
#endif

    UISwitch *walkSw = nil;
    UIView *walkRow = [self toggleRow:@"Overworld Roaming Walk" sel:@selector(onToggleCompanionWalk:) on:getSavedBool(@"Pref_CompanionWalk", false) out:&walkSw];
    self.companionWalkSwitch = walkSw;
    [self addRow:walkRow toSection:secCompanion];

#ifndef LITE_MODE
    // 6. CREATURES
    MenuSection *secCreatures = [self addSection:@"CREATURES" collapsed:YES];
    UISwitch *catchSw = nil;
    UIView *catchRow = [self toggleRow:@"100% Catch Rate" sel:@selector(onRareCatchRate:) on:getSavedBool(@"Pref_RareCatch100", false) out:&catchSw];
    self.rareCatchRateSwitch = catchSw;
    [self addRow:catchRow toSection:secCreatures];

    UISwitch *bugSw = nil;
    UIView *bugRow = [self toggleRow:@"Never-flee insects" sel:@selector(onNeverFleeInsects:) on:getSavedBool(@"Pref_NeverFleeInsects", false) out:&bugSw];
    self.neverFleeInsectsSwitch = bugSw;
    [self addRow:bugRow toSection:secCreatures];

    UISwitch *fishBiteSw = nil;
    UIView *fishBiteRow = [self toggleRow:@"Auto-bite" sel:@selector(onFishBite:) on:getSavedBool(@"Pref_FishBite", false) out:&fishBiteSw];
    self.fishBiteSwitch = fishBiteSw;
    [self addRow:fishBiteRow toSection:secCreatures];

    // 7. QUARRY
    MenuSection *secQuarry = [self addSection:@"QUARRY" collapsed:YES];
    UISwitch *qSw = nil;
    UIView *qRow = [self toggleRow:@"Unlimited Daily Entries" sel:@selector(onUnlimitedQuarry:) on:getSavedBool(@"Pref_UnlimitedQuarry", true) out:&qSw];
    self.unlimitedQuarrySwitch = qSw;
    [self addRow:qRow toSection:secQuarry];

    // 8. TIME TRAVEL
    MenuSection *secTime = [self addSection:@"TIME TRAVEL" collapsed:YES];
    [self addRow:[self timeDisplayRow] toSection:secTime];

    UISwitch *ttMasterSw = nil;
    UIView *ttMasterRow = [self toggleRow:@"Master Enable: Time Travel" sel:@selector(onToggleTimeTravel:) on:g_timeTravelActive out:&ttMasterSw];
    self.timeTravelMasterSwitch = ttMasterSw;
    [self addRow:ttMasterRow toSection:secTime];

    UISwitch *ttFreezeSw = nil;
    UIView *ttFreezeRow = [self toggleRow:@"Freeze Game Clock" sel:@selector(onToggleTimeFreeze:) on:g_timeFreezeActive out:&ttFreezeSw];
    self.timeFreezeSwitch = ttFreezeSw;
    [self addRow:ttFreezeRow toSection:secTime];

    [self addRow:[self datePickerRow] toSection:secTime];
    [self addRow:[self twoButtonRow:@"Apply Selected Date" sel1:@selector(onApplyDatePicker)
                             title2:@"Seasonal Presets" sel2:@selector(onSeasonalPresetsAction)] toSection:secTime];

    [self addRow:[self threeButtonRow:@"+3h (Villagers)" sel1:@selector(onQuickJumpPlus3H)
                               title2:@"+12h (Quarry)" sel2:@selector(onQuickJumpPlus12H)
                               title3:@"+24h (Daily)" sel3:@selector(onQuickJumpPlus24H)] toSection:secTime];

    [self addRow:[self threeButtonRow:@"-3h (Undo)" sel1:@selector(onQuickJumpMinus3H)
                               title2:@"-24h (Back)" sel2:@selector(onQuickJumpMinus24H)
                               title3:@"Reset Real Time" sel3:@selector(onResetRealTime)] toSection:secTime];
#endif

    // 9. SPEEDHACK
    MenuSection *secSpeed = [self addSection:@"SPEEDHACK" collapsed:YES];
    UISlider *sl = nil;
    UILabel *sLbl = nil;
    float currentSpeed = getSavedFloat(@"Pref_Speedhack", 1.0f);
    UIView *slRow = [self sliderRowWithTitle:@"Speed Multiplier" min:1.0f max:10.0f value:currentSpeed outSlider:&sl outLabel:&sLbl sel:@selector(onSpeedSliderChanged:)];
    self.speedSlider = sl;
    self.speedLabel = sLbl;
    [self addRow:slRow toSection:secSpeed];
    [self addRow:[self buttonRow:@"Reset Speed (1.0x)" sel:@selector(onResetSpeed)] toSection:secSpeed];

    // Status Label at bottom
    self.status = [[UILabel alloc] initWithFrame:CGRectMake(14, 0, PW - 28, STATUSH)];
    self.status.textColor = [UIColor colorWithWhite:0.8 alpha:1.0];
    self.status.font = [UIFont systemFontOfSize:11.5];
    self.status.numberOfLines = 2;
#ifdef LITE_MODE
    self.status.text = @"Lite Mode (Direct Injection)\nMade by PHUROR using Trepan";
#else
    self.status.text = @"Made by PHUROR using Trepan";
#endif
    [self.panel addSubview:self.status];

    [self layoutPanel];
}

// Build Settings Menu (Long-Press Launcher)
- (void)buildSettingsPanel:(UIView*)parentView {
    self.settingsPanel = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 310, 240)];
    self.settingsPanel.backgroundColor = bgCol();
    self.settingsPanel.layer.cornerRadius = 14;
    self.settingsPanel.layer.borderWidth = 1.5;
    self.settingsPanel.layer.borderColor = borderCol().CGColor;
    self.settingsPanel.hidden = YES;
    [parentView addSubview:self.settingsPanel];

    UILabel *t = [[UILabel alloc] initWithFrame:CGRectMake(14, 8, 230, 30)];
    t.text = @"SETTINGS";
    t.textColor = [UIColor whiteColor];
    t.font = [UIFont boldSystemFontOfSize:15];
    [self.settingsPanel addSubview:t];

    UIButton *cl = [UIButton buttonWithType:UIButtonTypeCustom];
    cl.frame = CGRectMake(310 - 38, 7, 30, 30);
    [cl setTitle:@"X" forState:UIControlStateNormal];
    cl.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    [cl setTitleColor:[UIColor colorWithWhite:0.85 alpha:1.0] forState:UIControlStateNormal];
    [cl addTarget:self action:@selector(onSettingsClose) forControlEvents:UIControlEventTouchUpInside];
    [self.settingsPanel addSubview:cl];

    CGFloat curY = 48.0;

    // 1. RESET COMPANION (red button)
    UIButton *resetBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    resetBtn.frame = CGRectMake(14, curY, 282, 36);
    resetBtn.backgroundColor = [UIColor colorWithRed:0.75 green:0.2 blue:0.15 alpha:1.0];
    resetBtn.layer.cornerRadius = 8;
    resetBtn.layer.borderWidth = 1.0;
    resetBtn.layer.borderColor = [UIColor colorWithRed:0.95 green:0.35 blue:0.25 alpha:1.0].CGColor;
    [resetBtn setTitle:@"RESET COMPANION" forState:UIControlStateNormal];
    [resetBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    resetBtn.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    [resetBtn addTarget:self action:@selector(onEmergencySafeBob) forControlEvents:UIControlEventTouchUpInside];
    [self.settingsPanel addSubview:resetBtn];
    curY += 44.0;

    // 2. FPS & Performance HUD (Toggle)
    UIView *hudRow = [[UIView alloc] initWithFrame:CGRectMake(14, curY, 282, 34)];
    UILabel *hudLbl = [[UILabel alloc] initWithFrame:CGRectMake(0, 2, 200, 30)];
    hudLbl.text = @"FPS & Performance HUD";
    hudLbl.textColor = [UIColor whiteColor];
    hudLbl.font = [UIFont systemFontOfSize:13.0];
    [hudRow addSubview:hudLbl];

    UISwitch *hudSw = [[UISwitch alloc] initWithFrame:CGRectZero];
    hudSw.frame = CGRectMake(282 - 51, 1, 51, 31);
    hudSw.onTintColor = accentOrangeCol();
    hudSw.on = getSavedBool(@"Pref_FpsHud", false);
    [hudSw addTarget:self action:@selector(onToggleFpsHud:) forControlEvents:UIControlEventValueChanged];
    [hudRow addSubview:hudSw];
    self.urpDebuggerSwitch = hudSw;
    [self.settingsPanel addSubview:hudRow];
    curY += 42.0;

    // 3. Debug Screen (button that opens debug screen)
    UIButton *debugBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    debugBtn.frame = CGRectMake(14, curY, 282, 34);
    debugBtn.backgroundColor = buttonBgCol();
    debugBtn.layer.cornerRadius = 8;
    debugBtn.layer.borderWidth = 1.0;
    debugBtn.layer.borderColor = [UIColor colorWithWhite:0.32 alpha:1.0].CGColor;
    [debugBtn setTitle:@"Debug Screen" forState:UIControlStateNormal];
    [debugBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    debugBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12.5];
    [debugBtn addTarget:self action:@selector(onOpenDebugScreen) forControlEvents:UIControlEventTouchUpInside];
    [self.settingsPanel addSubview:debugBtn];
    curY += 44.0;

    // Bottom Credit: "Made by PHUROR using Trepan"
    UILabel *creditLbl = [[UILabel alloc] initWithFrame:CGRectMake(14, curY, 282, 22)];
    creditLbl.text = @"Made by PHUROR using Trepan";
    creditLbl.textColor = accentOrangeCol();
    creditLbl.font = [UIFont boldSystemFontOfSize:11];
    creditLbl.textAlignment = NSTextAlignmentCenter;
    [self.settingsPanel addSubview:creditLbl];

    self.settingsPanel.frame = CGRectMake(0, 0, 310, curY + 28.0);
}

// Build Debug Screen
- (void)buildDebugPanel:(UIView*)parentView {
    self.debugPanel = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 310, 340)];
    self.debugPanel.backgroundColor = bgCol();
    self.debugPanel.layer.cornerRadius = 14;
    self.debugPanel.layer.borderWidth = 1.5;
    self.debugPanel.layer.borderColor = borderCol().CGColor;
    self.debugPanel.hidden = YES;
    [parentView addSubview:self.debugPanel];

    UILabel *t = [[UILabel alloc] initWithFrame:CGRectMake(14, 8, 230, 30)];
    t.text = @"DEBUG SCREEN";
    t.textColor = [UIColor whiteColor];
    t.font = [UIFont boldSystemFontOfSize:15];
    [self.debugPanel addSubview:t];

    UIButton *cl = [UIButton buttonWithType:UIButtonTypeCustom];
    cl.frame = CGRectMake(310 - 38, 7, 30, 30);
    [cl setTitle:@"X" forState:UIControlStateNormal];
    cl.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    [cl setTitleColor:[UIColor colorWithWhite:0.85 alpha:1.0] forState:UIControlStateNormal];
    [cl addTarget:self action:@selector(onDebugClose) forControlEvents:UIControlEventTouchUpInside];
    [self.debugPanel addSubview:cl];

    self.diagnosticsLabel = [[UILabel alloc] initWithFrame:CGRectMake(14, 44, 282, 140)];
    self.diagnosticsLabel.textColor = [UIColor colorWithWhite:0.85 alpha:1.0];
    self.diagnosticsLabel.font = [UIFont fontWithName:@"Menlo" size:9.5] ?: [UIFont systemFontOfSize:9.5];
    self.diagnosticsLabel.numberOfLines = 0;
    self.diagnosticsLabel.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1.0];
    self.diagnosticsLabel.layer.cornerRadius = 6;
    self.diagnosticsLabel.layer.masksToBounds = YES;
    [self.debugPanel addSubview:self.diagnosticsLabel];

    UIButton *rescanBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    rescanBtn.frame = CGRectMake(14, 192, 282, 34);
    rescanBtn.backgroundColor = buttonBgCol();
    rescanBtn.layer.cornerRadius = 6;
    rescanBtn.layer.borderWidth = 1.0;
    rescanBtn.layer.borderColor = [UIColor colorWithWhite:0.32 alpha:1.0].CGColor;
    [rescanBtn setTitle:@"Rescan In-Memory State" forState:UIControlStateNormal];
    [rescanBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    rescanBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    [rescanBtn addTarget:self action:@selector(onRescanState) forControlEvents:UIControlEventTouchUpInside];
    [self.debugPanel addSubview:rescanBtn];

    UILabel *noteLbl = [[UILabel alloc] initWithFrame:CGRectMake(14, 232, 282, 54)];
    noteLbl.text = @"Target: ACPCC Complete (v7.1.4 Build 270)\nStrategy B: Special NPC Companion Bypass\nCheating.SendTrap: Neutralized (Zero Risk)\nFPS HUD: Realtime framerate & memory tracker";
    noteLbl.textColor = [UIColor colorWithWhite:0.55 alpha:1.0];
    noteLbl.font = [UIFont systemFontOfSize:10.0];
    noteLbl.numberOfLines = 4;
    noteLbl.textAlignment = NSTextAlignmentCenter;
    [self.debugPanel addSubview:noteLbl];

    UILabel *creditLbl = [[UILabel alloc] initWithFrame:CGRectMake(14, 294, 282, 24)];
    creditLbl.text = @"Made by PHUROR using Trepan";
    creditLbl.textColor = accentOrangeCol();
    creditLbl.font = [UIFont boldSystemFontOfSize:11];
    creditLbl.textAlignment = NSTextAlignmentCenter;
    [self.debugPanel addSubview:creditLbl];
}

- (void)onOpenDebugScreen {
    UIView *parent = self.debugPanel.superview ?: (self.overlayWindow.rootViewController.view ?: keyWindow());
    self.debugPanel.center = CGPointMake(parent.bounds.size.width / 2.0, parent.bounds.size.height / 2.0);
    self.debugPanel.hidden = NO;
    [self updateIconOpacity];
    [self refreshDiagnostics];
}

- (void)onDebugClose {
    self.debugPanel.hidden = YES;
    [self updateIconOpacity];
}

- (void)onLongPress:(UILongPressGestureRecognizer*)g {
    if (g.state != UIGestureRecognizerStateBegan) return;
    UIView *parent = self.settingsPanel.superview ?: (self.overlayWindow.rootViewController.view ?: keyWindow());
    self.settingsPanel.center = CGPointMake(parent.bounds.size.width / 2.0, parent.bounds.size.height / 2.0);
    self.settingsPanel.hidden = NO;
    if (self.urpDebuggerSwitch) {
        self.urpDebuggerSwitch.on = (self.fpsHud && !self.fpsHud.hidden) || getSavedBool(@"Pref_FpsHud", false);
    }
    [self updateIconOpacity];
}

- (void)onSettingsClose {
    self.settingsPanel.hidden = YES;
    [self updateIconOpacity];
}

- (void)onRescanState {
    sLiveUserProfile = 0;
    sCachedAssistantManager = 0;
    findUserProfile();
    findAssistantManager();
    [self refreshDiagnostics];
}

- (void)refreshDiagnostics {
    uintptr_t base = getUnityBase();
    uintptr_t prof = findUserProfile();
    void *mgr = findAssistantManager();
    int64_t b = readBells();
    int64_t lt = readLeafTokens();
    int32_t ct = readCompleteTickets();
    bool urpActive = self.fpsHud && !self.fpsHud.hidden;
    int64_t curSecs = hook_UtcTime_get_Now(NULL);
    int64_t realSecs = (int64_t)time(NULL);
    NSString *curComp = getCurrentCompanionId() ?: @"None";

    self.diagnosticsLabel.text = [NSString stringWithFormat:
        @" UnityBase: %p\n"
        @" UserProfile: %p\n"
        @" AssistantManager: %p\n"
        @" Active Bells: %lld | Tokens: %lld | Tickets: %d\n"
        @" Companion: %s (FurnBypass: %s)\n"
        @" Time Travel: %s (Offset: %llds)\n"
        @" Game Time: %lld | Real: %lld\n"
        @" Campsite: %s | FPS HUD: %s",
        (void*)base, (void*)prof, mgr, b, lt, ct,
        [curComp UTF8String], gUnlockAllAssistantsOn ? "Active" : "Off",
        g_timeTravelActive ? (g_timeFreezeActive ? "Frozen" : "Active") : "Disabled",
        g_timeOffsetSeconds,
        curSecs, realSecs,
        gForceCampsiteNpcOn ? "Active" : "Off",
        urpActive ? "Active" : "Off"];
}

- (void)layoutPanel {
    UIView *parent = self.panel.superview ?: (self.overlayWindow.rootViewController.view ?: keyWindow());
    if (!parent) return;
    CGFloat W = parent.bounds.size.width, SH = parent.bounds.size.height;
    CGFloat H = MIN(SH - 2 * PANEL_MARGIN, 560.0);
    self.panel.frame = CGRectMake(0, 0, PW, H);
    self.panel.center = CGPointMake(W / 2.0, SH / 2.0);
    self.closeBtn.frame = CGRectMake(PW - 38, 7, 30, 30);
    self.applyBtn.frame = CGRectMake(PW - 38 - 6 - 60, 7, 60, 30);
    self.titleLabel.frame = CGRectMake(14, 7, PW - 38 - 6 - 60 - 20, 30);
    self.scroll.frame = CGRectMake(0, HEADERBAR, PW, H - HEADERBAR - STATUSH);
    self.status.frame = CGRectMake(14, H - STATUSH, PW - 28, STATUSH);

    CGFloat y = 4;
    for (UIView *v in self.scroll.subviews) {
        if (v.hidden) continue;
        CGRect f = v.frame;
        f.origin.y = y;
        f.size.width = PW;
        v.frame = f;
        y += f.size.height + 2;
    }
    self.scroll.contentSize = CGSizeMake(PW, y + 16);
}

- (void)refresh {
    int64_t b = readBells();
    int64_t lt = readLeafTokens();
    int32_t ct = readCompleteTickets();
    if (self.bellsField && !self.bellsField.isEditing) {
        darkPlaceholder(self.bellsField, (b >= 0) ? [NSString stringWithFormat:@"%lld", b] : @"—");
    }
    if (self.leafTokensField && !self.leafTokensField.isEditing) {
        darkPlaceholder(self.leafTokensField, (lt >= 0) ? [NSString stringWithFormat:@"%lld", lt] : @"—");
    }
    if (self.completeTicketsField && !self.completeTicketsField.isEditing) {
        darkPlaceholder(self.completeTicketsField, (ct >= 0) ? [NSString stringWithFormat:@"%d", ct] : @"—");
    }
    if (self.urpDebuggerSwitch) {
        self.urpDebuggerSwitch.on = (self.fpsHud && !self.fpsHud.hidden) || getSavedBool(@"Pref_FpsHud", false);
    }
    if (self.timeTravelMasterSwitch) {
        self.timeTravelMasterSwitch.on = g_timeTravelActive;
    }
    if (self.timeFreezeSwitch) {
        self.timeFreezeSwitch.on = g_timeFreezeActive;
    }
    if (self.datePicker) {
        int64_t cur = hook_UtcTime_get_Now(NULL);
        self.datePicker.date = [NSDate dateWithTimeIntervalSince1970:cur];
    }
    if (self.bypassFurnitureSwitch) {
        self.bypassFurnitureSwitch.on = gUnlockAllAssistantsOn;
    }
    if (self.crossoverCookiesSwitch) {
        self.crossoverCookiesSwitch.on = getSavedBool(@"Pref_CrossoverCookies", false);
    }
    if (self.fullCatalogSwitch) {
        self.fullCatalogSwitch.on = (getSavedBool(@"Pref_FullCatalog", false) || getSavedBool(@"Pref_CrossoverCatalog", false) || getSavedBool(@"Pref_SeasonalItems", false));
    }
    if (self.hhInfiniteTicketsSwitch) {
        self.hhInfiniteTicketsSwitch.on = getSavedBool(@"Pref_HHInfiniteTickets", false);
    }
    if (self.hhAutoPassSwitch) {
        self.hhAutoPassSwitch.on = getSavedBool(@"Pref_HHAutoPass", false);
    }
    if (self.hhUniversalFlawlessSwitch) {
        self.hhUniversalFlawlessSwitch.on = getSavedBool(@"Pref_HHUniversalFlawless", false);
    }
    [self updateTimeDisplay];
    [self refreshCompanionUI];
}

// Actions: Apply
- (void)onApply {
    [self.panel endEditing:YES];
    int applied = 0;
    if (self.bellsField.text.length > 0) {
        int64_t v = (int64_t)self.bellsField.text.longLongValue;
        if (v >= 0 && writeBells(v)) applied++;
        self.bellsField.text = @"";
    }
    if (self.leafTokensField.text.length > 0) {
        int64_t v = (int64_t)self.leafTokensField.text.longLongValue;
        if (v >= 0 && writeLeafTokens(v)) applied++;
        self.leafTokensField.text = @"";
    }
    if (self.completeTicketsField.text.length > 0) {
        int64_t v = (int64_t)self.completeTicketsField.text.longLongValue;
        if (v >= 0 && writeCompleteTickets((int32_t)v)) applied++;
        self.completeTicketsField.text = @"";
    }
    [self refresh];
    int64_t bNow = readBells();
    int64_t ltNow = readLeafTokens();
    int32_t ctNow = readCompleteTickets();
    self.status.text = [NSString stringWithFormat:@"Applied! Bells: %lld | Tokens: %lld | Tickets: %d", bNow, ltNow, ctNow];
}

// Currencies Quick Actions
- (void)onAddBells1M {
    int64_t cur = readBells();
    if (cur < 0) cur = 0;
    int64_t target = MIN(cur + 1000000LL, 9999999LL);
    writeBells(target);
    [self refresh];
    self.status.text = [NSString stringWithFormat:@"+1,000,000 Bells added! Total: %lld", target];
}

- (void)onMaxBells {
    writeBells(9999999LL);
    [self refresh];
    self.status.text = @"Bells set to maximum (9,999,999)!";
}

- (void)onAddLeafTokens1K {
    int64_t cur = readLeafTokens();
    if (cur < 0) cur = 0;
    int64_t target = MIN(cur + 1000LL, 99999LL);
    writeLeafTokens(target);
    [self refresh];
    self.status.text = [NSString stringWithFormat:@"+1,000 Leaf Tokens added! Total: %lld", target];
}

- (void)onMaxLeafTokens {
    writeLeafTokens(99999LL);
    [self refresh];
    self.status.text = @"Leaf Tokens set to maximum (99,999)!";
}

- (void)onAddCompleteTickets100 {
    int32_t cur = readCompleteTickets();
    if (cur < 0) cur = 0;
    int32_t target = MIN(cur + 100, 9999);
    writeCompleteTickets(target);
    [self refresh];
    self.status.text = [NSString stringWithFormat:@"+100 Complete Tickets added! Total: %d", target];
}

- (void)onMaxCompleteTickets {
    writeCompleteTickets(9999);
    [self refresh];
    self.status.text = @"Complete Tickets set to maximum (9,999)!";
}

- (void)onMaxMaterials {
    int updated = maxAllMaterials(9999);
    if (updated > 0) {
        self.status.text = [NSString stringWithFormat:@"Maxed %d Crafting Material slots to 9,999!", updated];
    } else {
        self.status.text = @"No materials in active inventory memory yet (enter campsite first).";
    }
}

- (void)onCurrencyFreeze:(UISwitch*)sw {
    saveBool(@"Pref_CurrencyFreeze", sw.isOn);
    if (sw.isOn) {
        self.frozenBells = readBells();
        self.frozenTokens = readLeafTokens();
        self.frozenTickets = readCompleteTickets();
        if (!self.freezeTimer) {
            self.freezeTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(freezeTick) userInfo:nil repeats:YES];
        }
        self.status.text = @"Currency Freeze ON — balances locked.";
    } else {
        [self.freezeTimer invalidate];
        self.freezeTimer = nil;
        self.frozenBells = -1;
        self.frozenTokens = -1;
        self.frozenTickets = -1;
        self.status.text = @"Currency Freeze OFF.";
    }
}

- (void)freezeTick {
    if (!self.currencyFreezeSwitch.isOn) return;
    if (self.frozenBells >= 0) writeBells(self.frozenBells);
    if (self.frozenTokens >= 0) writeLeafTokens(self.frozenTokens);
    if (self.frozenTickets >= 0) writeCompleteTickets((int32_t)self.frozenTickets);
}

// ============================ Fortune Cookies Handlers ============================

- (void)onToggleCrossoverCookies:(UISwitch*)sw {
    saveBool(@"Pref_CrossoverCookies", sw.isOn);
    bool ok1 = applyGate(&gGateCookieCampaignCheck, sw.isOn);
    bool ok2 = applyGate(&gGateCookieReleaseCheck, sw.isOn);
    bool ok3 = applyGate(&gGateCookiePresenterCheck, sw.isOn);
    bool ok4 = applyGate(&gGateCookieCacheBypass, sw.isOn);
    bool ok5 = applyGate(&gGateCookiePresenterEnableData, sw.isOn);
    bool ok6 = applyGate(&gGateCookiePresenterCampaignId, sw.isOn);
    bool ok7 = applyGate(&gGateCookiePresenterReleaseId, sw.isOn);
    self.status.text = (ok1 && ok2 && ok3 && ok4 && ok5 && ok6 && ok7) ?
        (sw.isOn ? @"Crossover Cookies in Shop: ON" : @"Crossover Cookies in Shop: OFF") :
        @"Cookie shop patch applied.";
}

// ============================ Exclusive Shops & Crossovers Handlers ============================

- (void)onToggleFullCatalog:(UISwitch*)sw {
    saveBool(@"Pref_FullCatalog", sw.isOn);
    applyCatalogGates(sw.isOn);
    self.status.text = sw.isOn ? @"Full Catalog: ON" : @"Full Catalog: OFF";
}

// ============================ Happy Homeroom Handlers ============================

- (void)onToggleHHInfiniteTickets:(UISwitch*)sw {
    saveBool(@"Pref_HHInfiniteTickets", sw.isOn);
    bool ok1 = applyGate(&gGateHHStamina, sw.isOn);
    bool ok2 = applyGate(&gGateHHVouchers, sw.isOn);
    bool ok3 = applyGate(&gGateHHTicketEnough, sw.isOn);
    self.status.text = (ok1 && ok2 && ok3) ? (sw.isOn ? @"HH Infinite Tickets & Vouchers: ON" : @"HH Infinite Tickets & Vouchers: OFF") : @"HH ticket patch failed.";
}

- (void)onToggleHHAutoPass:(UISwitch*)sw {
    saveBool(@"Pref_HHAutoPass", sw.isOn);
    bool ok = applyGate(&gGateHHClearGrade3, sw.isOn);
    self.status.text = ok ? (sw.isOn ? @"HH Auto-Pass 3 Medals: ON" : @"HH Auto-Pass 3 Medals: OFF") : @"HH auto-pass patch failed.";
}

- (void)onToggleHHUniversalFlawless:(UISwitch*)sw {
    saveBool(@"Pref_HHUniversalFlawless", sw.isOn);
    bool ok1 = applyGate(&gGateHHFlawless, sw.isOn);
    bool ok2 = applyGate(&gGateHHMaxScore, sw.isOn);
    self.status.text = (ok1 && ok2) ? (sw.isOn ? @"HH Universal Flawless: ON" : @"HH Universal Flawless: OFF") : @"HH flawless patch failed.";
}

// ============================ Camp Caretaker & Companion Handlers ============================

- (void)refreshCompanionUI {
    NSString *curId = getCurrentCompanionId();
    if (curId.length > 0) {
        ACPCCVillager *found = nil;
        for (ACPCCVillager *v in [ACPCCVillager loadAllVillagers]) {
            if ([v.villagerId isEqualToString:curId]) {
                found = v;
                break;
            }
        }
        if (found) {
            self.companionNameLabel.text = [NSString stringWithFormat:@"Active: %@ [%@]", found.name, found.villagerId];
            self.companionStatusLabel.text = [NSString stringWithFormat:@"%@ · %@ · Roaming AI", found.category, found.species];
            if (found.iconImage) {
                self.companionAvatarView.image = found.iconImage;
            }
        } else {
            self.companionNameLabel.text = [NSString stringWithFormat:@"Active ID: %@", curId];
            self.companionStatusLabel.text = @"Special NPC / Custom Companion";
        }
    } else {
        self.companionNameLabel.text = @"Active: None (Not Appointed)";
        self.companionStatusLabel.text = @"Tap Browse to select a companion";
        NSData *d = [[NSData alloc] initWithBase64EncodedString:kFloatIconBase64 options:0];
        self.companionAvatarView.image = [UIImage imageWithData:d];
    }
}

- (void)showToast:(NSString*)msg {
    UIView *rootView = self.overlayWindow.rootViewController.view ?: (UIView*)self.overlayWindow;
    if (!rootView) return;

    UILabel *toast = [[UILabel alloc] initWithFrame:CGRectMake(20, 50, rootView.bounds.size.width - 40, 36)];
    toast.backgroundColor = [UIColor colorWithRed:0.85 green:0.25 blue:0.15 alpha:0.95];
    toast.layer.cornerRadius = 10;
    toast.layer.masksToBounds = YES;
    toast.layer.borderWidth = 1.0;
    toast.layer.borderColor = [UIColor colorWithRed:1.0 green:0.8 blue:0.4 alpha:0.9].CGColor;
    toast.textColor = [UIColor whiteColor];
    toast.font = [UIFont boldSystemFontOfSize:12.5];
    toast.textAlignment = NSTextAlignmentCenter;
    toast.text = msg;
    toast.alpha = 0.0;
    [rootView addSubview:toast];

    [UIView animateWithDuration:0.2 animations:^{
        toast.alpha = 1.0;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.3 delay:2.0 options:0 animations:^{
            toast.alpha = 0.0;
        } completion:^(BOOL finished) {
            [toast removeFromSuperview];
        }];
    }];
}

- (void)onEmergencySafeBob {
    saveBool(@"Pref_EmergencySafeBobPending", true);
    bool ok = forceSetCompanion(@"cat00");
    if (ok) {
        saveBool(@"Pref_EmergencySafeBobPending", false);
        [self showToast:@"EMERGENCY RESCUE: Appointed Bob (cat00)!"];
        self.status.text = @"Emergency Rescue: Appointed Bob (cat00)!";
    } else {
        [self showToast:@"EMERGENCY: Safe Bob Queued for Load!"];
        self.status.text = @"Emergency Safe Bob queued for engine initialization.";
    }
    [self refreshCompanionUI];
}

- (void)onToggleBypassFurniture:(UISwitch*)sw {
    saveBool(@"Pref_BypassFurniture", sw.isOn);
    gUnlockAllAssistantsOn = sw.isOn;
    bool ok = applyGate(&gGateUnlockAllAssistants, sw.isOn);
    self.status.text = ok ? (sw.isOn ? @"Furniture Bypass ON (All Special NPCs unlocked in native UI)." : @"Furniture Bypass OFF.") : @"Bypass patch failed.";
}

- (void)onToggleCompanionWalk:(UISwitch*)sw {
    saveBool(@"Pref_CompanionWalk", sw.isOn);
    bool ok = setCompanionWalkWith(sw.isOn);
    self.status.text = ok ? (sw.isOn ? @"Overworld following AI enabled." : @"Overworld following AI paused.") : @"AssistantManager not loaded yet.";
}

- (void)onDismissCompanion {
    bool ok = dismissCompanion();
    [self refreshCompanionUI];
    self.status.text = ok ? @"Active Caretaker companion dismissed." : @"No companion active or AssistantManager not loaded.";
}

- (void)onOpenVillagerSelector {
    UIView *parent = self.overlayWindow.rootViewController.view ?: (self.overlayWindow ?: keyWindow());
    if (!parent) return;

    if (!self.villagerModal) {
        self.villagerModal = [[ReddsVillagerSelectorModal alloc] initWithFrame:parent.bounds];
        __weak typeof(self) weakSelf = self;
        self.villagerModal.onSelectVillager = ^(ACPCCVillager *v) {
            [weakSelf onVillagerPicked:v];
        };
        self.villagerModal.onCloseModal = ^{
            [weakSelf updateIconOpacity];
        };
        [parent addSubview:self.villagerModal];
    } else {
        self.villagerModal.frame = parent.bounds;
        [parent bringSubviewToFront:self.villagerModal];
    }

    self.villagerModal.selectedVillagerId = getCurrentCompanionId();
    [self.villagerModal refreshData];
    self.villagerModal.hidden = NO;
    self.villagerModal.alpha = 0.0;
    [self updateIconOpacity];
    [UIView animateWithDuration:0.25 animations:^{
        self.villagerModal.alpha = 1.0;
    }];
}

- (void)onVillagerPicked:(ACPCCVillager*)v {
    bool ok = forceSetCompanion(v.villagerId);
    [self refreshCompanionUI];
    [self updateIconOpacity];
    if (ok) {
        self.status.text = [NSString stringWithFormat:@"Appointed %@ (%@) as Roaming Companion!", v.name, v.villagerId];
    } else {
        self.status.text = [NSString stringWithFormat:@"Companion set to %@ (%@). Reload area to display.", v.name, v.villagerId];
    }
}

- (void)appointSpecialNpc:(NSString*)npcId name:(NSString*)name {
    bool ok = forceSetCompanion(npcId);
    [self refreshCompanionUI];
    if (ok) {
        self.status.text = [NSString stringWithFormat:@"Appointed %@ (%@) as Roaming Companion!", name, npcId];
    } else {
        self.status.text = [NSString stringWithFormat:@"Companion set to %@ (%@). Reload area to display.", name, npcId];
    }
}

- (void)onQuickIsabelle { [self appointSpecialNpc:@"sza00" name:@"Isabelle"]; }
- (void)onQuickLabelle { [self appointSpecialNpc:@"hgc00" name:@"Labelle"]; }
- (void)onQuickHarriet { [self appointSpecialNpc:@"poo00" name:@"Harriet"]; }
- (void)onQuickReese { [self appointSpecialNpc:@"alw00" name:@"Reese"]; }
- (void)onQuickTomNook { [self appointSpecialNpc:@"rco00" name:@"Tom Nook"]; }
- (void)onQuickBrewster { [self appointSpecialNpc:@"pge00" name:@"Brewster"]; }
- (void)onQuickBlathers { [self appointSpecialNpc:@"owl00" name:@"Blathers"]; }
- (void)onQuickDJKK { [self appointSpecialNpc:@"end03" name:@"DJ KK"]; }
- (void)onQuickKK { [self appointSpecialNpc:@"end00" name:@"KK"]; }

// ============================ Time Travel & Spoofing Handlers ============================

- (NSString*)formattedDateString:(NSTimeInterval)secs {
    NSDate *d = [NSDate dateWithTimeIntervalSince1970:secs];
    static NSDateFormatter *df = nil;
    if (!df) {
        df = [NSDateFormatter new];
        df.dateFormat = @"yyyy-MM-dd HH:mm:ss";
        df.timeZone = [NSTimeZone localTimeZone];
    }
    return [df stringFromDate:d];
}

- (NSString*)formattedOffsetString:(int64_t)offsetSecs {
    if (offsetSecs == 0) return @"None (Real Time)";
    int64_t absVal = llabs(offsetSecs);
    int64_t days = absVal / 86400LL;
    int64_t rem1 = absVal % 86400LL;
    int64_t hours = rem1 / 3600LL;
    int64_t rem2 = rem1 % 3600LL;
    int64_t minutes = rem2 / 60LL;
    int64_t seconds = rem2 % 60LL;
    NSString *sign = (offsetSecs > 0) ? @"+" : @"-";
    if (days > 0) {
        return [NSString stringWithFormat:@"%@%lldd %02lldh %02lldm %02llds", sign, days, hours, minutes, seconds];
    } else {
        return [NSString stringWithFormat:@"%@%02lldh %02lldm %02llds", sign, hours, minutes, seconds];
    }
}

- (void)startClockTimer {
    if (!self.clockTickTimer) {
        self.clockTickTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(onClockTick) userInfo:nil repeats:YES];
    }
    [self updateTimeDisplay];
}

- (void)stopClockTimer {
    [self.clockTickTimer invalidate];
    self.clockTickTimer = nil;
}

- (void)onClockTick {
    if (self.panel && !self.panel.hidden) {
        [self updateTimeDisplay];
    }
}

- (void)updateTimeDisplay {
    if (!self.gameTimeDisplayLabel) return;
    int64_t curSecs = hook_UtcTime_get_Now(NULL);
    NSString *dateStr = [self formattedDateString:curSecs];
    NSString *offsetStr = [self formattedOffsetString:g_timeOffsetSeconds];

    NSString *modeStr = @"Real Time";
    UIColor *modeColor = [UIColor colorWithRed:0.4 green:0.85 blue:0.4 alpha:1.0];
    if (g_timeFreezeActive) {
        modeStr = @"FROZEN";
        modeColor = [UIColor colorWithRed:0.4 green:0.7 blue:1.0 alpha:1.0];
    } else if (g_timeTravelActive) {
        modeStr = @"SPOOFED";
        modeColor = accentOrangeCol();
    }

    self.gameTimeDisplayLabel.text = [NSString stringWithFormat:@"Game Time: %@", dateStr];
    self.offsetDisplayLabel.text = [NSString stringWithFormat:@"Offset: %@  [%@]", offsetStr, modeStr];
    self.offsetDisplayLabel.textColor = modeColor;
}

- (void)onToggleTimeTravel:(UISwitch*)sw {
    saveBool(@"Pref_TimeTravelActive", sw.isOn);
    g_timeTravelActive = sw.isOn;
    if (g_timeFreezeActive) {
        g_frozenTimestamp = hook_UtcTime_get_Now(NULL);
    }
    [self updateTimeDisplay];
    self.status.text = sw.isOn ? @"Time Travel ENABLED (In-game clock spoofing active)." : @"Time Travel DISABLED (Real device time active).";
}

- (void)onToggleTimeFreeze:(UISwitch*)sw {
    saveBool(@"Pref_TimeFreezeActive", sw.isOn);
    g_timeFreezeActive = sw.isOn;
    if (sw.isOn) {
        g_frozenTimestamp = hook_UtcTime_get_Now(NULL);
        self.status.text = @"Clock FROZEN at current second!";
    } else {
        self.status.text = @"Clock unfrozen. Time advancing normally.";
    }
    [self updateTimeDisplay];
}

- (void)onDatePickerValueChanged:(UIDatePicker*)dp {
    NSTimeInterval targetSecs = [dp.date timeIntervalSince1970];
    self.status.text = [NSString stringWithFormat:@"Selected: %@ (Tap 'Apply Selected Date' to jump)", [self formattedDateString:targetSecs]];
}

- (void)onApplyDatePicker {
    if (!self.datePicker) return;
    NSTimeInterval targetSecs = [self.datePicker.date timeIntervalSince1970];
    int64_t realNow = (int64_t)time(NULL);
    g_timeOffsetSeconds = (int64_t)targetSecs - realNow;
    g_timeTravelActive = true;
    if (g_timeFreezeActive) {
        g_frozenTimestamp = (int64_t)targetSecs;
    }
    if (self.timeTravelMasterSwitch) self.timeTravelMasterSwitch.on = YES;
    saveBool(@"Pref_TimeTravelActive", true);
    saveInt64(@"Pref_TimeTravelOffset", g_timeOffsetSeconds);
    [self updateTimeDisplay];
    self.status.text = [NSString stringWithFormat:@"Applied! Clock shifted to %@", [self formattedDateString:targetSecs]];
}

- (void)applyTargetDate:(NSDate*)targetDate name:(NSString*)name {
    NSTimeInterval targetSecs = [targetDate timeIntervalSince1970];
    int64_t realNow = (int64_t)time(NULL);
    g_timeOffsetSeconds = (int64_t)targetSecs - realNow;
    g_timeTravelActive = true;
    if (g_timeFreezeActive) {
        g_frozenTimestamp = (int64_t)targetSecs;
    }
    if (self.timeTravelMasterSwitch) self.timeTravelMasterSwitch.on = YES;
    if (self.datePicker) self.datePicker.date = targetDate;
    saveBool(@"Pref_TimeTravelActive", true);
    saveInt64(@"Pref_TimeTravelOffset", g_timeOffsetSeconds);
    [self updateTimeDisplay];
    self.status.text = [NSString stringWithFormat:@"Jumped to %@ (%@)!", name, [self formattedDateString:targetSecs]];
}

- (void)onSeasonalPresetsAction {
    UIViewController *rootVC = self.overlayWindow.rootViewController ?: keyWindow().rootViewController;
    while (rootVC.presentedViewController) {
        rootVC = rootVC.presentedViewController;
    }
    if (!rootVC) return;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Seasonal Event Presets"
        message:@"Select an event to jump immediately to its festive season:"
        preferredStyle:UIAlertControllerStyleActionSheet];

    NSCalendar *cal = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
    NSDateComponents *comps = [cal components:NSCalendarUnitYear fromDate:[NSDate date]];
    NSInteger currentYear = comps.year;

    void (^jumpToDate)(NSInteger, NSInteger, NSInteger, NSString*) = ^(NSInteger m, NSInteger d, NSInteger h, NSString *name) {
        NSDateComponents *targetComps = [NSDateComponents new];
        targetComps.year = currentYear;
        targetComps.month = m;
        targetComps.day = d;
        targetComps.hour = h;
        targetComps.minute = 0;
        targetComps.second = 0;
        targetComps.timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
        NSDate *targetDate = [cal dateFromComponents:targetComps];
        if (targetDate) {
            [self applyTargetDate:targetDate name:name];
        }
    };

    [alert addAction:[UIAlertAction actionWithTitle:@"Halloween (Jack's Spooky Event - Oct 31)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        jumpToDate(10, 31, 15, @"Halloween");
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"Toy Day (Jingle's Christmas - Dec 24)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        jumpToDate(12, 24, 6, @"Toy Day");
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"Cherry Blossoms (Spring Festival - Apr 10)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        jumpToDate(4, 10, 6, @"Cherry Blossoms");
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"Summer Island (Fireworks & Beetles - Jul 15)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        jumpToDate(7, 15, 6, @"Summer Island");
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"New Year Countdown (Jan 01)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        jumpToDate(1, 1, 0, @"New Year Countdown");
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];

    if (alert.popoverPresentationController) {
        alert.popoverPresentationController.sourceView = self.panel;
        alert.popoverPresentationController.sourceRect = CGRectMake(PW / 2.0, 150, 1, 1);
    }

    [rootVC presentViewController:alert animated:YES completion:nil];
}

- (void)onQuickJumpHours:(int)hours {
    g_timeTravelActive = true;
    g_timeOffsetSeconds += ((int64_t)hours * 3600LL);
    if (g_timeFreezeActive) {
        g_frozenTimestamp += ((int64_t)hours * 3600LL);
    }
    if (self.timeTravelMasterSwitch) self.timeTravelMasterSwitch.on = YES;
    saveBool(@"Pref_TimeTravelActive", true);
    saveInt64(@"Pref_TimeTravelOffset", g_timeOffsetSeconds);
    if (self.datePicker) {
        int64_t cur = hook_UtcTime_get_Now(NULL);
        self.datePicker.date = [NSDate dateWithTimeIntervalSince1970:cur];
    }
    [self updateTimeDisplay];
    int64_t curSecs = hook_UtcTime_get_Now(NULL);
    self.status.text = [NSString stringWithFormat:@"%@%dh jumped! New time: %@", (hours > 0 ? @"+" : @""), hours, [self formattedDateString:curSecs]];
}

- (void)onQuickJumpPlus3H {
    [self onQuickJumpHours:3];
}

- (void)onQuickJumpPlus12H {
    [self onQuickJumpHours:12];
}

- (void)onQuickJumpPlus24H {
    [self onQuickJumpHours:24];
}

- (void)onQuickJumpMinus3H {
    [self onQuickJumpHours:-3];
}

- (void)onQuickJumpMinus24H {
    [self onQuickJumpHours:-24];
}

- (void)onResetRealTime {
    g_timeOffsetSeconds = 0;
    g_timeTravelActive = false;
    g_timeFreezeActive = false;
    if (self.timeTravelMasterSwitch) self.timeTravelMasterSwitch.on = NO;
    if (self.timeFreezeSwitch) self.timeFreezeSwitch.on = NO;
    saveBool(@"Pref_TimeTravelActive", false);
    saveBool(@"Pref_TimeFreezeActive", false);
    saveInt64(@"Pref_TimeTravelOffset", 0);
    if (self.datePicker) {
        int64_t cur = (int64_t)time(NULL);
        self.datePicker.date = [NSDate dateWithTimeIntervalSince1970:cur];
    }
    [self updateTimeDisplay];
    self.status.text = @"Clock reset to real device time.";
}

// Crafting
- (void)onInstantCraft:(UISwitch*)sw {
    saveBool(@"Pref_InstantCraft", sw.isOn);
    bool ok1 = applyGate(&gGateCraftComplete, sw.isOn);
    bool ok2 = applyGate(&gGateCraftRecipeTime, sw.isOn);
    self.status.text = (ok1 && ok2) ? (sw.isOn ? @"Instant Crafting ON (0s Timers)." : @"Instant Crafting OFF.") : @"Crafting patch failed.";
}

// Gardening
- (void)onInstantBloomOnce {
    int count = instantBloomAllPlots();
    if (count > 0) {
        self.status.text = [NSString stringWithFormat:@"Instant Bloom applied to %d flowerbed slots!", count];
    } else {
        self.status.text = @"No flowerbed slots found in memory. Visit garden first!";
    }
}

- (void)onInstantBloomToggle:(UISwitch*)sw {
    saveBool(@"Pref_InstantBloom", sw.isOn);
    bool ok1 = applyGate(&gGateFlowerComplete, sw.isOn);
    bool ok2 = applyGate(&gGateFlowerBud, sw.isOn);
    self.status.text = (ok1 && ok2) ? (sw.isOn ? @"Always Instant Bloom ON." : @"Always Instant Bloom OFF.") : @"Flower patch failed.";
}

- (void)onRareCatchRate:(UISwitch*)sw {
    saveBool(@"Pref_RareCatch100", sw.isOn);
    gCatchRate100On = sw.isOn;
    self.status.text = sw.isOn ? @"100% Creature Catch Rate ON (Guaranteed Catch)." : @"100% Creature Catch Rate OFF.";
}

// Fishing & Insects
- (void)onFishBite:(UISwitch*)sw {
    saveBool(@"Pref_FishBite", sw.isOn);
    gInstantFishBiteOn = sw.isOn;
    self.status.text = sw.isOn ? @"Auto-Bite ON (No nibble delay)." : @"Auto-Bite OFF.";
}


- (void)onNeverFleeInsects:(UISwitch*)sw {
    saveBool(@"Pref_NeverFleeInsects", sw.isOn);
    bool ok1 = applyGate(&gGateInsectEscape, sw.isOn);
    bool ok2 = applyGate(&gGateInsectIsEscaped, sw.isOn);
    self.status.text = (ok1 && ok2) ? (sw.isOn ? @"Never-Flee Insects ON (Sprint/miss safely)." : @"Never-Flee Insects OFF.") : @"Insect patch failed.";
}

// Villagers
- (void)onMaxAllFriendship {
    int count = maxAllFriendship(70);
    if (count > 0) {
        self.status.text = [NSString stringWithFormat:@"Max Friendship applied to %d villagers (Level 70)!", count];
    } else {
        self.status.text = @"Villager data not loaded yet. Talk to an animal first.";
    }
}

- (void)onFulfillRequests {
    int count = completeAllAnimalRequests();
    if (count > 0) {
        self.status.text = [NSString stringWithFormat:@"Fulfilled requests for %d animals!", count];
    } else {
        self.status.text = @"No active animal requests found in memory.";
    }
}

// Campsite Force-Spawner
- (void)onForceCampsiteNpc:(UISwitch*)sw {
    saveBool(@"Pref_ForceCampsiteNpc", sw.isOn);
    gForceCampsiteNpcOn = sw.isOn;
    self.status.text = sw.isOn ? @"Force Campsite Villagers ON (Active on area reload)." : @"Force Campsite Villagers OFF.";
}

- (void)onCycleCampsitePreset:(UIButton*)btn {
    gCampsitePreset = (gCampsitePreset + 1) % 2;
    saveInt(@"Pref_CampsitePreset", gCampsitePreset);
    NSString *t = (gCampsitePreset == 1) ? @"Preset: Fan Favorites" : @"Preset: Developer 8";
    [btn setTitle:t forState:UIControlStateNormal];
    self.status.text = [NSString stringWithFormat:@"Campsite preset set to: %@", t];
}

// Shovelstrike Quarry
- (void)onUnlimitedQuarry:(UISwitch*)sw {
    saveBool(@"Pref_UnlimitedQuarry", sw.isOn);
#ifdef JAILED
    self.status.text = sw.isOn ? @"Unlimited Quarry Entries active (pre-baked in hybrid IPA)." : @"Unlimited Quarry Entries baked in hybrid IPA.";
#else
    bool ok1 = applyGate(&gGateQuarryOpened, sw.isOn);
    bool ok2 = applyGate(&gGateQuarryCleared, sw.isOn);
    bool ok3 = applyGate(&gGateQuarryTickets, sw.isOn);
    if (!sw.isOn && getSavedBool(@"Pref_FreeFriendQuarry", false)) {
        applyGate(&gGateQuarryOpened, true);
        applyGate(&gGateQuarryCleared, true);
    }
    self.status.text = (ok1 && ok2 && ok3) ? (sw.isOn ? @"Unlimited Quarry Entries ON." : @"Unlimited Quarry Entries OFF.") : @"Quarry patch failed.";
#endif
}

- (void)onFreeFriendQuarry:(UISwitch*)sw {
    saveBool(@"Pref_FreeFriendQuarry", sw.isOn);
#ifdef JAILED
    self.status.text = @"Quarry hacks disabled on jailed iOS to prevent Map crash.";
#else
    bool ok1 = applyGate(&gGateQuarryFriendCount, sw.isOn);
    bool ok2 = applyGate(&gGateQuarryFriendEnable, sw.isOn);
    bool ok3 = applyGate(&gGateQuarryFriendClosed, sw.isOn);
    bool ok4 = applyGate(&gGateQuarryNeedHelp, sw.isOn);
    bool ok5 = applyGate(&gGateQuarryCanUseHelp, sw.isOn);
    bool ok6 = applyGate(&gGateQuarryCurrentHelp, sw.isOn);
    bool ok7 = applyGate(&gGateQuarryRemainHelp, sw.isOn);
    if (sw.isOn) {
        applyGate(&gGateQuarryOpened, true);
        applyGate(&gGateQuarryCleared, true);
    } else if (!getSavedBool(@"Pref_UnlimitedQuarry", false)) {
        applyGate(&gGateQuarryOpened, false);
        applyGate(&gGateQuarryCleared, false);
    }
    self.status.text = (ok1 && ok2 && ok3 && ok4 && ok5 && ok6 && ok7) ? (sw.isOn ? @"Free Friend Quarry Entry ON." : @"Free Friend Quarry Entry OFF.") : @"Quarry friend patch failed.";
#endif
}

// Speedhack & Engine Tools
- (void)onSpeedSliderChanged:(UISlider*)sl {
    float val = roundf(sl.value * 10.0f) / 10.0f;
    self.speedLabel.text = [NSString stringWithFormat:@"Speed Multiplier: %.1fx", val];
    applySpeedhack(val);
    saveFloat(@"Pref_Speedhack", val);
    self.status.text = [NSString stringWithFormat:@"Engine speed set to %.1fx", val];
}

- (void)onResetSpeed {
    self.speedSlider.value = 1.0f;
    self.speedLabel.text = @"Speed Multiplier: 1.0x";
    applySpeedhack(1.0f);
    saveFloat(@"Pref_Speedhack", 1.0f);
    self.status.text = @"Engine speed reset to normal (1.0x).";
}

- (void)onToggleFpsHud:(UISwitch*)sw {
    saveBool(@"Pref_FpsHud", sw.isOn);
    if (sw.isOn) {
        if (!self.fpsHud) {
            self.fpsHud = [[ReddsFpsHud alloc] initWithFrame:CGRectMake(24, 70, 180, 26)];
            UIView *targetView = self.overlayWindow.rootViewController.view ?: (UIView*)self.overlayWindow;
            [targetView addSubview:self.fpsHud];
        }
        self.fpsHud.hidden = NO;
        [self.fpsHud start];
        self.status.text = @"FPS & Performance HUD enabled.";
    } else {
        if (self.fpsHud) {
            [self.fpsHud stop];
            self.fpsHud.hidden = YES;
        }
        self.status.text = @"FPS & Performance HUD disabled.";
    }
}

@end

// ============================ Substrate Hook Installation ============================
static void installCoreHooks(void) {
#ifndef JAILED
    uintptr_t base = getUnityBase();
    if (!base) return;

    // 1. Permanently Neutralize Cheating.SendTrap (0x22C5628)
    void *sendTrapAddr = (void*)(base + 0x22C5628);
    MSHookFunction(sendTrapAddr, (void*)&hook_Cheating_SendTrap, (void**)&orig_Cheating_SendTrap);

    // 2. Hook UtcTime.get_Now (0x1E2B904) - Time Travel & Clock Spoofing
    void *utcNowAddr = (void*)(base + 0x1E2B904);
    MSHookFunction(utcNowAddr, (void*)&hook_UtcTime_get_Now, (void**)&orig_UtcTime_get_Now);

    // 3. Hook CmpsUserBoot.SetLastTimeInfo (0x212BDD8) - Anti-Save-Pollution Protection
    void *setLastTimeAddr = (void*)(base + 0x212BDD8);
    MSHookFunction(setLastTimeAddr, (void*)&hook_SetLastTimeInfo, (void**)&orig_SetLastTimeInfo);

    // 4. Strategy B: Hook RegistrationChecker.CanRegister (0x25D74C8) - Caretaker Furniture Bypass
    void *canRegAddr = (void*)(base + 0x25D74C8);
    MSHookFunction(canRegAddr, (void*)&hook_RegistrationChecker_CanRegister, (void**)&orig_RegistrationChecker_CanRegister);

    // 5. Strategy B: Hook AssistantManager..ctor (0x25D3DF0) to capture instance
    void *asstCtorAddr = (void*)(base + 0x25D3DF0);
    MSHookFunction(asstCtorAddr, (void*)&hook_AssistantManager_ctor, (void**)&orig_AssistantManager_ctor);

    // 6. Hook CmpsSksGardening.Catch (0x2B438D8) -> hook_Catch
    void *catchAddr = (void*)(base + 0x2B438D8);
    MSHookFunction(catchAddr, (void*)&hook_Catch, (void**)&orig_Catch);

    // 7. Hook FishPick.OnStart (0x28A1854) -> hook_FishPick_OnStart (no nibbles, bite immediately)
    void *fishPickAddr = (void*)(base + 0x28A1854);
    MSHookFunction(fishPickAddr, (void*)&hook_FishPick_OnStart, (void**)&orig_FishPick_OnStart);

    // 8. Hook FishBite.OnStart (0x28A0A94) -> hook_FishBite_OnStart (extended 60s bite window)
    void *fishBiteAddr = (void*)(base + 0x28A0A94);
    MSHookFunction(fishBiteAddr, (void*)&hook_FishBite_OnStart, (void**)&orig_FishBite_OnStart);

    // 8. Hook CmpsGameDebugSetting.get_MyCampsiteNpcLabelArray (0x1FD3B24)
    void *campsiteSpAddr = (void*)(base + 0x1FD3B24);
    MSHookFunction(campsiteSpAddr, (void*)&hook_get_MyCampsiteNpcLabelArray, (void**)&orig_get_MyCampsiteNpcLabelArray);

    // 9. Hook UserProfileEntry.get_Bell (0x1DF5ED4) to capture profile safely
    void *getBellAddr = (void*)(base + 0x1DF5ED4);
    MSHookFunction(getBellAddr, (void*)&hook_UserProfileEntry_get_Bell, (void**)&orig_UserProfileEntry_get_Bell);

    // 10. Hook UserProfileEntry.get_NewLeafTicket (0x1DF617C) to capture profile safely
    void *getTokenAddr = (void*)(base + 0x1DF617C);
    MSHookFunction(getTokenAddr, (void*)&hook_UserProfileEntry_get_NewLeafTicket, (void**)&orig_UserProfileEntry_get_NewLeafTicket);

    // 11. Hook AssistantManager.GetAssistantNpcLabel (0x25D4A40) to capture manager safely
    void *asstLabelAddr = (void*)(base + 0x25D4A40);
    MSHookFunction(asstLabelAddr, (void*)&hook_AssistantManager_GetAssistantNpcLabel, (void**)&orig_AssistantManager_GetAssistantNpcLabel);

    // 12. Hook CmpsItemStock.GetItemStockAmount (0x21785A4) to capture itemStock safely
    void *getItemStockAddr = (void*)(base + 0x21785A4);
    MSHookFunction(getItemStockAddr, (void*)&hook_CmpsItemStock_GetItemStockAmount, (void**)&orig_CmpsItemStock_GetItemStockAmount);

    // 13. Hook CmpsUserSelf.get_Instance (0x2126194) to capture userSelf safely
    void *getUserSelfAddr = (void*)(base + 0x2126194);
    MSHookFunction(getUserSelfAddr, (void*)&hook_CmpsUserSelf_get_Instance, (void**)&orig_CmpsUserSelf_get_Instance);
#endif
}

static void ensureMenuAttached(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (gMenu && gMenu.isAttached && gMenu.overlayWindow) return;

        UIWindowScene *activeScene = nil;
        if (@available(iOS 13.0, *)) {
            for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
                if ([scene isKindOfClass:UIWindowScene.class]) {
                    UIWindowScene *ws = (UIWindowScene *)scene;
                    if (ws.activationState == UISceneActivationStateForegroundActive) {
                        activeScene = ws;
                        break;
                    }
                    if (!activeScene) activeScene = ws;
                }
            }
        }

        installCoreHooks();
        ensureBridgeInstalled();
        if (!gMenu) {
            gMenu = [ReddsToolsMenu new];
        }
        [gMenu attachToScene:activeScene];
        NSLog(@"[ReddsTools] Redds Tools Overlay attached in screen center successfully!");
    });
}

#ifndef JAILED
// Hook UIWindow makeKeyAndVisible to attach immediately when game window is presented
%hook UIWindow
- (void)makeKeyAndVisible {
    %orig;
    if (!gMenu || !gMenu.isAttached) {
        ensureMenuAttached();
    }
}
%end

// Hook Unity launch sequence as secondary entrypoint
%hook UnityAppController
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    BOOL ret = %orig;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        ensureMenuAttached();
    });
    return ret;
}
- (void)applicationDidBecomeActive:(UIApplication *)application {
    %orig;
    ensureMenuAttached();
}
%end
#endif

__attribute__((constructor)) static void initialize(void) {
    NSLog(@"[ReddsTools] Redds Tools Initialized for com.nintendo.zasa.");
    ensureBridgeInstalled();
#ifndef JAILED
    // Apply immediate memory patch to neutralize Cheating.SendTrap early
    applyGate(&gGateNeutralizeSendTrap, true);
    // Apply Strategy B furniture ownership bypass memory gate early
    applyGate(&gGateUnlockAllAssistants, true);
#endif

    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        ensureMenuAttached();
    }];

    // Immediate dispatch to main queue to attach overlay window in center of screen
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        ensureMenuAttached();
    });
}
