param(
    [string]$Godot = "$env:USERPROFILE\Desktop\Godot_v4.5.1-stable_win64.exe",
    [ValidateSet('Web','Android','Android Test APK','Android Acceptance')]
    [string]$Target = 'Web'
)
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (-not (Test-Path -LiteralPath $Godot)) { throw 'Pass -Godot with the installed Godot 4.5.1 editor executable.' }
function Invoke-Godot([string[]]$Arguments, [string]$LogName) {
    $quoted = $Arguments | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }
    $taskProcess = Start-Process -FilePath $Godot -ArgumentList $quoted -WindowStyle Hidden -PassThru -RedirectStandardOutput "$projectRoot/build/logs/$LogName.stdout.log" -RedirectStandardError "$projectRoot/build/logs/$LogName.stderr.log"
    @{pid=$taskProcess.Id;arguments=$Arguments;started_utc=(Get-Date).ToUniversalTime().ToString('o')} | ConvertTo-Json | Set-Content -LiteralPath "$projectRoot/build/logs/$LogName-process.json"
    while (-not $taskProcess.WaitForExit(55000)) { Write-Output "Godot $LogName still running (owned PID $($taskProcess.Id))" }
    if ($taskProcess.ExitCode -ne 0) { throw "Godot $LogName failed: $($taskProcess.ExitCode)" }
}
Push-Location $projectRoot
try {
    New-Item -ItemType Directory -Path 'build/logs','build/android','build/site/play' -Force | Out-Null
    Invoke-Godot @('--headless','--editor','--path',$projectRoot,'--import','--log-file',"$projectRoot/build/logs/import.log") 'import'
    if ($Target -eq 'Web') {
        Invoke-Godot @('--headless','--path',$projectRoot,'--export-release','Web','build/site/play/index.html','--log-file',"$projectRoot/build/logs/export-web.log") 'export-web'
    } else {
        $out = @{'Android'='tideline-tow-debug.aab';'Android Test APK'='tideline-tow-test.apk';'Android Acceptance'='tideline-tow-acceptance.apk'}[$Target]
        if (-not (Test-Path -LiteralPath "$projectRoot/android/build/build.gradle")) {
            # Godot's first template-install invocation can exit after import.
            Invoke-Godot @('--headless','--path',$projectRoot,'--install-android-build-template','--export-debug',$Target,"build/android/$out",'--log-file',"$projectRoot/build/logs/install-android-template.log") 'install-android-template'
        }
        Invoke-Godot @('--headless','--path',$projectRoot,'--export-debug',$Target,"build/android/$out",'--log-file',"$projectRoot/build/logs/export-$($Target.Replace(' ','-')).log") "export-$($Target.Replace(' ','-'))"
        if (-not (Test-Path -LiteralPath "build/android/$out")) { throw 'Godot exited without the expected Android artifact.' }
    }
} finally { Pop-Location }
