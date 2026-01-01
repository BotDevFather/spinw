#!/bin/bash
set -e

# ------------------------
# CONFIG
# ------------------------
SIZE=1080
CENTER=540
RADIUS=500
AVATAR_SIZE=160
AVATAR_FRAME=180
BORDER=6

# ------------------------
# COLLECT AVATARS
# ------------------------
AVATARS=()
for f in avatars/*; do
  if identify "$f" >/dev/null 2>&1; then
    AVATARS+=("$f")
  else
    echo "Skipping invalid image: $f"
  fi
done

COUNT=${#AVATARS[@]}

if [ "$COUNT" -lt 2 ]; then
  echo "Need at least 2 valid avatars, found $COUNT"
  exit 1
fi

SLICE_ANGLE=$(echo "360 / $COUNT" | bc -l)

# ------------------------
# CREATE BASE CANVAS
# ------------------------
convert -size ${SIZE}x${SIZE} xc:none wheel.png

ANGLE=0

# ------------------------
# BUILD WHEEL
# ------------------------
for IMG in "${AVATARS[@]}"; do
  # Random bright color
  COLOR=$(printf "#%06X\n" $((RANDOM % 16777215)))

  # Draw slice
  convert wheel.png \
    -fill "$COLOR" \
    -draw "path 'M $CENTER,$CENTER L $CENTER,30 A $RADIUS,$RADIUS 0 0,1 $CENTER,$CENTER Z'" \
    -rotate "$ANGLE" \
    wheel.png

  # Prepare avatar (circle + border)
  convert "$IMG" \
    -resize ${AVATAR_SIZE}x${AVATAR_SIZE}^ \
    -gravity center \
    -extent ${AVATAR_SIZE}x${AVATAR_SIZE} \
    \( -size ${AVATAR_SIZE}x${AVATAR_SIZE} xc:none -draw "circle $((AVATAR_SIZE/2)),$((AVATAR_SIZE/2)) $((AVATAR_SIZE/2)),$BORDER" \) \
    -compose DstIn -composite \
    -bordercolor white -border $BORDER \
    miff:- |

  # Composite avatar into slice
  convert wheel.png \
    -gravity center \
    -geometry +0-$((RADIUS / 2)) \
    -rotate "$ANGLE" \
    -composite \
    wheel.png

  ANGLE=$(echo "$ANGLE + $SLICE_ANGLE" | bc)
done

echo "Wheel built successfully with $COUNT slices"
