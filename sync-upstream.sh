#!/usr/bin/env bash
# Re-base this plugin on the Agents plugin of the installed Omarchy release:
# copy the upstream files, re-apply hook.patch, and regenerate manifest.json
# from upstream's. Review with `git diff`, then validate and commit.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
upstream="${OMARCHY_PATH:-/usr/share/omarchy}/shell/plugins/agents"
[[ -f $upstream/Panel.qml ]] || { echo "upstream not found: $upstream" >&2; exit 1; }

cp "$upstream/Panel.qml" "$upstream/Main.qml" "$upstream/Agent.qml" "$repo/"
rm -rf "$repo/assets" && cp -r "$upstream/assets" "$repo/assets"

if ! patch --quiet --forward --no-backup-if-mismatch -d "$repo" -p1 <"$repo/hook.patch"; then
  echo "hook.patch did not apply cleanly; re-add the two '// agent-insights:' blocks in Panel.qml by hand," >&2
  echo "then refresh the patch: diff -u --label a/Panel.qml --label b/Panel.qml $upstream/Panel.qml Panel.qml > hook.patch" >&2
  exit 1
fi

version="$(jq -r .version "$repo/manifest.json")"
jq --arg version "$version" '
  .id = "jaimestill.agent-insights"
  | .name = "Agent Insights"
  | .author = "JaimeStill"
  | .version = $version
  | .description = "Omarchy Agents panel with the per-day and per-model token breakdowns restored."
  | .barWidget.displayName = "Agent Insights"
  | del(.barWidget.aliases)
  | .omarchy = ((.omarchy // {}) + {clonedFrom: "omarchy.agents"})
  | del(.omarchy.clonePaths)
' "$upstream/manifest.json" >"$repo/manifest.json.tmp"
mv "$repo/manifest.json.tmp" "$repo/manifest.json"

base="$(pacman -Q omarchy 2>/dev/null | awk '{print $2}')"
echo "${base:-unknown}" >"$repo/UPSTREAM_VERSION"

omarchy plugin validate "$repo"
echo "Synced from omarchy ${base:-unknown}. Review 'git diff', bump .version in manifest.json, commit."
