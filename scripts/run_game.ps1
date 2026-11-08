$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$godot = $env:GODOT

if (-not $godot) {
    $found = Get-ChildItem -Path (Join-Path $root "tools") -Filter "Godot*.exe" -Recurse -File -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($found) {
        $godot = $found.FullName
    }
}

if (-not $godot) {
    throw "未找到 Godot。请将 Godot 4.x 放入 tools\godot\，或设置环境变量 GODOT。"
}

& $godot --path (Join-Path $root "src\game")
