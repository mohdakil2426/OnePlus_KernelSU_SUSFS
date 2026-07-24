#!/usr/bin/env bash
# Manual KernelSU hooks for non-GKI Linux 4.19 (SM8250).
# Based on KernelSU-Next / KernelSU non-GKI integration guidance and community OP8 builders.
# Run from kernel source root. Best-effort: skips cleanly if symbols already present.

set -euo pipefail

log() { echo "[hooks] $*"; }
warn() { echo "[hooks][warn] $*" >&2; }

if [[ ! -f Makefile ]] || ! grep -q '^VERSION' Makefile; then
  echo "error: run from kernel source root" >&2
  exit 1
fi

# --- fs/exec.c ---
if [[ -f fs/exec.c ]] && ! grep -q 'ksu_handle_execveat' fs/exec.c; then
  log "Patching fs/exec.c"
  if grep -q '#include <linux/fs_struct.h>' fs/exec.c; then
    sed -i '/#include <linux\/fs_struct.h>/a\
\
#ifdef CONFIG_KSU\
extern bool ksu_execveat_hook __read_mostly;\
extern int ksu_handle_execveat(int *fd, struct filename **filename_ptr, void *argv, void *envp, int *flags);\
extern int ksu_handle_execveat_sucompat(int *fd, struct filename **filename_ptr, void *argv, void *envp, int *flags);\
#endif
' fs/exec.c
  fi
  # Insert after first getname_flags in do_execveat_common-like path (best-effort)
  if grep -q 'getname_flags' fs/exec.c && ! grep -q 'ksu_handle_execveat(&fd' fs/exec.c; then
    awk '
      /filename = getname_flags\(/ && !done {
        print
        print "#ifdef CONFIG_KSU"
        print "\tif (unlikely(ksu_execveat_hook))"
        print "\t\tksu_handle_execveat(&fd, &filename, &argv, &envp, &flags);"
        print "\telse"
        print "\t\tksu_handle_execveat_sucompat(&fd, &filename, &argv, &envp, &flags);"
        print "#endif"
        done = 1
        next
      }
      { print }
    ' fs/exec.c > fs/exec.c.tmp && mv fs/exec.c.tmp fs/exec.c
  fi
else
  log "fs/exec.c already hooked or missing"
fi

# --- fs/open.c ---
if [[ -f fs/open.c ]] && ! grep -q 'ksu_handle_faccessat' fs/open.c; then
  log "Patching fs/open.c"
  if grep -q '#include <linux/rcupdate.h>' fs/open.c; then
    sed -i '/#include <linux\/rcupdate.h>/a\
\
#ifdef CONFIG_KSU\
extern int ksu_handle_faccessat(int *dfd, const char __user **filename_user, int *mode, int *flags);\
#endif
' fs/open.c
  fi
  if grep -q 'user_path_at' fs/open.c; then
    sed -i '/user_path_at(/i\
#ifdef CONFIG_KSU\
	ksu_handle_faccessat(\&dfd, \&filename, \&mode, NULL);\
#endif
' fs/open.c || true
  fi
else
  log "fs/open.c already hooked or missing"
fi

# --- fs/stat.c ---
if [[ -f fs/stat.c ]] && ! grep -q 'ksu_handle_stat' fs/stat.c; then
  log "Patching fs/stat.c"
  if grep -q '#include <linux/compat.h>' fs/stat.c; then
    sed -i '/#include <linux\/compat.h>/a\
\
#ifdef CONFIG_KSU\
extern int ksu_handle_stat(int *dfd, const char __user **filename_user, int *flags);\
#endif
' fs/stat.c
  fi
  if grep -q 'getname_flags' fs/stat.c; then
    sed -i '/getname_flags(/i\
#ifdef CONFIG_KSU\
	ksu_handle_stat(\&dfd, \&filename, \&flags);\
#endif
' fs/stat.c || true
  fi
else
  log "fs/stat.c already hooked or missing"
fi

# --- kernel/reboot.c (important for SUSFS supercalls) ---
if [[ -f kernel/reboot.c ]] && ! grep -q 'ksu_handle_sys_reboot' kernel/reboot.c; then
  log "Patching kernel/reboot.c"
  if grep -q '#include <linux/uaccess.h>' kernel/reboot.c; then
    sed -i '/#include <linux\/uaccess.h>/a\
\
#ifdef CONFIG_KSU\
extern int ksu_handle_sys_reboot(int magic1, int magic2, unsigned int cmd, void __user **arg);\
#endif
' kernel/reboot.c
  fi
  if grep -q 'SYSCALL_DEFINE4(reboot' kernel/reboot.c; then
    sed -i '/SYSCALL_DEFINE4(reboot/,/^}/{
      /int ret = 0;/a\
\
#ifdef CONFIG_KSU\
	ksu_handle_sys_reboot(magic1, magic2, cmd, \&arg);\
#endif
    }' kernel/reboot.c || true
  fi
else
  log "kernel/reboot.c already hooked or missing"
fi

# --- path_umount backport for < 5.9 ---
if [[ -f fs/namespace.c ]] && ! grep -q '^int path_umount' fs/namespace.c; then
  log "Backporting path_umount to fs/namespace.c"
  cat >> fs/namespace.c << 'EOF'

/* Backport path_umount for KernelSU/SUSFS on kernels < 5.9 */
static int can_umount_ksu(const struct path *path, int flags)
{
	struct mount *mnt = real_mount(path->mnt);

	if (flags & ~(MNT_FORCE | MNT_DETACH | MNT_EXPIRE | UMOUNT_NOFOLLOW))
		return -EINVAL;
	if (!may_mount())
		return -EPERM;
	if (path->dentry != path->mnt->mnt_root)
		return -EINVAL;
	if (!check_mnt(mnt))
		return -EINVAL;
	if (mnt->mnt.mnt_flags & MNT_LOCKED)
		return -EINVAL;
	if (flags & MNT_FORCE && !capable(CAP_SYS_ADMIN))
		return -EPERM;
	return 0;
}

int path_umount(struct path *path, int flags)
{
	struct mount *mnt = real_mount(path->mnt);
	int ret;

	ret = can_umount_ksu(path, flags);
	if (!ret)
		ret = do_umount(mnt, flags);
	dput(path->dentry);
	mntput_no_expire(mnt);
	return ret;
}
EXPORT_SYMBOL(path_umount);
EOF
  if [[ -f fs/internal.h ]] && ! grep -q 'path_umount' fs/internal.h; then
    echo 'int path_umount(struct path *path, int flags);' >> fs/internal.h
  fi
else
  log "path_umount already present or fs/namespace.c missing"
fi

log "Manual hooks step finished"
