#!/bin/bash
set -e

# ------------------------
# CONFIG
# ------------------------
SIZE=1080
CENTER=540
RADIUS=500
AVATAR_SIZE=160
FRAME_SIZE=180
BORDER=6

# ------------------------
# COLLECT AVATARS
# ------------------------
AVATARS=(avatars/*.jpg)

COUNT=${#AVATARS[@]}
if [ "$COUNT" -lt 2 ]; then
  echo "Need at least 2 avatars, found $COUNT"
  exit 1
fi

SLICE_ANGLE=$(echo "360 / $COUNT" | bc -l)

# ------------------------
# BASE CANVAS
# ------------------------
convert -size ${SIZE}x${SIZE} xc:none wheel.png

ANGLE=0
IDX=0

# ------------------------
# BUILD WHEEL
# ------------------------
for IMG in "${AVATARS[@]}"; do
  TMP_AVATAR="avatar_${IDX}.png"

  # Random color per slice
  COLOR=$(printf "#%06X\n" $((RANDOM % 16777215)))

  # Draw slice
  convert wheel.png \
    -fill "$COLOR" \
    -draw "path 'M $CENTER,$CENTER L $CENTER,30 A $RADIUS,$RADIUS 0 0,1 $CENTER,$CENTER Z'" \
    -rotate "$ANGLE" \
    wheel.png

  # Prepare avatar (circle mask + border)
  convert "$IMG" \
    -resize ${AVATAR_SIZE}x${AVATAR_SIZE}^ \
    -gravity center \
    -extent ${AVATAR_SIZE}x${AVATAR_SIZE} \
    \( -size ${AVATAR_SIZE}x${AVATAR_SIZE} xc:none \
       -draw "circle $((AVATAR_SIZE/2)),$((AVATAR_SIZE/2)) $((AVATAR_SIZE/2)),$BORDER" \) \
    -compose DstIn -composite \
    -bordercolor white -border $BORDER \
    "$TMP_AVATAR"

  # Composite avatar onto wheel (NO PIPE)
  convert wheel.png \
    "$TMP_AVATAR" \
    -gravity center \
    -geometry +0-$((RADIUS / 2)) \
    -rotate "$ANGLE" \
    -composite \
    wheel.png

  rm -f "$TMP_AVATAR"

  ANGLE=$(echo "$ANGLE + $SLICE_ANGLE" | bc)
  IDX=$((IDX + 1))
done

echo "Wheel built successfully with $COUNT slices"
