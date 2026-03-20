# 測試用腳本：僅發送固定訊息至 Discord Webhook
$webhook = "https://discord.com/api/webhooks/1472107208023081128/RfuzPLMYCYA8XXwTaMQUcWg_VU_TULRl6Lh_sJm1LJW-MyMEDh-ThCZW-_iH-ZD8B77K"  # 務必確認正確

# 強制發送測試訊息（多次嘗試確保）
$testContent = "腳本執行測試 - 時間: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - 來自隱藏 PowerShell"

# 嘗試 1: 基本發送
$payload = @{ content = $testContent } | ConvertTo-Json -Compress
try {
    Invoke-RestMethod -Uri $webhook -Method Post -Body $payload -ContentType 'application/json' -ErrorAction Stop
} catch {
    $_ | Out-File -FilePath "$env:TEMP\test_error.txt" -Append
}

# 嘗試 2: 使用 curl.exe 替代（較不易被阻擋）
try {
    curl.exe -H "Content-Type: application/json" -d $payload -X POST $webhook
} catch {
    $_ | Out-File -FilePath "$env:TEMP\test_error_curl.txt" -Append
}

# 寫入診斷檔案（確認腳本是否執行）
"測試完成 - 時間: $(Get-Date)" | Out-File -FilePath "$env:TEMP\test_run.txt" -Append
