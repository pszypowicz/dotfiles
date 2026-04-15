# Candidate source for fzf's Alt-C directory jump.
#
# From $HOME: emit a curated list of "places I actually jump to" -
#   - every git repository under ~/Developer (discovered by presence of .git,
#     so any host layout works: github.com/owner/repo, dev.azure.com/org/project/repo, etc.)
#   - top-level directories inside ~/Developer/_scratch (non-repo playgrounds)
#
# From anywhere else: fall back to fd's normal recursive directory walk
# rooted at $PWD, so Alt-C still works as a general-purpose jump tool
# once you're already inside a project.
function __fzf_alt_c_source
    if test "$PWD" = "$HOME"
        fd --type d --hidden --prune '^\.git$' "$HOME/Developer" --exec dirname
        fd --type d --max-depth 1 . "$HOME/Developer/_scratch"
    else
        fd --type d
    end
end
