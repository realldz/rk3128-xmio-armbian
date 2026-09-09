# Analyze Rockchip RKAF update image: dump header info and partition table.
# Usage: pwsh -File analyze-rkimage.ps1 <path-to-update.img> [-Extract <outdir>]
param(
    [Parameter(Mandatory=$true)][string]$Path,
    [string]$Extract
)

$ErrorActionPreference = 'Stop'
$fs = [System.IO.File]::OpenRead($Path)
$br = New-Object System.IO.BinaryReader($fs)

function Read-U32([long]$off) {
    $script:fs.Position = $off
    return $script:br.ReadUInt32()
}

$magic = Read-U32 0
Write-Host ("File size : {0} bytes ({1:N1} MB)" -f $fs.Length, ($fs.Length/1MB))
Write-Host ("Magic     : 0x{0:X8}" -f $magic)

# Chip / version strings in header (first 256 bytes as ASCII)
$fs.Position = 0
$hdr = $br.ReadBytes(512)
$ascii = ($hdr | ForEach-Object { if ($_ -ge 32 -and $_ -le 126) { [char]$_ } else { '.' } }) -join ''
Write-Host "Header ASCII (512B):"
Write-Host $ascii

# Known AF header: partition entries are 70 bytes each:
#   56B path (null-padded) + 4B flash offset (512B sectors) + 4B flash size (sectors)
#   + 2B header flag + 4B data offset (bytes in file) + 4B data size (bytes)
# Header size field is at 0x19 (commonly 0x62/0x64/0xA2); try candidates and validate.
$entryCount = 0
$entries = @()
foreach ($hs in @(0x64, 0x62, 0xA2)) {
    $cnt = Read-U32 $hs
    if ($cnt -gt 0 -and $cnt -le 64) {
        $tblOff = $hs + 4
        $ok = $true
        $test = @()
        for ($i = 0; $i -lt $cnt; $i++) {
            $e = $tblOff + 70 * $i
            if ($e + 70 -gt $fs.Length) { $ok = $false; break }
            $fs.Position = $e
            $pathBytes = $br.ReadBytes(56)
            $nul = [Array]::IndexOf($pathBytes, [byte]0)
            if ($nul -le 0) { $nul = $pathBytes.Length }
            $name = [System.Text.Encoding]::ASCII.GetString($pathBytes, 0, $nul).Trim()
            if ($name -notmatch '^[\x21-\x7E\. /_-]+$' -or $name.Length -lt 2) { $ok = $false; break }
            $foff = $br.ReadUInt32(); $fsz = $br.ReadUInt32()
            $br.ReadUInt16() | Out-Null
            $doff = $br.ReadUInt32(); $dsz = $br.ReadUInt32()
            if ($foff -gt 0x100000000 -or $doff -gt $fs.Length) { $ok = $false; break }
            $test += [pscustomobject]@{ Name=$name; FlashOff=$foff; FlashSect=$fsz; DataOff=$doff; DataSize=$dsz }
        }
        if ($ok) { $entryCount = $cnt; $entries = $test; Write-Host ("`nHeader size = 0x{0:X}, entries = {1}" -f $hs, $cnt); break }
    }
}

if ($entryCount -eq 0) {
    Write-Host "Could not parse partition table with known header sizes."
    $fs.Close()
    exit 1
}

Write-Host ("{0,-22} {1,14} {2,14} {3,12} {4,12}" -f "Name","FlashOff","FlashSectors","DataOff","DataSize")
foreach ($e in $entries) {
    Write-Host ("{0,-22} 0x{1:X10} 0x{2:X10} {3,12} {4,12}" -f $e.Name, $e.FlashOff, $e.FlashSect, $e.DataOff, $e.DataSize)
}

if ($Extract) {
    New-Item -ItemType Directory -Force -Path $Extract | Out-Null
    foreach ($e in $entries) {
        $safe = $e.Name -replace '[\\/:*?"<>| ]', '_'
        $out = Join-Path $Extract $safe
        Write-Host ("Extracting {0} -> {1}" -f $e.Name, $out)
        $fs.Position = $e.DataOff
        $remaining = $e.DataSize
        $buf = New-Object byte[] (1MB)
        $ostream = [System.IO.File]::Create($out)
        try {
            while ($remaining -gt 0) {
                $chunk = [Math]::Min($remaining, $buf.Length)
                $read = $fs.Read($buf, 0, $chunk)
                if ($read -le 0) { break }
                $ostream.Write($buf, 0, $read)
                $remaining -= $read
            }
        } finally { $ostream.Close() }
    }
    Write-Host "Done."
}
$fs.Close()
