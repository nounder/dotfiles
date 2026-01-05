function _fzf_history_add --description "Add files to fzf file history with frecency"
    set -l history_file "$HOME/.local/share/fzf_file_history"
    set -l now (date +%s)

    # Half-lives in seconds
    set -l hourly_half 3600
    set -l daily_half 86400
    set -l monthly_half 2592000

    mkdir -p (dirname "$history_file")
    touch "$history_file"

    # Load existing entries into associative-style lists
    set -l paths
    set -l hourlies
    set -l dailies
    set -l monthlies
    set -l timestamps

    for line in (cat "$history_file")
        set -l parts (string split ":" "$line")
        test (count $parts) -lt 5 && continue
        set -a paths $parts[1]
        set -a hourlies $parts[2]
        set -a dailies $parts[3]
        set -a monthlies $parts[4]
        set -a timestamps $parts[5]
    end

    # Bump each selected file
    for f in $argv
        set -l abs_path (realpath "$f" 2>/dev/null)
        test -z "$abs_path" && continue

        # Add trailing slash for directories
        if test -d "$abs_path"
            set abs_path "$abs_path/"
        end

        # Find existing index
        set -l idx 0
        for i in (seq (count $paths))
            if test "$paths[$i]" = "$abs_path"
                set idx $i
                break
            end
        end

        if test $idx -gt 0
            # Decay existing values and add 1
            set -l elapsed (math "$now - $timestamps[$idx]")
            set hourlies[$idx] (math "($hourlies[$idx] * 2^(-$elapsed / $hourly_half)) + 1")
            set dailies[$idx] (math "($dailies[$idx] * 2^(-$elapsed / $daily_half)) + 1")
            set monthlies[$idx] (math "($monthlies[$idx] * 2^(-$elapsed / $monthly_half)) + 1")
            set timestamps[$idx] $now
        else
            # New entry
            set -a paths "$abs_path"
            set -a hourlies 1
            set -a dailies 1
            set -a monthlies 1
            set -a timestamps $now
        end
    end

    # Write back
    true > "$history_file"
    for i in (seq (count $paths))
        echo "$paths[$i]:$hourlies[$i]:$dailies[$i]:$monthlies[$i]:$timestamps[$i]" >> "$history_file"
    end
end
