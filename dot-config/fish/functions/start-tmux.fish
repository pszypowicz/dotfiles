function start-tmux

    # test if variable VSCODE_WORKSPACE_FOLDER_BASENAME is set
    if set -q VSCODE_WORKSPACE_FOLDER_BASENAME
        set -l tmux_session_name "vscode-$VSCODE_WORKSPACE_FOLDER_BASENAME"

        if tmux has-session -t $tmux_session_name 2>/dev/null
            exec tmux attach-session -d -t $tmux_session_name \; new-window -c "$PWD"
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
