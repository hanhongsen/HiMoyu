param(
    [switch]$Capture,
    # 3D 场景选择：sample = 3 工位样板（默认），full25 = 25 工位完整办公室
    [ValidateSet("sample", "full25")]
    [string]$Scene = "sample"
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$godot = $env:GODOT

if (-not $godot) {
    $found = Get-ChildItem -Path (Join-Path $root "tools") -Filter "Godot*.exe" -Recurse -File -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending |
        Select-Object -First 1
    if ($found) {
        $godot = $found.FullName
    }
}

if (-not $godot) {
    throw "未找到 Godot。请将 Godot 4.x 放入 tools\godot\，或设置环境变量 GODOT。"
}

# 独立启动入口：只打开 3D 场景，不修改 project.godot 的 run/main_scene（默认仍为 2D 的 main.tscn）
$scenePath = switch ($Scene) {
    "full25" { "res://scenes/prototype_3d/office_full_25.tscn" }
    default  { "res://scenes/prototype_3d/office_preview_3d.tscn" }
}
$args = @("--path", (Join-Path $root "src\game"), $scenePath)
if ($Capture) {
    $args += @("--", "--capture")
}
& $godot @args
