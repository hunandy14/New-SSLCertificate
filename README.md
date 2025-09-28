# SSL/TLS 憑證管理工具

這個專案提供了用於建立和管理 SSL/TLS 憑證的 PowerShell 腳本，適用於內部網路或開發環境的憑證簽發。

## 快速開始

```powershell
# 1. 載入建立 CA 的腳本
iex "function New-RootCA {$(irm 'https://raw.githubusercontent.com/hunandy14/New-SSLCertificate/refs/heads/master/New-RootCA.ps1')}"

# 2. 載入簽發憑證的腳本
iex "function New-SSLCertificate {$(irm 'https://raw.githubusercontent.com/hunandy14/New-SSLCertificate/refs/heads/master/New-SSLCertificate.ps1')}"

# 3. 建立 CA 目錄並產生 Root CA
mkdir CA -Force
New-RootCA -CNName "MyCompanyCA" -OutPath ".\CA"

# 4. 使用 CA 簽發 SSL 憑證
New-SSLCertificate -CAKeyPath ".\CA\MyCompanyCA.key" -CACrtPath ".\CA\MyCompanyCA.crt" -CN "example.com"
```

## 完整功能

### New-RootCA - 建立根憑證授權單位
```powershell
New-RootCA -CNName <CA名稱> [-OutPath <路徑>] [-ExpiryYears <年數>] [-PfxPasswd <密碼>]
```
- **`-CNName`** (必填) - CA 名稱
- **`-OutPath`** - 輸出目錄 (預設：當前目錄)
- **`-ExpiryYears`** - 有效年數 (1-50年，預設：10年)
- **`-PfxPasswd`** - PFX 密碼 ($null=不產生, ""=無密碼, "xxx"=有密碼)

### New-SSLCertificate - 簽發 SSL 憑證
```powershell
New-SSLCertificate -CAKeyPath <CA私鑰> -CACrtPath <CA憑證> -CommonName <域名> [-SubjectAltNames <SAN陣列>] [-OutDir <目錄>] [-ExpiryYears <年數>] [-PfxPasswd <密碼>]
```
- **`-CAKeyPath`** (必填) - CA 私鑰路徑
- **`-CACrtPath`** (必填) - CA 憑證路徑
- **`-CommonName`** 或 **`-CN`** (必填) - 主要域名
- **`-SubjectAltNames`** - 其他域名陣列 (SAN)
- **`-OutDir`** - 輸出目錄 (預設：當前目錄)
- **`-ExpiryYears`** - 有效年數 (1-30年，預設：10年)
- **`-PfxPasswd`** - PFX 密碼設定
