# Activity Check

On **every** connection to a server (remote or
local), check for recent heinzel activity in the
system journal. This keeps the user informed about
changes made by other team members or previous
sessions.

## When to run

After reading the server memory file and before
starting any requested work. This applies to every
connection, not just the first of the day.

## How to check

**systemd (Linux):**

```
journalctl -t heinzel --since "7 days ago" \
  --no-pager -q 2>/dev/null
```

As a non-root user outside the `systemd-journal` /
`adm` groups, `journalctl` silently shows only the
user's own entries. When connected as non-root, try
`sudo -n journalctl -t heinzel ...` first. If sudo
is unavailable, run the command without `-q` and
watch for the "not seeing messages from other
users" hint. When visibility is limited, tell the
user the activity check may be incomplete — do not
stay silent.

**macOS:**

```
log show --predicate 'senderImagePath CONTAINS "logger"' \
  --info --last 7d 2>/dev/null | grep heinzel
```

**FreeBSD:**

```
grep -h heinzel /var/log/messages.0 \
  /var/log/messages 2>/dev/null | tail -20
```

Note: this shows the last 20 matches, not a strict
7-day window, and only reaches one rotation back
(`messages.0`). Older rotated logs are usually
compressed; mention the limitation if relevant.

If the command fails or returns nothing — and
journal visibility is not limited (see above) —
skip silently: no activity to report.

## What to show

If there are entries, show a brief summary to the
user:

```
Recent heinzel activity (last 7 days):
- [2026-04-12 14:32] [alice as root] Installed nginx,
  opened port 443 — because static site launch
- [2026-04-11 09:15] [bob as bob] Updated Node.js
  22.14 → 22.15
```

- Group related entries when possible.
- Keep it concise — summarize, don't dump raw logs.
- If there are more than 10 entries, summarize the
  oldest and show the most recent 5 in detail.

## No activity

If the journal has no heinzel entries, say nothing.
Do not report "no recent activity" — silence means
no news.
