#!/usr/bin/env bash
set -e

WHEEL_SIZE=800
OUT="wheel.png"
MAX=20

COLORS=(
  "#FF6B6B" "#4ECDC4" "#FFD166" "#06D6A0" "#118AB2"
  "#EF476F" "#8338EC" "#3A86FF" "#FB5607" "#FF006E"
  "#4CC9F0" "#7209B7" "#F72585" "#4361EE" "#FFBE0B"
)

if [ "$#" -lt 2 ]; then
  echo "Need at least 2 images"
  exit 1
fi

if [ "$#" -gt "$MAX" ]; then
  echo "Max $MAX images allowed"
  exit 1
fi

command -v convert >/dev/null || exit 1
command -v curl >/dev/null || exit 1
command -v bc >/dev/null || exit 1

COUNT=$#
TMP=$(mktemp -d)

echo "Users: $COUNT"

# -----------------------------
# Download + crop circle
# -----------------------------
i=0
for url in "$@"; do
  i=$((i+1))
  curl -L --silent "$url" -o "$TMP/$i.jpg" || true

  convert "$TMP/$i.jpg" \
    -resize 120x120^ -gravity center -extent 120x120 \
    \( +clone -alpha extract \
       -draw "fill black polygon 0,0 120,0 120,120 0,120 fill white circle 60,60 60,0" \
       -alpha off \) \
    -compose copy_opacity -composite \
    "$TMP/$i.png"
done

# -----------------------------
# Base wheel (conic)
# -----------------------------
ANGLE=$(echo "360/$COUNT" | bc -l)
GRAD=""

for ((i=0;i<COUNT;i++)); do
  s=$(echo "$i*$ANGLE" | bc -l)
  e=$(echo "$s+$ANGLE" | bc -l)
  c=${COLORS[$((i % ${#COLORS[@]}))]}
  GRAD+="$c ${s}deg ${e}deg"
  [ "$i" -lt $((COUNT-1)) ] && GRAD+=", "
done

convert -size ${WHEEL_SIZE}x${WHEEL_SIZE} \
  "gradient:conic-gradient($GRAD)" \
  -distort Polar 0 \
  "$TMP/base.png"

# -----------------------------
# Place photos
# -----------------------------
R=$((WHEEL_SIZE * 35 / 100))
CX=$((WHEEL_SIZE/2))
CY=$((WHEEL_SIZE/2))

for ((i=0;i<COUNT;i++)); do
  mid=$(echo "$i*$ANGLE + $ANGLE/2" | bc -l)
  rad=$(echo "$mid*3.14159/180" | bc -l)

  x=$(echo "$CX + $R*c($rad)" | bc -l | cut -d. -f1)
  y=$(echo "$CY - $R*s($rad)" | bc -l | cut -d. -f1)

  convert "$TMP/$((i+1)).png" \
    -background none -rotate "$(echo "90-$mid" | bc -l)" \
    "$TMP/r$i.png"

  composite -geometry "+$((x-60))+$((y-60))" \
    "$TMP/r$i.png" "$TMP/base.png" "$TMP/base.png"
done

# -----------------------------
# Pointer
# -----------------------------
convert -size 80x100 xc:none \
  -fill red \
  -draw "polygon 40,0 80,100 0,100" \
  "$TMP/pointer.png"

composite -gravity north "$TMP/pointer.png" "$TMP/base.png" "$OUT"

rm -rf "$TMP"
echo "Generated $OUT"
