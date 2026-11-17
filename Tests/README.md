# Offline checks

Run from the Sintezza_Theme repository with Python 3.12 and Lupa's Lua 5.1 runtime.

```powershell
& 'C:/Program Files/WindowsApps/OpenAI.CodexPrimaryRuntime.v26-1112-611-0_26.1112.611.0_x64__3k8sg7r9htsxt/dependencies/python/python.exe' Tests/run.py --runtime 'D:/Games/WoW_addons/.execute-verification/.loot-verification-20261117/python'
```

FirstRun.lua loads the production Locale.lua, Fonts.lua and Settings.lua with UI stubs. It checks fresh and old profiles, preserved account fields, combat deferral, all manual launchers, an existing visible panel, failed openings, repeated events, reloads, character changes and replacing installed files. These mocks exercise lifecycle and persistence contracts. Native client rendering requires separate verification.

Tooltip.lua loads the production Help.lua and widget factory. It checks cursor and default-owner anchoring, edge flipping, stationary-cursor work, live UI-scale changes, repeated opening, owner hiding, fallback without a cursor API, cleanup after hiding, and subtitle-free shared header alignment and font roles.

Widgets.lua loads the actual shared factory with an anchor-constraint model. It checks tab bounds, non-overlap, reopening/resizing, selection, numeric-slider dimensions, zero values after showing, profile-write isolation, dragging, typed values and range changes. The same test reproduces the old overconstrained tab layout when run against its previous factory source. It does not render the native game client.

Slider regressions also cover nested setter notifications, accepted-value readback, coupled-row refreshes without extra writes and recovery after a setter error. Help tests cover initially unresolved label dimensions and repositioning an existing trigger after its caption changes.
