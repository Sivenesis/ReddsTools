.section __TEXT,__const
.global _g_redds_embedded_icons
.global _g_redds_embedded_icons_size
.p2align 3
_g_redds_embedded_icons:
.incbin "icons_archive.bin"
_g_redds_embedded_icons_end:
_g_redds_embedded_icons_size:
.quad _g_redds_embedded_icons_end - _g_redds_embedded_icons
