# In-scope Claude project transcript dirs under ~/.config/claude/projects: the
# current project's dir (PWD path with non-alnum runs collapsed to dashes), or
# every project's dir with --all. Shared by ,cr (via __claude_sessions) and ,cs
# so their default-vs-all scoping stays in sync.
function __claude_project_dirs --description 'In-scope Claude project dirs (PWD, or all with --all)'
    if test "$argv[1]" = --all
        find ~/.config/claude/projects -mindepth 1 -maxdepth 1 -type d 2>/dev/null
    else
        echo ~/.config/claude/projects/(string replace -ar '[^a-zA-Z0-9-]' - $PWD)
    end
end
