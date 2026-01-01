#!/usr/bin/env bash
set -e

# ================= CONFIG =================
WHEEL_SIZE=800
PHOTO_SIZE=120
MAX=20
OUT="wheel.png"

COLORS=(
  "#FF6B6B" "#4ECDC4" "#FFD166" "#06D6A0" "#118AB2"
  "#EF476F" "#8338EC" "#3A86FF" "#FB5607" "#FF006E"
  "#4CC9F0" "#7209B7" "#F72585" "#4361EE" "#FFBE0B"
)

# ================= CHECKS =================
if [ "$#" -lt 2 ]; then
  echo "❌ Need at least 2 images"
  exit 1
fi

if [ "$#" -gt "$MAX" ]; then
  echo "❌ Max $MAX images allowed"
  exit 1
fi

for cmd in convert composite curl bc; do
  command -v $cmd >/dev/null || { echo "❌ Missing $cmd"; exit 1; }
done

COUNT=$#
TMP=$(mktemp -d)

echo "Users: $COUNT"

# ================= DOWNLOAD & CIRCLE =================
i=0
for url in "$@"; do
  i=$((i+1))
  curl -L --silent "$url" -o "$TMP/$i.jpg" || true

  convert "$TMP/$i.jpg" \
    -resize ${PHOTO_SIZE}x${PHOTO_SIZE}^ \
    -gravity center -extent ${PHOTO_SIZE}x${PHOTO_SIZE} \
    \( +clone -alpha extract \
       -draw "fill black polygon 0,0 ${PHOTO_SIZE},0 ${PHOTO_SIZE},${PHOTO_SIZE} 0,${PHOTO_SIZE} fill white circle $((PHOTO_SIZE/2)),$((PHOTO_SIZE/2)) $((PHOTO_SIZE/2)),0" \
       -alpha off \) \
    -compose copy_opacity -composite \
    "$TMP/p$i.png"
done

# ================= BASE WHEEL =================
convert -size ${WHEEL_SIZE}x${WHEEL_SIZE} xc:none "$TMP/base.png"

ANGLE=$(echo "360/$COUNT" | bc -l)
CX=$((WHEEL_SIZE/2))
CY=$((WHEEL_SIZE/2))
R=$((WHEEL_SIZE/2))

for ((i=0;i<COUNT;i++)); do
  start=$(echo "$i*$ANGLE" | bc -l)
  end=$(echo "$start+$ANGLE" | bc -l)
  color=${COLORS[$((i % ${#COLORS[@]}))]}

  x2=$(echo "$CX + $R * c($end * 3.14159 / 180)" | bc -l | cut -d. -f1)
  y2=$(echo "$CY - $R * s($end * 3.14159 / 180)" | bc -l | cut -d. -f1)

  convert -size ${WHEEL_SIZE}x${WHEEL_SIZE} xc:none \
    -fill "$color" \
    -draw "path 'M $CX,$CY L $WHEEL_SIZE,$CY A $R,$R 0 0,1 $x2,$y2 Z'" \
    "$TMP/sector.png"

  composite "$TMP/sector.png" "$TMP/base.png" "$TMP/base.png"
done

# ================= PLACE PHOTOS =================
PHOTO_R=$((WHEEL_SIZE * 35 / 100))

for ((i=0;i<COUNT;i++)); do
  mid=$(echo "$i*$ANGLE + $ANGLE/2" | bc -l)
  rad=$(echo "$mid * 3.14159 / 180" | bc -l)

  x=$(echo "$CX + $PHOTO_R * c($rad)" | bc -l | cut -d. -f1)
  y=$(echo "$CY - $PHOTO_R * s($rad)" | bc -l | cut -d. -f1)

  convert "$TMP/p$((i+1)).png" \
    -background none -rotate "$(echo "90-$mid" | bc -l)" \
    "$TMP/r$i.png"

  composite -geometry "+$((x-PHOTO_SIZE/2))+$((y-PHOTO_SIZE/2))" \
    "$TMP/r$i.png" "$TMP/base.png" "$TMP/base.png"
done

# ================= POINTER =================
convert -size 80x100 xc:none \
  -fill red \
  -draw "polygon 40,0 80,100 0,100" \
  "$TMP/pointer.png"

composite -gravity north "$TMP/pointer.png" "$TMP/base.png" "$OUT"

rm -rf "$TMP"
echo "✅ Generated $OUT"
