# AGENTS.md

This file records repository-specific working rules derived from the current
layout and documentation in this repository.

## Source Of Truth

- Start from `README.md`, `README.ja.md`, `config.example.toml`, and any
  relevant `docs/design-*.md` note before changing user-visible behavior.
- There is no separate `CONTRIBUTING.md` in this repository today, so match
  existing file layout, naming, and inline test style.

## Change Scope

- Keep `wtmux` Windows-first. Runtime behavior should continue to center on
  ConPTY and tmux-like tab/pane workflows.
- Add configuration in a backward-compatible way using serde defaults.
- When a change adds or changes user-visible configuration or workflows, update
  these files together:
  - `README.md`
  - `README.ja.md`
  - `config.example.toml`
  - a design note under `docs/` when the behavior spans startup/session/UI flow

## Rust Conventions

- Prefer module-local unit tests inside `#[cfg(test)]` blocks in the touched
  source file.
- Keep pure logic testable without a real PTY where possible.
- Reuse existing structures and naming before introducing new modules.
- Keep comments short and only where the control flow is not obvious.

## Verification

- Run `cargo fmt`.
- Run `cargo test`.
- For Windows-only PTY behavior, keep as much as possible covered by pure unit
  tests and record any manual verification evidence separately when needed.

## Local Safety

- Repo-local git hooks live in `.githooks/`.
- Install them with `scripts/install-local-hooks.sh`, which sets
  `core.hooksPath` in local git config.
- Secret scanning is two-layered:
  - `betterleaks` for general secrets
  - `scripts/check-sensitive-changes.sh` for local machine leakage such as
    IP addresses, Windows product-key patterns, home-directory paths, and
    locally configured sensitive terms
- Add extra local usernames or machine-specific values with:
  `git config --local --add codex.sensitiveTerm <value>`
