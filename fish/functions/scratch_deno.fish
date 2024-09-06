function scratch_deno
    set -l TS (date +%y%m%d)
    set -l HM (date +%H%M)
    set -l PREFIX $HM"-"

    set -l BASE $HOME/Hacks

    set -l name (read -p "echo \"Name (default 'scratch'): "\")

    if test -z $name
        set name deno_scratch
    end

    set -l TARGET_DIR $BASE/$TS"-"$PREFIX"$name"

    mkdir $TARGET_DIR

    cd $TARGET_DIR


    echo >deno.json '{
  "tasks": {
    "start": "deno run -A main.ts",
    "dev": "deno run -A --watch main.ts"
  }
}'
    touch main.ts

    $EDITOR main.ts
end
