function _fzf_search_directory --description "Search the current directory. Replace the current token with the selected file paths."

    # Directly use fd binary to avoid output buffering delay caused by a fd alias, if any.
    # Debian-based distros install fd as fdfind and the fd package is something else, so
    # check for fdfind first. Fall back to "fd" for a clear error message.
    set -f fd_cmd (command -v fdfind || command -v fd  || echo "fd")
    set -f --append fd_cmd --color=always $fzf_fd_opts

    set -f fzf_arguments --multi --ansi $fzf_directory_opts
    set -f token (commandline --current-token)
    # expand any variables or leading tilde (~) in the token
    set -f expanded_token (eval echo -- $token)
    # unescape token because it's already quoted so backslashes will mess up the path
    set -f unescaped_exp_token (string unescape -- $expanded_token)

    # If the current token is a directory and has a trailing slash,
    # then use it as fd's base directory.
    if string match --quiet -- "*/" $unescaped_exp_token && test -d "$unescaped_exp_token"
        set --append fd_cmd --base-directory=$unescaped_exp_token
        # don't hide any files. if user is scoping, assume they want to see everything
        set --append fd_cmd --no-ignore
        # use the directory name as fzf's prompt to indicate the search is limited to that directory
        set --prepend fzf_arguments --prompt="Directory $unescaped_exp_token> " --preview="_fzf_preview_file $expanded_token{}"
        set -f file_paths_selected $unescaped_exp_token($fd_cmd 2>/dev/null | _fzf_wrapper $fzf_arguments)
    else
        set --prepend fzf_arguments --prompt="Directory> " --query="$unescaped_exp_token" --preview='_fzf_preview_file {}'
        # Only use frecency prioritization in git repos
        if project_root >/dev/null 2>&1
            # --tiebreak=index preserves frecency order when fzf scores are equal
            set --append fzf_arguments --tiebreak=index
            # Prepend history entries (sorted by frecency) to fd output
            set -f cwd (pwd)/
            set -f file_paths_selected (begin
                # Get frecency-sorted history, filter to current dir
                for f in (_fzf_history_get)
                    if string match -q "$cwd*" "$f"
                        set -l rel (string replace "$cwd" "" "$f")
                        # Strip trailing slash for consistency with fd output
                        set rel (string trim -r -c / "$rel")
                        test -e "$rel" && echo "$rel"
                    end
                end
                $fd_cmd 2>/dev/null
            end | awk '!seen[$0]++' | _fzf_wrapper $fzf_arguments)
        else
            set -f file_paths_selected ($fd_cmd 2>/dev/null | _fzf_wrapper $fzf_arguments)
        end
    end

    if test $status -eq 0
        # Save selected files to history
        _fzf_history_add $file_paths_selected

        # If the command line was empty, open the file in $EDITOR
        if test -z "$token" && test -z (commandline)
            commandline --function repaint
            $EDITOR $file_paths_selected
        else
            commandline --current-token --replace -- (string escape -- $file_paths_selected | string join ' ')
        end
    end

    commandline --function repaint
end
