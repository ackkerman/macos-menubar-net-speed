# MenubarNetSpeed

macOS メニューバーに常駐し、Wi-Fi (en0) の実効通信速度とオンデマンド計測を行う軽量ツールです。通常時は OS のネットワーク統計のみを参照し、ユーザー操作時のみ外部通信を行います。

## 機能
- メニューバーに 1 秒ごとの上り/下り実効速度を表示
- メニューから最大速度測定（Cloudflare スピードテストを使用）
- メニューのインターフェース選択で監視対象を切替（en*/utun* 等を列挙）
- メニューから `sudo iftop -i <選択インターフェース> -N -P -B -m 100M` を Terminal で起動（sudo パスワード入力が必要）
- Dock 非表示 (`LSUIElement`)

## 前提
- macOS 13 以降
- Xcode Command Line Tools（`swift` が使える環境）

## ビルド & パッケージ
```bash
make build
```
- 成果物: `build/MenubarNetSpeed.app`

## インストール
```bash
make install
```
- `/Applications/MenubarNetSpeed.app` へコピー

## 実行
```bash
make run
```
- ビルド済みの `.app` を `open` で起動します。メニューバー右上に「↓ 0 ↑ 0」が表示されます。

## クリーン
```bash
make clean
```

## ログ出力
- 起動時に `/tmp/menubarnetspeed.log` にデバッグログを追記します。
- システムログ確認例:
  ```bash
  log show --style compact --predicate 'process == "MenubarNetSpeed"' --last 2m
  ```

## カスタマイズ
- 計測インターフェース: `Sources/AppDelegate.swift` の `interfaceName` を変更
- Info.plist: バンドル ID 等は `Info.plist` を直接編集

## ライセンス
このリポジトリのライセンス情報は未設定です。
