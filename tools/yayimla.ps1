# Veb versiyani yigib yerlesdirir.
# Isa salmaq:  .\tools\yayimla.ps1
#
# Damgalama addimi burada oldugu ucun unudulmur. O olmasa main.dart.js
# damgasiz qalir ve brahzer onu her acilisda yeniden yukleyir.

# ErrorActionPreference = "Stop" qoymuruq: PowerShell 5.1 xarici programin
# stderr-e yazdigi adi xeberdarligi da xeta sayir ve yigimi dayandirir.
# Ugur yoxlamasi $LASTEXITCODE ile aparilir.

$flutter = "C:\src\flutter\bin\flutter.bat"
if (-not (Test-Path $flutter)) { $flutter = "flutter" }

Write-Host "1/3  Yigilir..." -ForegroundColor Cyan
& $flutter build web --release
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "2/3  Fayl adina damga vurulur..." -ForegroundColor Cyan
node tools/hash_build.mjs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "3/3  Yerlesdirilir..." -ForegroundColor Cyan
firebase deploy --only hosting
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ""
Write-Host "Hazirdir: https://vibe-f9d13.web.app" -ForegroundColor Green
