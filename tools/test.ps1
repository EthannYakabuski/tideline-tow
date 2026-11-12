param([string]$Godot="$env:USERPROFILE\Desktop\Godot_v4.5.1-stable_win64.exe",[string[]]$Only=@('model','ui','platform'))
$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$cases=@(
    @{name='model';args=@('--script','tests/test_model.gd');pattern='TIDELINE MODEL CHECKS: (\d+) passed / \1 total'},
    @{name='ui';args=@('--script','tests/test_ui.gd');pattern='UI_ASSERTIONS.*FAILURES 0'},
    @{name='platform';args=@('res://platform/tests/test_services.tscn');pattern='passed=57 failed=0'}
)
foreach ($case in $cases) {
    if ($case.name -notin $Only) { continue }
    $logRoot=Join-Path $projectRoot "build/final-tests/$($case.name)"
    New-Item -ItemType Directory -Path $logRoot,"$logRoot/appdata" -Force | Out-Null
    $env:APPDATA="$logRoot/appdata"
    $env:TIDELINE_TEST_ROOT=$logRoot
    $args=@('--headless','--path',"`"$projectRoot`"",'--log-file',"`"$logRoot/runtime.log`"")+$case.args
    $process=Start-Process -FilePath $Godot -ArgumentList $args -WindowStyle Hidden -PassThru -RedirectStandardOutput "$logRoot/stdout.log" -RedirectStandardError "$logRoot/stderr.log"
    @{pid=$process.Id;arguments=$args;started_utc=(Get-Date).ToUniversalTime().ToString('o')} | ConvertTo-Json | Set-Content -LiteralPath "$logRoot/process.json"
    $elapsed=0
    while (-not $process.WaitForExit(55000)) {
        $elapsed+=55
        if ($elapsed -ge 220) {
            $process.Refresh()
            if (-not $process.HasExited) { Stop-Process -Id $process.Id }
            throw "Timed out $($case.name) (stopped only tracked PID $($process.Id))"
        }
        Write-Output "Running $($case.name) tests"
    }
    $log=Get-Content -LiteralPath "$logRoot/runtime.log" -Raw
    if ($process.ExitCode -ne 0 -or $log -match 'SCRIPT ERROR|Parse Error|ObjectDB instances leaked' -or $log -notmatch $case.pattern) { throw "Failed $($case.name): see $logRoot" }
    ($log -split "`n") | Where-Object {$_ -match 'ASSERTIONS|FIXTURES|MODEL CHECKS'} | Write-Output
}
