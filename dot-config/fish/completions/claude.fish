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

        # Try session name from active sessions file, fall back to first user message, then date
        set -l name (grep -m1 '"name"' ~/.config/claude/sessions/*.json 2>/dev/null | string match -r "\"sessionId\":\"$sid\".*\"name\":\"([^\"]+)\"" | tail -1)

        if test -n "$name"
            set desc "$name"
        else
            set -l msg (grep -m1 '"type":"user"' $f | jq -r '
                .message.content
                | if type == "array" then map(select(.type == "text") | .text)[0] else . end
                | .[0:50] | gsub("[\\t\\n<>]"; " ") | ltrimstr(" ")' 2>/dev/null)
            if test -n "$msg"
                set desc "$msg"
            else
                set desc (date -r (stat -f %m $f) '+%b %d %H:%M')
            end
        end

        printf '%s\t%s\n' $sid $desc
    end
end

# Source the official completions
source /opt/homebrew/share/fish/completions/claude.fish

# Replace the official --resume completion with our argument provider
complete -e -c claude -s r -l resume
complete -c claude -x -k -n __fish_use_subcommand -s r -l resume -d 'Resume a conversation by session ID' -a '(__claude_resume_sessions)'
