$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$python = Join-Path $root ".venv\Scripts\python.exe"

if (-not (Test-Path $python)) {
    throw "未找到虚拟环境，请先运行 scripts\setup_engine.ps1"
}

Set-Location (Join-Path $root "src\engine")
& $python -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
