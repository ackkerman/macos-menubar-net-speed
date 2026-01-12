# Plan

- スケルトン: AppKitベースのメニューバー専用 macOS アプリを手動ビルドする。
- 実装: spec.md の仕様に沿って NSStatusItem とネットワーク統計取得を実装し、LSUIElement で Dock 非表示。
- ビルド/パッケージ: `swiftc` でバイナリを作成し、`.app` バンドルを手動生成する。成果物は `build/MenubarNetSpeed.app` に配置。
- 検証: ビルド成功の確認（実行テストはヘッドレスのため省略）。
