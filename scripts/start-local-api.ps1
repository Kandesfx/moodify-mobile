param(
    [string]$BackendPath = (Join-Path (Split-Path $PSScriptRoot -Parent | Split-Path -Parent) 'moodify-backend'),
    [switch]$Worker
)

$ErrorActionPreference = 'Stop'
$backend = (Resolve-Path -LiteralPath $BackendPath).Path
$maven = Join-Path $backend 'mvnw.cmd'
if (-not (Test-Path -LiteralPath $maven)) {
    throw "Khong tim thay mvnw.cmd trong $backend"
}

if ($Worker) {
    Set-Location -LiteralPath $backend
    & $maven '-Dspring-boot.run.arguments=--server.port=8088 --spring.jpa.hibernate.ddl-auto=none --app.seed.tracks-on-startup=false --app.scheduling.enabled=false --app.maintenance.enabled=false --sync.scheduler.enabled=false --spring.docker.compose.enabled=false' 'spring-boot:run'
    exit $LASTEXITCODE
}

function Test-LocalApi {
    try {
        $result = Invoke-WebRequest -UseBasicParsing -Uri 'http://127.0.0.1:8088/api/tracks?page=0&size=1' -TimeoutSec 3
        return $result.StatusCode -eq 200
    } catch {
        return $false
    }
}

if (Test-LocalApi) {
    Write-Host 'Backend local dang san sang tren cong 8088.'
    exit 0
}
if (Get-NetTCPConnection -LocalPort 8088 -State Listen -ErrorAction SilentlyContinue) {
    throw 'Cong 8088 da duoc su dung, nhung API Moodify khong phan hoi. Kiem tra tien trinh dang chiem cong.'
}

$logDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'build\local-api'
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
$workerArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $PSCommandPath + '"'), '-BackendPath', ('"' + $backend + '"'), '-Worker')
$process = Start-Process -FilePath 'powershell.exe' -ArgumentList $workerArgs -WorkingDirectory $backend -WindowStyle Hidden -RedirectStandardOutput (Join-Path $logDir 'stdout.log') -RedirectStandardError (Join-Path $logDir 'stderr.log') -PassThru
for ($attempt = 0; $attempt -lt 90; $attempt++) {
    if (Test-LocalApi) {
        Write-Host 'Backend local da san sang tren cong 8088.'
        exit 0
    }
    if ($process.HasExited) { break }
    Start-Sleep -Seconds 1
    $process.Refresh()
}
throw "Backend chua san sang. Xem log trong $logDir; kiem tra MySQL va MongoDB local."
