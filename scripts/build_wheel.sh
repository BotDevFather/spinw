#!/bin/bash
set -e

SIZE=1080
CENTER=540
RADIUS=500

COUNT=$(ls avatars | wc -l)
if [ "$COUNT" -lt 2 ]; then
  echo "Need at least 2 avatars"
  exit 1
fi

SLICE_ANGLE=$(echo "360 / $COUNT" | bc -l)

# Base transparent canvas
convert -size ${SIZE}x${SIZE} xc:none wheel.png

ANGLE=0

for IMG in avatars/*.jpg; do
  # Random color per slice
  COLOR=$(printf "#%06X\n" $((RANDOM % 16777215)))

  # Draw slice
  convert wheel.png \
    -fill "$COLOR" \
    -draw "path 'M $CENTER,$CENTER L $CENTER,40 A $RADIUS,$RADIUS 0 0,1 $CENTER,$CENTER Z'" \
    -rotate "$ANGLE" \
    wheel.png

  # Place avatar in slice center
  convert wheel.png \
    \( "$IMG" -resize 160x160 -gravity center -extent 180x180 -bordercolor white -border 6 \) \
    -gravity center \
    -geometry +0-$((RADIUS / 2)) \
    -rotate "$ANGLE" \
    -composite \
    wheel.png

  ANGLE=$(echo "$ANGLE + $SLICE_ANGLE" | bc)
done
