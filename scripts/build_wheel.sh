#!/bin/bash

SIZE=800
RADIUS=380
CENTER=$((SIZE / 2))

COUNT=$(ls avatars | wc -l)
SLICE_ANGLE=$(echo "360 / $COUNT" | bc -l)

convert -size ${SIZE}x${SIZE} xc:none wheel.png

START=0
i=0

for IMG in avatars/*.jpg; do
  COLOR=$(printf "#%06X\n" $((RANDOM * RANDOM % 16777215)))

  END=$(echo "$START + $SLICE_ANGLE" | bc)

  # Draw slice
  convert wheel.png \
    -fill "$COLOR" \
    -draw "path 'M $CENTER,$CENTER L $CENTER,20 A $RADIUS,$RADIUS 0 0,1 $CENTER,$CENTER Z'" \
    -rotate "$START" \
    wheel.png

  # Place avatar
  convert wheel.png \
    \( "$IMG" -resize 140x140 -gravity center -extent 160x160 -bordercolor white -border 4 \) \
    -gravity center \
    -geometry +0-$((RADIUS / 2)) \
    -rotate "$START" \
    -composite \
    wheel.png

  START=$END
  i=$((i+1))
done
