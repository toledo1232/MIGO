$ErrorActionPreference = "Stop"

Set-Location "C:\Users\LENOVO\NEXORA\nexora-move\apps\nexora_app"

$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"

if (-not (Test-Path $adb)) {
    $command = Get-Command adb -ErrorAction SilentlyContinue

    if ($command) {
        $adb = $command.Source
    }
}

if (-not (Test-Path $adb)) {
    Write-Host "No se encontro ADB."
    exit 1
}

Write-Host ""
Write-Host "MIGO DRIVE"
Write-Host "Conectando Pixel con FastAPI..."

& $adb reverse --remove tcp:8000 2>$null

& $adb reverse tcp:8000 tcp:8000

Write-Host ""
Write-Host "ADB reverse:"
& $adb reverse --list

Write-Host ""
Write-Host "Ejecutando MIGO..."
flutter run
