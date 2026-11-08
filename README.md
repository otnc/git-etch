# git-etch

[![技術者倫理|遵守済み](https://gijutsusharin.li/badge.svg)](https://gijutsusharin.li)

`git fetch` と打つつもりで `git etch` とミスタイプすると、アレな音声が1回流れます。

```text
$ git etch origin
git: 'etch' is not a git command. It is, however, an ecchi one.

Nothing fetched. Everything etched.
```

> [!WARNING]
> **職場の PC には絶対に入れないこと。**

## インストール

macOS、Linux、Windows (Git for Windows) で動きます。リポジトリのルートで次を実行してください。Windows では Git Bash で実行します。

```sh
sh install.sh
```

`~/.local/bin` にインストールされます。PATH に入っていなければ追加してください。

```sh
export PATH="$HOME/.local/bin:$PATH"
```

Windows では、PowerShell で次を実行すると、コマンドプロンプトや PowerShell からも使えるようになります。

```powershell
[Environment]::SetEnvironmentVariable('Path', "$env:USERPROFILE\.local\bin;" + [Environment]::GetEnvironmentVariable('Path', 'User'), 'User')
```

インストール先は `INSTALL_DIR` で変えられます。`etch` という名前の Git エイリアスがあると、そちらが優先されます。

## 音声について

Pincree の音声は、ガイドラインに従ってリポジトリには同梱していません。インストール時に「ダウンロードするか」「18歳以上か」「ガイドラインに同意するか」を聞き、すべてに同意すると、`git etch` は未ダウンロードのものも含めたすべての音声から1つを選び、未ダウンロードのものが当たったときはダウンロードしてから再生します。

まとめてダウンロードするときは、次を実行します。

```sh
sh install.sh sounds
```

ダウンロードした音声を再配布しないでください。インストール先の `sounds/` に自分で `.wav` を置くと、それも再生されます。

## アンインストール

```sh
sh uninstall.sh
```

## 開発者向け

音声の一覧は `pincree-sounds.b64` に base64 で入っています。`node scripts/pincree-sounds.mjs decode` で `pincree-sounds.jsonl` (`.gitignore` 済み) に展開し、編集したら `encode` で戻してください。

## ライセンス

[MIT License](LICENSE-MIT) or [Apache License, Version 2.0](LICENSE-APACHE)

音声素材: Pincree  
音声素材利用のガイドライン: https://pincree.jp/guidelines
