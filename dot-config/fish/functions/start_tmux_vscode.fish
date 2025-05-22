function start_tmux_vscode
    #Check if tmux named session already exists
    if tmux has-session -t "$VSCODE_WORKSPACE_FOLDER_BASENAME" 2>/dev/null
        # filter out tmux session by name
        if tmux list-sessions -f "#{&&:#{==:#{session_name},$VSCODE_WORKSPACE_FOLDER_BASENAME},#{session_attached}}" | grep -q "$VSCODE_WORKSPACE_FOLDER_BASENAME"
            exec tmux attach-session -t "$VSCODE_WORKSPACE_FOLDER_BASENAME" \; split-window -c "$PWD"
        else
            # Attach to the existing session
            exec tmux attach-session -t "$VSCODE_WORKSPACE_FOLDER_BASENAME"
        end
    end

    exec tmux new-session -s "$VSCODE_WORKSPACE_FOLDER_BASENAME"
end
