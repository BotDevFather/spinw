#!/usr/bin/env bash
set -e

# ================= CONFIG =================
CANVAS=1000
WHEEL_SIZE=800
PHOTO_SIZE=120
MAX_USERS=20
OUT="wheel.png"

# watermark comes from env (payload)
WATERMARK="${WATERMARK:-}"

COLORS=(
  "#FF6B6B" "#4ECDC4" "#FFD166" "#06D6A0" "#118AB2"
  "#EF476F" "#8338EC" "#3A86FF" "#FB5607" "#FF006E"
  "#4CC9F0" "#7209B7" "#F72585" "#4361EE" "#FFBE0B"
)

# ================= VALIDATION =================
if [ "$#" -lt 2 ]; then
  echo "❌ Minimum 2 image URLs required"
  exit 1
fi

if [ "$#" -gt "$MAX_USERS" ]; then
  echo "❌ Maximum $MAX_USERS users allowed"
  exit 1
fi

for cmd in convert composite curl bc; do
  command -v "$cmd" >/dev/null || exit 1
done

COUNT=$#
TMP=$(mktemp -d)

CX=$((WHEEL_SIZE / 2))
CY=$((WHEEL_SIZE / 2))
R=$((WHEEL_SIZE / 2))
PHOTO_R=$((WHEEL_SIZE * 38 / 100))
ANGLE=$(echo "360 / $COUNT" | bc -l)

echo "Users: $COUNT"

# ================= DOWNLOAD & CIRCLE PHOTOS =================
i=0
for url in "$@"; do
  i=$((i+1))
  curl -L --silent "$url" -o "$TMP/$i.jpg" || true

  convert "$TMP/$i.jpg" \
    -resize ${PHOTO_SIZE}x${PHOTO_SIZE}^ \
    -gravity center -extent ${PHOTO_SIZE}x${PHOTO_SIZE} \
    \( +clone -alpha extract \
       -draw "fill black rectangle 0,0 ${PHOTO_SIZE},${PHOTO_SIZE} fill white circle $((PHOTO_SIZE/2)),$((PHOTO_SIZE/2)) $((PHOTO_SIZE/2)),0" \
       -alpha off \) \
    -compose copy_opacity -composite \
    "$TMP/p$i.png"
done

# ================= BASE WHEEL =================
convert -size ${WHEEL_SIZE}x${WHEEL_SIZE} xc:none "$TMP/wheel.png"

for ((i=0; i<COUNT; i++)); do
  START=$(echo "$i * $ANGLE - 90" | bc -l)   # <<< FIX POINTER ORIENTATION
  END=$(echo "$START + $ANGLE" | bc -l)
  COLOR=${COLORS[$((i % ${#COLORS[@]}))]}

  convert -size ${WHEEL_SIZE}x${WHEEL_SIZE} xc:none \
    -fill "$COLOR" -stroke "$COLOR" \
    -draw "arc $CX,$CY $((CX+R)),$((CY+R)) $START $END" \
    "$TMP/sector.png"

  composite "$TMP/sector.png" "$TMP/wheel.png" "$TMP/wheel.png"
done

# ================= PLACE PHOTOS =================
for ((i=0; i<COUNT; i++)); do
  MID=$(echo "$i * $ANGLE + $ANGLE / 2 - 90" | bc -l)
  RAD=$(echo "$MID * 3.14159265 / 180" | bc -l)

  X=$(echo "$CX + $PHOTO_R * c($RAD)" | bc -l | cut -d. -f1)
  Y=$(echo "$CY - $PHOTO_R * s($RAD)" | bc -l | cut -d. -f1)

  convert "$TMP/p$((i+1)).png" \
    -background none \
    -rotate "$(echo "90 - $MID" | bc -l)" \
    "$TMP/r$i.png"

  composite -geometry "+$((X - PHOTO_SIZE/2))+$((Y - PHOTO_SIZE/2))" \
    "$TMP/r$i.png" "$TMP/wheel.png" "$TMP/wheel.png"
done

# ================= POINTER (TOP, CORRECT) =================
convert -size 100x120 xc:none \
  -fill "#ff416c" \
  -draw "polygon 50,0 100,120 0,120" \
  "$TMP/pointer.png"

# ================= FINAL CANVAS =================
convert -size ${CANVAS}x${CANVAS} xc:white "$OUT"

# center wheel
composite -gravity center "$TMP/wheel.png" "$OUT" "$OUT"

# pointer on top
composite -gravity north "$TMP/pointer.png" "$OUT" "$OUT"

# ================= WATERMARK =================
if [ -n "$WATERMARK" ]; then
  convert "$OUT" \
    -gravity south \
    -fill "#999999" \
    -pointsize 28 \
    -annotate +0+30 "$WATERMARK" \
    "$OUT"
fi

rm -rf "$TMP"
echo "✅ Final spin wheel generated: $OUT"
