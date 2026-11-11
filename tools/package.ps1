# 打包：Godot 导出 → dist/<tag>/
#
#   powershell -File tools/package.ps1                       # 七天版，出 exe + web
#   powershell -File tools/package.ps1 -Days 5 -Lang 2 -Tag lite5 -Name One-Week-Basket-5day
#   powershell -File tools/package.ps1 -SkipExport           # 只重新压缩，不动 Godot
#
# -Days / -Lang 会被写进 godot/data/build.json，导出时烘进包里，导出后自动删掉。
# 产物落在 dist/，不进仓库（.gitignore 挡着），发版靠 gh release create。

param(
	[switch]$SkipExport,
	[int]$Days = 0,
	[int]$Lang = -1,
	[string]$Tag = "",
	[string]$Name = "One-Week-Basket",
	[string]$Godot = "D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$proj = Join-Path $root "godot"
$dataDir = Join-Path $proj "data"
$buildJson = Join-Path $dataDir "build.json"

if ([string]::IsNullOrWhiteSpace($Tag)) {
	$Tag = if ($Days -gt 0) { "d$Days" } else { "full" }
}
$out = Join-Path $root "dist\$Tag"
New-Item -ItemType Directory -Force -Path (Join-Path $out "win"), (Join-Path $out "web") | Out-Null

function Write-BuildJson {
	$obj = @{}
	if ($Days -gt 0) { $obj["days"] = $Days }
	if ($Lang -ge 0) { $obj["lang"] = $Lang }
	if ($obj.Count -eq 0) {
		if (Test-Path $buildJson) { Remove-Item $buildJson -Force }
		return
	}
	$json = $obj | ConvertTo-Json -Compress
	[System.IO.File]::WriteAllText($buildJson, $json, (New-Object System.Text.UTF8Encoding($false)))
	Write-Host "    构建参数：$json"
}

try {
	Write-BuildJson

	if (-not $SkipExport) {
		if (-not (Test-Path $Godot)) { throw "找不到 Godot：$Godot" }
		# 导出器不会自己建目录，父目录不存在就报「给定的导出路径不存在」。
		New-Item -ItemType Directory -Force -Path (Join-Path $proj "build\$Tag\win"), (Join-Path $proj "build\$Tag\web") | Out-Null

		Write-Host "[1/3] 导出 Windows（$Tag）"
		& $Godot --headless --path $proj --export-release "Windows Desktop" (Join-Path $proj "build\$Tag\win\$Name.exe")
		if ($LASTEXITCODE -ne 0) { throw "导出 Windows 失败" }

		Write-Host "[2/3] 导出 Web（$Tag）"
		& $Godot --headless --path $proj --export-release "Web" (Join-Path $proj "build\$Tag\web\index.html")
		if ($LASTEXITCODE -ne 0) { throw "导出 Web 失败" }
	}
}
finally {
	if (Test-Path $buildJson) { Remove-Item $buildJson -Force }
}

Write-Host "[3/3] 收进 dist\$Tag"
Copy-Item (Join-Path $proj "build\$Tag\win\$Name.exe") (Join-Path $out "win\$Name.exe") -Force
$zip = Join-Path $out "one-week-basket-web.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path (Join-Path $proj "build\$Tag\web\*") -DestinationPath $zip

Get-ChildItem $out -Recurse -File |
	Select-Object @{n = "文件"; e = { $_.FullName.Replace($root + "\", "") } },
		@{n = "MB"; e = { [math]::Round($_.Length / 1MB, 2) } },
		@{n = "sha256"; e = { (Get-FileHash $_.FullName -Algorithm SHA256).Hash.Substring(0, 16) } } |
	Format-Table -AutoSize

Write-Host ""
Write-Host "发版（产物不进仓库，只挂 Release）："
Write-Host "  gh release create vX.Y.Z `"$($out)\win\$Name.exe`" `"$zip`" --title `"一周菜篮 vX.Y.Z`" --notes `"…`""
