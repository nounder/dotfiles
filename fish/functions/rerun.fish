function rerun --description "Watch DIR [DIR…]; rerun CMD [ARGS…] on change"
    set -l idx (contains -i -- -- $argv)
    if test $idx -le 1
        echo "Usage: watchrun DIR [DIR…] -- CMD [ARGS…]" >&2
        return 1
    end
    set -l dirs $argv[1..(math $idx - 1)]
    set -l cmd $argv[(math $idx + 1)..-1]

    for dir in $dirs
        echo "Watching: "(realpath $dir)
    end

    printf '%s  %s\n' (date '+%F %T') "Running initial command"
    command $cmd

    fswatch -r -l 1 $dirs | while read -l change
        printf '%s  %s\n' (date '+%F %T') "$change"
        command $cmd
    end
end
