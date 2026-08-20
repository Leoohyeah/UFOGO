<p align="center">
  <img src="https://github.com/Leoohyeah/UFOGO/blob/main/assets/UFOGO.png" alt="UFOGO app icon" width="220" />
</p>

UFOGO 是一款面向 iOS 裝置開發與測試場景的定位模擬與路線模擬工具，主要用於在已連線裝置上進行 GPS 位置模擬與移動軌跡控制。

## 專案簡介

本專案聚焦於 iOS 裝置的定位模擬、路線模擬與裝置連線流程，主要功能包括：

- GPS 位置模擬
- 路線移動模擬
- 背景定位處理
- 裝置配對與連線控制
- 開發者與測試場景下的地理位置驗證

## 安裝與設定

### 1. 準備必要工具

- Mac
  - iLoader for [Mac](https://github.com/nab138/iloader/releases/latest/download/iloader-darwin-universal.dmg)。
- Windows
  - [iTunes](https://apple.co/ms)
  - [Apple Device](https://apps.microsoft.com/detail/9np83lwlpz9k?hl=zh-TW&gl=TW)
  - iLoader [exe](https://github.com/nab138/iloader/releases/latest/download/iloader-windows-x64.exe) 或 [msi](https://github.com/nab138/iloader/releases/latest/download/iloader-windows-x64.msi) 擇一
- IOS
  - 安裝 [LocalDevVPN](https://apps.apple.com/us/app/localdevvpn/id6755608044)，用於 IOS 開發環境下的 VPN / 通訊設定。
  - 請務必開啟 `開發者模式`。

### 2. 取得 Pairing File

1. 安裝後打開 [iLoader](https://github.com/nab138/iloader)。
2. 登入 Apple ID，並與 iPhone 完成配對。
3. 在 iLoader 中選擇「管理配對檔案」。
4. 點選「匯出」手動匯出 `pairingFile.plist`。
5. 將 `pairingFile.plist` 檔案傳輸到 iOS 裝置的「檔案」App。
- Mac 可使用 AirDrop
- Windows 可使用 Apple Device

### 3. 側載 UFOGO IPA

1. 下載最新的 [UFOGO IPA](https://github.com/Leoohyeah/UFOGO/releases/latest)
2. 開啟 iLoader
3. 登入 Apple ID，並與 iPhone 完成配對。
4. 在 iLoader 選擇「匯入IPA」，選擇匯入剛下載的 UFOGO IPA

### 4. IOS 執行 UFOGO APP

1. IOS 開啟 LocalDevVPN 點選 Connect
2. IOS 開啟 UFOGO APP
3. 在匯入配對檔案的地方選擇剛剛放進裝置的 `pairingFile.plist` 
4. Wifi情況下可正常使用，行動數據使用時，請先開關一次行動數據或飛航模式

## 致謝

- [StikDebug](https://github.com/StephenDev0/StikDebug)：提供相關裝置配對與通訊模式的參考範例。
- [idevice](https://github.com/jkcoxson/idevice)：作為 iDevice 連線與裝置控制相關流程的技術參考。
- [iLoader](https://github.com/nab138/iloader)：提供 macOS / Windows 環境下的配對與裝置連線工具支援。

## 授權

本專案採用 GNU Affero General Public License v3.0（AGPL-3.0）授權。

若您分發、修改或提供本專案，則需遵守 AGPL-3.0 之相關條款，並在必要情況下提供相對應來源程式碼與授權資訊。

完整授權條款請參閱 LICENSE 檔案。

## 使用限制

本專案僅供合法的開發者、測試、研究與教育用途使用，並不適用於一般消費者用途的 GPS 應用程式。使用者應遵守適用之法律法規、平台規範及相關服務條款。

本專案不鼓勵、支援或授權任何違法行為。任何使用方式均應符合當地法規及相關要求，並由使用者自行承擔使用後果。

## 贊助

如果您喜歡這個專案，並希望支持後續維護與開發，歡迎透過以下方式贊助：

- :heart: [Portaly](https://portaly.cc/leoohyeah/support)

您的支持有助於維持專案開發、測試環境與持續更新。

## 備註

本專案依照實際用途與開發環境進行配置，使用者應自行確認相關工具、設備支援與平台規範。


