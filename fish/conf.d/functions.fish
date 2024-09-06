function dotfiles-edit
    cd ~/dotfiles

    e
end

function today
    set -l NAME (date "+%Y-%m-%d")
    set -l FILE ~/Documents/Journal/$NAME.md

    if test -f $FILE
        e $FILE
    else
        echo $NAME \n==========\n\n >$FILE
        e +4 $FILE
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
