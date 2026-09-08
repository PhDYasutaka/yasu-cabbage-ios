# きゃべつ (LetusApp-iOS)

東京理科大学のLMS「LETUS」用のiOS WKWebViewラッパーアプリ。Android版（`LetusApp`）のiOS移植版。

## 機能

- LETUS (`https://letus.ed.tus.ac.jp/`) をアプリ内WebViewで表示。SSO(Shibboleth)ログインもWebView内で完結
- Cookieは永続化され、次回起動時もログイン状態を維持
- 課題提出などのファイルダウンロードは共有シート経由でFiles/AirDropに保存可能
- ファイルアップロード時、端末内ファイルの選択に加えて「写真を撮影/選択してPDFにまとめてアップロード」が可能（複数枚→1つのPDFに変換）
- Pull-to-refresh対応

### 未実装（意図的に保留中）

バックグラウンドでの新着通知監視（`Future/BackgroundNotificationChecker.swift.txt`に実装済みのロジックはあるが未接続）。理由は[Sources/AppDelegate.swift](Sources/AppDelegate.swift)のコメントの通り、`BGTaskScheduler`のBackground Modes capabilityが無料/個人チームの署名では正しくプロビジョニングできずクラッシュするため。**有料のApple Developer Program（$99/年）に加入すれば有効化できる。** 現状は個人サイドロード運用のため未接続のままにしている。

## ビルド方法（CI）

`main`ブランチへのpushで GitHub Actions (`.github/workflows/build-ios.yml`) が自動的に**未署名**の`.ipa`をビルドし、Artifactとして14日間保持する。ローカルにMacがなくても、Windows上のClaude CodeからこのCIをトリガー・監視できる。

```
gh run list --repo PhDYasutaka/yasu-cabbage-ios --limit 5
gh run download <RUN_ID> --repo PhDYasutaka/yasu-cabbage-ios -n CabbageApp-unsigned-ipa -D build-output/CabbageApp-unsigned-ipa
```

## 実機へのインストール（個人サイドロード / 無料Apple ID）

有料Developer Programなしで自分のiPhoneにインストールする手順。**署名は7日間で失効するため、7日ごとに再サイドロードが必要。**

### 必要なもの

- Windows PC（このワークスペースと同じPCでOK）
- iPhone本体とLightning/USB-Cケーブル
- 無料のApple ID（何らかのApple IDでOK。App Store課金用と分けたい場合は新規作成しても良い）
- [Sideloadly](https://sideloadly.io/)（このPCには`winget install iOSGods.Sideloadly`で導入済み。実体は`%LOCALAPPDATA%\Sideloadly\sideloadly.exe`。初回起動時にiTunes/Apple Mobile Device Supportのインストールを求められたら案内に従う）

### 手順

1. 上記の`build-output/CabbageApp-unsigned-ipa/CabbageApp.ipa`を用意する（すでに最新コミット分がこのパスに存在するはずなので、コード変更していなければ再ビルド不要）
2. iPhoneをUSBケーブルでPCに接続し、「このコンピュータを信頼する」を許可
3. Sideloadlyを起動し(インストール済みならスタートメニューで「Sideloadly」を検索)、`.ipa`を上のCabbageApp.ipaにドラッグ＆ドロップ
4. Apple IDのメールアドレスを入力して「Start」。初回はApple IDのパスワード入力を求められる（2ファクタ認証のコードも）
5. サイドロード完了後、iPhone側で「設定 > 一般 > VPNとデバイス管理」から、使用したApple IDの「デベロッパAPP」を信頼する
6. ホーム画面に追加された「きゃべつ」アイコンをタップして起動

### 7日後の再インストール

同じ手順を繰り返すだけ（Sideloadlyがボタン一つで再署名・再インストールしてくれる）。コードを変更していなければ同じ`CabbageApp.ipa`を再利用できる。

### 既知の制限（個人サイドロードならでは）

- 署名は7日で失効し、期限が切れるとアプリが起動できなくなる（要再サイドロード）
- プッシュ通知・バックグラウンド自動更新は使用不可（上記の通り未実装）。新着通知はアプリを開いたときにその場でLETUSのページとして表示されるのみ
- 同じ無料Apple IDで同時にインストールできるアプリ数に上限がある（Apple側の制約）

## 開発時の注意

- `project.yml`はXcodeGen用の定義。Xcodeプロジェクトファイル自体はリポジトリに含めず、CI/ローカルで`xcodegen generate`により都度生成する
- Bundle ID: `yasu.cabbage`
