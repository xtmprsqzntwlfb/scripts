#!/usr/bin/env sh
function convert_path(){
    # Author: djcj <djcj@gmx.de>
    last="$1"

    to_unix=no
    mixed_mode=no
    realpath=no
    subst_home=no

    p=$(echo $last | sed -e 's|\\\+|/|g;s|/\+|/|g')

    if [ "${p:0:1}" = / ]; then
        if [ -n "$(echo ${p:0:7} | grep -e '^/[a-z]/\?$')" ]; then
            drive=${p:5:1}
            p=${drive^^}:${p:6}
        elif [ -n "$(echo ${p:0:3} | grep -e '^/[a-z]/\?$')" ]; then
            drive=${p:1:1}
            p=${drive^^}:${p:2}
        else
            firstDir=/$(echo $p | cut -d'/' -f2)
            offset=$(printf "$firstDir" | wc -m)
            rootDirs=$(grep -e ' lxfs ' /proc/mounts | awk '{print $2}')
            if [ -z "$(echo $rootDirs | tr ' ' '\n' | grep -e "^$firstDir\$")" ]; then
                firstDir=/
                offset=0
            fi
            p=$lxss/$(grep -e " $firstDir " /proc/mounts | awk '{print $1}')${p:$offset}
        fi
    fi
    if [ $mixed_mode = no ]; then
        p=$(echo $p | tr '/' '\\')
    fi
    echo $p
}

windows() { [[ -n "$WINDIR" ]]; }

function symlink(){
    if [ -z "$1" ] || [ -z "$2" ]
    then
        echo "Error: LINK and TARGET not provided"
        echo "Usage: symlink <TARGET> <LINK>"
        return
    fi
    target="$1"
    link="$2"

    if windows; then
        # Windows needs to be told if it's a directory or not. Infer that.
        # Also: note that we convert `/` to `\`. In this case it's necessary.
        if [[ -d "$target" ]]; then
            cmd <<< "mklink /D \"$(convert_path $link)\" \"$(convert_path $target)\"" > /dev/null
        else
            cmd <<< "mklink \"$(convert_path $link)\" \"$(convert_path $target)\"" > /dev/null
        fi
    else
        # You know what? I think ln's parameters are backwards.
        ln -s "$target" "$link"
    fi
}

args="$@"
for file in $args
do
    if [[ -f "install-location.txt" ]]
    then
        link="$(cat install-location.txt)\\hack\\scripts\\$file"
        if [[ -f "$link" ]]
        then
            rm "$link"
        fi
        symlink "$(realpath $file)" "$link"
    fi
done