### AnyKernel3 installer for OnePlus 8 (instantnoodle)
## AnyKernel3 framework by osm0sis

properties() { '
kernel.string=OP8 KernelSU-Next + SUSFS
do.devicecheck=1
do.modules=0
do.systemless=0
do.cleanup=1
do.cleanuponabort=0
do.check_boot_version=0
device.name1=instantnoodle
supported.versions=
supported.patchlevels=
supported.vendorpatchlevels=
keycheck.timeout=10
'; }

block=boot
is_slot_device=auto
ramdisk_compression=auto
patch_vbmeta_flag=auto
no_magisk_check=1

. tools/ak3-core.sh

split_boot

if [ -f "$SPLITIMG/ramdisk.cpio" ]; then
	unpack_ramdisk
	write_boot
else
	flash_boot
fi
