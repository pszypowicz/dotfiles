# Resumable Claude sessions as `title<TAB>date<TAB>path`, newest first, live
# sessions excluded. Default scope is the current project; pass --all for every
# project. Backs the ,cr picker (list column + preview path).
function __claude_sessions --description 'List resumable Claude sessions as title<TAB>date<TAB>path'
    set -l dirs
    if test "$argv[1]" = --all
        set dirs (find ~/.config/claude/projects -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
    else
        set dirs ~/.config/claude/projects/(string replace -ar '[^a-zA-Z0-9-]' - $PWD)
    end

    # Live session ids to exclude (can't safely resume a running session).
    set -l active_sids
    for f in ~/.config/claude/sessions/*.json
        test -f $f; or continue
        set -l pid (string match -r '"pid":([0-9]+)' < $f)[2]
        if test -n "$pid"; and kill -0 $pid 2>/dev/null
            set -a active_sids (string match -r '"sessionId":"([^"]+)"' < $f)[2]
        end
    end

    set -l files
    for dir in $dirs
        test -d $dir; or continue
        set -a files (find $dir -maxdepth 1 -type f -name '*.jsonl' 2>/dev/null)
    end
    test (count $files) -gt 0; or return

    for f in (command ls -t $files 2>/dev/null | head -40)
        set -l sid (path change-extension '' $f | path basename)
        contains -- $sid $active_sids; and continue

        # Title preference: user-set > model-generated > first real typed prompt
        # > slash-command name (for command-only sessions) > uuid. The typed
        # filter skips synthetic user lines (command-message/caveat wrappers,
        # which carry "promptSource":null) so titles read like real prompts.
        set -l title (grep '"type":"custom-title"' $f 2>/dev/null | tail -1 \
            | string match -r '"customTitle":"([^"]*)"')[2]
        test -z "$title"; and set title (grep '"type":"ai-title"' $f 2>/dev/null | tail -1 \
            | string match -r '"aiTitle":"([^"]*)"')[2]
        test -z "$title"; and set title (grep -m1 '"promptSource":"typed"' $f 2>/dev/null \
            | jq -r '.message.content
                | if type == "array" then (map(select(.type=="text") | .text)[0] // "") else . end
                | .[0:60] | gsub("[\t\n<>]"; " ") | gsub("  +"; " ") | ltrimstr(" ")' 2>/dev/null)
        test -z "$title"; and set title (grep -o '<command-name>/[^<]*</command-name>' $f 2>/dev/null \
            | string replace -r '<command-name>(/[^<]+)</command-name>' '$1' \
            | string match -rv '^/(clear|compact)$' | head -1)
        test -z "$title"; and set title $sid

        printf '%s\t%s\t%s\n' $title (date -r (stat -f %m $f) '+%b %d %H:%M') $f
    end
end
