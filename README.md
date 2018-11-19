# Extagram

## What's this?
指定したInstagramアカウントのフォロワーに自動でいいねするツール

## Installation
1. elixirのインストール
```sh
brew install elixir
```
2.ChromeDriverをインストール[link](https://sites.google.com/a/chromium.org/chromedriver/downloads)

3./usr/local/bin配下に移動(任意)
```sh
mv ./chromedriver /usr/local/bin/
```
4.依存ライブラリをインストール
```sh
mix deps.get
```

5.環境変数の設定　ログインするアカウントを指定する
```
export INSTAGRAM_USERNAME=hoge
export INSTAGRAM_PASSWORD=fuga
#いいねするアカウントの数(デフォルトで100)
export LIKE_TARGET_LIMIT=1000
#デフォルトではヘッドレスモード(バックグラウンド動作)だが、以下を指定でウィンドウが立ち上がる
#export HEADLESS_MODE=false
```

## How to use

1.chromedriverを起動
```sh
chromedriver
```

2.extagram実行 複数アカウントを指定すると順番にいいねを始める
```sh
mix auto_like username1 username2
```


