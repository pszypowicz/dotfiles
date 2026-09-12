# Point one stable path at the agent the current ssh session forwarded, so
# ssh_config can name a path that never changes. sshd picks a fresh random name
# for the socket on every connection, and a process that started before that
# connection never learns the new name. A tmux pane attached from a phone
# therefore cannot reach the agent the phone forwarded. Naming the link instead
# of the socket keeps those panes working.
#
# The link is published only after the agent signs something. Listing a key and
# signing with it are separate permissions: a forwarded agent can answer the
# list request and refuse every signature, and macOS keeps an empty launchd
# agent whose socket answers a list request with nothing at all. ssh talks to
# one agent per connection and cannot fall back to another, so a link that
# names an agent which will not sign turns every affected host into a failed
# connection. Proving the signature first keeps the failure out of ssh.
#
# The proof costs one signature, and it runs only when the link does not
# already name this socket, so a burst of new panes inside one session tests
# nothing. mosh forwards no agent and a terminal at the machine has no
# forwarded agent either, so neither one reaches the test.
() {
    local link=$HOME/.ssh/agent-forwarded.sock
    [[ -n ${SSH_AUTH_SOCK:-} && -S $SSH_AUTH_SOCK ]] || return
    [[ $SSH_AUTH_SOCK != $link ]] || return
    [[ $SSH_AUTH_SOCK != $(readlink $link 2>/dev/null) ]] || return

    local guard=()
    (( $+commands[timeout] )) && guard=(timeout 5)

    local key
    key=$($guard ssh-add -L 2>/dev/null | head -1) || return
    [[ -n $key ]] || return

    local probe
    probe=$(mktemp) || return
    print -r -- $key > $probe
    $guard ssh-add -T $probe >/dev/null 2>&1 && ln -sfn $SSH_AUTH_SOCK $link
    rm -f $probe
}
