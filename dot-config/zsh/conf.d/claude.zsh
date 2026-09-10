# Keep Claude Code's startup terminal queries off the screen. It re-enables
# echo for a window before it enters raw mode, and inside that window it sends
# XTVERSION and Primary DA, so the line discipline echoes tmux's replies as
# ^[ sequences. The window widens with the transcript load, which is why a
# --resume of a large session leaks the most reliably. Claude Code restores
# the termios it found at startup, so echo goes off around the whole run.
# Remove this once anthropics/claude-code#92275 is fixed.
#
# claude stays a direct child of the shell. tmux reads the pane command from
# the foreground process group leader, and a wrapper script would take that
# place and break the automatic-rename-format match on `claude*`.
claude() {
    [[ -t 0 ]] || { command claude "$@"; return }
    local saved
    saved=$(stty -g)
    {
        stty -echo
        command claude "$@"
    } always {
        stty "$saved" 2>/dev/null
    }
}
