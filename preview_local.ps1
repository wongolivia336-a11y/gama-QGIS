$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$port = 8766
Write-Host "Preview: http://127.0.0.1:$port/"
Write-Host 'Press Ctrl+C to stop the server.'
python -m http.server $port --bind 127.0.0.1 --directory $repoRoot
