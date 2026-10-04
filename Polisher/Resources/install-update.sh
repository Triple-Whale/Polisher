#!/bin/bash
set -euo pipefail

old_pid="$1"
candidate="$2"
installed="$3"
staging="$4"
status_file="$5"
backup="$staging/Previous.app"

fail() {
    printf '%s\n' "$1" > "$status_file"
    if [[ ! -d "$installed" && -d "$backup" ]]; then
        /bin/mv "$backup" "$installed"
    fi
    if ! /bin/kill -0 "$old_pid" 2>/dev/null; then
        /usr/bin/open -n "$installed" || true
    fi
    exit 1
}

[[ "$old_pid" =~ ^[0-9]+$ ]] || exit 1
for ((attempt = 0; attempt < 240; attempt++)); do
    if ! /bin/kill -0 "$old_pid" 2>/dev/null; then
        break
    fi
    /bin/sleep 0.25
done
if /bin/kill -0 "$old_pid" 2>/dev/null; then
    fail "Polisher did not quit in time. The existing app was kept. Please try updating again."
fi

[[ -d "$candidate" && -d "$installed" && ! -e "$backup" ]] || fail "The update files are unavailable. Nothing was installed."
/bin/mv "$installed" "$backup" || fail "The existing app could not be moved. Check the Applications folder permissions."
/bin/mv "$candidate" "$installed" || fail "The update could not be installed. The previous version was restored."
if ! /usr/bin/open -n "$installed"; then
    /bin/mv "$installed" "$staging/Failed.app"
    /bin/mv "$backup" "$installed"
    fail "The updated app could not be opened. The previous version was restored."
fi
