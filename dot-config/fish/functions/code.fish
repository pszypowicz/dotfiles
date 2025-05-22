function code
    if test (count $argv) -eq 0
        osascript \
            -e 'tell application "Visual Studio Code" to open "'$PWD'"'
    else if test (count $argv) -eq 1
        osascript \
            -e 'tell application "Visual Studio Code" to open "'(realpath $argv[1])'"'
    else
        return 1
    end
end
