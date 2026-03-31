# Startup Tabs Status

## 目的

このドキュメントは `startup.tabs` 機能の現在地を固定し、
個人用 PR やレビュー前の共有に使える状態要約として残す。

## 今できていること

- `config.toml` に `[[startup.tabs]]` を追加できる
- 1 件目の `startup.tabs` は既存の初期タブに適用される
- 2 件目以降は追加タブとして起動される
- 各タブに `name` を設定できる
- 各タブに `command` を設定できる
- 空文字や空白だけの `command` は送信しない
- 改行を端末入力向けに正規化して送信する
- startup tabs 初期化後に先頭タブへフォーカスを戻す

## 追加済みの補助物

- `README.md`
- `README.ja.md`
- `config.example.toml`
- `docs/design-startup-tabs.md`
- `docs/validation-startup-tabs.md`
- `scripts/smoke-startup-tabs.ps1`

## 実施済みテスト

### macOS (ARM) ローカル

2026-04-01 実行:

```bash
cargo test
```

結果:

- `12 passed; 0 failed`
- startup tabs 用に追加した config / window manager test を含めて成功

2026-04-01 実行:

```bash
cargo fmt --check
```

結果:

- 失敗
- ただし失敗内容は今回の変更だけではなく、既存コードベース全体にまたがる
  整形差分
- upstream へ出す前に、今回の差分だけで済むのか、別件として repo 全体の整形
  を扱うのかを切り分ける必要がある

### Parallels / Windows 11 on Arm

2026-04-01 実行:

```bash
prlctl start "Windows 11"
prlctl list -i "Windows 11"
prlctl exec "Windows 11" cmd /c ver
prlctl exec "Windows 11" powershell -NoLogo -NoProfile -Command "Get-Command git -ErrorAction SilentlyContinue | Format-Table -HideTableHeaders Name,Source"
```

確認できたこと:

- VM は起動できる
- ゲストは `efi-arm64`
- Windows バージョンは `10.0.26200.7840`
- `prlctl exec` は使える
- 少なくとも `git.exe` は入っている

現時点の制約:

- いま見えている Parallels ゲストは `ARM Windows` のみ
- `prlctl exec --current-user` は今の状態では使えず、自動実行は
  `systemprofile` 文脈になる
- その文脈では `rustc` / `cargo` が見えていない
- そのため、Parallels ゲスト内で現行差分を build して
  `scripts/smoke-startup-tabs.ps1` を回す段階まではまだ進めていない

## まだできていないこと

### Windows 上の実スモーク

未実施:

- `cmd.exe` で startup tabs の自動スモーク
- `pwsh.exe` で startup tabs の自動スモーク
- `--vt-trace` を含む Windows 証跡回収

必要条件:

- `x64 Windows` での build / 実行経路
- もしくは Parallels 側に `x64` ゲストを用意する
- あるいは既存のリモート `x64 Windows` を SSH で操作する

### 最終判断に必要な証拠

- `x64 Windows` での `cargo test`
- `x64 Windows` での `cargo build --release`
- `scripts/smoke-startup-tabs.ps1` の JSON report
- 必要なら `vt_trace.log`
- 目視確認用のスクリーンショット

## 判断

いまの段階で言えること:

- 設計、実装、unit test、設定例、検証計画は揃っている
- macOS 上の純ロジック検証は通っている
- ただし upstream 向けに十分と言うには、まだ `x64 Windows` の
  実行証跡が不足している

## 個人用 PR の使い方

この機能はまず fork 側の Draft PR として可視化し、
以下を PR 本文に載せるのがよい。

- 何を追加したか
- macOS で何が通ったか
- Parallels ARM Windows で何が確認できたか
- まだ不足している `x64 Windows` 検証は何か

このドキュメントはそのまま個人用 PR の状況説明の元資料として使う。
