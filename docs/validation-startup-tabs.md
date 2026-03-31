# Startup Tabs Validation Plan

## 目的

`startup.tabs` による複数タブ起動と初期コマンド実行機能を、
過不足なく検証するための実施計画をまとめる。

この機能は UI 上の見え方だけではなく、

- 設定ファイルの互換性
- 起動時のタブ生成順
- 各タブへのコマンド配送
- Windows / ConPTY 上での実行成立性

を分けて確認する必要がある。

## 先に押さえる前提

現状のリポジトリが明示している配布ターゲットは `x64 Windows` である。
少なくとも以下のファイルでは `x64` が固定されている。

- `README.md`
- `build-portable.ps1`
- `build-installer.ps1`
- `build-msix.ps1`
- `installer/msix/AppxManifest.xml`
- `installer/wtmux.iss`

そのため、アーキテクチャ別の優先順位は以下とする。

1. 必須: `x64 Windows`
2. 追加で強い証拠: `Windows 11 on Arm`
3. 補助証拠: Apple Silicon + Parallels の Intel VM エミュレーション

## 環境ごとの役割

### 1. macOS (ARM) ローカル

役割:

- 設計と実装
- 純ロジック unit test
- 差分整理
- 検証計画とスクリプト作成

確認項目:

- `startup.tabs` の TOML パース
- タブ数、順序、名前
- 空コマンドのスキップ
- 改行正規化
- 起動後に先頭タブへフォーカスが戻ること

### 2. Parallels / Windows 11 on Arm

役割:

- Windows API / ConPTY の一次スモーク
- UI の早い反復確認
- `cmd.exe` / `pwsh.exe` の最低限確認

確認項目:

- `wtmux.exe` 自体が起動できること
- startup tabs が UI 上で見えること
- 初期コマンドが取りこぼれず走ること

注意:

- これは有効な検証だが、`x64 Windows` 本命の代替にはしない

### 3. リモート x64 Windows + SSH

役割:

- 本命の自動化検証
- `cargo test`
- `cargo build --release`
- startup tabs の自動スモーク
- ログ / 証跡回収

確認項目:

- `cmd.exe` で複数タブ起動と各タブの初期コマンド実行
- `pwsh.exe` で同上
- 必要なら `wsl.exe` の追加確認
- 実行後に証跡ファイルが揃うこと

### 4. リモート x64 Windows + RDP

役割:

- 最終的な視覚確認
- タブ名
- アクティブタブ
- フォーカス復帰
- 出力の見え方

確認項目:

- 初期タブと追加タブの表示順
- タブタイトルが設定どおりか
- 起動後に先頭タブへ戻っているか
- 非アクティブタブ側でもコマンドが動いていたことが見えるか

## 推奨の実施順

1. macOS で unit test
2. Parallels / Windows 11 on Arm で高速スモーク
3. リモート x64 Windows を SSH で本命検証
4. 必要箇所だけ RDP で可視確認

## テスト観点

### A. 純ロジック

- config 読み込みが後方互換であること
- `[[startup.tabs]]` が未設定なら従来挙動のまま
- 1件目が既存の初期タブに割り当たること
- 2件目以降で新規タブが追加されること
- 空文字 / 空白コマンドは送信しないこと
- LF / CRLF が CR に正規化されること

### B. Windows 実行

- `cmd.exe`
- `pwsh.exe`
- 必要なら `wsl.exe`

観点:

- 各タブに別々のコマンドが送られること
- タブ間で取り違えないこと
- すべてのタブが終了すれば `wtmux` も終了できること

### C. UI / 視覚確認

- タブ名表示
- アクティブタブ
- 最初のタブへフォーカス復帰
- 複数タブが起動している見た目

## 自動化スクリプト

`scripts/smoke-startup-tabs.ps1` を追加している。

このスクリプトは以下を行う。

- 一時ディレクトリを作る
- `LOCALAPPDATA` をその一時ディレクトリ配下へ切り替える
- 一時 `config.toml` を生成する
- startup tabs に 2 タブ分のコマンドを書く
- 各タブのコマンドで一意な marker file を出力する
- 必要なら `--vt-trace` を有効化する
- 実行後に marker file と report JSON を検査する

重要:

- 既存ユーザーの `%LOCALAPPDATA%\wtmux\config.toml` は触らない
- `WTMUX_CONFIG_DIR` ではなく `LOCALAPPDATA` を一時的に差し替える
  方針を取る

## SSH での実行例

リモート Windows 側にこのリポジトリがある前提:

```powershell
cargo test
cargo build --release
powershell -ExecutionPolicy Bypass -File .\scripts\smoke-startup-tabs.ps1 -WtmuxExe .\target\release\wtmux.exe -Shell cmd
powershell -ExecutionPolicy Bypass -File .\scripts\smoke-startup-tabs.ps1 -WtmuxExe .\target\release\wtmux.exe -Shell pwsh -EnableVtTrace
```

## RDP での最終チェックリスト

- 起動時に 2 タブ以上が見える
- タブ名が `server` / `tests` など指定どおり
- 起動後に先頭タブがアクティブ
- 非アクティブタブでもコマンド結果が残っている
- 必要なら `cmd.exe` と `pwsh.exe` の両方で見た目を確認

## 回収する証跡

- `cargo test` の出力
- `cargo build --release` の出力
- `scripts/smoke-startup-tabs.ps1` の JSON report
- marker file 2件
- 必要なら `%LOCALAPPDATA%\wtmux\vt_trace.log`
- RDP でのスクリーンショット

## 既知の制約

- Apple Silicon 上の Parallels Intel VM エミュレーションは補助検証とみなす
- `x64 Windows` 実機またはそれに準ずる環境を最終判断に使う
- `wsl.exe` の検証は環境依存なので、まずは `cmd.exe` / `pwsh.exe`
  を必須にする
