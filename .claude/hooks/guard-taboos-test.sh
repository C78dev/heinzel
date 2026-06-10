#!/bin/sh
# guard-taboos-test.sh — dev-only fixture matrix for
# guard-taboos.sh. Run manually before committing guard
# changes:  sh .claude/hooks/guard-taboos-test.sh
# Not invoked by Claude Code at runtime.

HOOK="$(cd "$(dirname "$0")" && pwd)/guard-taboos.sh"
PASS=0
FAIL=0

json_for() {
  # Wrap a raw command string as PreToolUse hook input.
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$1" \
      | jq -Rs '{tool_name:"Bash",tool_input:{command:.}}'
  else
    printf '%s' "$1" | python3 -c 'import json,sys; \
print(json.dumps({"tool_name":"Bash","tool_input":\
{"command":sys.stdin.read()}}))'
  fi
}

check() {
  EXPECT=$1
  CMDSTR=$2
  OUT=$(json_for "$CMDSTR" \
    | env -u HEINZEL_GUARD_DISABLE sh "$HOOK")
  if printf '%s' "$OUT" \
    | grep -q '"permissionDecision":"deny"'; then
    GOT=deny
  else
    GOT=pass
  fi
  if [ "$GOT" = "$EXPECT" ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL [$EXPECT, got $GOT]: $CMDSTR"
  fi
}

# --- must block ------------------------------------------------
check deny 'halt'
check deny 'poweroff'
check deny 'systemctl poweroff'
check deny 'init 0'
check deny 'shutdown now'
check deny 'shutdown -h now'
check deny 'ssh root@h "shutdown -h now"'
check deny 'ssh -o BatchMode=yes root@h '\''mkfs.ext4 /dev/sda3'\'''
check deny 'mkfs.ext4 /dev/sda1'
check deny 'newfs /dev/ada0p3'
check deny 'wipefs -a /dev/sdb'
check deny 'fdisk /dev/sda'
check deny 'sfdisk /dev/sda < layout.txt'
check deny 'sgdisk -n 2:0:0 /dev/sda'
check deny 'sgdisk --zap-all /dev/sda'
check deny 'parted /dev/sda mklabel gpt'
check deny 'parted /dev/sda rm 2'
check deny 'gpart destroy -F ada0'
check deny 'gpart add -t freebsd-zfs ada0'
check deny 'dd if=image.raw of=/dev/sda bs=4M'
check deny 'ssh h "dd if=img of=/dev/vtbd0"'
check deny 'rm /etc/ssh/ssh_host_ed25519_key'
check deny 'rm -f ~/.ssh/id_ed25519'
check deny 'shred -u /root/.ssh/authorized_keys'
check deny "sed -i 's/^/#/' /etc/ssh/sshd_config"
check deny 'ssh h "echo PermitRootLogin yes >> /etc/ssh/sshd_config"'
check deny 'tee /etc/ssh/sshd_config < new.conf'
check deny 'vi /etc/ssh/sshd_config'
check deny 'HEINZEL_GUARD_DISABLE=1 mkfs.ext4 /dev/sda1'
check deny 'export HEINZEL_GUARD_DISABLE=1; fdisk /dev/sda'

# --- must pass -------------------------------------------------
check pass 'fdisk -l'
check pass 'sfdisk -l /dev/sda'
check pass 'sfdisk -d /dev/sda'
check pass 'gdisk -l /dev/sda'
check pass 'sgdisk -p /dev/sda'
check pass 'parted -l'
check pass 'gpart show ada0'
check pass 'gpart status'
check pass 'lsblk -f'
check pass 'diskutil list'
check pass 'shutdown -r now'
check pass 'ssh root@h "shutdown -r now"'
check pass 'shutdown -c'
check pass 'mkswap /dev/sda2'
check pass 'rm /tmp/foo'
check pass 'systemctl restart nginx'
check pass 'cat /etc/ssh/sshd_config'
check pass 'grep PermitRootLogin /etc/ssh/sshd_config'
check pass 'sshd -T'
check pass 'df -h'
check pass 'echo halting services'
check pass 'dd if=/dev/sda of=/root/disk-backup.img'
check pass 'uname -a'
check pass 'echo see HEINZEL_GUARD_DISABLE in the docs'

# --- fallback path: malformed (non-JSON) stdin -----------------
OUT=$(printf '%s' 'mkfs.ext4 /dev/sda1' \
  | env -u HEINZEL_GUARD_DISABLE sh "$HOOK")
if printf '%s' "$OUT" \
  | grep -q '"permissionDecision":"deny"'; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  echo "FAIL: raw-input fallback did not deny mkfs"
fi

# --- operator override via inherited environment ---------------
OUT=$(json_for 'mkfs.ext4 /dev/sda1' \
  | HEINZEL_GUARD_DISABLE=1 sh "$HOOK")
if [ -z "$OUT" ]; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  echo "FAIL: HEINZEL_GUARD_DISABLE=1 env did not disable guard"
fi

echo "guard-taboos tests: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
