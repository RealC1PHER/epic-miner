# Zip the MSVC build (windows\build-windows-msvc.cmd) as epic-miner-<version>-windows-x64.zip
# plus a SHA256SUMS file. Frenziez Miner installs from these two release assets.
#
# The version is taken from hiveos\h-manifest.conf so both builds of a release carry the same one.
# RandomX is linked in statically (MSVC/MASM path), so there is no randomx DLL. The exe needs the
# Microsoft Visual C++ 2015-2022 x64 runtime (MSVCP140 / VCRUNTIME140).
#
# Usage (from the repo root):  powershell -File windows\package-windows.ps1 [-OutDir <dir>]
param([string]$OutDir = (Get-Location).Path)
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$ver = (Select-String -Path "$root\hiveos\h-manifest.conf" -Pattern '^CUSTOM_VERSION=(.+)$').Matches[0].Groups[1].Value
$exe = "$root\target\x86_64-pc-windows-msvc\release\epic-miner.exe"
if (-not (Test-Path $exe)) { throw "missing $exe (run windows\build-windows-msvc.cmd)" }

$name = "epic-miner-$ver-windows-x64"
$stage = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString())
$dir = Join-Path $stage $name
New-Item -ItemType Directory -Force $dir | Out-Null
Copy-Item $exe $dir
Copy-Item "$root\LICENSE" $dir

$zip = Join-Path $OutDir "$name.zip"
if (Test-Path $zip) { Remove-Item $zip }
# Entries are added one by one with "/" names: Compress-Archive and ZipFile.CreateFromDirectory in
# Windows PowerShell 5.1 write "\" separators, which is not standard zip.
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::Open($zip, [IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($f in Get-ChildItem $dir -File) {
        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $f.FullName, "$name/$($f.Name)") | Out-Null
    }
} finally { $archive.Dispose() }
Remove-Item -Recurse -Force $stage

$hash = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLower()
"$hash  $name.zip" | Set-Content -Path (Join-Path $OutDir "SHA256SUMS") -Encoding ascii
"$hash  $zip"
