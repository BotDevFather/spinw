#!/bin/bash

WINNER=$1
COUNT=$2

DURATION=3
FULL_SPINS=4
SLICE_ANGLE=$((360 / COUNT))
FINAL_ANGLE=$((FULL_SPINS * 360 + WINNER * SLICE_ANGLE))

ffmpeg -loop 1 -i wheel.png \
-filter_complex "
[0]rotate='(t/$DURATION)*$FINAL_ANGLE*PI/180':c=none[w];
[w]drawbox=x=390:y=10:w=20:h=40:color=red:t=fill
" \
-t $DURATION \
-pix_fmt yuv420p \
output.mp4
