# Startup Tabs Design

## Goal

Allow `wtmux` to open multiple tabs at startup and execute an initial command in
 each tab automatically.

## Constraints From The Current Codebase

- Shell selection is currently global. `wtmux` chooses one shell from CLI or
  config and uses that shell for all tabs.
- New tabs already know how to start a session, but input can only be written to
  the focused pane of the active tab.
- PTY startup is Windows-specific, while most unit tests in this repository are
  pure module tests.

## Proposed UX

Add startup tab definitions to `config.toml`:

```toml
[[startup.tabs]]
name = "server"
command = "npm run dev"

[[startup.tabs]]
name = "tests"
command = "cargo test"
```

### Semantics

- If `startup.tabs` is empty or missing, startup behavior stays unchanged.
- The first `startup.tabs` entry maps to the already-created initial tab.
- Additional entries create additional tabs in order.
- `name` is optional. If omitted, the existing default tab name remains.
- `command` is optional. If omitted or blank, the tab starts idle.
- Commands are sent after each shell session has started. They are normalized to
  terminal input line endings and executed with Enter.

## Why Send Input Instead Of Wrapping The Shell Command

Using shell-specific wrappers such as `cmd.exe /k ...`, `pwsh -Command ...`, or
`wsl.exe -e ...` would require different quoting and "stay open" behavior per
shell. Sending the initial command through the PTY keeps startup behavior
consistent with normal interactive use and reuses the existing shell selection
logic.

## Implementation Plan

1. Extend config parsing with `startup.tabs`.
2. Add `WindowManager` support for writing to a specific tab's focused pane.
3. Build the startup tab set after the initial tab starts.
4. Resize all tabs once, then dispatch initial commands to each configured tab.
5. Restore focus to the first startup tab.

## Non-Goals For This Change

- Per-tab shell overrides
- Persisted sessions or detach/attach semantics
- Arbitrary pane layouts at startup

## Test Plan

- Parse `startup.tabs` from TOML and verify defaults.
- Verify configured tab names and tab count.
- Verify commands are written to the correct tabs with a trailing Enter.
- Verify blank commands are skipped.
- Verify focus ends on the first startup tab after initialization.
