$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$venv = Join-Path $root ".venv"

if (-not (Test-Path $venv)) {
    Write-Host "创建虚拟环境：$venv"
    python -m venv $venv
}

$python = Join-Path $venv "Scripts\python.exe"
& $python -m pip install --upgrade pip
& $python -m pip install --index-url https://pypi.org/simple --timeout 60 --retries 5 fastapi "uvicorn[standard]" pytest httpx

Write-Host "引擎依赖安装完成。"
