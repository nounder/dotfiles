function dotfiles-edit
    cd ~/dotfiles

    edit-with-fallback
end

alias co=dotfiles-edit

function edit-with-fallback
    if test (count $argv) -gt 0
        nvim $argv
    else
        nvim -c ":lua require('telescope').extensions['recent-files'].recent_files({})"
    end
end

alias er=edit-recent-cwd
alias eg="nvim -c ':Neogit kind=replace"
alias es="nvim -c ':Neogit kind=replace"


function today
    set DAYS 0

    if set -q argv[1]
        set DAYS $argv[1]

        if test $DAYS -gt 0
            set DAYS "+$DAYS"
        else if test $DAYS -lt 0
            set DAYS "-"(math abs $DAYS)
        end
    end

    set NAME (date "+%Y-%m-%d")

    if ! test $DAYS -eq 0
        set NAME (date -v"$DAYS"d "+%Y-%m-%d")
    end

    set FILE ~/Documents/Journal/$NAME.md

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
