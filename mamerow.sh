#!/bin/bash
# mamerow.sh
############
#
# Show info about the ROM from MAME ROW gamelist.
#

readonly gamelist=mamerow_gamelist.txt

USAGE="
Usage:
$(basename $0) number1 [number2 [number3]]
"

if [[ -z "$1" ]]; then
    echo "$USAGE"
    exit 1
fi


for number in $@; do
    # checking if it's a number
    if ! [[ $number =~ ^[0-9]+$ ]]; then
        echo "Ignoring \"$number\": not a positive integer." >&2
        continue
    fi

    rom_info=$(sed -n ${number}p "$gamelist")

    if [[ -z "$rom_info" ]]; then
        echo "Ignoring \"$number\": there's no game with this number." >&2
        continue
    fi

    game_name=$(echo "$rom_info" | cut -d\; -f2 )
    company=$(  echo "$rom_info" | cut -d\; -f11)
    year=$(     echo "$rom_info" | cut -d\; -f10)
    rom_file=$( echo "$rom_info" | cut -d\; -f1 )
    bios=$(     echo "$rom_info" | cut -d\; -f7 )
    sample=$(   echo "$rom_info" | cut -d\; -f8 )

    echo "
$number
**Game Name:** $game_name
**Company:** $company
**Year:** $year
**ROM file name:** ${rom_file}.zip"

    [[ -n "$bios"   ]] && echo "**BIOS:** $bios"
    [[ -n "$sample" ]] && echo "**Sample:** $sample"
    echo
done
