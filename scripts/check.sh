#!/bin/sh

set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

failures=0

fail() {
	printf 'FAIL: %s\n' "$1" >&2
	failures=$((failures + 1))
}

for field in Interface Title Version Category; do
	if ! grep -q "^## ${field}:" shPerformance.toc; then
		fail "missing TOC metadata: ${field}"
	fi
done

for entry in $(awk 'NF && $1 !~ /^#/ { gsub(/\\/, "/"); print }' shPerformance.toc); do
	if [ ! -f "$entry" ]; then
		fail "TOC references missing file: ${entry}"
	fi
done

for asset in media/fpsicon.TGA media/msicon.TGA media/shPerformance-logo.png; do
	if [ ! -f "$asset" ]; then
		fail "missing runtime asset: ${asset}"
	fi
done

restricted_pattern='UnitHealth|UnitPower|UnitAura|C_UnitAuras|COMBAT_LOG_EVENT_UNFILTERED|C_RestrictedActions|C_Secrets'
for file in init.lua utils.lua shPerformance.lua shFps.lua shLatency.lua; do
	if grep -En "$restricted_pattern" "$file"; then
		fail "review WoW 12 restricted or secret API usage in ${file}"
	fi
done

if command -v luac >/dev/null 2>&1; then
	for file in init.lua utils.lua shPerformance.lua shFps.lua shLatency.lua lib/*.lua; do
		if ! luac -p "$file"; then
			fail "Lua syntax check failed: ${file}"
		fi
	done
else
	printf '%s\n' 'SKIP: luac is unavailable; install a Lua 5.1 compiler for syntax checks.'
fi

if [ "$failures" -ne 0 ]; then
	printf 'Validation failed with %d issue(s).\n' "$failures" >&2
	exit 1
fi

printf '%s\n' 'Validation passed.'
