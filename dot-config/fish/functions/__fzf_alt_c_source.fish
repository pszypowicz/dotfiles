# Candidate source for fzf's Alt-C directory jump.
#
# From $HOME: emit the curated ~/Developer repo list via
# __fzf_developer_repos so the most-recently-visited repos sit right
# under the fzf prompt for fast arrow-key selection without typing.
#
# From anywhere else: fall back to zoxide frecency plus fd's recursive
# walk rooted at $PWD, so Alt-C stays useful for both "jump within this
# project" and "jump to another project without going back to $HOME first".
function __fzf_alt_c_source
    if test "$PWD" = "$HOME"
        __fzf_developer_repos
    else
        begin
            zoxide query --list 2>/dev/null
            fd --type d
        end | awk '!seen[$0]++'
    end
end
