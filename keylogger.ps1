# 極簡測試腳本：使用 curl.exe 發送固定訊息（避開 Invoke-RestMethod 阻擋）
$webhook = "https://discord.com/api/webhooks/您的Webhook網址"  # 確認無誤

# 準備 payload（確保非空）
$payload = '{\"content\":\"腳本執行測試 - curl 版本 - 時間: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + '\"}'

# 寫入診斷檔案（確認腳本運行）
"測試開始 - 時間: $(Get-Date)" | Out-File -FilePath "$env:TEMP\curl_test_start.txt" -Append

# 使用 curl.exe 發送（-s 安靜模式，-X POST 指定方法）
curl.exe -s -H "Content-Type: application/json" -d $payload -X POST $webhook

# 再次寫入診斷（確認發送完成）
"測試完成 - 時間: $(Get-Date)" | Out-File -FilePath "$env:TEMP\curl_test_end.txt" -Append
