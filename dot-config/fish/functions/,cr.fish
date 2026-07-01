# Fuzzy-pick a Claude Code session to resume, previewing its transcript on the
# right. Lists the current project's sessions; --all widens to every project.
# fzf renders its own tmux popup via --tmux in FZF_DEFAULT_OPTS.
function ,cr --description 'Pick a Claude session to resume, with a transcript preview'
    argparse a/all h/help -- $argv; or return 1
    if set -q _flag_help
        echo 'Usage: ,cr [--all]'
        echo ''
        echo "Fuzzy-pick a Claude Code session to resume, previewing its transcript."
        echo "Default scope is the current project; --all lists every project."
        return 0
    end

    set -l scope
    set -q _flag_all; and set scope --all

    set -l rows (__claude_sessions $scope)
    if test -z "$rows"
        if set -q _flag_all
            echo ',cr: no resumable sessions found' >&2
        else
            echo ',cr: no resumable sessions for this project (try: ,cr --all)' >&2
        end
        return 1
    end

    set -l preview "$HOME/.config/claude/scripts/claude-session-preview.sh {2}"
    # Align the list into columns: pad each title to the longest (capped at 45),
    # then a dimmed, aligned date. The path rides along as a hidden second field
    # for the preview and is searched out via --nth=1.
    #
    # The preview opens scrolled to the bottom (you tend to remember a session by
    # its last messages, not its first prompt): `follow` tails the output, and the
    # focus:preview-bottom bind forces the end even on the focused row, sidestepping
    # the fzf quirk where follow+wrap can stop mid-content on long wrapped lines.
    set -l choice (printf '%s\n' $rows \
        | awk -F '\t' '
            { ttl[NR]=$1; dt[NR]=$2; pth[NR]=$3; n=length($1); if (n>45) n=45; if (n>w) w=n }
            END { for (i=1;i<=NR;i++) printf "%-*.*s  \033[2m%s\033[0m\t%s\n", w, w, ttl[i], dt[i], pth[i] }
          ' \
        | fzf --ansi --reverse --prompt='session> ' \
            --delimiter=\t --with-nth=1 --nth=1 \
            --bind 'focus:preview-bottom' \
            --preview=$preview --preview-window='right,60%,wrap,follow')
    test -z "$choice"; and return

    set -l file (string split -m1 \t -- $choice)[2]
    set -l sid (path change-extension '' $file | path basename)
    claude --resume $sid
end
