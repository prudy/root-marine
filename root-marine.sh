#!/bin/bash

# A root-marine
# run options: -safety-off
#
# Control:
# ',' - left
# '.' - right
# ' ' - releas
# q   - exit
#
# It is a very simple version. The same PIDs and users can appear multiple times.

key_left=','
key_right='.'
key_release=' '
key_quit="[qQ]"

cols=`tput cols`
lines=`tput lines`

slider_pos=$(($cols/2))
arrow_pos=0
arrow_time=0
arrow_col=0
arrow_speed=100000000
arrow_pattern=''
arrow='|'
tick=10000000
timeout=$tick
lines_time=0
screen[0]=""
line_ticks[0]=0
line_weight[0]=1
max_weight=5
obj_max_len=11
wave='~'
border_wave="$(yes $wave | head -n$(($obj_max_len+1)) | tr -d '\n')"
first_line=$(($lines/3))
last_line=$(($lines*2/3))
hit_pos=0
hit_line=$first_line
hit_stage=0
hit_obj=""
hit_len=0
safe_mode=1
PIDS=()
USERS=()
USER=""
PID=""
obj_random_level=100
user_random_level=500
pid_users_update_delay=10
pid_users_time=0
abbys_random_level=500

[ "$1" == "-safety-off" ] && safe_mode=0

renice -n -20 $$ &>/dev/null

function Logo {
L[0]='                 |'
L[1]='               \ _ /'
L[2]='             -= (_) =-             _\/'
L[3]='               /   \               /o\\'
L[4]="                 |                  |\"'\"\"_\/_"
L[5]="                                  -'|    //o\-,                         ,~"
L[6]="                                 \"         |   \"',-,                    |\ "
L[7]="                              ,-\"  \"\"      |        \"\",                /| \ "
L[8]="                            .\"      \"\"\"        \"       \"--\"-,.        /_|__\ "
name="ROOT-MARINE 1.0"
    printf "%$((($cols+${#name})/2))s\n" "$name"
    l=1
    while [ $l -lt $(($first_line - ${#L[@]})) ]; do
	echo
	let l++
    done
    l=$((${#L[@]} + $l - $first_line))
    while [ $l -lt ${#L[@]} ]; do
	echo "${L[$l]:0:$cols}"
	let l++
    done
}

function Init {
    TO_FIRST_LINE="\033[$(($first_line+1));1f"    
    TO_CURSOR_POS="\033[$lines;$(($slider_pos+1))f"
    clear
    Logo
    echo -en $TO_FIRST_LINE    
    l=$first_line
    while [ $l -lt $(($lines-1)) ]; do
	if [ $l -ge $first_line -a $l -le $last_line ]; then
	    screen[$l]=$(yes $wave | head -n$(($cols + $obj_max_len*2)) | tr -d '\n')
	    line_ticks[$l]=0
	    line_weight[$l]=$(( 1+($l-$first_line+1)*$max_weight/($last_line-$first_line+1) ))
	elif [ $l -lt $first_line ]; then
	    screen[$l]=""
	else
	    k=0
	    screen[$l]=""
	    while [ $k -lt $(($obj_max_len+$cols)) ]; do
		if [ $RANDOM -le $abbys_random_level ]; then
		    screen[$l]="${screen[$l]}~"
		else
		    screen[$l]="${screen[$l]} "
		fi
		let k++
	    done
	fi
	echo "${screen[$l]:$obj_max_len:$cols}"
	let l++
    done
    echo -en $TO_CURSOR_POS    
    lines_time=$(($(date +%s%N) + $tick))
    pid_users_time=$(date +%s)
}

function GetUsers {
    USERS=(`w -h -s | sed -ne "/^[^ ]*  *pts/s/^\([^ ]*\)  *pts\/\([^ ]*\).*$/\1@\2/" -ne "/^.\{,$obj_max_len\}$/p" | tr '\n' ' '`)
}

function GetPids {
    PIDS=(`ps h -eo pid | sed -ne "/^.\{,$obj_max_len\}$/p" | tr '\n' ' '`)
}

#$1 - time[s]
function UpdateObjSources {
    [ $1 -lt $pid_users_time ] && return
    let pid_users_time=pid_users_time+$pid_users_update_delay
    GetUsers
    GetPids
}

function RandomUser {
    [ ${#USERS[@]} -eq 0 ] && return 1
    USER=${USERS[$((($RANDOM * $((${#USERS[@]} - 1)))/32767))]}
    return 0
}

function RandomPid {
    [ ${#PIDS[@]} -eq 0 ] && return 1
    PID=${PIDS[$((($RANDOM * $((${#PIDS[@]} - 1)))/32767))]}
    return 0
}

# $1 - tty
function ProcessUser {
    [ $safe_mode -ne 0 ] && return
    skill -KILL -t "$1" &>/dev/null
}

# $1 - pid
function ProcessPid {
    [ $safe_mode -ne 0 ] && return
    kill -9 "$1" &>/dev/null
}

# $1 - obj
function RemoveObj {
    pts="${1#*@}"
    if [ ${#pts} -ne ${#1} ]; then
	ProcessUser "pts/$pts"
    else
	ProcessPid $1
    fi
}

function Paint {
    TO_FIRST_LINE="\033[$(($first_line+1));1f"
    TO_CURSOR_POS="\033[$(($lines));$(($slider_pos+1))f"
    echo -en $TO_FIRST_LINE
    l=$first_line
    while [ $l -le $last_line ]; do
	echo ${screen[$l]:$obj_max_len:$cols}
	let l++
    done
    echo -en $TO_CURSOR_POS
}

function SliderLeft {
    [ $slider_pos -eq 0 ] && return
    let slider_pos--
}

function SliderRight {
    [ $slider_pos -ge $(($cols-1)) ] && return
    let slider_pos++
}

# $1 - line
function MoveHit {
    [ $hit_stage -eq 0 -o $1 -ne $hit_line ] && return 0
    
    case $hit_stage in
    1) 	obj=$(yes '@' | head -n$hit_len | tr -d '\n')
	screen[$hit_line]="${screen[$hit_line]:0:$hit_pos}$obj${screen[$hit_line]:$(($hit_pos+$hit_len))}"
	hit_stage=2
	;;
    2) 	obj=$(yes '*' | head -n$hit_len | tr -d '\n')
	screen[$hit_line]="${screen[$hit_line]:0:$hit_pos}$obj${screen[$hit_line]:$(($hit_pos+$hit_len))}"
	hit_stage=3
	;;
    3) 	obj=$(yes '.' | head -n$hit_len | tr -d '\n')
	screen[$hit_line]="${screen[$hit_line]:0:$hit_pos}$obj${screen[$hit_line]:$(($hit_pos+$hit_len))}"
	hit_stage=4
	;;
    4) 	obj=$(yes $wave | head -n$hit_len | tr -d '\n')
	screen[$hit_line]="${screen[$hit_line]:0:$hit_pos}$obj${screen[$hit_line]:$(($hit_pos+$hit_len))}"
	hit_stage=0
	;;
    esac
    
    if [ $(($hit_line % 2)) -eq 0 ]; then
	let hit_pos--
    else
	let hit_pos++
    fi
    
    return 1
}

# $1 line
# $2 pos in line
function Hit {
    obj="${screen[$1]:$2:1}"
    if [ "$obj" != "$wave" ]; then
	left="${screen[$1]:0:$2}"
	left="${left##*$wave}"
	hit_pos=$(($2-${#left}))
	hit_line=$1
	hit_stage=1
	right="${screen[$1]:$2}"
	right="${right%%$wave*}"
	obj="$left$right"
	RemoveObj $obj
	hit_len=${#obj}
	MoveHit $hit_line
        return 1
    fi
    return 0
}

function StartArrow {
    [ $arrow_pos -ne 0 -o $hit_stage -ne 0 ] && return
    arrow_time=$(date +%s%N)
    arrow_col=$slider_pos
    arrow_pos=$(($lines-1))
    MoveArrow $arrow_time
}

# $1 - time
function MoveArrow {
    [ $arrow_pos -eq 0 ] && return 0
    [ $arrow_time -gt $1 ] && return 0
    if [ $arrow_pos -gt $last_line -a $arrow_pos -lt $(($lines-1)) ]; then
	TO_ARROW_POS="\033[$((arrow_pos+1));$(($arrow_col+1))f"
	echo -ne "$TO_ARROW_POS"
	echo -n "${screen[$arrow_pos]:$(($arrow_col+$obj_max_len)):1}"
    elif [ $arrow_pos -gt $first_line -a "${screen[$arrow_pos]:$(($arrow_col+$obj_max_len)):1}" == "$arrow" ]; then
	screen[$arrow_pos]="${screen[$arrow_pos]:0:$(($arrow_col+$obj_max_len))}$wave${screen[$arrow_pos]:$(($arrow_col+$obj_max_len+1))}"
    elif [ $arrow_pos -le $first_line ]; then
	arrow_pos=0
	return 1
    fi
    let arrow_time=arrow_time+$arrow_speed
    let arrow_pos--

    if [ $arrow_pos -gt $last_line ]; then
	TO_ARROW_POS="\033[$((arrow_pos+1));$(($arrow_col+1))f"
	echo -ne "$TO_ARROW_POS"
	echo -n "$arrow"
    else
	Hit $arrow_pos $(($obj_max_len+$arrow_col))
	if [ $? -eq 1 ]; then
	    arrow_pos=0
	else
	    screen[$arrow_pos]="${screen[$arrow_pos]:0:$(($arrow_col+$obj_max_len))}$arrow${screen[$arrow_pos]:$(($arrow_col+$obj_max_len+1))}"
	fi
    fi
    return 1
}

# $1 - line
function RandomObject {
    [ $RANDOM -gt $obj_random_level ] && return
    if [ $RANDOM -le $user_random_level ]; then
	RandomUser
	[ $? -ne 0 ] && return
	obj="$USER"
    else
	RandomPid
	[ $? -ne 0 ] && return
	obj="$PID"
    fi
    len=${#obj}
    if [ "$(($1%2))" -eq 0 ]; then
	if [ "${screen[$1]:$(($obj_max_len+$cols-1))}" == "$border_wave" ]; then
	    screen[$1]="${screen[$1]:0:$(($obj_max_len+$cols))}$obj${screen[$1]:$(($obj_max_len+$cols+$len))}"
	fi
    else
	if [ "${screen[$1]:0:$(($obj_max_len+1))}" == "$border_wave" ]; then
	    screen[$1]="${screen[$1]:0:$(($obj_max_len-$len))}$obj${screen[$1]:$obj_max_len}"
	fi
    fi
}

function RandomObjects {
    l=$first_line
    while [ $l -le $last_line ]; do
	RandomObject $l
	let l++
    done

}
# $1 - line
function MoveObject {
    if [ "$(($1%2))" -eq 0 ]; then
	screen[$1]="${screen[$1]:1}$wave"
    else
	screen[$1]="$wave${screen[$1]:0:$(($obj_max_len+$cols+$obj_max_len-1))}"
    fi
}

# $1 - time
function MoveObjects {
    [ $lines_time -gt $1 ] && return 0
    UpdateObjSources $(($1/1000000000))
    let lines_time=lines_time+$tick
    RandomObjects
    if [ $arrow_pos -ne 0 ]; then
        al=$arrow_pos
    else
	al=-1
    fi
    l=$first_line
    while [ $l -le $last_line ]; do
	let line_tick[$l]++
	if [ ${line_tick[$l]} -ge ${line_weight[$l]} ]; then
	    line_tick[$l]=0
	    if [ $l -eq $al ]; then
		if [ "${screen[$al]:$(($arrow_col+$obj_max_len)):1}" == "$arrow" ]; then
		    screen[$al]="${screen[$al]:0:$(($arrow_col+$obj_max_len))}$wave${screen[$al]:$(($arrow_col+$obj_max_len+1))}"
		fi
		MoveObject $l
		if [ "${screen[$al]:$(($arrow_col+$obj_max_len)):1}" == '$wave' ]; then
		    screen[$al]="${screen[$al]:0:$(($arrow_col+$obj_max_len))}$arrow${screen[$al]:$(($arrow_col+$obj_max_len+1))}"
		fi
	    else
		MoveObject $l
	    fi
	    MoveHit $l
	fi
	let l++
    done
    return 1
}

function TimeActions {
    statue=0
    ntime=$(date +%s%N)

    l_timeout=0
    MoveObjects $ntime
    status=$?
    [ $lines_time -gt $ntime ] && l_timeout=$(($lines_time - $ntime))
    
    a_timeout=0
    if [ $arrow_pos -ne 0 ]; then
	MoveArrow $ntime
	let status=status+$?
	[ $arrow_time -gt $ntime ] && a_timeout=$(($arrow_time - $ntime))
    fi

    
    if [ $a_timeout -lt $l_timeout ]; then
	timeout=$a_timeout
    else
	timeout=$l_timeout
    fi
    [ $timeout -eq 0 ] && timeout=10000000
    timeout=$(printf "%d.%09d" $(($timeout/1000000000)) $(($timeout%1000000000)))
    
    [ $status -ne 0 ] && Paint
}

Init
Paint

#on old bash 'read -t x.y' does not work, so do it somehow else
orig_stty=`stty -g`
stty -echo -icanon time 0 min 0
end=0
while [ $end -ne 1 ]; do
    TimeActions
    # the tick time is fast enough for keyboard so can be reused
    sleep $timeout
    IFS=''
    read -r -s ch
    IFS=' '
    #read -t $timeout -r -s -n1 ch
    while [ "x$ch" != "x" ]; do
	case ${ch:0:1} in
	$key_quit)
	    end=1
	    break
	    ;;
	$key_left)
	    SliderLeft
	    ;;
	$key_right)
	    SliderRight
	    ;;
	$key_release)
	    StartArrow
	    ;;
	*)
	    ;;
	esac
	ch="${ch:1}"
    done
done

stty "$orig_stty"
echo
