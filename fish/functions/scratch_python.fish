function scratch_python
    set -l TS (date +%y%m%d)
    set -l HM (date +%H%M)
    set -l PREFIX $HM"-"

    set -l BASE $HOME/Hacks

    set -l TARGET_DIR $BASE/$TS"-"$PREFIX"python"

    mkdir $TARGET_DIR

    cd $TARGET_DIR

    cp -r $HOME/dotfiles/templates/python-scratch/ .

    git init

    direnv load

    $EDITOR main.py
end
