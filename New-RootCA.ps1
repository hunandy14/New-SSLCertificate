<#
.SYNOPSIS
    快速產生自簽 Root CA 憑證的 PowerShell 腳本

.DESCRIPTION
    使用 OpenSSL 自動產生 Root CA 私鑰、憑證和 PFX 檔案。
    支援自訂 CA 名稱、輸出路徑、有效期限和 PFX 密碼。

.PARAMETER CNName
    憑證授權單位 (CA) 名稱，必填參數

.PARAMETER OutPath
    輸出檔案路徑，預設為當前工作目錄

.PARAMETER ExpiryYears
    憑證有效年數 (1-50 年)，預設 10 年

.PARAMETER PfxPasswd
    PFX 檔案密碼。$null=不產生 PFX，""=空密碼 PFX，"password"=有密碼 PFX

.EXAMPLE
    .\New-RootCA.ps1 -CNName "MyCompanyCA"
    在當前目錄產生 MyCompanyCA.key 和 MyCompanyCA.crt（不含 PFX）

.EXAMPLE
    .\New-RootCA.ps1 -CNName "MyCA" -PfxPasswd ""
    產生檔案組合，包含空密碼的 PFX

.EXAMPLE
    .\New-RootCA.ps1 -CNName "MyCA" -PfxPasswd "secret123" -ExpiryYears 5
    產生完整檔案組合，包含有密碼的 PFX，有效期 5 年

.NOTES
    需求：OpenSSL (可透過 winget install ShiningLight.OpenSSL 安裝)
    產物：<CNName>.key、<CNName>.crt、<CNName>.pfx (可選)
    
    Author: Generated Script
    Version: 2.0
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$CNName,
    
    [string]$OutPath = $PWD.Path,
    
    [ValidateRange(1,50)]
    [int]$ExpiryYears = 10,
    
    [string]$PfxPasswd = $null
)

$ErrorActionPreference = "Stop"

# 檢查 openssl 是否可用
$openssl = Get-Command openssl -ErrorAction SilentlyContinue
if (-not $openssl) {
    Write-Host "❌ 找不到 OpenSSL。請先安裝：" -ForegroundColor Red
    Write-Host "   winget install ShiningLight.OpenSSL" -ForegroundColor Yellow
    Write-Host "   或 choco install openssl"
    exit 1
}

# 準備輸出路徑
New-Item -ItemType Directory -Path $OutPath -Force | Out-Null

# 設定檔案路徑
$files = @{
    key = Join-Path $OutPath "$CNName.key"
    crt = Join-Path $OutPath "$CNName.crt"
    pfx = Join-Path $OutPath "$CNName.pfx"
}

# 有效天數（簡單以 365*年 計算）
$days = [int]($ExpiryYears * 365)

# 產生 CA 私鑰
Write-Host "🔑 產生 CA 私鑰 => $($files.key)"
openssl genrsa -out $files.key 4096
if ($LASTEXITCODE -ne 0) { Write-Error "CA 私鑰產生失敗" }

# 產生 CA 憑證（自簽）
$subject = "/C=TW/ST=Taiwan/O=$CNName/OU=IT/CN=$CNName"
Write-Host "📜 產生 CA 憑證 => $($files.crt)"
openssl req -x509 -new -nodes -key $files.key -sha256 -days $days -out $files.crt -subj $subject
if ($LASTEXITCODE -ne 0) { Write-Error "CA 憑證產生失敗" }

# 匯出 PFX（若有提供密碼參數）
if ($PSBoundParameters.ContainsKey('PfxPasswd')) {
    Write-Host "📦 匯出 PFX => $($files.pfx)"
    openssl pkcs12 -export -inkey $files.key -in $files.crt -out $files.pfx -passout "pass:$PfxPasswd"
    if ($LASTEXITCODE -ne 0) { Write-Error "PFX 匯出失敗" }
}

Write-Host "`n✅ 完成！輸出檔案：" -ForegroundColor Green
Write-Host "   - CA 私鑰：$($files.key)"
Write-Host "   - CA 憑證：$($files.crt)"
if ($PSBoundParameters.ContainsKey('PfxPasswd')) {
    $passwordInfo = if ($PfxPasswd -eq "") { "無密碼" } else { "密碼：$PfxPasswd" }
    Write-Host "   - CA PFX：$($files.pfx) （$passwordInfo）"
    Write-Host "`n💡 提示：雙擊 PFX 檔案可安裝到 Windows 受信任根憑證。"
} else {
    Write-Host "`n💡 提示：使用 -PfxPasswd 參數可產生 PFX 檔案。-PfxPasswd `"`" 可產生無密碼 PFX。"
}
