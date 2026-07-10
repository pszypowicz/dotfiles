# Completions for Claude Code (claude), plus project-aware --resume
# suggestions. Base flags and subcommands mirror `claude --help`; the
# claude-code-update skill keeps them in sync with new CLI releases.

function __claude_resume_sessions
    set -l project_dir ~/.config/claude/projects/(string replace -ar '[^a-zA-Z0-9-]' - $PWD)
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
        set -l msg (grep -m1 '"type":"user"' $f 2>/dev/null | jq -r '
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

set -l subcommands agents auth auto-mode doctor gateway install mcp plugin project setup-token ultrareview update

function __claude_no_subcommand
    not __fish_seen_subcommand_from agents auth auto-mode doctor gateway install mcp plugin project setup-token ultrareview update
end

# Suppress default file completion; path-taking flags re-enable it with -F
complete -c claude -f

# Subcommands
complete -c claude -n __fish_use_subcommand -a agents -d 'Manage background agents'
complete -c claude -n __fish_use_subcommand -a auth -d 'Manage authentication'
complete -c claude -n __fish_use_subcommand -a auto-mode -d 'Inspect auto mode classifier configuration'
complete -c claude -n __fish_use_subcommand -a doctor -d 'Check the health of the installation'
complete -c claude -n __fish_use_subcommand -a gateway -d 'Run the enterprise auth/telemetry gateway'
complete -c claude -n __fish_use_subcommand -a install -d 'Install Claude Code native build'
complete -c claude -n __fish_use_subcommand -a mcp -d 'Configure and manage MCP servers'
complete -c claude -n __fish_use_subcommand -a plugin -d 'Manage plugins'
complete -c claude -n __fish_use_subcommand -a project -d 'Manage project state'
complete -c claude -n __fish_use_subcommand -a setup-token -d 'Set up a long-lived authentication token'
complete -c claude -n __fish_use_subcommand -a ultrareview -d 'Cloud-hosted multi-agent code review'
complete -c claude -n __fish_use_subcommand -a update -d 'Check for updates and install'

# Boolean top-level flags
complete -c claude -n __claude_no_subcommand -s c -l continue -d 'Continue the most recent conversation in this directory'
complete -c claude -n __claude_no_subcommand -s p -l print -d 'Print response and exit'
complete -c claude -n __claude_no_subcommand -s v -l version -d 'Output the version number'
complete -c claude -n __claude_no_subcommand -s h -l help -d 'Display help'
complete -c claude -n __claude_no_subcommand -s d -l debug -d 'Enable debug mode (optional category filter)'
complete -c claude -n __claude_no_subcommand -s w -l worktree -d 'Create a new git worktree for this session'
complete -c claude -n __claude_no_subcommand -l bg -d 'Start as a background agent and return immediately'
complete -c claude -n __claude_no_subcommand -l background -d 'Start as a background agent and return immediately'
complete -c claude -n __claude_no_subcommand -l bare -d 'Minimal mode: skip hooks, plugins, memory, CLAUDE.md'
complete -c claude -n __claude_no_subcommand -l safe-mode -d 'Start with all customizations disabled'
complete -c claude -n __claude_no_subcommand -l brief -d 'Enable SendUserMessage tool'
complete -c claude -n __claude_no_subcommand -l chrome -d 'Enable Claude in Chrome integration'
complete -c claude -n __claude_no_subcommand -l no-chrome -d 'Disable Claude in Chrome integration'
complete -c claude -n __claude_no_subcommand -l ide -d 'Auto-connect to IDE on startup'
complete -c claude -n __claude_no_subcommand -l tmux -d 'Create a tmux session for the worktree'
complete -c claude -n __claude_no_subcommand -l fork-session -d 'Resume into a new session ID'
complete -c claude -n __claude_no_subcommand -l from-pr -d 'Resume a session linked to a PR'
complete -c claude -n __claude_no_subcommand -l remote-control -d 'Enable Remote Control (optionally named)'
complete -c claude -n __claude_no_subcommand -l verbose -d 'Override verbose mode setting'
complete -c claude -n __claude_no_subcommand -l ax-screen-reader -d 'Screen-reader friendly output'
complete -c claude -n __claude_no_subcommand -l prompt-suggestions -d 'Enable prompt suggestions'
complete -c claude -n __claude_no_subcommand -l dangerously-skip-permissions -d 'Bypass all permission checks'
complete -c claude -n __claude_no_subcommand -l allow-dangerously-skip-permissions -d 'Make permission bypass available without enabling it'
complete -c claude -n __claude_no_subcommand -l disable-slash-commands -d 'Disable all skills'
complete -c claude -n __claude_no_subcommand -l strict-mcp-config -d 'Only use MCP servers from --mcp-config'
complete -c claude -n __claude_no_subcommand -l no-session-persistence -d 'Do not save the session to disk (print mode)'
complete -c claude -n __claude_no_subcommand -l include-partial-messages -d 'Stream partial message chunks (stream-json)'
complete -c claude -n __claude_no_subcommand -l include-hook-events -d 'Include hook lifecycle events (stream-json)'
complete -c claude -n __claude_no_subcommand -l replay-user-messages -d 'Re-emit stdin user messages on stdout'
complete -c claude -n __claude_no_subcommand -l exclude-dynamic-system-prompt-sections -d 'Move per-machine sections out of the system prompt'

# Value-taking top-level flags
complete -c claude -n __claude_no_subcommand -l model -x -a 'fable opus sonnet haiku' -d 'Model for the current session'
complete -c claude -n __claude_no_subcommand -l fallback-model -x -a 'fable opus sonnet haiku' -d 'Fallback model(s) when primary is unavailable (print mode)'
complete -c claude -n __claude_no_subcommand -l effort -x -a 'low medium high xhigh max' -d 'Effort level for the current session'
complete -c claude -n __claude_no_subcommand -l permission-mode -x -a 'acceptEdits auto bypassPermissions manual dontAsk plan' -d 'Permission mode for the session'
complete -c claude -n __claude_no_subcommand -l output-format -x -a 'text json stream-json' -d 'Output format (print mode)'
complete -c claude -n __claude_no_subcommand -l input-format -x -a 'text stream-json' -d 'Input format (print mode)'
complete -c claude -n __claude_no_subcommand -l setting-sources -x -a 'user project local' -d 'Setting sources to load'
complete -c claude -n __claude_no_subcommand -l agent -x -d 'Agent for the current session'
complete -c claude -n __claude_no_subcommand -l agents -x -d 'JSON object defining custom agents'
complete -c claude -n __claude_no_subcommand -l allowedTools -l allowed-tools -x -d 'Tool names to allow'
complete -c claude -n __claude_no_subcommand -l disallowedTools -l disallowed-tools -x -d 'Tool names to deny'
complete -c claude -n __claude_no_subcommand -l tools -x -d 'Available built-in tools'
complete -c claude -n __claude_no_subcommand -l system-prompt -x -d 'System prompt for the session'
complete -c claude -n __claude_no_subcommand -l append-system-prompt -x -d 'Append to the default system prompt'
complete -c claude -n __claude_no_subcommand -l add-dir -r -F -d 'Additional directories to allow tool access to'
complete -c claude -n __claude_no_subcommand -l plugin-dir -r -F -d 'Load a plugin from a directory or .zip'
complete -c claude -n __claude_no_subcommand -l plugin-url -x -d 'Fetch a plugin .zip from a URL'
complete -c claude -n __claude_no_subcommand -l mcp-config -r -F -d 'Load MCP servers from JSON files or strings'
complete -c claude -n __claude_no_subcommand -l settings -r -F -d 'Settings JSON file or string'
complete -c claude -n __claude_no_subcommand -l debug-file -r -F -d 'Write debug logs to a file'
complete -c claude -n __claude_no_subcommand -l file -x -d 'File resources to download at startup'
complete -c claude -n __claude_no_subcommand -l betas -x -d 'Beta headers for API requests'
complete -c claude -n __claude_no_subcommand -l json-schema -x -d 'JSON Schema for structured output'
complete -c claude -n __claude_no_subcommand -l max-budget-usd -x -d 'Maximum dollar spend (print mode)'
complete -c claude -n __claude_no_subcommand -s n -l name -x -d 'Display name for this session'
complete -c claude -n __claude_no_subcommand -l session-id -x -d 'Use a specific session UUID'
complete -c claude -n __claude_no_subcommand -l remote-control-session-name-prefix -x -d 'Prefix for Remote Control session names'

# Project-aware --resume: suggest resumable sessions for this directory
complete -c claude -x -k -n __fish_use_subcommand -s r -l resume -d 'Resume a conversation by session ID' -a '(__claude_resume_sessions)'

# auth
set -l auth_cmds login logout status
complete -c claude -n "__fish_seen_subcommand_from auth; and not __fish_seen_subcommand_from $auth_cmds" -a login -d 'Sign in to your Anthropic account'
complete -c claude -n "__fish_seen_subcommand_from auth; and not __fish_seen_subcommand_from $auth_cmds" -a logout -d 'Log out from your Anthropic account'
complete -c claude -n "__fish_seen_subcommand_from auth; and not __fish_seen_subcommand_from $auth_cmds" -a status -d 'Show authentication status'

# mcp
set -l mcp_cmds add add-from-claude-desktop add-json get list login logout remove reset-project-choices serve
complete -c claude -n "__fish_seen_subcommand_from mcp; and not __fish_seen_subcommand_from $mcp_cmds" -a add -d 'Add an MCP server'
complete -c claude -n "__fish_seen_subcommand_from mcp; and not __fish_seen_subcommand_from $mcp_cmds" -a add-from-claude-desktop -d 'Import MCP servers from Claude Desktop'
complete -c claude -n "__fish_seen_subcommand_from mcp; and not __fish_seen_subcommand_from $mcp_cmds" -a add-json -d 'Add an MCP server from a JSON string'
complete -c claude -n "__fish_seen_subcommand_from mcp; and not __fish_seen_subcommand_from $mcp_cmds" -a get -d 'Get details about an MCP server'
complete -c claude -n "__fish_seen_subcommand_from mcp; and not __fish_seen_subcommand_from $mcp_cmds" -a list -d 'List configured MCP servers'
complete -c claude -n "__fish_seen_subcommand_from mcp; and not __fish_seen_subcommand_from $mcp_cmds" -a login -d 'Authenticate with an MCP server'
complete -c claude -n "__fish_seen_subcommand_from mcp; and not __fish_seen_subcommand_from $mcp_cmds" -a logout -d 'Clear stored OAuth credentials for a server'
complete -c claude -n "__fish_seen_subcommand_from mcp; and not __fish_seen_subcommand_from $mcp_cmds" -a remove -d 'Remove an MCP server'
complete -c claude -n "__fish_seen_subcommand_from mcp; and not __fish_seen_subcommand_from $mcp_cmds" -a reset-project-choices -d 'Reset approved and rejected .mcp.json choices'
complete -c claude -n "__fish_seen_subcommand_from mcp; and not __fish_seen_subcommand_from $mcp_cmds" -a serve -d 'Start the Claude Code MCP server'

# plugin
set -l plugin_cmds details disable enable eval init new install i list marketplace prune autoremove tag uninstall remove update
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and not __fish_seen_subcommand_from $plugin_cmds" -a details -d "Show a plugin's components and token cost"
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and not __fish_seen_subcommand_from $plugin_cmds" -a disable -d 'Disable an enabled plugin'
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and not __fish_seen_subcommand_from $plugin_cmds" -a enable -d 'Enable a disabled plugin'
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and not __fish_seen_subcommand_from $plugin_cmds" -a eval -d 'Run eval cases against a plugin'
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and not __fish_seen_subcommand_from $plugin_cmds" -a init -d 'Scaffold a new plugin'
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and not __fish_seen_subcommand_from $plugin_cmds" -a install -d 'Install a plugin from marketplaces'
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and not __fish_seen_subcommand_from $plugin_cmds" -a list -d 'List installed plugins'
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and not __fish_seen_subcommand_from $plugin_cmds" -a marketplace -d 'Manage marketplaces'
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and not __fish_seen_subcommand_from $plugin_cmds" -a prune -d 'Remove unneeded auto-installed dependencies'
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and not __fish_seen_subcommand_from $plugin_cmds" -a tag -d 'Create a release git tag for a plugin'
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and not __fish_seen_subcommand_from $plugin_cmds" -a uninstall -d 'Uninstall an installed plugin'
complete -c claude -n "__fish_seen_subcommand_from plugin plugins; and not __fish_seen_subcommand_from $plugin_cmds" -a update -d 'Update a plugin to the latest version'

# plugin marketplace
set -l marketplace_cmds add list remove rm update
complete -c claude -n "__fish_seen_subcommand_from marketplace; and not __fish_seen_subcommand_from $marketplace_cmds" -a add -d 'Add a marketplace from a URL, path, or GitHub repo'
complete -c claude -n "__fish_seen_subcommand_from marketplace; and not __fish_seen_subcommand_from $marketplace_cmds" -a list -d 'List configured marketplaces'
complete -c claude -n "__fish_seen_subcommand_from marketplace; and not __fish_seen_subcommand_from $marketplace_cmds" -a remove -d 'Remove a configured marketplace'
complete -c claude -n "__fish_seen_subcommand_from marketplace; and not __fish_seen_subcommand_from $marketplace_cmds" -a update -d 'Update marketplace(s) from their source'

# project
complete -c claude -n '__fish_seen_subcommand_from project; and not __fish_seen_subcommand_from purge' -a purge -d 'Delete all Claude Code state for a project'

# install targets
complete -c claude -n '__fish_seen_subcommand_from install' -a 'stable latest' -d 'Version to install'
