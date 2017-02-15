#!/usr/bin/env bash
# mamerow.sh
############
#
# Show info about the ROM from MAME ROW gamelist.
#
# random.org URL to get a MAME ROW random number:
# https://www.random.org/integers/?num=1&min=2&max=2185&col=1&base=10&format=plain&rnd=new
#
# TODO:
# - use single letters for the non-random rounds (phoenix and nrallyx)
# - [DONE]the gamelist integrity checking/fixing must be the first thing this script does
# - [DONE] MAIN MENU
#   - [DONE] create new post
#   - [DONE] manage gamelist
#       - [DONE] update with a new round
#       - [DONE] edit previous round info
#       - get gamelist from github
#       - send gamelist to github
#   - [DONE] previous rounds information

readonly GAMELIST_URL="https://raw.githubusercontent.com/meleu/mame-row-management/master/mamerow_gamelist.txt"
readonly GAMELIST=mamerow_gamelist.txt
readonly BACKTITLE="MAME ROW management tool"
readonly MIN=2
readonly MAX=2185
readonly ROUND_URL_TEMPLATE="https://retropie.org.uk/forum/"

ROUND_LIST=
LAST_ROUND=
LAST_ROUND_GAME=

POLL_URL=

# game info
ROM_DATA=
NUMBER=
GAME=
COMPANY=
YEAR=
ROM_FILE=
BIOS=
SAMPLE=
ROUND=
URL=



# dialog functions ##########################################################

function dialogMenu() {
    local text="$1"
    shift
    dialog --no-mouse --backtitle "$BACKTITLE" --menu "$text\n\nChoose an option." 17 75 10 "$@" 2>&1 > /dev/tty
}



function dialogInput() {
    local text="$1"
    shift
    dialog --no-mouse --backtitle "$BACKTITLE" --inputbox "$text" 9 70 "$@" 2>&1 > /dev/tty
}



function dialogYesNo() {
    dialog --no-mouse --backtitle "$BACKTITLE" --yesno "$@" 15 75 2>&1 > /dev/tty
}



function dialogMsg() {
    dialog --no-mouse --backtitle "$BACKTITLE" --msgbox "$@" 20 70 2>&1 > /dev/tty
}



function dialogInfo {
    dialog --infobox "$@" 8 50 2>&1 >/dev/tty
}



function dialogEditForm() {
    local game_number="$1"
    local new_round="$2"
    local new_url="$3"
    dialog --no-mouse --backtitle "$BACKTITLE" \
        --form "Editing MAME ROW data for $game_number \"$(get_game_name "$game_number")\"\n(Enter 'x' for Round # to delete this round)" 17 75 5 \
        "Round #:" 1 1 "$new_round" 1 10 5 4 \
        "URL    :" 2 1 "$new_url"   2 10 80 0 \
        2>&1 > /dev/tty
}

# end of dialog functions ###################################################



# menu functions ############################################################

function main_menu() {
    local choice

    while true; do
        choice=$(dialogMenu "Last round: #$LAST_ROUND\nGame: \"$LAST_ROUND_GAME\"\nURL: $LAST_ROUND_URL" \
            1 "Create a new MAME ROW post" \
            2 "Manage MAME ROW gamelist" \
            3 "Previous rounds"
        )
        case "$choice" in
            1)
                create_new_post
                ;;

            2)
                manage_gamelist_menu
                ;;

            3)
                previous_rounds_info
                ;;

            *)
                break
                ;;
        esac
    done
}



function create_new_post() {
    local next_round="$[ LAST_ROUND + 1]"
    local numbers=()
    local poll_url
    local entries=()
    local entry
    local round
    local game
    local url

    while true; do
        round=$(dialogInput "Do you want to create a post for which MAME ROW round?" "$next_round") || return

        # the right choice!
        [[ "$round" -eq "$next_round" ]] && break

        validate_round "$round" || continue

        dialogYesNo "The next round should be #$next_round but you chose #$round.\n\nAre you sure you want to create a post for round #$round?" \
        && break
    done

    numbers=( $(get_random_game_numbers) )

    dialogMsg "\
The three random games for MAME ROW #$round are:\n\n
${numbers[0]}: $(get_game_name ${numbers[0]})\n
${numbers[1]}: $(get_game_name ${numbers[1]})\n
${numbers[2]}: $(get_game_name ${numbers[2]})\n\n
Press <ENTER> to get the link to create the poll."

    poll_url="$(create_poll "$round" ${numbers[@]})"

    # WE HAVE EVERYTHING WE NEED TO CREATE THE POST!!!
    post_file="post-mame-row-$round.md"

    cat > "$post_file" << _EoF_
# This is the **MAME** **R**andom **O**f the **W**eek #$round

The three random numbers for this week are: ${numbers[0]}, ${numbers[1]}, ${numbers[2]}.

## [Click here to vote which game you choose for MAME ROW #$round]($poll_url)

The result of the poll is posted on Wednesday, so we have Monday and Tuesday for experimentation.

$(show_game_info_f md ${numbers[@]})

_EoF_

    cat text.md >> "$post_file"

    echo -e "## Links to the previous \"rounds\"\n" >> "$post_file"

    echo "$ROUND_LIST" \
    | while read -r entry; do
        round=$(echo "$entry" | cut -d\; -f2)
        game=$(get_game_name $(echo $entry | cut -d\; -f1))
        url=$(echo "$entry" | cut -d\; -f3)
        echo "$round. [$game]($url)"
    done >> "$post_file"

    dialogMsg "DONE!\n\nThe post content is ready!\n\nJust copy the content of \"$post_file\" file and post it!"
}



function manage_gamelist_menu() {
    # TODO: remove not_implemented
    local not_implemented="\nNOTE: options with \"!!\" are not implemented."
    local choice
    local cmd=(dialogMenu "Manage MAME ROW gamelist $not_implemented"
        1 "Update gamelist with a new round information"
        2 "Edit a previous round information"
        3 "!!Get gamelist from the github repository"
        4 "!!Send the local gamelist to the github repository"
    )
    while true; do
        choice=$("${cmd[@]}")
        case "$choice" in
            1)
                update_gamelist
                ;;

            2)
                while true; do
                    edit_previous_round_menu "Edit round information" || break
                done
                ;;

            3)
                dialogMsg "TODO: download_gamelist"
                ;;

            4)
                dialogMsg "TODO: send_gamelist"
                ;;

            *)
                break
                ;;
        esac
    done
}



function edit_previous_round_menu() {
    local round
    local form
    local new_round
    local new_url
    local ret

    round=$(edit_gamelist_menu "$@")
    [[ -z "$round" ]] && return 1
    fill_game_data $(get_game_number_by_round "$round")
    new_round="$ROUND"
    new_url="$URL"

    while true; do
        form=( $(dialogEditForm "$round" "$new_round" "$new_url") ) || return 0

        new_round="${form[0]}"
        new_url="${form[@]:1}"

        if [[ "$ROUND" == "$new_round" && "$URL" == "$new_url" ]]; then
            dialogMsg "Nothing changed!"
            break
        fi

        if [[ "$ROUND" != "$new_round" ]]; then
            validate_round "$new_round" || continue
        fi

        if [[ "$URL" != "$new_url" ]]; then
            validate_url "$new_url"
            ret=$?
            if [[ "$ret" -ne 0 ]]; then
                [[ "$ret" -ne 2 ]] && continue
                dialogYesNo "GAMELIST INCONSISTENCY WARNING!\n\nAre you really sure you want to change the \"$GAME\" MAME ROW URL?\nOld URL: $URL\nNew URL: $new_url" \
                || continue
            fi
        fi

        [[ "$new_round" == "x" ]] && new_url=""
        dialogYesNo "CURRENT INFO:\nRound #: $ROUND\nURL: $URL\n\nNEW INFO:\nRound #: $new_round\nURL: $new_url\n\nDo you accept the changes?" \
        || break

        # if reach this point, the user really want to change info
        set_round_and_url "$NUMBER" "$new_round" "$new_url"
        break
    done
}



function edit_gamelist_menu() {
    local cmd=(dialogMenu "$1 ")
    shift
    local options=( "$@" )
    local round_number_list
    local i
    
    if [[ "${#options[@]}" -eq 0 ]]; then
        # explaining the regex below (negated by grep -v):
        # zero or more digits followed by ';' followed by (0 OR non-digit)
        round_number_list=$(echo "$ROUND_LIST" | grep -v '^[0-9]*;\(0\|[^0-9]\)' | cut -d\; -f2)

        # TODO: show the not randomly chosen rounds too (use letters as tags)
        for i in $round_number_list; do
            options+=( "$i" "$(get_game_name_by_round "$i")")
        done
    fi

    "${cmd[@]}" "${options[@]}"
}



function previous_rounds_info() {
    local round
    while true; do
        round=$(edit_gamelist_menu "Show info about previous a previous round.")
        [[ -z "$round" ]] && break
        dialogMsg "$(show_round_info "$round")"
    done
}



function update_gamelist() {
    local round
    local game_name
    local tmp
    local url
    local next_round=$[ LAST_ROUND + 1 ]

    # getting the round from user
    #############################
    while true; do
        round=$(dialogInput "Enter the round number" "$next_round") || return

        # the right choice!
        [[ "$round" -eq "$next_round" ]] && break

        validate_round "$round" || continue

        dialogYesNo "The next round should be #$next_round but you chose #$round.\n\nAre you sure you want to update info for round #$round?" \
        && break
    done
    
    # getting game_number from user
    ###############################
    while true; do
        game_number=$(dialogInput "Enter the game number") || return

        validate_game_number "$game_number" || continue

        game_name=$(get_game_name "$game_number")
        dialogYesNo "The game number $game_number corresponds to the game \"$game_name\"\n\nDo you want to continue?" \
        && break
    done

    # getting URL from user
    #######################
    while true; do
        url=$(dialogInput "Enter the MAME ROW #$round URL" "$ROUND_URL_TEMPLATE") || return

        validate_url "$url" || continue

        dialogYesNo "Confirm URL for MAME ROW #$round - \"$game_name\":\n\n$url" \
        && break
    done

    # if reach this point, everything is OK, just update
    ####################################################
    set_round_and_url "$game_number" "$round" "$url"
}



function validate_round() {
    local round="$1"
    local tmp

    [[ -z "$round" ]] && return 1

    # 'x' is valid (the user wants to delete)
    [[ "$round" == "x" ]] && return 0

    # must be a number
    [[ "$round" =~ ^[[:digit:]]+$ ]] || return 1

    # round must be in [1, 2185[
    if [[ "$round" -lt $[ MIN - 1 ] || "$round" -ge $MAX ]]; then
        dialogMsg "ERROR!\n\nInvalid round number: $round\n\nThe round number must be between $[MIN-1] and $[MAX-1] (inclusive)."
        continue
    fi

    # this round exists
    tmp=$(get_game_name_by_round "$round")
    if [[ -n "$tmp" ]]; then
        dialogMsg "ERROR!\n\nThe round #$round already exists in gamelist.\nThe game is \"$tmp\"."
        return 2
    fi

    # if reach this point, the round is valid
    return 0
}



function validate_game_number() {
    local game_number="$1"
    local tmp

    # type something!
    [[ -z "$game_number" ]] && return 1

    # not a number
    [[ "$game_number" =~ ^[[:digit:]]+$ ]] || return 1

    # invalid game number
    if [[ "$game_number" -lt $MIN || "$game_number" -gt $MAX ]]; then
        dialogMsg "ERROR!\n\nInvalid game number: $game_number\n\nThe game number must be between $MIN and $MAX (inclusive)."
        return 1
    fi

    # this game was played in a previous round
    tmp=$(get_round_by_game_number "$game_number")
    if [[ -n "$tmp" ]]; then
        dialogMsg "ERROR!\n\nThe game $game_number \"$(get_game_name $game_number)\" was played in MAME ROW #$tmp!"
        return 2
    fi
}



function validate_url() {
    local url="$1"
    local tmp

    # if it's not a retropie forum URL, ask again
    if ! [[ "$url" =~ ^${ROUND_URL_TEMPLATE}..* ]]; then
        dialogMsg "ERROR!\n\nThe URL provided isn't a valid RetroPie forum URL!\n\nPlease, provide an URL starting with \"$ROUND_URL_TEMPLATE\""
        return 1
    fi

    tmp=$(get_round_by_url "$url")
    if [[ -n "$tmp" ]]; then
        dialogMsg "ERROR!\n\nThis is the same URL as the MAME ROW #$tmp - \"$(get_game_name_by_round $tmp)\"."
        return 2
    fi

}

# end of menu functions #####################################################



# gamelist functions ########################################################

# args:
# $1 - the game number
function fill_game_data() {
    if [[ -z "$1" ]]; then
        echo "ERROR: fill_game_data(): missing arguments!" >&2
        exit 1
    fi

    local number="$1"

    ROM_DATA=$(sed -n ${number}p "$GAMELIST")

    # checking if the gamelist has this game (gamelist is corrupted?)
    if [[ -z "$ROM_DATA" ]]; then
        echo "ERROR: there's no game with number \"$number\"." >&2
        return 1
    fi

    NUMBER=$number
    GAME=$(    echo "$ROM_DATA" | cut -d\; -f2 )
    COMPANY=$( echo "$ROM_DATA" | cut -d\; -f11)
    YEAR=$(    echo "$ROM_DATA" | cut -d\; -f10)
    ROM_FILE=$(echo "$ROM_DATA" | cut -d\; -f1 )
    BIOS=$(    echo "$ROM_DATA" | cut -d\; -f7 )
    SAMPLE=$(  echo "$ROM_DATA" | cut -d\; -f8 )
    ROUND=$(   echo "$ROM_DATA" | cut -d\; -f12 | tr -d '\n\r' )
    URL=$(     echo "$ROM_DATA" | cut -d\; -f13 | tr -d '\n\r' )
}



function update_round_list() {
    ROUND_LIST=$(
        cut -s -d\; -f 12-13 "$GAMELIST" \
        | grep -vn '\(^$\|^;\)' \
        | sed 's/:/;/' \
        | tail -n +2 \
        | sort -t\; -k2 -n
    )
    LAST_ROUND=$(echo "$ROUND_LIST" | tail -1 | cut -d\; -f2)
    LAST_ROUND_GAME_NUMBER=$(echo "$LAST_ROUND" | cut -d\; -f1)
    LAST_ROUND_GAME=$(get_game_name_by_round "$LAST_ROUND")
    LAST_ROUND_URL=$(get_url_by_round "$LAST_ROUND")
}



# args:
# $1    - use "md" for markdown, any other string for no formats
# $2... - game numbers
function show_game_info_f() {
    local f
    local i

    [[ "$1" = "md" ]] && f="**"
    shift

    if [[ -z "$1" ]]; then
        echo "ERROR: show_game_info_f(): missing game number!" >&2
        return 1
    fi

    for i in "$@"; do
        fill_game_data "$i" || return 1
        [[ -n "$ROUND"  ]] && echo "${f}MAME ROW #:${f} $ROUND"
        [[ -n "$URL"    ]] && echo "${f}MAME ROW URL:${f} $URL"
        echo "${f}Number:${f} ${NUMBER}"
        echo "${f}Game Name:${f} $GAME"
        echo "${f}Company:${f} $COMPANY"
        echo "${f}Year:${f} $YEAR"
        echo "${f}ROM file name:${f} $ROM_FILE.zip"
        [[ -n "$BIOS"   ]] && echo "${f}BIOS:${f} $BIOS"
        [[ -n "$SAMPLE" ]] && echo "${f}Sample:${f} $SAMPLE"
        echo
    done
}



function show_game_info() {
    show_game_info_f nf $1
}



function show_round_info() {
    show_game_info_f nf $(get_game_number_by_round $1)
}



function get_game_name() {
    local i
    for i in "$@"; do
        fill_game_data "$i" || continue
        echo "$GAME"
    done
}



# arg:
# $1 - the GameNumber you want to get the RoundNumber
function get_round_by_game_number() {
    echo "$ROUND_LIST" | grep -m 1 "^$1;" | cut -d\; -f2
}



function get_round_by_url() {
    echo "$ROUND_LIST" | grep -m 1 ";$1$" | cut -d\; -f2
}



# arg:
# $1 - the RoundNumber you want to get the GameNumber
function get_game_number_by_round() {
    echo "$ROUND_LIST" | grep -m 1 "[0-9]\+;$1\(;\|$\)" | cut -d\; -f1
}



function get_game_name_by_round() {
    get_game_name $(get_game_number_by_round "$1")
}



function get_url_by_round() {
    fill_game_data $(get_game_number_by_round "$1")
    echo "$URL"
}



# possible problems in gamelist
# - repeated rounds (0 can repeat)
# - rounds with invalid data (not a number)
# - rounds with no URL
# - repeated URLs
function check_gamelist_integrity() {
    local game_number
    local invalid_rounds
    local repeated_rounds
    local round_sequence=()
    local err_msg
    local previous_round_game
    local i j
    local err_round_url=()
    local valid_round_regex="^[^;]\+;[[:digit:]]\+"
    # explaing the regex:
    # from the start of the line, one or more "not-;", followed by ';'
    # followed by one or more digits, followed by ";http"

#    dialog --infobox "Checking gamelist integrity..." 3 40 
    dialogInfo "\n\nChecking gamelist integrity..."

    # checking if the round number is a number
    ##########################################
    invalid_rounds=$(echo "$ROUND_LIST" | grep -v "$valid_round_regex")
    if [[ -n "$invalid_rounds" ]]; then
        game_number=$(echo "$invalid_rounds" | cut -d\; -f1 | xargs)

        for i in $game_number; do # no quotes surrounding $game_number is mandatory!
            dialogMsg "\nThe field used to record the round number for $i \"$(get_game_name "$i")\" has invalid data.\n\nRemoving the bad data..." \
            || exit 1
            set_round_and_url "$i" "x" ""
        done
    fi

    # checking repeated round numbers (ignoring round 0)
    ####################################################
    repeated_rounds=$(echo "$ROUND_LIST" | cut -d\; -f2 | uniq -d | tr -d 0)
    while [[ -n "$repeated_rounds" ]]; do
        for i in $repeated_rounds; do # no quotes is mandatory
            game_number=$(echo "$ROUND_LIST" | grep "^[^;]\+;$i" | cut -d\; -f1)
            for j in $game_number; do # no quotes is mandatory
                dialogMsg "\nThe game $j \"$(get_game_name "$j")\" has a repeated round number ($i).\n\nRemoving the bad data..." \
                || exit 1
                set_round_and_url "$j" "x" ""
            done
        done
        repeated_rounds=$(echo "$ROUND_LIST" | cut -d\; -f2 | uniq -d | tr -d 0)
    done


    # check if the round numbers are in sequence
    ############################################
    # the round_sequence below gets the round numbers (cut -f2)
    round_sequence=( $(echo "$ROUND_LIST" | grep "$valid_round_regex" | cut -d\; -f2 | grep -v '^0$') )

    j=0
    previous_round_game=$(get_game_name_by_round 1)
    for i in "${round_sequence[@]}"; do
        let j+=1
        if [[ "$j" != "$i" ]]; then
            ret=1
            err_msg+="\nThe rounds sequence is broken after MAME ROW #$[j-1]: "
            err_msg+="\"$previous_round_game\"\n"
            err_msg+="No game found for round"
            if [[ "$[i-j]" -ne 1 ]]; then
                err_msg+="s #${j}-$[i-1]\n"
            else
                err_msg+=" #$j\n"
            fi

            j="$i"
        fi

        previous_round_game=$(get_game_name_by_round "$i")
    done
    [[ -n "$err_msg" ]] && dialogMsg "WARNING: There's a discontinuity in the rounds sequence.\n\n$err_msg\n\nUse the \"Manage MAME ROW gamelist\" option and fix it."

    # check if the URL is OK
    ########################
    while true; do
        for i in "${round_sequence[@]}"; do
            [[ "$(get_url_by_round $i)" != "$ROUND_URL_TEMPLATE"* ]] \
            && err_round_url+=( "$i" "$(get_game_name_by_round $i)" )
        done
        [[ "${#err_round_url[@]}" -eq 0 ]] && break
        edit_previous_round_menu "ERROR: Rounds with problems in URL" "${err_round_url[@]}"
        err_round_url=()
    done

    return "$ret"
}



function set_round_and_url() {
    local game_number="$1"
    local round="$2"
    local url="$3"
    local field
    local new_rom_data
    local check_rom_data

    fill_game_data "$game_number"

    IFS=\; read -a field << _EoF_
$ROM_DATA
_EoF_

    # if round == x, delete this round
    if [[ "$round" == "x" ]]; then
        round=""
        url=""
    fi

    new_rom_data=$(
        for i in $(seq 0 ${#field[@]} ); do
            [[ $i -eq 11 ]] && break
            echo -n "${field[$i]};"
        done
        [[ $i -eq 11 ]] && echo -n "$round;$url"
    )

    sed -i "${game_number}c\\$new_rom_data" "$GAMELIST"

    check_rom_data=$(sed -n ${game_number}p "$GAMELIST")
    if [[ "$check_rom_data" = "$new_rom_data" ]]; then
        dialogMsg "SUCCESS!\n\nThe gamelist was successfully updated with this info:\n\n$(show_game_info $game_number | sed 's/$/\\n/')"
        update_round_list
    else
        dialogMsg "ERROR!\n\nFailed to update the gamelist!"
    fi
}

# end of gamelist functions #################################################



# other functions ###########################################################

function get_random_game_numbers() {
    local count=0
    local number
    local round
    local game
    local numbers=()
    local i

#XXX: debugging
#j=0
    while [[ "$count" -lt 3 ]]; do
#let j+=1
#number=$(sed -n ${j}p numbers.txt)
# XXX: end of debugging tricks

        number=$(curl -s "https://www.random.org/integers/?num=1&min=2&max=2185&col=1&base=10&format=plain&rnd=new")

        # XXX: I'm not sure if it is enough to detect problems
        if [[ -z "$number" ]]; then
            dialogMsg "ERROR: unable to get a random number!"
            return 1
        fi

        dialogInfo "\nGot number $number.\n\nChecking if it's OK..."

        # checking if this number was already sorted (really rare condition)
        for i in 0 1 2; do
            [[ "$number" != "${numbers[$i]}" ]] && continue
            echo "Ignoring \"$number\": repeated number." >&2
            continue 2
        done

        round="$(get_round_by_game_number $number)"
        game="$(get_game_name $number)"

        if [[ -n "$round" ]]; then
            echo "Ignoring number $number - \"$game\"." >&2
            echo "This game was chosen on MAME ROW #$round" >&2
            continue
        fi

        # checking if it's a Mahjong
        if [[ "$game" =~ [Mm][Aa][Hh][Jj][Oo][Nn][Gg] ]]; then
            echo "Ignoring number $number - $game: it's a Mahjong game." >&2
            continue
        fi

        numbers+=( "$number" )
        let count+=1
    done

    echo ${numbers[@]}
}



function url_encode() {
    echo "$@" | sed '
        s:%:%25:g
        s: :%20:g
        s:<:%3C:g
        s:>:%3E:g
        s:{:%7B:g
        s:}:%7D:g
        s:|:%7C:g
        s:\\:%5C:g
        s:\^:%5E:g
        s:~:%7E:g
        s:\[:%5B:g
        s:\]:%5D:g
        s:`:%60:g
        s:;:%3B:g
        s:/:%2F:g
        s:?:%3F:g
        s^:^%3A^g
        s:@:%40:g
        s:=:%3D:g
        s:&:%26:g
        s:\$:%24:g
        s:\!:%21:g
        s:(:%28:g
        s:):%29:g'
}



function create_poll() {
    if [[ $# -lt 4 ]]; then
        echo "create_poll(): missing arguments!" >&2
        return 1
    fi

    local round
    local poll_url_template="http://www.strawpoll.me/"
    local poll_url
    local post_file
    local question
    local option=()
    local i

    round="$1"
    shift

    question=$(url_encode "What game do you choose for MAME ROW #$round")
    
    for i in 0 1 2; do
        option[$i]=$(url_encode $(get_game_name $1))
        if [[ -z "${option[$i]}" ]]; then
            echo "Failed to create the poll: \"$1\" is an invalid game number" >&2
            return 1
        fi
        shift
    done

    while true; do
        echo >&2
        echo "Use the URL below to create the poll for MAME ROW #$round:" >&2
        echo >&2
        echo "http://www.strawpoll.me/#?savedPoll=%7B%22title%22:%22${question}?%22,%22dupcheck%22:%221%22,%22multi%22:false,%22captcha%22:false,%22options%22:%5B%22${option[0]}%22,%22${option[1]}%22,%22${option[2]}%22%5D%7D" >&2
        echo >&2
        echo "Press <ENTER> to continue..." >&2
        read

        while true; do
            poll_url=$(dialogInput "Enter the created poll URL (or cancel to get the link to the draft again)" "$poll_url_template") \
            || continue 2

            # if it's not a retropie forum URL, ask again
            [[ "$poll_url" =~ ^${poll_url_template}..* ]] && break 2

            dialogMsg "ERROR!\n\nThe URL provided isn't a strawpoll.me URL!\n\nPlease, provide an URL starting with \"$poll_url_template\""
            continue
        done
    done

    echo "$poll_url"
}




# start here ################################################################

if ! [[ -f "$GAMELIST" ]]; then
    echo "\"$GAMELIST\": file not found!" >&2
    # TODO: try to download the gamelist from $GAMELIST_URL
    exit 1
fi

update_round_list

check_gamelist_integrity

main_menu
