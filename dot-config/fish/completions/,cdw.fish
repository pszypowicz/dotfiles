# Complete ,cdw with sibling worktrees: branch (or basename for detached HEAD)
# as the token, worktree path as the description. __cdw_list autoloads on demand.
complete -c ',cdw' -f -a '(__cdw_list)'
