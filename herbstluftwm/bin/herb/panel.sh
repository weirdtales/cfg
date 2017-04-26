#!/bin/bash

set -f

monitor=${1:-0}
height=16
padding_top=0
padding_bottom=0
padding_left=0
padding_right=$padding_left
bottom=0
font="-*-smoothansi-medium-*-*-*-13-*-*-*-*-*-*-*"

geometry=( `herbstclient monitor_rect $monitor` )
x=${geometry[0]}
y=${geometry[1]}
((bottom)) && y=$((${geometry[1]}+${geometry[3]}-height))
width="${geometry[2]}"

x=$((x + padding_left))
width=$((width - padding_left - padding_right))
y=$((y + padding_top))

xgeom="${width}x${height}+$x+$y"

function uniq_linebuffered() {
    exec awk '$0 != l { print ; l=$0 ; fflush(); }' "$@"
}

update_pad() {
    ((bottom)) && herbstclient pad $monitor 0 0 "$1" \
               || herbstclient pad $monitor "$1"
}

activecolor="#9fbc00"
emphbg="#303030"

update_pad $((height + padding_top + padding_bottom))

{
    child+=" $!"
    while true; do
        date +$'date\t%M'
        sleep 2 || break
    done > >(uniq_linebuffered) &
    child+=" $!"
    herbstclient --idle
    kill $child
}|{
    tags=( `herbstclient tag_status $monitor` )
    date=""

    while true; do
        IFS=$'\t' read -ra cmd || break
        case "${cmd[0]}" in
            tag*)
                tags=( `herbstclient tag_status $monitor` )
                ;;
            focus_changed|window_title_changed)
                windowtitle="${cmd[@]:2}"
                ;;
            date)
                date=`date +'%Y-%m-%d'`
                hhmm=`date +'%H:%M'`
                if [[ -x $HOME/bin/bat.sh ]]; then
                    batlev=`$HOME/bin/bat.sh`
                    batcol="#13bc00"
                    [[ "$batlev" -lt "21" ]] && batcol="#bc1300"
                    baticon=""
                    [[ "`cat /sys/class/power_supply/BAT0/status`" == "Charging" ]] && baticon="⚡"
                fi
                ;;
            quit_panel)
                exit 0
                ;;
            *)
                ;;
        esac

	output=""
        for i in "${tags[@]}"; do
            occupied=true
            focused=false
            here=false
            urgent=false
            visible=true
            case ${i:0:1} in
                '.')
                    occupied=false
                    visible=false
                    ;;
                '#')
                    focused=true
                    here=true
                    ;;
                '%') focused=true;;
                '+') here=true;;
                '!') urgent=true;;
                ':') visible=false;;
            esac

	    tagname="${i:1}"

	    $here     && output+="^bg(#333)" || output+="^bg()"
	    #$visible  && output+="^fg()" || output+=""
	    $occupied && output+="^fg()" || output+="^fg(#555)"
	    $urgent   && output+="^bg(#e33)"
	    $focused  && output+="^bg(yellow)^fg(#111)" || output+=""
            output+=" $tagname "
        done
	output+="^fg()^bg()"

	dtw=`textwidth "$font" "$date $hhmm $batlev 1234567"`
	output+="^pa($(( $width - $dtw))^fg(#777)$date ^fg(yellow)${hhmm} ^fg(#555)| ^fg($batcol)$batlev^fg(cyan)$baticon"

	echo $output
    done
#} | $HOME/bin/lemonbar -d -g "`printf '%dx%d%+d%+d' $width $height $x $y`" -u 2 -f "$font" -B "#121212"
} | dzen2 -xs $(( $monitor + 1 )) -h $height -w $width -fn "$font"
