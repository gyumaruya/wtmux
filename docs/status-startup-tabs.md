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

- `16 passed; 0 failed`
- Windows 固有の `core::pty::tests::test_conpty_creation`
- Windows 固有の `core::pty::tests::test_conpty_accepts_written_exit_input`
- startup tabs 用に追加した quiet-period 判定 test を含めて成功

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
powershell -ExecutionPolicy Bypass -File .\scripts\smoke-startup-tabs.ps1 -WtmuxExe .\target\release\wtmux.exe -Shell cmd -TabCount 1 -EnableVtTrace -RunRoot C:\Temp\startup-smoke-cmd-1b
powershell -ExecutionPolicy Bypass -File .\scripts\smoke-startup-tabs.ps1 -WtmuxExe .\target\release\wtmux.exe -Shell cmd -TabCount 2 -EnableVtTrace -RunRoot C:\Temp\startup-smoke-cmd-2
powershell -ExecutionPolicy Bypass -File .\scripts\smoke-startup-tabs.ps1 -WtmuxExe .\target\release\wtmux.exe -Shell pwsh -TabCount 1 -EnableVtTrace -RunRoot C:\Temp\startup-smoke-pwsh-1
powershell -ExecutionPolicy Bypass -File .\scripts\smoke-startup-tabs.ps1 -WtmuxExe .\target\release\wtmux.exe -Shell pwsh -TabCount 2 -EnableVtTrace -RunRoot C:\Temp\startup-smoke-pwsh-2
```

結果:

- 4 パターンすべて成功
- `cmd.exe` で 1 tab / 2 tabs の marker file 生成を確認
- `pwsh.exe` で 1 tab / 2 tabs の marker file 生成を確認
- すべて `exitCode = 0`
- すべて `vt_trace.log` と `report.json` を保存

途中で解消した問題:

- 非対話の `prlctl exec` 配下では `input redirection is not supported` で
  main loop が落ちていた
- これは `WTMUX_HEADLESS=1` を導入して解消済み
- `cmd.exe /k "chcp 65001 >nul"` の初期出力だけで ready 判定すると、
  shell の起動が落ち着く前に初期コマンドを送ってしまう
- これは shell 出力が一定時間静かになってから dispatch する形に変更して解消
- さらに smoke script が `cmd /c "wtmux.exe"` 経由で GUI プロセスを
  正しく待てていなかった
- これは `wtmux.exe` を直接 `Start-Process` して待つ形に変更して解消

判断:

- Windows ARM 上の build / unit test 基盤は整った
- 非対話 smoke を成立させる `headless` 経路は入った
- startup tabs の実挙動は `cmd.exe` / `pwsh.exe` とも実スモークを通過した
- Parallels ARM 上では今回の主要機能は検証済み

## まだできていないこと

### Windows 上の実スモーク

未完了:

- `x64 Windows` での build / 実行証跡
- 可能なら RDP での目視確認
- 必要なら `wsl.exe` を含む追加 shell 観点

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
- Windows ARM 上で `cargo test` / `cargo build --release` が通った
- Windows ARM 上で `cmd.exe` / `pwsh.exe` の startup tabs smoke が通った
- upstream 向けには、まだ `x64 Windows` の実行証跡が不足している

## 個人用 PR の使い方

この機能はまず fork 側の Draft PR として可視化し、
以下を PR 本文に載せるのがよい。

- 何を追加したか
- macOS で何が通ったか
- Parallels ARM Windows で何が確認できたか
- まだ不足している `x64 Windows` 検証は何か

このドキュメントはそのまま個人用 PR の状況説明の元資料として使う。
