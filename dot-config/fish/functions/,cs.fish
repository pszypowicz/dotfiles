# Search Claude Code session transcripts by content and resume the match. fzf is
# a mere selector here (--disabled): every keystroke re-runs ripgrep over the
# sessions via claude-session-search.sh, so you find a session by something said
# inside it, not just its title. Default scope is the current project; --all
# searches every project. The matched line is the row; the transcript previews on
# the right, scrolled to its latest messages.
function ,cs --description 'Search Claude session contents and resume the match'
    argparse a/all h/help -- $argv; or return 1
    if set -q _flag_help
        echo 'Usage: ,cs [--all]'
        echo ''
        echo "Live-search Claude Code session contents (your prompts, Claude's replies,"
        echo "and the commands it ran) and resume the one you pick. Type to search;"
        echo "results update as you go. Default scope is the current project; --all"
        echo "searches every project."
        return 0
    end

    set -l scope
    set -q _flag_all; and set scope --all

    set -l dirs (__claude_project_dirs $scope)
    set -l backend "$HOME/.config/claude/scripts/claude-session-search.sh"
    set -l preview "$HOME/.config/claude/scripts/claude-session-preview.sh {2}"

    # ripgrep does the filtering; fzf only selects. {q} is the live query, the
    # session path rides along as a hidden second field for the preview and
    # resume. The sleep debounces reload while typing; the preview opens at the
    # tail (see ,cr for the follow + focus:preview-bottom rationale).
    set -l reload "$backend --query {q} -- $dirs"
    set -l choice (echo -n '' | fzf --ansi --disabled --reverse --prompt='search> ' \
        --delimiter=\t --with-nth=1 \
        --bind "start:reload:$reload || true" \
        --bind "change:reload:sleep 0.1; $reload || true" \
        --bind 'focus:preview-bottom' \
        --preview=$preview --preview-window='right,60%,wrap,follow')
    test -z "$choice"; and return

    set -l file (string split -m1 \t -- $choice)[2]
    set -l sid (path change-extension '' $file | path basename)
    claude --resume $sid
end
