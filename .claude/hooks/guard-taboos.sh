#!/bin/sh
# guard-taboos.sh — PreToolUse hook (matcher: Bash).
#
# Mechanically enforces heinzel's absolute taboos from
# CLAUDE.md → Critical Safety Rules, below the model layer:
#
#   - halt / poweroff / shutdown without -r
#   - mkfs / newfs / wipefs (write forms)
#   - partition-table writers (fdisk/sfdisk/gdisk/sgdisk/
#     parted/gpart write forms; dd onto a raw disk device)
#   - rm/shred of SSH keys (host keys, authorized_keys, id_*)
#   - writes to /etc/ssh/sshd_config(.d/)
#
# The hook scans the ENTIRE command string, so taboos hidden
# inside wrappers like  ssh root@host "mkfs.ext4 /dev/sda1"
# are caught regardless of quoting. A PreToolUse deny blocks
# in every permission mode, including bypassPermissions.
#
# Known, accepted false positives (the patterns are deliberately
# coarse — this guard protects production disks, not grep
# pipelines): e.g. `grep poweroff /var/log/syslog` or
# `systemctl status shutdown.target` are blocked. Rephrase the
# probe (`grep 'power[o]ff'`) instead of fighting the guard.
# `cp /etc/ssh/sshd_config /tmp/` is blocked although it only
# reads the file — copy out via `cat /etc/ssh/sshd_config >
# /tmp/copy` instead.
#
# Being blocked is EXPECTED behavior. Explain it to the user.
# Never rephrase, re-quote, or otherwise obfuscate a command to
# evade this guard.
#
# Heinzel-repo development note: commit messages passed as
# heredocs flow through the Bash command string, so writing
# ABOUT taboo commands in a message triggers the guard. Write
# the message to a file with a non-Bash tool and use
# `git commit -F <file>` — that executes nothing on any server.
#
# Override for legitimate flows (e.g. rules/os-replacement.md
# runs mkfs/sgdisk by design): the OPERATOR sets
# HEINZEL_GUARD_DISABLE=1 in the environment BEFORE launching
# the session. An inline assignment inside a proposed command
# does not count and is itself blocked, so the model cannot
# disarm the guard.

# Operator-level override: inherited environment only.
if [ "${HEINZEL_GUARD_DISABLE:-}" = "1" ]; then
  exit 0
fi

INPUT=$(cat)

# Extract the Bash tool's command string. Without jq (or on
# malformed input) fall back to scanning the raw stdin text —
# that can only over-block, never under-block.
CMD=""
if command -v jq >/dev/null 2>&1; then
  CMD=$(printf '%s' "$INPUT" \
    | jq -r '.tool_input.command // empty' 2>/dev/null) || CMD=""
fi
[ -n "$CMD" ] || CMD="$INPUT"

hit() {
  printf '%s' "$CMD" | grep -Eq "$1"
}

deny() {
  # JSON decision on stdout; blocks in all permission modes.
  # Reasons must stay plain ASCII without quotes/backslashes.
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse",'
  printf '"permissionDecision":"deny",'
  printf '"permissionDecisionReason":"heinzel guard: %s ' "$1"
  printf '(CLAUDE.md - Critical Safety Rules). Blocked in all '
  printf 'permission modes. Explain this to the user; do not '
  printf 'rephrase the command to evade the guard."}}\n'
  exit 0
}

# The model must not disarm the guard from inside a command.
# Matches the assignment form only — merely mentioning the
# variable name (docs, grep) is fine. Note: heredocs flow
# through the command string too, so writing the literal
# assignment into a file or commit message also triggers
# this; phrase such text without the equals sign.
if hit 'HEINZEL_GUARD_DISABLE='; then
  deny "inline HEINZEL_GUARD_DISABLE assignment is not \
allowed - the operator must export it before launching the \
session"
fi

# --- Power off ------------------------------------------------
if hit '(^|[^[:alnum:]_-])(halt|poweroff)([^[:alnum:]_-]|$)'; then
  deny "halt/poweroff never runs without explicit user request"
fi
if hit '(^|[^[:alnum:]_])init[[:space:]]+0([^0-9]|$)'; then
  deny "init 0 powers off the server"
fi
if hit '(^|[^[:alnum:]_-])shutdown([^[:alnum:]_-]|$)' \
  && ! hit '(^|[[:space:]])-(r|c)([[:space:]]|$)'; then
  deny "shutdown without -r powers off the server (reboots \
use shutdown -r; -c cancels)"
fi

# --- Filesystem creation --------------------------------------
if hit '(^|[^[:alnum:]_.-])mkfs(\.[[:alnum:]]+)?([^[:alnum:]_.-]|$)'
then
  deny "mkfs destroys the filesystem on its target"
fi
if hit '(^|[^[:alnum:]_.-])newfs([^[:alnum:]_.-]|$)'; then
  deny "newfs destroys the filesystem on its target"
fi
if hit '(^|[^[:alnum:]_.-])wipefs([^[:alnum:]_.-]|$)' \
  && hit '(^|[[:space:]])(-a|--all|-o|--offset)'; then
  deny "wipefs in write mode erases filesystem signatures"
fi

# --- Partition table writers ----------------------------------
# Read-only inspection stays allowed: fdisk -l, sfdisk -l/-d,
# gdisk -l, sgdisk -p, parted -l/print, gpart show/status/list,
# lsblk, diskutil list.
if hit '(^|[^[:alnum:]_.-])fdisk([^[:alnum:]_.-]|$)' \
  && ! hit '(^|[[:space:]])-l'; then
  deny "fdisk without -l opens the partition table for writing"
fi
if hit '(^|[^[:alnum:]_.-])sfdisk([^[:alnum:]_.-]|$)' \
  && ! hit '(^|[[:space:]])(-l|--list|-d|--dump|-V|--verify)'; then
  deny "sfdisk in write mode modifies the partition table"
fi
if hit '(^|[^[:alnum:]_.-])c?gdisk([^[:alnum:]_.-]|$)' \
  && ! hit '(^|[[:space:]])-l'; then
  deny "gdisk without -l opens the partition table for writing"
fi
if hit '(^|[^[:alnum:]_.-])sgdisk([^[:alnum:]_.-]|$)' \
  && hit '(^|[[:space:]])(-n|-d|-t|-c|-Z|-o|-g|-N|--new|--delete|--typecode|--change-name|--zap(-all)?|--clear|--largest-new|--mbrtogpt)'
then
  deny "sgdisk write options modify the partition table"
fi
if hit '(^|[^[:alnum:]_.-])parted([^[:alnum:]_.-]|$)' \
  && hit '(mklabel|mkpart|resizepart|rm[[:space:]]+[0-9]|set[[:space:]]+[0-9])'
then
  deny "parted write commands modify the partition table"
fi
if hit 'gpart[[:space:]]+(create|add|delete|destroy|modify|resize|bootcode|recover|set|undo|commit)'
then
  deny "gpart write verbs modify the partition table"
fi
if hit '(^|[^[:alnum:]_-])dd([^[:alnum:]_-]|$)' \
  && hit 'of=["'\'']?/dev/'; then
  deny "dd onto a raw device overwrites disk content and \
partition table"
fi

# --- SSH keys and sshd_config ---------------------------------
if hit '(^|[^[:alnum:]_-])(rm|shred|unlink)([^[:alnum:]_-]|$)' \
  && hit '(/etc/ssh/ssh_host_|authorized_keys|\.ssh/id_)'; then
  deny "deleting SSH keys is never allowed"
fi
if hit '/etc/ssh/sshd_config'; then
  if hit '>>?[[:space:]]*["'\'']?/etc/ssh/sshd_config' \
    || hit 'tee[[:space:]]+(-a[[:space:]]+)?["'\'']?/etc/ssh/sshd_config' \
    || { hit '(^|[^[:alnum:]_-])(sed|perl)([^[:alnum:]_-]|$)' \
         && hit '(^|[[:space:]])-i'; } \
    || hit '(^|[^[:alnum:]_-])(vi|vim|nvim|nano|emacs|ed)([^[:alnum:]_-]|$)' \
    || hit '(^|[^[:alnum:]_-])(rm|truncate|chmod|chown|mv|cp)([^[:alnum:]_-]|$)'
  then
    deny "modifying /etc/ssh/sshd_config is never allowed \
(reading it is fine: cat, grep, sshd -T)"
  fi
fi

# No taboo matched: no decision, normal permission flow applies.
exit 0
