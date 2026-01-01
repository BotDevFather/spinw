#!/usr/bin/env bash
set -e

# ================= CONFIG =================
CANVAS=1000
WHEEL_SIZE=1500
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
ANGLE=$(echo "scale=2; 360 / $COUNT" | bc)

echo "🚀 Creating spin wheel with $COUNT users..."

# ================= DOWNLOAD & CIRCLE PHOTOS =================
i=0
for url in "$@"; do
  i=$((i+1))
  echo "📸 Processing photo $i/$COUNT..."
  
  # Download image with timeout and remove color profile
  curl -L --silent --max-time 30 "$url" -o "$TMP/$i.jpg" || {
    echo "⚠️  Could not download photo $i, creating placeholder"
    # Create colored placeholder with number
    convert -size ${PHOTO_SIZE}x${PHOTO_SIZE} xc:none \
      -fill "${COLORS[$(( (i-1) % ${#COLORS[@]} ))]}" \
      -draw "circle $((PHOTO_SIZE/2)),$((PHOTO_SIZE/2)) $((PHOTO_SIZE/2)),$((PHOTO_SIZE/10))" \
      -fill white \
      -pointsize $((PHOTO_SIZE/3)) \
      -gravity center \
      -annotate +0+0 "$i" \
      "$TMP/$i.jpg"
  }

  # Convert to circular photo with border - REMOVE COLOR PROFILE
  convert "$TMP/$i.jpg" \
    -resize ${PHOTO_SIZE}x${PHOTO_SIZE}^ \
    -gravity center \
    -extent ${PHOTO_SIZE}x${PHOTO_SIZE} \
    \( +clone -fill black -colorize 100% \) \
    \( +clone -fill white -draw "circle $((PHOTO_SIZE/2)),$((PHOTO_SIZE/2)) $((PHOTO_SIZE/2)),0" \) \
    -alpha off \
    -compose copy_opacity \
    -composite \
    -strip \  # REMOVE COLOR PROFILE
    -shave 1x1 \
    -bordercolor white \
    -border 4 \
    -bordercolor black \
    -border 1 \
    "$TMP/p$i.png"
done

# ================= CREATE WHEEL WITH SECTORS =================
echo "🎨 Creating wheel sectors..."

# Create transparent base wheel
convert -size ${WHEEL_SIZE}x${WHEEL_SIZE} xc:none "$TMP/wheel_base.png"

# Create colored sectors using conic gradient approximation
for ((i=0; i<COUNT; i++)); do
  START=$(echo "scale=2; $i * $ANGLE" | bc)
  END=$(echo "scale=2; ($i + 1) * $ANGLE" | bc)
  COLOR=${COLORS[$((i % ${#COLORS[@]}))]}
  
  echo "  Sector $((i+1)): $START° to $END° ($COLOR)"
  
  # Create sector mask (pie slice)
  convert -size ${WHEEL_SIZE}x${WHEEL_SIZE} xc:none \
    -fill "$COLOR" \
    -draw "path 'M $CX,$CY \
           L $WHEEL_SIZE,$((CY)) \
           A $R,$R 0 0,1 \
           $(echo "scale=0; $CX + $R * c($END * 3.14159 / 180)" | bc -l | cut -d. -f1),$(echo "scale=0; $CY - $R * s($END * 3.14159 / 180)" | bc -l | cut -d. -f1) \
           Z'" \
    "$TMP/sector_$i.png"
  
  # Merge sectors
  if [ $i -eq 0 ]; then
    cp "$TMP/sector_$i.png" "$TMP/wheel_colored.png"
  else
    composite "$TMP/sector_$i.png" "$TMP/wheel_colored.png" "$TMP/wheel_colored.png"
  fi
done

# Add inner center circle (to hide sector tips)
convert "$TMP/wheel_colored.png" \
  -fill '#0a0a1a' \
  -draw "circle $CX,$CY $CX,$((CY - 60))" \
  -fill '#3a3a6a' \
  -stroke '#3a3a6a' \
  -strokewidth 8 \
  -draw "circle $CX,$CY $CX,$((CY - 60))" \
  "$TMP/wheel_colored.png"

# ================= PLACE PHOTOS ON WHEEL =================
echo "📍 Placing photos on wheel..."

for ((i=0; i<COUNT; i++)); do
  # Calculate photo position (middle of sector)
  MID_ANGLE=$(echo "scale=2; ($i * $ANGLE) + ($ANGLE / 2)" | bc)
  
  # Convert to radians
  MID_RAD=$(echo "scale=10; ($MID_ANGLE - 90) * 3.14159265 / 180" | bc)
  
  # Calculate X,Y position
  X=$(echo "scale=0; $CX + $PHOTO_R * c($MID_RAD)" | bc -l | cut -d. -f1)
  Y=$(echo "scale=0; $CY - $PHOTO_R * s($MID_RAD)" | bc -l | cut -d. -f1)
  
  # Rotate photo to face outward (perpendicular to radius)
  ROTATION=$(echo "scale=2; 90 - $MID_ANGLE" | bc)
  
  convert "$TMP/p$((i+1)).png" \
    -background none \
    -rotate "$ROTATION" \
    -strip \  # REMOVE COLOR PROFILE
    "$TMP/r$i.png"
  
  # Place photo on wheel
  composite -geometry "+$((X - PHOTO_SIZE/2))+$((Y - PHOTO_SIZE/2))" \
    "$TMP/r$i.png" "$TMP/wheel_colored.png" "$TMP/wheel_colored.png"
done

# Add center star decoration
echo "⭐ Adding center decoration..."
convert -size 80x80 xc:none \
  -fill white \
  -draw "polygon 40,10 50,30 70,30 55,40 60,60 40,50 20,60 25,40 10,30 30,30" \
  "$TMP/center_star.png"

composite -gravity center "$TMP/center_star.png" "$TMP/wheel_colored.png" "$TMP/wheel_colored.png"

# ================= CREATE POINTER =================
echo "📍 Creating pointer..."
convert -size 100x120 xc:none \
  -fill "#ff416c" \
  -draw "polygon 50,0 75,100 25,100" \
  -fill "#0a0a1a" \
  -draw "circle 50,95 50,105" \
  "$TMP/pointer.png"

# ================= CREATE FINAL CANVAS =================
echo "🎯 Creating final canvas..."

# Create white canvas
convert -size ${CANVAS}x${CANVAS} xc:white "$TMP/canvas.png"

# Calculate wheel position to center it
WHEEL_X=$(( (CANVAS - WHEEL_SIZE) / 2 ))
WHEEL_Y=$(( (CANVAS - WHEEL_SIZE) / 2 ))

# Place wheel on canvas
composite -geometry "+${WHEEL_X}+${WHEEL_Y}" \
  "$TMP/wheel_colored.png" "$TMP/canvas.png" "$TMP/canvas.png"

# Place pointer at top center (adjusting for wheel offset)
POINTER_X=$(( CANVAS / 2 - 50 ))
POINTER_Y=$(( WHEEL_Y - 100 ))

composite -geometry "+${POINTER_X}+${POINTER_Y}" \
  "$TMP/pointer.png" "$TMP/canvas.png" "$TMP/canvas.png"

# ================= ADD WATERMARK =================
if [ -n "$WATERMARK" ]; then
  echo "🏷️  Adding watermark..."
  convert "$TMP/canvas.png" \
    -gravity south \
    -fill "rgba(153,153,153,0.7)" \
    -pointsize 28 \
    -annotate +0+30 "$WATERMARK" \
    "$TMP/canvas.png"
fi

# Add border to final image
convert "$TMP/canvas.png" \
  -bordercolor '#0a0a1a' \
  -border 20 \
  -bordercolor '#3a3a6a' \
  -border 5 \
  -strip \  # REMOVE COLOR PROFILE FROM FINAL IMAGE
  "$OUT"

# ================= CLEANUP & OUTPUT =================
rm -rf "$TMP"
echo "✅ Final spin wheel generated: $OUT"
echo "📊 Details:"
echo "   • Users: $COUNT"
echo "   • Canvas size: ${CANVAS}x${CANVAS}"
echo "   • Wheel size: ${WHEEL_SIZE}x${WHEEL_SIZE}"
echo "   • Photo size: ${PHOTO_SIZE}x${PHOTO_SIZE}"
echo "   • Sectors: $COUNT (${ANGLE}° each)"
echo "   • Output file: $(pwd)/$OUT"
