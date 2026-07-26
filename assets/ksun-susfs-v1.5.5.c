#include <linux/bitops.h>
#include <linux/cred.h>
#include <linux/errno.h>
#include <linux/fs.h>
#include <linux/mount.h>
#include <linux/namei.h>
#include <linux/susfs.h>
#include <linux/uaccess.h>

#include "compat/kernel_compat.h"
#include "selinux/selinux.h"

#define KERNEL_SU_OPTION 0xDEADBEEF

#ifdef CONFIG_KSU_SUSFS_TRY_UMOUNT
extern void ksu_try_umount(const char *mnt, bool check_mnt, int flags,
			   uid_t uid);

void susfs_try_umount_all(uid_t uid)
{
	susfs_try_umount(uid);
	ksu_try_umount("/system", true, 0, uid);
	ksu_try_umount("/system_ext", true, 0, uid);
	ksu_try_umount("/vendor", true, 0, uid);
	ksu_try_umount("/product", true, 0, uid);
	ksu_try_umount("/odm", true, 0, uid);
	ksu_try_umount("/data/adb/modules", false, MNT_DETACH, uid);
	ksu_try_umount("/debug_ramdisk", true, MNT_DETACH, uid);
}
#endif

static int susfs_reply(unsigned long arg5, int error)
{
	if (!ksu_access_ok((void __user *)arg5, sizeof(error)))
		return -EFAULT;
	if (copy_to_user((void __user *)arg5, &error, sizeof(error)))
		return -EFAULT;
	return 0;
}

static int susfs_copy_string(unsigned long arg3, unsigned long arg5,
			     const char *value)
{
	int error;
	size_t size = strlen(value) + 1;

	if (!ksu_access_ok((void __user *)arg3, size))
		error = -EFAULT;
	else
		error = copy_to_user((void __user *)arg3, value, size);
	return susfs_reply(arg5, error);
}

static u64 susfs_enabled_features(void)
{
	u64 features = 0;

#ifdef CONFIG_KSU_SUSFS_SUS_PATH
	features |= BIT_ULL(0);
#endif
#ifdef CONFIG_KSU_SUSFS_SUS_MOUNT
	features |= BIT_ULL(1);
#endif
#ifdef CONFIG_KSU_SUSFS_AUTO_ADD_SUS_KSU_DEFAULT_MOUNT
	features |= BIT_ULL(2);
#endif
#ifdef CONFIG_KSU_SUSFS_AUTO_ADD_SUS_BIND_MOUNT
	features |= BIT_ULL(3);
#endif
#ifdef CONFIG_KSU_SUSFS_SUS_KSTAT
	features |= BIT_ULL(4);
#endif
#ifdef CONFIG_KSU_SUSFS_SUS_OVERLAYFS
	features |= BIT_ULL(5);
#endif
#ifdef CONFIG_KSU_SUSFS_TRY_UMOUNT
	features |= BIT_ULL(6);
#endif
#ifdef CONFIG_KSU_SUSFS_AUTO_ADD_TRY_UMOUNT_FOR_BIND_MOUNT
	features |= BIT_ULL(7);
#endif
#ifdef CONFIG_KSU_SUSFS_SPOOF_UNAME
	features |= BIT_ULL(8);
#endif
#ifdef CONFIG_KSU_SUSFS_ENABLE_LOG
	features |= BIT_ULL(9);
#endif
#ifdef CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS
	features |= BIT_ULL(10);
#endif
#ifdef CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG
	features |= BIT_ULL(11);
#endif
#ifdef CONFIG_KSU_SUSFS_OPEN_REDIRECT
	features |= BIT_ULL(12);
#endif
#ifdef CONFIG_KSU_SUSFS_SUS_SU
	features |= BIT_ULL(13);
#endif
	return features;
}

int ksu_susfs_handle_prctl(int option, unsigned long arg2,
			    unsigned long arg3, unsigned long arg4,
			    unsigned long arg5)
{
	int error = -EOPNOTSUPP;
	u64 features;

	(void)arg4;
	if (option != KERNEL_SU_OPTION || current_uid().val != 0)
		return 0;

	switch (arg2) {
#ifdef CONFIG_KSU_SUSFS_SUS_PATH
	case CMD_SUSFS_ADD_SUS_PATH:
		error = susfs_add_sus_path(
			(struct st_susfs_sus_path __user *)arg3);
		break;
#endif
#ifdef CONFIG_KSU_SUSFS_SUS_MOUNT
	case CMD_SUSFS_ADD_SUS_MOUNT:
		error = susfs_add_sus_mount(
			(struct st_susfs_sus_mount __user *)arg3);
		break;
#endif
#ifdef CONFIG_KSU_SUSFS_SUS_KSTAT
	case CMD_SUSFS_ADD_SUS_KSTAT:
	case CMD_SUSFS_ADD_SUS_KSTAT_STATICALLY:
		error = susfs_add_sus_kstat(
			(struct st_susfs_sus_kstat __user *)arg3);
		break;
	case CMD_SUSFS_UPDATE_SUS_KSTAT:
		error = susfs_update_sus_kstat(
			(struct st_susfs_sus_kstat __user *)arg3);
		break;
#endif
#ifdef CONFIG_KSU_SUSFS_TRY_UMOUNT
	case CMD_SUSFS_ADD_TRY_UMOUNT:
		error = susfs_add_try_umount(
			(struct st_susfs_try_umount __user *)arg3);
		break;
	case CMD_SUSFS_RUN_UMOUNT_FOR_CURRENT_MNT_NS:
		susfs_try_umount(current_uid().val);
		error = 0;
		break;
#endif
#ifdef CONFIG_KSU_SUSFS_SPOOF_UNAME
	case CMD_SUSFS_SET_UNAME:
		error = susfs_set_uname(
			(struct st_susfs_uname __user *)arg3);
		break;
#endif
#ifdef CONFIG_KSU_SUSFS_ENABLE_LOG
	case CMD_SUSFS_ENABLE_LOG:
		if (arg3 > 1)
			error = -EINVAL;
		else {
			susfs_set_log(arg3);
			error = 0;
		}
		break;
#endif
#ifdef CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG
	case CMD_SUSFS_SET_CMDLINE_OR_BOOTCONFIG:
		error = susfs_set_cmdline_or_bootconfig((char __user *)arg3);
		break;
#endif
#ifdef CONFIG_KSU_SUSFS_OPEN_REDIRECT
	case CMD_SUSFS_ADD_OPEN_REDIRECT:
		error = susfs_add_open_redirect(
			(struct st_susfs_open_redirect __user *)arg3);
		break;
#endif
	case CMD_SUSFS_SHOW_VERSION:
		return susfs_copy_string(arg3, arg5, SUSFS_VERSION);
	case CMD_SUSFS_SHOW_VARIANT:
		return susfs_copy_string(arg3, arg5, SUSFS_VARIANT);
	case CMD_SUSFS_SHOW_ENABLED_FEATURES:
		features = susfs_enabled_features();
		if (!ksu_access_ok((void __user *)arg3, sizeof(features)))
			error = -EFAULT;
		else
			error = copy_to_user((void __user *)arg3, &features,
					     sizeof(features));
		break;
	default:
		return 0;
	}

	susfs_reply(arg5, error);
	return 0;
}

bool susfs_is_current_ksu_domain(void)
{
	return is_ksu_domain();
}

bool susfs_is_current_zygote_domain(void)
{
	return is_zygote(current_cred());
}

static bool susfs_path_exists(const char *name)
{
	struct path path;

	if (kern_path(name, LOOKUP_FOLLOW, &path))
		return false;
	path_put(&path);
	return true;
}

void ksu_susfs_on_post_fs_data(void)
{
#ifdef CONFIG_KSU_SUSFS_AUTO_ADD_SUS_BIND_MOUNT
	extern bool susfs_is_auto_add_sus_bind_mount_enabled;
	susfs_is_auto_add_sus_bind_mount_enabled =
		!susfs_path_exists(DATA_ADB_NO_AUTO_ADD_SUS_BIND_MOUNT);
#endif
#ifdef CONFIG_KSU_SUSFS_AUTO_ADD_SUS_KSU_DEFAULT_MOUNT
	extern bool susfs_is_auto_add_sus_ksu_default_mount_enabled;
	susfs_is_auto_add_sus_ksu_default_mount_enabled =
		!susfs_path_exists(DATA_ADB_NO_AUTO_ADD_SUS_KSU_DEFAULT_MOUNT);
#endif
#ifdef CONFIG_KSU_SUSFS_AUTO_ADD_TRY_UMOUNT_FOR_BIND_MOUNT
	extern bool susfs_is_auto_add_try_umount_for_bind_mount_enabled;
	susfs_is_auto_add_try_umount_for_bind_mount_enabled =
		!susfs_path_exists(
			DATA_ADB_NO_AUTO_ADD_TRY_UMOUNT_FOR_BIND_MOUNT);
#endif
}
