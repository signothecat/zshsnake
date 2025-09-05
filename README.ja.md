[English](https://github.com/signothecat/zsnake/blob/develop/README.md) | 日本語(Japanese)

<img width="400" alt="zsnake" src="https://github.com/user-attachments/assets/c50d7d2b-ae32-45fe-8dc4-9d7e4f84d186" />

# zsnake

**zsh で遊べるヘビゲーム**をリリースしました！

<img src="https://github.com/user-attachments/assets/274ec216-55f1-4e37-9ec0-eaf1074db9ad" width="50%">

## Table of Contents(目次)

- [Features(特徴)](#features)
- [Requirements(要件)](#requirements)
- [Installation(インストール方法)](#installation)
  - [Local Install(直接ファイルを読み込んで遊ぶ)](#local-install)
  - [Global Install(グローバルにインストールする)](#global-install)
- [FAQ(よくある質問)](#faq)
  - [How can I uninstall zsnake?(アンインストール方法を教えて)](#how-can-i-uninstall-zsnake)
- [Contributing(コントリビュート)](#contributing)
- [License(ライセンス)](#license)

## Features(特徴)

- 矢印キー ⬅️⬆️⬇️➡️、**W/A/S/D**キー、もしくは**h/j/k/l**キーで遊べます
- zsh で動作します

## Requirements(要件)

- Zsh 5.8 以上が必要です

注記：ゲーム画面描画には、Unicode 文字（`■`）を使用しています。ASCII のみの環境では、表示がずれたり
文字化けしたりする可能性があります。

## Installation(インストール方法)

### Local Install(直接ファイルを読み込んで遊ぶ)

リポジトリをクローンし、クローンされたディレクトリに移動します:

```zsh
git clone https://github.com/signothecat/zsnake.git
```

クローンされたディレクトリに移動します:

```
cd zsnake
```

ゲームを起動します:

```zsh
zsh zsnake.zsh
```

### Global Install(グローバルにインストールする)

リポジトリをクローンします:

```zsh
git clone https://github.com/signothecat/zsnake.git
```

`zsnake.zsh`を、`/usr/local/bin/zsnake`としてコピーします:

```zsh
cd zsnake
sudo cp zsnake.zsh /usr/local/bin/zsnake
```

ゲームを起動します(どこでも):

```zsh
zsnake
```

## FAQ(よくある質問)

### How can I uninstall zsnake?(アンインストール方法を教えて)

もし Local Install をした場合は、`zsnake`フォルダを削除してください。

```zsh
rm -rf zsnake
```

もし Global Install をした場合は、`/usr/local/bin`にある zsnake フォルダを削除してください。

```zsh
sudo rm /usr/local/bin/zsnake
```

## Contributing(コントリビュート)

このプロジェクトは現在進行系でプログラミング初心者の signothecat が作成しています。新しいアイデアの
提案や問題点の報告など、もし頂けたらとても有り難いです。(Issue、Pull Request 大歓迎です！) プレイ報
告などもお待ちしております！

## License(ライセンス)

MIT License © 2025 signothecat
