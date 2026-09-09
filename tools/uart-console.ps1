param(
    [string]$Action = "probe",
    [string]$Command = "",
    [int]$Seconds = 3,
    [string]$Port = "COM23"
)
# uart-console.ps1 - serial console tool for RK3128 box (CH341 @ COM23, 115200 8N1)
# Actions: probe | send | capture
$ErrorActionPreference = "Stop"

function Open-Port {
    $p = New-Object System.IO.Ports.SerialPort($Port, 115200, [System.IO.Ports.Parity]::None, 8, [System.IO.Ports.StopBits]::One)
    $p.ReadTimeout = 200
    $p.WriteTimeout = 2000
    $p.Encoding = [System.Text.Encoding]::ASCII
    $p.DtrEnable = $true
    $p.RtsEnable = $true
    $p.Open()
    return $p
}

function Read-For($sp, [double]$sec) {
    $sb = New-Object System.Text.StringBuilder
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $sec) {
        try {
            $chunk = $sp.ReadExisting()
            if ($chunk) { [void]$sb.Append($chunk) }
        } catch {}
        Start-Sleep -Milliseconds 50
    }
    return $sb.ToString()
}

switch ($Action) {
    "probe" {
        $sp = Open-Port
        $data = Read-For $sp $Seconds
        if (-not $data.Trim()) {
            # line silent: nudge with Enter to elicit login prompt
            $sp.Write("`r`n")
            $data = Read-For $sp 2
            if ($data.Trim()) { $data = "[after Enter]`r`n" + $data }
        }
        $sp.Close()
        if ($data.Trim()) {
            "=== RX ($($data.Length) chars) ==="
            $data -replace "`r", ""
        } else {
            "NO DATA - line silent. Check: box powered? TX/RX not swapped? correct COM?"
        }
    }
    "send" {
        if (-not $Command) { throw "send requires -Command" }
        $sp = Open-Port
        $sp.Write("`r")
        Start-Sleep -Milliseconds 200
        Read-For $sp 1 | Out-Null
        $sp.Write("$Command`r")
        $out = Read-For $sp $Seconds
        $sp.Close()
        "=== sent: $Command ==="
        $out -replace "`r", ""
    }
    "capture" {
        $sp = Open-Port
        $data = Read-For $sp $Seconds
        $sp.Close()
        if ($data.Trim()) { $data -replace "`r", "" } else { "NO DATA in ${Seconds}s" }
    }
    default { throw "unknown action: $Action" }
}
