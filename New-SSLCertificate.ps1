<#
.SYNOPSIS
    使用現有 Root CA 簽發 SSL/TLS 憑證的 PowerShell 腳本

.DESCRIPTION
    使用 OpenSSL 和指定的 CA 私鑰與憑證來簽發伺服器 SSL 憑證。
    支援多個 Subject Alternative Names (SAN)，適用於網站、API 等服務。

.PARAMETER CAKeyPath
    CA 私鑰檔案路徑，必填參數

.PARAMETER CACrtPath
    CA 憑證檔案路徑，必填參數

.PARAMETER CommonName
    憑證主要域名 (CN)，必填參數

.PARAMETER SubjectAltNames
    其他域名陣列 (SAN)，可包含多個域名或 IP

.PARAMETER OutPath
    輸出檔案路徑，預設為當前工作目錄

.PARAMETER ExpiryYears
    憑證有效年數 (1-10 年)，預設 1 年

.PARAMETER PfxPasswd
    PFX 檔案密碼。$null=不產生PFX，""=空密碼PFX，"password"=有密碼PFX

.EXAMPLE
    .\New-SSLCertificate.ps1 -CAKeyPath ".\MyCA.key" -CACrtPath ".\MyCA.crt" -CN "mysite.com" -OutDir "SSL"
    簽發 mysite.com 的 SSL 憑證，檔案名稱自動為 mysite-com

.EXAMPLE
    .\New-SSLCertificate.ps1 -CAKeyPath ".\MyCA.key" -CACrtPath ".\MyCA.crt" -CommonName "api.company.com" -SubjectAltNames @("www.company.com", "company.com", "192.168.1.100") -PfxPasswd ""
    簽發包含多個 SAN 的憑證，並產生無密碼 PFX

.EXAMPLE
    .\New-SSLCertificate.ps1 -CAKeyPath ".\MyCA.key" -CACrtPath ".\MyCA.crt" -CommonName "secure.local" -ExpiryYears 2 -PfxPasswd "secret123"
    簽發 2 年有效期的憑證，並產生有密碼的 PFX

.NOTES
    需求：OpenSSL (可透過 winget install ShiningLight.OpenSSL 安裝)
    產物：<域名>.key、<域名>.csr、<域名>.crt、<域名>.pfx (可選)
    
    Author: Generated Script
    Version: 1.0
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateScript({Test-Path $_ -PathType Leaf})]
    [string]$CAKeyPath,
    
    [Parameter(Mandatory=$true)]
    [ValidateScript({Test-Path $_ -PathType Leaf})]
    [string]$CACrtPath,
    
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [Alias("CN")]
    [string]$CommonName,
    
    [string[]]$SubjectAltNames = @(),
    
    [string]$OutDir = $PWD.Path,
    
    [ValidateRange(1,30)]
    [int]$ExpiryYears = 10,
    
    [string]$PfxPasswd = $null
)

$ErrorActionPreference = "Stop"

# 檢查 OpenSSL
if (-not (Get-Command openssl -ErrorAction SilentlyContinue)) {
    Write-Host "❌ 找不到 OpenSSL。請先安裝：" -ForegroundColor Red
    Write-Host "   winget install ShiningLight.OpenSSL" -ForegroundColor Yellow
    Write-Host "   或 choco install openssl"
    exit 1
}

# 準備輸出路徑
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

# 從 CommonName 自動生成檔案名稱
$CertName = $CommonName -replace '[^a-zA-Z0-9]', '-' -replace '^-+|-+$', '' -replace '-+', '-'
Write-Host "💡 檔案名稱：$CertName" -ForegroundColor Yellow

# 設定檔案路徑
$files = @{
    key = Join-Path $OutDir "$CertName.key"
    csr = Join-Path $OutDir "$CertName.csr" 
    crt = Join-Path $OutDir "$CertName.crt"
    pfx = Join-Path $OutDir "$CertName.pfx"
    config = Join-Path $OutDir "temp_ssl.conf"
}

$days = $ExpiryYears * 365

# 產生 OpenSSL 配置檔案
$opensslConfig = @"
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = $CommonName

[v3_req]
keyUsage = digitalSignature, keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth, clientAuth
"@

# 加入 SAN 如果有提供
if ($SubjectAltNames.Count -gt 0) {
    $sanList = @()
    foreach ($san in $SubjectAltNames) {
        if ($san -match '^\d+\.\d+\.\d+\.\d+$') {
            $sanList += "IP:$san"
        } else {
            $sanList += "DNS:$san"
        }
    }
    $opensslConfig += "`nsubjectAltName = " + ($sanList -join ", ")
} else {
    # 強制加入 CN 作為 SAN（現代瀏覽器要求）
    $opensslConfig += "`nsubjectAltName = DNS:$CommonName"
}

# 寫入臨時配置檔案
$opensslConfig | Out-File -FilePath $files.config -Encoding ASCII

try {
    # 產生伺服器私鑰
    Write-Host "🔑 產生伺服器私鑰 => $($files.key)"
    openssl genrsa -out $files.key 2048
    if ($LASTEXITCODE -ne 0) { Write-Error "伺服器私鑰產生失敗" }

    # 產生憑證簽名請求 (CSR)
    Write-Host "📋 產生憑證簽名請求 => $($files.csr)"
    openssl req -new -key $files.key -out $files.csr -config $files.config
    if ($LASTEXITCODE -ne 0) { Write-Error "CSR 產生失敗" }

    # 用 CA 簽發憑證
    Write-Host "📜 簽發 SSL 憑證 => $($files.crt)"
    openssl x509 -req -in $files.csr -CA $CACrtPath -CAkey $CAKeyPath -CAcreateserial -out $files.crt -days $days -extensions v3_req -extfile $files.config
    if ($LASTEXITCODE -ne 0) { Write-Error "憑證簽發失敗" }

    # 匯出 PFX（若有提供密碼參數）
    if ($PSBoundParameters.ContainsKey('PfxPasswd')) {
        Write-Host "📦 匯出 PFX => $($files.pfx)"
        openssl pkcs12 -export -out $files.pfx -inkey $files.key -in $files.crt -certfile $CACrtPath -passout "pass:$PfxPasswd"
        if ($LASTEXITCODE -ne 0) { Write-Error "PFX 匯出失敗" }
    }
    
    Write-Host "`n✅ 完成！輸出檔案：" -ForegroundColor Green
    Write-Host "   - 伺服器私鑰：$($files.key)"
    Write-Host "   - 憑證簽名請求：$($files.csr)"
    Write-Host "   - SSL 憑證：$($files.crt)"
    
    # 顯示當前序列號
    $srlFile = Join-Path (Split-Path $CAKeyPath) (Split-Path $CAKeyPath -LeafBase + ".srl")
    if (Test-Path $srlFile) {
        $serialNumber = (Get-Content $srlFile -Raw).Trim()
        Write-Host "   - 當前序列號：$serialNumber"
    }
    
    if ($PSBoundParameters.ContainsKey('PfxPasswd')) {
        $passwordInfo = if ($PfxPasswd -eq "") { "無密碼" } else { "密碼：$PfxPasswd" }
        Write-Host "   - SSL PFX：$($files.pfx) （$passwordInfo）"
        Write-Host "`n💡 提示：PFX 檔案包含私鑰、憑證和 CA 鏈，可直接匯入 IIS 或其他服務。"
    } else {
        Write-Host "`n💡 提示：使用 -PfxPasswd 參數可產生 PFX 檔案。-PfxPasswd `"`" 可產生無密碼 PFX。"
    }
    
    Write-Host "`n🔗 憑證資訊："
    Write-Host "   - 主要域名：$CommonName"
    if ($SubjectAltNames.Count -gt 0) {
        Write-Host "   - 其他域名：$($SubjectAltNames -join ', ')"
    }
    Write-Host "   - 有效期限：$ExpiryYears 年"
    
} finally {
    # 清理臨時檔案
    if (Test-Path $files.config) {
        Remove-Item $files.config -Force
        Remove-Item $files.csr -Force
    }
}
