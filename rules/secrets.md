# Secrets Hygiene

Secrets are objects to manage, never content to
display. Heinzel routinely works next to private
keys, password files, and tokens — none of their
values may ever appear in the conversation, in
reports, in memory files, in changelogs, or in
emails.

This rule governs how heinzel handles secrets.
Detecting *misconfigured* secrets (world-readable
keys, weak permissions) is the job of the
`heinzel-security` skill.

## What Counts as a Secret

- SSH private keys (`~/.ssh/id_*`,
  `/etc/ssh/ssh_host_*_key`)
- TLS/SSL private keys (`/etc/ssl/private/`,
  `*.key`, `*.pem` containing `PRIVATE KEY`)
- `/etc/shadow` and password hashes
- `.env` files and application config with
  credentials (database URLs with passwords,
  `secret_key_base`, API tokens)
- `~/.netrc`, `~/.aws/credentials`,
  `~/.config/gcloud/`, cloud provider tokens
- Mail credentials (`msmtprc`, `sasl_passwd`)
- Backup repository passwords (restic/borg env
  and password files)

When in doubt, treat it as a secret.

## Inspect via Metadata, Never Content

Existence, ownership, permissions, and size are
almost always what actually matters:

```
ls -l /etc/ssl/private/example.key
stat /root/.restic-env
wc -c /var/www/app/.env
file /etc/ssh/ssh_host_ed25519_key
```

Fingerprints identify keys without exposing them:

```
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
openssl x509 -noout -subject -enddate \
  -fingerprint -in /etc/ssl/certs/example.crt
```

Check whether a key matches a certificate by
comparing hashes of the public parts — never by
printing either file:

```
openssl x509 -noout -pubkey -in example.crt \
  | sha256sum
openssl pkey -pubout -in example.key | sha256sum
```

## Commands That Leak

- Never `cat`, `head`, `tail`, `less`, or `grep`
  (without `-c`/`-l`) a file from the list above.
- When a config that embeds credentials must be
  shown, redact on the fly:

  ```
  sed 's/\(password[ =:]*\).*/\1REDACTED/I' \
    /etc/app/config.ini
  ```

- Watch for accidental leaks: `ps aux` can show
  passwords in argv, `env` output can contain
  tokens, debug logs can echo credentials. If
  server output unexpectedly contains a credential,
  do **not** repeat the value — report *that* it
  leaked, where, and recommend rotating it.

## Redaction in Heinzel Artifacts

Changelog entries (`logger -t heinzel`),
`memory.md`, `todo.md`, pre-replacement
inventories, and email bodies record that a
credential exists, its location, and its
permissions — never its value.

Good:

```
logger -t heinzel "Rotated DB password for app \
(value in /var/www/app/.env, mode 600)"
```

Bad:

```
logger -t heinzel "Set DB password to hunter2"
```

## Email Attachments

Files likely to contain secrets are
**default-refuse** for the `heinzel-email` skill:
`.env`, `id_*`, `*_key`, `*.pem` with private key
material, `shadow`, `msmtprc`, `.netrc`, cloud
credential files, anything under
`/etc/ssl/private/`. Warn the user explicitly and
attach only on an explicit per-file override. The
content preview itself would leak — preview these
files with `ls -l` + `file` instead of showing
lines.

## Never Into the Repo Tree

Never copy key material or credential files
anywhere under the heinzel repo. `memory/` (and
`memory/servers/` in team mode) can be shared via
git — a committed key is a published key. This
generalizes the rule in `rules/os-replacement.md`
→ Certificates: store such material outside the
repo (e.g. `~/heinzel-keys/<hostname>/` with mode
`0700` on the directory and `0600` on files) and
record only the *path* in memory or inventories.

## Secrets the User Pastes Into Chat

Sometimes the user pastes a password or token
directly. Then:

- Use it for the immediate task only. Never write
  the value into any repo file, memory, changelog,
  todo, or email.
- When placing it on a server, create the target
  file with safe permissions *before* writing the
  content:

  ```
  install -m 600 /dev/null /etc/app/secret.conf
  ```

- Suggest pointing heinzel at an existing file
  path next time instead of pasting.
- If the value transited an untrusted channel,
  recommend rotating it.
