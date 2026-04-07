# Extend the official completions with project-aware --resume suggestions

function __claude_resume_sessions
    set -l project_dir ~/.config/claude/projects/(string replace -a / - $PWD)
    test -d $project_dir; or return

    # Collect active session IDs to exclude
    set -l active_sids
    for f in ~/.config/claude/sessions/*.json
        test -f $f; or continue
        set -l pid (string match -r '"pid":([0-9]+)' < $f)[2]
        if test -n "$pid"; and kill -0 $pid 2>/dev/null
            set -a active_sids (string match -r '"sessionId":"([^"]+)"' < $f)[2]
        end
    end

    for f in (command ls -t $project_dir/*.jsonl 2>/dev/null | head -20)
        set -l sid (path change-extension '' $f | path basename)
        contains -- $sid $active_sids; and continue

        # Extract customTitle from JSONL (last occurrence wins, as renames overwrite)
        set -l title (grep '"type":"custom-title"' $f 2>/dev/null | tail -1 | string match -r '"customTitle":"([^"]*)"')[2]

        # Build description from first user message or file date
        set -l msg (grep -m1 '"type":"user"' $f | jq -r '
            .message.content
            | if type == "array" then map(select(.type == "text") | .text)[0] else . end
            | .[0:50] | gsub("[\\t\\n<>]"; " ") | ltrimstr(" ")' 2>/dev/null)
        if test -z "$msg"
            set msg (date -r (stat -f %m $f) '+%b %d %H:%M')
        end

        # Use title if named, UUID otherwise (fish handles quoting automatically)
        if test -n "$title"
            printf '%s\t%s\n' $title $msg
        else
            printf '%s\t%s\n' $sid $msg
        end
    end
end

# Source the official completions
source /opt/homebrew/share/fish/completions/claude.fish

# Replace the official --resume completion with our argument provider
complete -e -c claude -s r -l resume
complete -c claude -x -k -n __fish_use_subcommand -s r -l resume -d 'Resume a conversation by session ID' -a '(__claude_resume_sessions)'
