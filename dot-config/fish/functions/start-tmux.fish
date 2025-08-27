function start-tmux

    # test if variable VSCODE_WORKSPACE_FOLDER_BASENAME is set
    if set -q VSCODE_WORKSPACE_FOLDER_BASENAME
        set -l tmux_session_name "vscode-$VSCODE_WORKSPACE_FOLDER_BASENAME"

        if tmux has-session -t $tmux_session_name 2>/dev/null
            # check if the pane current path is the same as $PWD
            set -l current_pane_path (tmux list-sessions -f "#{==:#{session_name},$tmux_session_name}" -F "#{pane_current_path}")

            if [ "$current_pane_path" = "$PWD" ]
                # if yes, just attach to the session
                exec tmux attach-session -d -t $tmux_session_name
            else
                # if not, split the window to open a new pane with the current path
                # and attach to the session
                exec tmux attach-session -d -t $tmux_session_name \; split-window -c "$PWD"
            end

        else
            exec tmux new-session -s $tmux_session_name -c "$PWD"
        end
    else
        # The -A flag makes new-session behave like attach-session
        #  if session-name already exists; if -A is given, -D behaves
        #  like -d to attach-session
        exec tmux new-session -A -D -s default -c "$PWD"
    end
end
