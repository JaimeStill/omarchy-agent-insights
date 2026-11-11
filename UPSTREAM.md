# Tracking upstream

The plugin is based on Omarchy's Agents plugin (`$OMARCHY_PATH/shell/plugins/agents/`), at the release
recorded in `UPSTREAM_VERSION`.

Upstream files are changed in two places only, both in `Panel.qml` and both marked
`// agent-insights:`. `hook.patch` holds them:

- the `insightsCollapsed` property on the panel root
- the `StatsSection { ... }` block at the end of `component ProviderSection`

Everything new lives in `StatsSection.qml`.

## After an `omarchy update`

```bash
./sync-upstream.sh   # copies Panel/Main/Agent/assets, re-applies hook.patch, rebuilds manifest.json
git diff             # review upstream's changes
```

Then bump `version` in `manifest.json`, commit and push. Other machines pick the change up with
`omarchy plugin update jaimestill.agent-insights`, which the dotfiles `install.sh` runs.

If `hook.patch` no longer applies, the script stops and says so. Re-add the two marked
blocks by hand, then regenerate the patch with the command it prints.

`collectors.py` is not copied: the collectors import it from `$OMARCHY_PATH`.
`manifest.json` is always generated from upstream's, so new providers and settings
come across automatically.

## Letting Claude Code do it

`.claude/agents/upstream-sync.md` is a Claude Code agent that runs this whole procedure, from
inside this repo:

```bash
cd ~/plugins/omarchy-agent-insights && claude "use the upstream-sync agent"
```

It runs the steps above:
- checks whether the installed release changed
- syncs, and repairs `hook.patch` if it no longer applies
- checks `StatsSection.qml` against anything upstream renamed
- validates the plugin and checks the live panel for QML errors
- bumps the version and commits

It never pushes; review its report, then `git push`.
