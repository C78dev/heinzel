# Copying Directories Between Servers

When copying a directory tree from one server to
another (rsync, scp, tar, etc.), always check for
symlinks that point outside the copied tree:

```
find /path/to/copied/dir -type l | while read -r l
do
  printf '%s -> %s\n' "$l" "$(readlink -f "$l")"
done | grep -v ' -> /path/to/copied/dir/' | sort -u
```

This prints each symlink with its resolved target
so the user can see where it points. The trailing
slash in the filter matters: without it, targets
in sibling paths like `/path/to/copied/dir-old`
would be wrongly excluded too.

If any symlinks point to paths outside the directory,
their targets must also be copied.

Before marking a directory copy as complete, verify
on the destination:

```
find /path/to/copied/dir -xtype l
```

This lists broken symlinks. If any exist, investigate
and copy the missing targets.
