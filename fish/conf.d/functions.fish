function dotfiles-edit
    cd ~/dotfiles

    e
end

function today
    set -l DAYS 0
    if set -q argv[1]
        set DAYS $argv[1]
        if test $DAYS -gt 0
            set DAYS "+$DAYS"
        else if test $DAYS -lt 0
            set DAYS "-"(math abs $DAYS)
        end
    end

    set -l NAME (date "+%Y-%m-%d")

    if ! test $DAYS -eq 0
        set -l NAME (date -v"$DAYS"d "+%Y-%m-%d")
    end

    echo $NAME

    set -l FILE ~/Documents/Journal/$NAME.md

    if test -f $FILE
        $EDITOR $FILE
    else
        echo $NAME \n==========\n\n >$FILE
        $EDITOR +4 $FILE
    end
end



function tomorrow
    set -l NAME (date -v+1d "+%Y-%m-%d")
    set -l FILE ~/Documents/Journal/$NAME.md

    if test -f $FILE
        e $FILE
    else
        echo $NAME \n==========\n\n >$FILE
        e +4 $FILE
    end
end



function llama
    mods -m llama3.1-70b $argv
end


alias ai="mods"
alias ac="mods -C"
alias ap="mods --role code"
alias as="mods --role shell"
