#!/bin/bash

WINNER_INDEX=$1
COUNT=$2

DURATION=3
FULL_SPINS=4

SLICE_ANGLE=$(echo "360 / $COUNT" | bc -l)

# FINAL ANGLE — MATCHES UI LOGIC
FINAL_ROTATION=$(echo "$FULL_SPINS*360 + (360 - ($WINNER_INDEX*$SLICE_ANGLE) - ($SLICE_ANGLE/2))" | bc)

ffmpeg -y -loop 1 -i wheel.png \
-filter_complex "
rotate='(1 - pow(1 - t/$DURATION, 3)) * $FINAL_ROTATION * PI/180':c=none,
drawbox=x=530:y=20:w=20:h=60:color=red:t=fill
" \
-t $DURATION \
-r 30 \
-pix_fmt yuv420p \
output.mp4
