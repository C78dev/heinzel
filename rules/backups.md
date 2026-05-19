# Backups Before Modifying Config Files

Before editing any config file, back it up:

```
BACKUP_DIR="/var/backups/heinzel"
mkdir -p "$BACKUP_DIR"
cp /etc/some/config.conf \
  "$BACKUP_DIR/config.conf.$(date +%Y%m%d-%H%M%S)"
# Clean backups older than 30 days
find "$BACKUP_DIR" -type f -mtime +30 -delete
```

In unprivileged mode, use `~/.heinzel-backups/` for
user-owned files. System config files cannot be
edited — defer those to the sysadmin report.

## Never back up in place inside drop-in directories

Several Linux config systems read **every** file in a
directory and parse them. A backup left next to the
original gets parsed too, often with a warning at best
and broken behaviour at worst.

Affected paths include (but are not limited to):

- `/etc/apt/apt.conf.d/`
- `/etc/apt/sources.list.d/`
- `/etc/cron.d/`
- `/etc/systemd/system/*.d/`
- `/etc/ssh/sshd_config.d/`
- `/etc/sudoers.d/`
- `/etc/nginx/conf.d/`, `sites-enabled/`,
  `modules-enabled/`
- `/etc/logrotate.d/`
- `/etc/profile.d/`

When editing a file in one of those directories, write
the backup to `/var/backups/heinzel/` only. Never leave
it in the source directory, not even with a `.bak` or
timestamped suffix:

- `apt` logs daily warnings about
  `50unattended-upgrades.bak.YYYYMMDD` files (invalid
  filename extension) and silently ignores them.
- `sshd` refuses to start with stray files in
  `sshd_config.d/`.
- A forgotten `/etc/sudoers.d/old.bak` can rescind
  privileges silently if its parser pass fails.

If a session uncovers an existing in-place backup in
one of those directories, move it to
`/var/backups/heinzel/` rather than leaving it where
it is.
