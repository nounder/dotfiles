# Fish shell

Do NOT execute long commands in if statement, like this:

```fish
if not git fetch origin "$branch_name:$branch_name" 2>/dev/null
  # ...
```

INSTEAD do this:

```
git fetch origin "$branch_name:$branch_name" 2>/dev/null
  if not test $status -eq 0
    # ...
```
