# 打包：Godot 导出 → dist/
#
#   pwsh -File tools/package.ps1              # 出 exe + web 包
#   pwsh -File tools/package.ps1 -SkipExport  # 只重新压缩，不动 Godot
#
# 产物落在 dist/，不进仓库（.gitignore 挡着），发版靠 gh release create。

param(
	[switch]$SkipExport,
	[string]$Godot = "D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$proj = Join-Path $root "godot"
$dist = Join-Path $root "dist"

New-Item -ItemType Directory -Force -Path (Join-Path $dist "win"), (Join-Path $dist "web") | Out-Null

if (-not $SkipExport) {
	if (-not (Test-Path $Godot)) { throw "找不到 Godot：$Godot" }

	Write-Host "[1/3] 导出 Windows"
	& $Godot --headless --path $proj --export-release "Windows Desktop" (Join-Path $proj "build\win\One-Week-Basket.exe")
	if ($LASTEXITCODE -ne 0) { throw "导出 Windows 失败" }

	Write-Host "[2/3] 导出 Web"
	& $Godot --headless --path $proj --export-release "Web" (Join-Path $proj "build\web\index.html")
	if ($LASTEXITCODE -ne 0) { throw "导出 Web 失败" }
}

Write-Host "[3/3] 收进 dist/"
Copy-Item (Join-Path $proj "build\win\One-Week-Basket.exe") (Join-Path $dist "win\One-Week-Basket.exe") -Force
$zip = Join-Path $dist "one-week-basket-web.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path (Join-Path $proj "build\web\*") -DestinationPath $zip

Get-ChildItem $dist -Recurse -File |
	Select-Object @{n = "文件"; e = { $_.FullName.Replace($root + "\", "") } },
		@{n = "MB"; e = { [math]::Round($_.Length / 1MB, 2) } } |
	Format-Table -AutoSize

Write-Host ""
Write-Host "发版："
Write-Host "  gh release create v1.0.1 `"dist\win\One-Week-Basket.exe`" `"dist\one-week-basket-web.zip`" --title ... --notes ..."
