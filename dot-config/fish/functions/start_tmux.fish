function start_tmux
  # Check if tmux is already running
  # and if there are any unattached sessions
  # Get the list of unattached sessions

  set tmux_unattached_sessions (tmux list-sessions -F '#{session_name}' -f '#{==:#{session_attached},0}')

  # If there are unattached sessions, attach to the first one
  if test -n "$tmux_unattached_sessions"
    exec tmux attach -t "$tmux_unattached_sessions[1]"
  else
    # If no unattached sessions, start a new tmux session
    exec tmux
  end
end
