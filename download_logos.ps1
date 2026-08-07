# Logo Download Script
$logoDir = "C:\Users\SIMONE\Documents\BCTransporterNEW\BCTransporterWEB\mobile_app\assets\logos\autogrills"

if (-not (Test-Path $logoDir)) { New-Item -ItemType Directory -Force -Path $logoDir | Out-Null }

function Download-Logo {
    param($url, $filename)
    try {
        $outPath = Join-Path $logoDir $filename
        Write-Host "Downloading $filename from $url..." -ForegroundColor Cyan
        Invoke-WebRequest -Uri $url -OutFile $outPath -UseBasicParsing -TimeoutSec 30
        Write-Host "  Saved to $outPath" -ForegroundColor Green
    }
    catch {
        Write-Host "  Failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

$logos = @(
    @{ url = "https://upload.wikimedia.org/wikipedia/commons/e/ec/Autogrill-Logo.svg"; file = "autogrill.svg" }
    @{ url = "https://www.mychefpro.com/logo.svg"; file = "mychef.svg" }
    @{ url = "https://www.eni.com/visual-design/infographics/eni-for-2024/general/eni-logo.svg"; file = "eni.svg" }
    @{ url = "https://ip.gruppoapi.com/assets/images/logo.svg"; file = "ip.svg" }
    @{ url = "https://www.tamoil.it/assets/images/logo.svg"; file = "tamoil.svg" }
    @{ url = "https://www.shell.com/visual-assets/logo.svg"; file = "shell.svg" }
    @{ url = "https://www.q8.com/assets/images/logo.svg"; file = "q8.svg" }
    @{ url = "https://www.esso.com/assets/images/logo.svg"; file = "esso.svg" }
    @{ url = "https://www.totalenergies.it/assets/images/logo.svg"; file = "total.svg" }
    @{ url = "https://www.enelx.com/assets/images/logo.svg"; file = "enel_x.svg" }
    @{ url = "https://www.becharge.com/assets/images/logo.svg"; file = "becharge.svg" }
    @{ url = "https://www.free2x.it/assets/images/logo.svg"; file = "free_to_x.svg" }
    @{ url = "https://www.ionity.eu/assets/images/logo.svg"; file = "ionity.svg" }
    @{ url = "https://www.tesla.com/assets/images/logo.svg"; file = "tesla.svg" }
    @{ url = "https://www.bp.com/assets/images/logo.svg"; file = "bp.svg" }
)

foreach ($logo in $logos) { Download-Logo $logo.url $logo.file }

Write-Host "Done! Check $logoDir for downloaded files." -ForegroundColor Yellow
Write-Host "Convert SVG to PNG using an image editor if needed." -ForegroundColor Yellow
