#!/bin/sh
# Fetches wxWidgets locale .po files from the wxWidgets GitHub repository and
# compiles them to .mo files for use in the Aegisub installers/bundles.
#
# Output: <source_root>/src/mo/wxstd-{lang}.mo
# These are referenced by:
#   - packages/win_installer/fragment_translations.iss (ENABLE_WX_TRANSLATIONS)
#   - tools/osx-bundle.sh (WX locale copying section)
#
# Usage: ./tools/fetch_wxstd.sh [<source_root>]
#   source_root defaults to the parent of the directory containing this script.
#
# xref: https://github.com/TypesettingTools/Aegisub/issues/379

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_ROOT="${1:-$(dirname "$SCRIPT_DIR")}"
MO_DIR="$SOURCE_ROOT/src/mo"
WX_BRANCH="3.2"
WX_LOCALE_BASE="https://raw.githubusercontent.com/wxWidgets/wxWidgets/$WX_BRANCH/locale"

# Check dependencies
if ! command -v msgfmt >/dev/null 2>&1; then
    echo "ERROR: msgfmt not found. Install gettext:" >&2
    echo "  macOS:  brew install gettext && brew link gettext --force" >&2
    echo "  Debian: apt-get install gettext" >&2
    echo "  Fedora: dnf install gettext" >&2
    exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
    echo "ERROR: curl not found. Please install curl." >&2
    exit 1
fi

mkdir -p "$MO_DIR"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

# Mapping: aegisub_lang:wx_po_name
# Only languages where wxWidgets has a translation.
LOCALES="
ar:ar
ca:ca
cs:cs
da:da
de:de
el:el
es:es
eu:eu
fa:fa_IR
fi:fi
fr_FR:fr
gl:gl_ES
hu:hu
id:id
it:it
ja:ja
ko:ko_KR
lt:lt
nl:nl
pl:pl
pt_BR:pt_BR
pt_PT:pt
ru:ru
sr_RS:sr
tr:tr
uk_UA:uk
vi:vi
zh_CN:zh_CN
zh_TW:zh_TW
"

SUCCESS=0
FAILED=0

for entry in $LOCALES; do
    AEGI_LANG="${entry%%:*}"
    WX_PO_NAME="${entry##*:}"
    PO_URL="$WX_LOCALE_BASE/$WX_PO_NAME.po"
    TEMP_PO="$TMPDIR/$WX_PO_NAME.po"
    OUTPUT_MO="$MO_DIR/wxstd-$AEGI_LANG.mo"

    printf "Fetching %s.po -> wxstd-%s.mo ... " "$WX_PO_NAME" "$AEGI_LANG"

    if curl -fsSL "$PO_URL" -o "$TEMP_PO" 2>/dev/null && \
       msgfmt -o "$OUTPUT_MO" "$TEMP_PO" 2>/dev/null; then
        echo "OK"
        SUCCESS=$((SUCCESS + 1))
    else
        echo "FAILED"
        FAILED=$((FAILED + 1))
    fi
done

echo ""
echo "Done: $SUCCESS compiled, $FAILED failed."
echo "Output directory: $MO_DIR"

if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
