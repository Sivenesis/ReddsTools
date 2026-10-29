import os
import zipfile
import struct
import shutil
import sys

def main():
    repo_dir = os.path.dirname(os.path.abspath(__file__))

    default_ipa = os.path.join(repo_dir, 'raw', 'ACPCC_7.1.4.ipa')
    if not os.path.exists(default_ipa):
        parent_ipa = os.path.abspath(os.path.join(repo_dir, '..', 'raw', 'ACPCC_7.1.4.ipa'))
        if os.path.exists(parent_ipa):
            default_ipa = parent_ipa

    ipa_in = sys.argv[1] if len(sys.argv) > 1 else default_ipa
    ipa_out = sys.argv[2] if len(sys.argv) > 2 else os.path.splitext(ipa_in)[0] + '_Hybrid.ipa'

    dylib_candidates = [
        os.path.join(repo_dir, 'jailed', 'ReddsTools.dylib'),
        os.path.abspath(os.path.join(repo_dir, '..', 'jailed', 'ReddsTools.dylib')),
        r'F:\Progs\VIBECODE\PROJECTS\ios\games\acpcc\ReddsTools\jailed\ReddsTools.dylib',
    ]
    dylib_src = next((c for c in dylib_candidates if os.path.exists(c)), None)

    print(f"=== Redd's Tools Hybrid IPA Creator ===")
    print(f"Source IPA: {ipa_in}")
    print(f"Output IPA: {ipa_out}")
    print(f"Dylib to Inject: {dylib_src}")

    if not os.path.exists(ipa_in):
        print(f"ERROR: Source IPA not found at {ipa_in}")
        print("Please provide a decrypted ACPCC 7.1.4 IPA as argument: python create_hybrid_ipa.py <path_to_ipa>")
        sys.exit(1)

    if not dylib_src or not os.path.exists(dylib_src):
        print(f"ERROR: Jailed dylib not found.")
        print("Please build it first using ./build_jailed_dylib.sh or download from Releases.")
        sys.exit(1)

    with open(dylib_src, 'rb') as f:
        dylib_data = f.read()
    print(f"Loaded ReddsTools.dylib ({len(dylib_data)} bytes)")

    # 32 Static Patches for UnityFramework (Includes Time Travel Bridge & Safe Quarry Entries)
    patches = [
        # 1. Neutralize Anti-Cheat Telemetry
        ('Cheating.SendTrap', 0x22C5628, 'f8 5f bc a9 f6 57 01 a9', 'c0 03 5f d6 1f 20 03 d5'),
        # 2. Camp Caretaker Special Furniture Bypass & Candidate List Unlock
        ('RegistrationChecker.CanRegister', 0x25D74C8, 'f6 57 bd a9 f4 4f 01 a9', '20 00 80 52 c0 03 5f d6'),
        ('CandidateNpcList.LovePointBypass', 0x25D6884, 'f6 57 bd a9 f4 4f 01 a9', '20 00 80 52 c0 03 5f d6'),
        # 3. Unlock Full Catalog & Complete Ticket Items (5 patches)
        ('CatalogIsOnCatalog', 0x2951B30, '00 14 40 f9 60 00 00 b4', '20 00 80 52 c0 03 5f d6'),
        ('CatalogBookIsValidItem', 0x2EDC784, 'ff 03 01 d1 f6 57 01 a9', '20 00 80 52 c0 03 5f d6'),
        ('CatalogCompleteIsValidItem', 0x2EE4D10, 'ff 03 01 d1 f6 57 01 a9', '20 00 80 52 c0 03 5f d6'),
        ('CatalogCompleteAllowCookies', 0x2EE09E4, 'c0 1a 00 54', '1f 20 03 d5'),
        ('CatalogIgnoreBypass', 0x2E76AE8, 'f6 57 bd a9 f4 4f 01 a9', '00 00 80 52 c0 03 5f d6'),
        # 4. Instant Crafting
        ('InstantCraftComplete', 0x29AB41C, '00 08 40 f9 60 00 00 b4', '00 00 80 d2 c0 03 5f d6'),
        ('InstantRecipeTime', 0x29AB5B4, '00 14 40 f9 60 00 00 b4', '00 00 80 52 c0 03 5f d6'),
        # 5. Instant Flower Bloom & Bud
        ('InstantFlowerComplete', 0x1CE3614, '00 28 40 f9 60 00 00 b4', '00 00 80 52 c0 03 5f d6'),
        ('InstantFlowerBud', 0x1CE3504, '00 20 40 f9 60 00 00 b4', '00 00 80 52 c0 03 5f d6'),
        # 6. Never-Flee Insects
        ('NeverFleeInsects', 0x24141F0, 'f6 57 bd a9 f4 4f 01 a9', 'c0 03 5f d6 1f 20 03 d5'),
        ('InsectIsEscaped', 0x2414748, '08 a8 41 b9 1f 19 00 71', '00 00 80 52 c0 03 5f d6'),
        # 7. Crossover Fortune Cookies in Shop & Purchasing (All 7 gates)
        ('CookieCampaignCheck', 0x1C54F48, 'f6 57 bd a9 f4 4f 01 a9', '20 00 80 52 c0 03 5f d6'),
        ('CookieReleaseCheck', 0x1C54E94, 'f4 4f be a9 fd 7b 01 a9', '20 00 80 52 c0 03 5f d6'),
        ('CookiePresenterCheck', 0x2CA03C4, '5f 07 00 71 04 a8 40 7a', '0a 00 00 14 1f 20 03 d5'),
        ('CookieCacheBypass', 0x1C55D80, '40 19 00 b5 c8 bc 02 b0', '1f 20 03 d5 c8 bc 02 b0'),
        ('CookiePresenterEnableData', 0x2C9E4DC, '3f 04 00 71 ab 00 00 54', '20 00 80 52 c0 03 5f d6'),
        ('CookiePresenterCampaignId', 0x2CA4714, 'f4 4f be a9 fd 7b 01 a9', '20 00 80 52 c0 03 5f d6'),
        ('CookiePresenterReleaseId', 0x2CA50F4, '01 01 00 34 fd 7b bf a9', '20 00 80 52 c0 03 5f d6'),
        # 8. Happy Homeroom Hacks
        ('HHStamina3', 0x1BFE0E4, 'f4 4f be a9 fd 7b 01 a9', '60 00 80 52 c0 03 5f d6'),
        ('HHVouchers999', 0x1BFD944, 'f6 57 bd a9 f4 4f 01 a9', 'e0 7c 80 d2 c0 03 5f d6'),
        ('HHTicketEnough', 0x1BFDB80, 'f6 57 bd a9 f4 4f 01 a9', '20 00 80 52 c0 03 5f d6'),
        ('HHClearGrade3', 0x2D4255C, 'f8 5f bc a9 f6 57 01 a9', '60 00 80 52 c0 03 5f d6'),
        ('HHFlawless', 0x2362B90, 'ff 03 02 d1 fc 6f 02 a9', '40 00 80 52 c0 03 5f d6'),
        ('HHMaxScore1000', 0x2361C80, 'fd 7b bf a9 fd 03 00 91', '00 7d 80 52 c0 03 5f d6'),
        # 9. Shovelstrike Quarry Unlimited Daily Entries (Isolated ticket entry gates - safe against Map crash)
        ('QuarryNeverCleared', 0x2873C34, 'f4 4f be a9 fd 7b 01 a9', '00 00 80 52 c0 03 5f d6'),
        ('QuarryTicketRemain', 0x2873C94, 'f4 4f be a9 fd 7b 01 a9', '60 0c 80 52 c0 03 5f d6'),
        ('QuarryCanUseTicket', 0x1F76EEC, 'fd 7b bf a9 fd 03 00 91', '20 00 80 52 c0 03 5f d6'),
        ('QuarryCanNotUseTicket', 0x1B4574C, 'f4 4f be a9 fd 7b 01 a9', '00 00 80 52 c0 03 5f d6'),
        # 10. JIT-Free Time Travel Indirect Function Pointer Bridge via __DATA (0x7715B00)
        ('UtcTime.get_Now_Bridge', 0x1E2B904, 'f4 4f be a9 fd 7b 01 a9 fd 43 00 91 34 d2 02 b0 88 b2 7d 39 d3 ae 02 f0', '48 c7 02 d0 08 81 45 f9 48 00 00 b4 00 01 1f d6 00 00 80 d2 c0 03 5f d6'),
    ]

    unity_fw_path = 'Payload/zasa.app/Frameworks/UnityFramework.framework/UnityFramework'
    main_bin_path = 'Payload/zasa.app/zasa'
    injected_dylib_entry = 'Payload/zasa.app/Frameworks/ReddsTools.dylib'

    print("Opening source IPA and processing binaries...")
    with zipfile.ZipFile(ipa_in, 'r') as zin, zipfile.ZipFile(ipa_out, 'w', compression=zipfile.ZIP_DEFLATED) as zout:
        infolist = zin.infolist()
        total = len(infolist)
        print(f"Total entries to transfer: {total}")

        for idx, item in enumerate(infolist):
            data = zin.read(item.filename)

            if item.filename == unity_fw_path:
                print(f"-> Patching {unity_fw_path} ({len(data)} bytes)...")
                buf = bytearray(data)
                applied = 0
                for name, rva, orig_hex, patch_hex in patches:
                    orig_b = bytes.fromhex(orig_hex.replace(' ', ''))
                    patch_b = bytes.fromhex(patch_hex.replace(' ', ''))
                    cur_b = buf[rva:rva + len(orig_b)]
                    if cur_b != orig_b:
                        print(f"   WARNING: Mismatch at {name} (0x{rva:X}): expected {orig_b.hex()}, found {cur_b.hex()}")
                    buf[rva:rva + len(patch_b)] = patch_b
                    applied += 1
                print(f"   Applied {applied}/{len(patches)} static memory gates successfully!")
                data = bytes(buf)

            elif item.filename == main_bin_path:
                print(f"-> Injecting LC_LOAD_DYLIB into {main_bin_path} ({len(data)} bytes)...")
                buf = bytearray(data)
                magic, cputype, cpusubtype, filetype, ncmds, sizeofcmds = struct.unpack('<IIIIII', buf[:24])
                
                # LC_LOAD_DYLIB command
                dylib_cmd_path = b'@executable_path/Frameworks/ReddsTools.dylib\x00'
                cmd_header_len = 24
                cmd_len = cmd_header_len + len(dylib_cmd_path)
                cmd_aligned = ((cmd_len + 7) // 8) * 8
                padding = cmd_aligned - cmd_len

                cmd_bytes = struct.pack('<IIIIII', 0x0C, cmd_aligned, 24, 2, 0x10000, 0x10000) + dylib_cmd_path + (b'\x00' * padding)
                insert_pos = 32 + sizeofcmds

                buf[insert_pos:insert_pos + cmd_aligned] = cmd_bytes
                struct.pack_into('<II', buf, 16, ncmds + 1, sizeofcmds + cmd_aligned)
                print(f"   Injected LC_LOAD_DYLIB (ncmds: {ncmds} -> {ncmds + 1}, sizeofcmds: {sizeofcmds} -> {sizeofcmds + cmd_aligned})")
                data = bytes(buf)

            # Write file to new IPA
            zout.writestr(item, data)

            if (idx + 1) % 200 == 0 or idx == total - 1:
                print(f"   Transferred {idx + 1}/{total} files...")

        # Add injected ReddsTools.dylib
        print(f"-> Bundling {injected_dylib_entry} into IPA...")
        zinfo = zipfile.ZipInfo(injected_dylib_entry)
        zinfo.external_attr = 0o755 << 16  # -rwxr-xr-x
        zinfo.compress_type = zipfile.ZIP_DEFLATED
        zout.writestr(zinfo, dylib_data)

        # Add ReddsTools resource bundle (characters.json & icons)
        char_json_candidates = [
            os.path.join(repo_dir, 'layout', 'Library', 'Application Support', 'ReddsTools', 'characters.json'),
            os.path.join(repo_dir, '..', 'villagers', 'characters.json'),
            r'F:\Progs\VIBECODE\PROJECTS\ios\games\acpcc\villagers\characters.json'
        ]
        characters_json = next((c for c in char_json_candidates if os.path.exists(c)), None)

        icons_dir_candidates = [
            os.path.join(repo_dir, 'layout', 'Library', 'Application Support', 'ReddsTools', 'icons'),
            os.path.join(repo_dir, '..', 'villagers', 'companion_icons'),
            os.path.join(repo_dir, '..', 'villagers', 'icons'),
            r'F:\Progs\VIBECODE\PROJECTS\ios\games\acpcc\villagers\icons'
        ]
        icons_dir = next((c for c in icons_dir_candidates if os.path.exists(c)), None)

        if characters_json and os.path.exists(characters_json):
            print(f"-> Bundling ReddsTools/characters.json into IPA from {characters_json}...")
            with open(characters_json, 'rb') as f:
                zout.writestr('Payload/zasa.app/ReddsTools/characters.json', f.read())

        if icons_dir and os.path.exists(icons_dir):
            icon_files = [f for f in os.listdir(icons_dir) if f.endswith('.png')]
            print(f"-> Bundling {len(icon_files)} companion icons into Payload/zasa.app/ReddsTools/icons/ from {icons_dir}...")
            for ic in icon_files:
                with open(os.path.join(icons_dir, ic), 'rb') as f:
                    zout.writestr(f'Payload/zasa.app/ReddsTools/icons/{ic}', f.read())

    print(f"\nSUCCESS! Created Hybrid IPA at:")
    print(ipa_out)
    size_mb = os.path.getsize(ipa_out) / (1024 * 1024)
    print(f"File size: {size_mb:.2f} MB")

if __name__ == '__main__':
    main()
