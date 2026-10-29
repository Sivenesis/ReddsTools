// EmbeddedIcons.h - In-memory packed icon archive loader for jailed/injected dylib
#pragma once
#import <UIKit/UIKit.h>
#import <string.h>
#import <stdlib.h>

#pragma pack(push, 1)
typedef struct {
    char magic[8];        // "REDDICOS"
    uint32_t count;       // Total number of icon entries (478)
    uint32_t dataOffset;  // Offset where PNG payload starts
} ReddsIconArchiveHeader;

typedef struct {
    char name[16];        // e.g. "alp00.png"
    uint32_t offset;      // relative to payload start
    uint32_t size;        // length of PNG bytes
} ReddsIconEntry;
#pragma pack(pop)

// Assembly binary blob symbols defined in EmbeddedIcons.s
#ifdef __cplusplus
extern "C" {
#endif
    extern const uint8_t g_redds_embedded_icons[] __attribute__((weak));
    extern const uint64_t g_redds_embedded_icons_size __attribute__((weak));
#ifdef __cplusplus
}
#endif

static int redds_compare_icon_entry(const void *a, const void *b) {
    const char *key = (const char *)a;
    const ReddsIconEntry *entry = (const ReddsIconEntry *)b;
    return strcasecmp(key, entry->name);
}

static inline BOOL hasEmbeddedIcons(void) {
    if (&g_redds_embedded_icons == NULL) return NO;
    const uint8_t *blob = g_redds_embedded_icons;
    if (!blob) return NO;
    const ReddsIconArchiveHeader *hdr = (const ReddsIconArchiveHeader *)blob;
    return (memcmp(hdr->magic, "REDDICOS", 8) == 0 && hdr->count > 0);
}

static inline NSData* getEmbeddedIconData(NSString *filename) {
    if (!filename || filename.length == 0) return nil;
    if (&g_redds_embedded_icons == NULL) return nil;

    const uint8_t *blob = g_redds_embedded_icons;
    if (!blob) return nil;

    const ReddsIconArchiveHeader *hdr = (const ReddsIconArchiveHeader *)blob;
    if (memcmp(hdr->magic, "REDDICOS", 8) != 0) return nil;

    const ReddsIconEntry *entries = (const ReddsIconEntry *)(blob + sizeof(ReddsIconArchiveHeader));

    NSString *lookupName = filename;
    if (![lookupName hasSuffix:@".png"]) {
        lookupName = [lookupName stringByAppendingString:@".png"];
    }

    const char *cName = [lookupName UTF8String];
    if (!cName) return nil;

    const ReddsIconEntry *found = (const ReddsIconEntry *)bsearch(
        cName,
        entries,
        hdr->count,
        sizeof(ReddsIconEntry),
        redds_compare_icon_entry
    );

    if (!found) return nil;

    const uint8_t *dataSection = blob + hdr->dataOffset;
    const uint8_t *pngBytes = dataSection + found->offset;
    return [NSData dataWithBytesNoCopy:(void*)pngBytes length:found->size freeWhenDone:NO];
}

static inline UIImage* getEmbeddedIconImage(NSString *filename) {
    NSData *data = getEmbeddedIconData(filename);
    if (!data) return nil;
    return [UIImage imageWithData:data];
}
