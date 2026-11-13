# SNSリミッター（iOS）

インスタ・TikTok・YouTube を「1日◯分まで」＋「夜間ブロック」で制限する iPhone アプリの雛形です。
Apple 公式の Screen Time API（FamilyControls / DeviceActivity / ManagedSettings）を使っています。

## できること
- アプリ内で制限したいアプリを選ぶ（iOSの仕様で、アプリはApple純正の選択画面から選びます）
- 選んだアプリの合計利用が1日の上限に達したら、その日の残りはブロック（毎日0時にリセット）
- 夜間（例：23時〜7時）は時間に関係なくブロック
- ブロック中にアプリを開くと「今は使えません」画面を表示
- **リール・ショートだけ禁止**：インスタ・YouTubeのアプリ版は常にブロックし、Safariのブラウザ版で使う。Safari用ブロッカーでリール・ショートのページと入口を消す
- TikTokはブラウザ版も丸ごとブロック（アプリ版は時間制限の対象に選ぶ）

## 構成
| フォルダ | 役割 |
|---|---|
| `App/` | 設定画面（許可、アプリ選択、時間設定、開始/停止） |
| `MonitorExtension/` | OSが裏で呼ぶ監視拡張。上限到達・夜間の開始/終了でブロックを切り替え |
| `ShieldExtension/` | ブロック画面の文言・見た目 |
| `ContentBlocker/` | Safari用ブロッカー（`blockerList.json` がルール本体） |
| `ReportExtension/` | スクリーンタイム表示（今日の合計と多い順5アプリ） |
| `Shared/` | 設定の保存（App Group）とブロック処理 |
| `project.yml` | XcodeGen 用のプロジェクト定義 |

## 必要なもの
- Mac ＋ Xcode 15 以降
- iPhone 実機（iOS 16以降。**シミュレータではスクリーンタイム制限は動きません**）
- Apple Developer アカウント（自分のiPhoneで試すだけなら無料アカウントでも可の場合あり。App Store配布には有料登録＋Family Controls権限の申請が必要）

## ビルド手順
1. `brew install xcodegen`
2. `project.yml` の `bundleIdPrefix`・`DEVELOPMENT_TEAM`、App Group 名（`group.com.example.snslimiter`、`Shared/SharedSettings.swift` にもあり）を自分のものに変更
3. `cd sns-limiter && xcodegen generate` → `SNSLimiter.xcodeproj` を開く
4. 各ターゲットの Signing & Capabilities で「Family Controls」「App Groups」が付いていることを確認
5. iPhone を繋いで実行 → 「スクリーンタイムの利用を許可する」→ アプリを選ぶ → 「この設定で制限を開始」

## リール・ショート制限の使い方
1. アプリの「アプリ版は常にブロック」でインスタ・YouTubeを選ぶ
2. iPhoneの 設定 > アプリ > Safari > 拡張機能 で「SNSリミッター」をオン
3. インスタのDMはアプリの「インスタのDMを開く」ボタンから（アプリ内Safariで開くのでブロッカーが効き、インスタアプリにも飛ばされません。初回のみログインが必要）
4. 以後インスタ・YouTubeは Safari で instagram.com / youtube.com を開いて使う

### Safariブロッカーのルール（`ContentBlocker/blockerList.json`）
| 対象 | 内容 | 確実さ |
|---|---|---|
| YouTube | `youtube.com/shorts/` を直接開くとブロック | 確実 |
| YouTube | ショート読み込みAPI（`/youtubei/v1/reel/`）をブロック | 推測。サイト内でタップして遷移した場合の対策 |
| YouTube | ショートの棚・タブ・リンクを非表示 | 推測。YouTube側の画面変更で効かなくなることあり |
| Instagram | `instagram.com/reel/`・`/reels/` を直接開くとブロック | 確実 |
| Instagram | リールAPI（`/api/v1/clips/`）をブロック | 推測 |
| Instagram | リールタブ・リールへのリンクを非表示 | 推測 |
| TikTok | tiktok.com を丸ごとブロック | 確実 |

YouTube・インスタはページを再読み込みせずに画面を切り替えるため、URLブロックだけでは
サイト内でショートをタップしたときに止まらないことがあります。そのため「入口を隠す」「動画APIを止める」も重ねています。
「推測」のルールは実機のSafariで確認して、効かなければセレクタやURLを調整してください。

## App Store に出す場合
Family Controls（Distribution）の権限を Apple に申請する必要があります：
https://developer.apple.com/contact/request/family-controls-distribution

## 今後の拡張アイデア
- 独自チャット（将来的にインスタDMの代わりに。友達同士で励まし合う機能とセットで）
- アプリごとに別々の上限時間
- 「本当に開く？」の一呼吸画面（ShieldActionExtension で実装可能）
- 今日の利用時間グラフ（DeviceActivityReport 拡張）

## 実機での確認チェックリスト（最初にやること）
1. ビルドして起動 → 「スクリーンタイムの利用を許可する」で許可ダイアログが出て許可できる
2. 時間制限：対象にTikTokを選び、上限を5分にして開始 → 5分使うとブロック画面が出る
3. ブロック画面の文言が日本語で表示される
4. 夜間ブロック：開始/終了を数分後に設定 → その時刻にブロック・解除される
5. 翌日0時過ぎに時間制限がリセットされている
6. Safari > 拡張機能でブロッカーをオン → `youtube.com/shorts/…` を直接開くと止まる
7. YouTube（Safari）のトップでショートの棚・タブが消えている／ショートをタップしても再生されない
8. インスタ（Safari）でリールタブが消えている／リールをタップしても再生されない
9. 「インスタのDMを開く」→ ログインしてDMが使える、リールが出ない、インスタアプリに飛ばない
→ 6〜9で効かないものがあれば、Safariの「Webインスペクタ」で該当要素のクラス名やURLを調べて `blockerList.json` を直す
10. （未実装・設計中）連続スクロール止め：2時間ごとの区切りで「20分見たら次の区切りまでブロック」がDeviceActivityで期待どおり動くか
11. ブロック画面とアプリのトップに、デトックスTipsが毎回ちがうものになって表示される
12. アプリのトップに「今日のスクリーンタイム」と、多い順のアプリ5つが表示される（設定アプリのスクリーンタイムと数字が近いか）
