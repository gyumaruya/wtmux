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
- `git.exe` は入っている
- Rust toolchain を導入できる
- Visual Studio Build Tools と Windows SDK を導入できる

2026-04-01 実行:

```powershell
cargo test
```

結果:

- `13 passed; 0 failed`
- Windows 固有の `core::pty::tests::test_conpty_creation` を含めて成功

2026-04-01 実行:

```powershell
cargo build --release
```

結果:

- 成功
- `target\release\wtmux.exe` を生成

現時点の制約:

- いま見えている Parallels ゲストは `ARM Windows` のみ
- `prlctl exec --current-user` は今の状態では使えず、自動実行は
  `systemprofile` 文脈になる

### Windows 実スモーク結果

2026-04-01 実行:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\smoke-startup-tabs.ps1 -WtmuxExe .\target\release\wtmux.exe -Shell cmd
```

結果:

- 失敗
- タブ生成自体は見える
- ただし marker file が生成されない
- `WTMUX_DEBUG_STARTUP_TABS=1` 付きの再実行では、
  - tab 1 command は pending のまま close 済みタブとして drop
  - tab 2 command は dispatch されたが marker file は生成されない

判断:

- Windows ARM 上の build / unit test 基盤は整った
- しかし startup tabs の実挙動は、まだ実機 smoke を通っていない
- upstream 向けにはこの failure を解消してから進めるべき

## まだできていないこと

### Windows 上の実スモーク

未完了:

- `cmd.exe` smoke の成功
- `pwsh.exe` smoke の成功
- `--vt-trace` を含む成功証跡回収

必要条件:

- startup command dispatch の実機 failure 解消
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
- Windows ARM 上で `cargo test` / `cargo build --release` までは通った
- ただし startup tabs の実スモークは失敗している
- 加えて upstream 向けには、まだ `x64 Windows` の実行証跡も不足している

## 個人用 PR の使い方

この機能はまず fork 側の Draft PR として可視化し、
以下を PR 本文に載せるのがよい。

- 何を追加したか
- macOS で何が通ったか
- Parallels ARM Windows で何が確認できたか
- まだ不足している `x64 Windows` 検証は何か

このドキュメントはそのまま個人用 PR の状況説明の元資料として使う。
