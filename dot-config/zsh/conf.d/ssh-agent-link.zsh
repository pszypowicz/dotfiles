# Point one stable path at whatever agent socket the current ssh session
# forwarded, so ssh_config can name a path that never changes. sshd picks a
# fresh random name under ~/.ssh/agent for every connection, and a process that
# started before the connection - a tmux pane above all - never learns the new
# value. Naming the link instead of the socket keeps those panes working.
#
# Only a forwarded agent lands here. mosh carries no agent channel, so a mosh
# login leaves SSH_AUTH_SOCK empty. A terminal at the machine leaves it empty
# too, because the Secure Enclave agent is selected per host through
# IdentityAgent rather than through the environment. Neither one overwrites a
# link that an ssh session put in place.
if [[ -n ${SSH_AUTH_SOCK:-} && -S $SSH_AUTH_SOCK && $SSH_AUTH_SOCK != $HOME/.ssh/agent-forwarded.sock ]]; then
    ln -sfn "$SSH_AUTH_SOCK" "$HOME/.ssh/agent-forwarded.sock"
fi
