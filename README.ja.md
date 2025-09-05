[English](https://github.com/signothecat/zsnake/blob/develop/README.md) | 日本語(Japanese)

<img width="400" alt="zsnake" src="https://github.com/user-attachments/assets/c50d7d2b-ae32-45fe-8dc4-9d7e4f84d186" />

# zsnake

**zsh で遊べるヘビゲーム**をリリースしました！

<img src="https://github.com/user-attachments/assets/274ec216-55f1-4e37-9ec0-eaf1074db9ad" width="50%">

## 目次

- [特長](#特長)
- [システム要件](#システム要件)
- [インストール手順](#インストール手順)
  - [ローカル実行(簡単)](#ローカル実行簡単)
  - [グローバルにインストール(どこでも遊べる)](#グローバルにインストールどこでも遊べる)
- [よくある質問](#よくある質問)
  - [アンインストールするには？](#アンインストールするには)
- [Contributing](#contributing)
- [License(ライセンス)](#licenseライセンス)

## 特長

- 矢印キー ⬅️⬆️⬇️➡️、**W/A/S/D**キー、もしくは**h/j/k/l**キーで遊べます
- zsh で動作します

## システム要件

- Zsh 5.8 以上が必要です

注記：ゲーム画面描画には、Unicode 文字（`■`）を使用しています。\
ASCII のみの環境では、表示がずれたり、文字化けしたりする可能性があります。

## インストール手順

### ローカル実行(簡単)

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

### グローバルにインストール(どこでも遊べる)

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

## よくある質問

### アンインストールするには？

もし Local Install をした場合は、`zsnake`フォルダを削除してください。

```zsh
rm -rf zsnake
```

もし Global Install をした場合は、`/usr/local/bin`にある zsnake フォルダを削除してください。

```zsh
sudo rm /usr/local/bin/zsnake
```

## Contributing

このプロジェクトは、`signothecat`が作成しています。\
新しいアイデアの提案や問題点の報告など、もし頂けたらとても有り難いです。\
(Issue、Pull Request 大歓迎です！)\
プレイ報告などもお待ちしております！

## License(ライセンス)

MIT License © 2025 signothecat
