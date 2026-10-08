#!/bin/sh
# Derive the per-student lab values from a student index number.
#
#   scripts/student-seed.sh <student-id>
#
# Prints KEY=VALUE lines. bootstrap.sh uses them to personalise the lab
# (API items, cache lifetimes, certificate details, response token), and an
# instructor can run the same script to check a submitted report against the
# values that student must have seen. The derivation is deterministic: the
# same index number always gives the same values.
set -eu

ID=${1:-}
if [ -z "$ID" ]; then
    echo "usage: $0 <student-id>" >&2
    exit 1
fi

HASH=$(printf '%s' "$ID" | sha256sum | cut -c1-32)
# h N -> integer value of the N-th pair of hex digits (0..255)
h() { printf '%d' "0x$(printf '%s' "$HASH" | cut -c$(( $1 * 2 + 1 ))-$(( $1 * 2 + 2 )))"; }

TOKEN=$(printf '%s' "$HASH" | cut -c1-8)

# Cache lifetimes that the manuals do not spell out
INDEX_MAXAGE=$(( 120 + ( $(h 1) % 12 ) * 60 ))        # 120 .. 780 s   (/)
PRIVATE_MAXAGE=$(( 300 + ( $(h 2) % 10 ) * 120 ))     # 300 .. 1380 s  (/private/)

# REST API: 3..5 items with names chosen from a word list
WORDS="Widget Gadget Gizmo Sprocket Bracket Spindle Gasket Flange Bearing Valve Piston Rotor Nozzle Socket Hinge Pulley"
ITEM_COUNT=$(( 3 + $(h 3) % 3 ))
start=$(( $(h 4) % 16 ))
step=$(( 1 + 2 * ( $(h 5) % 8 ) ))      # odd, so all picks are distinct
ITEM_NAMES=""
i=0
while [ $i -lt $ITEM_COUNT ]; do
    idx=$(( ( start + i * step ) % 16 ))
    name=$(printf '%s' "$WORDS" | tr ' ' '\n' | sed -n "$(( idx + 1 ))p")
    ITEM_NAMES="${ITEM_NAMES:+$ITEM_NAMES }$name"
    i=$(( i + 1 ))
done
NEXT_ID=$(( ITEM_COUNT + 1 ))

# Length of the hidden note in index.html (changes the page size and the
# compression ratio measured in A2.1)
INDEX_NOTE_LINES=$(( 4 + $(h 6) % 20 ))

# HTTPS certificate: validity and an extra Subject Alternative Name
CERT_DAYS=$(( 180 + ( $(h 7) % 24 ) * 30 ))            # 180 .. 870 days
CERT_SAN="secure-$TOKEN.lab.local"

# HSTS lifetime
case $(( $(h 8) % 3 )) in
    0) HSTS_MAXAGE=15552000 ;;    # 180 days
    1) HSTS_MAXAGE=31536000 ;;    # 1 year
    *) HSTS_MAXAGE=63072000 ;;    # 2 years
esac

cat <<EOF
STUDENT_ID="$ID"
TOKEN="$TOKEN"
INDEX_MAXAGE="$INDEX_MAXAGE"
PRIVATE_MAXAGE="$PRIVATE_MAXAGE"
ITEM_COUNT="$ITEM_COUNT"
ITEM_NAMES="$ITEM_NAMES"
NEXT_ID="$NEXT_ID"
INDEX_NOTE_LINES="$INDEX_NOTE_LINES"
CERT_DAYS="$CERT_DAYS"
CERT_SAN="$CERT_SAN"
HSTS_MAXAGE="$HSTS_MAXAGE"
EOF
