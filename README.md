# auto-trading-support-tools
Linux + Wine + MetaTrader4/5 の自動売買サーバーの構築と監視をサポートするツール群です。
とくに複数の MT4/5 を扱う手間を軽減するためのものです。  


自動売買において、最も最悪の事態は「決済されないこと」です。
MetaTraderのクラッシュやサーバーの予期せぬ再起動を検知して対処をすれば被害は最小で済みます。
そのためのツール群です。


* 対応している Linux のディストリビューション
    * Ubuntu
    * Debian


* 動作確認環境は以下のディストリビューションの x86_64, minimal 版
    * Ubuntu 14.04, 16.04, 18.04, 18.10
    * Debian 8, 9


* 動作確認環境のカーネルバージョン
    * 格安VPSに多い仮想化方式 [OpenVZ](https://ja.wikipedia.org/wiki/OpenVZ) で使われるカーネル
        * 2.6.32-xxx
        * 3.10.0-xxx
    * 少しお高い VPS に多い仮想化方式 [KVM](https://ja.wikipedia.org/wiki/Kernel-based_Virtual_Machine) で使える最近のカーネル
        * 4.15.0-xxxx


## このツール群でできること
* まっさらな Linux VPS に MetaTrader4/5 (以下MT4/5) を動かすのに必要なもの一式をインストール
* 起動時にMT4/5を自動起動
* 以下のことを検知してLINEに通知
    * VPSの再起動
    * MT4/5 のクラッシュ
    * ソフトウェア更新が利用可能(自動更新はしない)

<img src="../../wiki/images/mt4_on_linux_vps.png" width="480px">  

↑ こうなる。そしてこの状態を保っていることを監視するためのもの。

## このツールがインストール・設定するもの
* 既存パッケージの最新化
* 可能ならば swap 領域の作成
* vncserver + wm2
    * 要するに最小構成のGUI
* wine
    * Linux 上で Windows 用アプリを動かすソフト
* MT4/5 インストーラ の起動
    * MT4/5本体は GUI で操作しながらインストールする必要が有るため手動でインストールする必要有リ


## Google Compute Engin の無料VMインスタンスでの例
まっさらな Linux VPS → 自動売買開始 → 監視 → LINE通知 までを一通りやってみましょうヽ(=´▽`=)ﾉ

1. [VMインスタンス作成](../../wiki/create_vm_gce)
1. [自動売買に必要なものをインストール](../../wiki/install_misc)
1. [VMインスタンスの GUI にリモート接続](../../wiki/connect_gui)
1. [MetaTrader をインストール・設定](../../wiki/install_mt)
1. [LINE への通知設定(LINE側)](../../wiki/create_line_channel)
1. [LINE への通知設定(VM側)](../../wiki/setup_line)
1. [再起動検知やMT4/5クラッシュ検知を設定](../../wiki/setup_monitoring)


を、一通り行っている作業動画がこちら↓  
[<img src="../../wiki/images/install_thumb.png" width="280px">](http://www.youtube.com/watch?v=h3-sCCXt8hY)


### おまけ
1. [外側からの監視の設定](../../wiki/setup_stackdriver)
    * サーバーそのものやネットワークのダウンを検知する


## 既にLinux + Wine + MetaTrader4/5 で自動売買をしている人向けの紹介

まずは crontab.
```
# start MetaTrader automatically at boot
@reboot $HOME/auto-trading-support-tools/mtctl.sh start land-fx

0 9 * * * $HOME/auto-trading-support-tools/check_daily.sh
*/10 * * * * $HOME/auto-trading-support-tools/check_process.sh land-fx
* * * * * $HOME/auto-trading-support-tools/check_reboot.sh
```

こんな感じで設定しておけば、再起動時とMT4/5プロセスが落ちたときにLINEへ通知を飛ばしてくれます。  


「land-fx」となっている部分はMT4/5がインストールされているフォルダ名なら何でもよく、複数指定可能。  指定された名前に該当するMT4/5のインストールフォルダを前方一致で検索するのでフォルダ名の先頭の一部を記載しておけばOK.


@reboot の行は再起動時のMT4/5の自動起動設定です。

mtctl.sh は 複数の MT4/5 の一覧・起動・終了・状態確認ができるスクリプトです。使い方は↓こん感じ。
```
Usage: mtctl.sh [-qsh] <list|start|status|stop> <MetaTrader Name1> [<MetaTrader Name2> ...]
	list: list MetaTrader installed
	start: start MetaTrader
	status: print status of specified MetaTrader
	stop: stop MetaTrader
	<MetaTrader Name>: folder name MetaTrader installed. It's searched in a forward match. (ex: "MetaTrader 4")
	-s: when list, show running status.(slow)
	-q: quiet mode. print nothing.
	-h: help. print this message.
```
