function _fzf_history_get --description "Get fzf file history sorted by frecency score"
    set -l history_file "$HOME/.local/share/fzf_file_history"
    set -l now (date +%s)

    # Half-lives in seconds
    set -l hourly_half 3600
    set -l daily_half 86400
    set -l monthly_half 2592000

    # Weights
    set -l hourly_weight 720
    set -l daily_weight 30
    set -l monthly_weight 1

    test -f "$history_file" || return

    # Calculate scores and output path:score pairs
    for line in (cat "$history_file")
        set -l parts (string split ":" "$line")
        test (count $parts) -lt 5 && continue

        set -l path $parts[1]
        set -l hourly $parts[2]
        set -l daily $parts[3]
        set -l monthly $parts[4]
        set -l ts $parts[5]

        set -l elapsed (math "$now - $ts")

        # Decay values
        set -l h (math "$hourly * 2^(-$elapsed / $hourly_half)")
        set -l d (math "$daily * 2^(-$elapsed / $daily_half)")
        set -l m (math "$monthly * 2^(-$elapsed / $monthly_half)")

        # Calculate score
        set -l score (math "$h * $hourly_weight + $d * $daily_weight + $m * $monthly_weight")

        echo "$score:$path"
    end | sort -t: -k1 -rn | cut -d: -f2-
end
