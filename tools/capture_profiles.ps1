param(
    [string]$Godot = "$env:USERPROFILE\Desktop\Godot_v4.5.1-stable_win64.exe",
    [string[]]$Profiles = @('phone','tablet7','tablet10'),
    [string[]]$Views = @('home','tow','campaign','result','shipyard','journal'),
    [string]$OutputRoot = 'marketing/screenshots'
)
$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$names=@{home='01-home';tow='02-rescue';campaign='03-contracts';result='04-result';shipyard='05-shipyard';journal='06-journal';daily='07-daily';district='08-lantern';copperdock='09-copperdock'}
$sizes=@{phone='1080x1920';tablet7='800x1280';tablet10='1200x1920'}
$receipt=@()
foreach ($profile in $Profiles) {
    if (-not $sizes.ContainsKey($profile)) { throw "Unknown profile $profile" }
    foreach ($view in $Views) {
        if (-not $names.ContainsKey($view)) { throw "Unknown view $view" }
        $captureRoot=Join-Path $projectRoot "$OutputRoot/$profile"
        $logRoot=Join-Path $projectRoot "build/captures/$profile-$view"
        New-Item -ItemType Directory -Path $captureRoot,$logRoot,"$logRoot/appdata" -Force | Out-Null
        $env:APPDATA="$logRoot/appdata"
        $output=Join-Path $captureRoot ($names[$view]+'.png')
        $args=@('--path',"`"$projectRoot`"",'--resolution',$sizes[$profile],
                '--log-file',"`"$logRoot/runtime.log`"",'--script','tests/capture.gd','--',
                "--profile=$profile","--view=$view","`"--output=$output`"")
        $process=Start-Process -FilePath $Godot -ArgumentList $args -WindowStyle Hidden -PassThru -RedirectStandardOutput "$logRoot/stdout.log" -RedirectStandardError "$logRoot/stderr.log"
        @{pid=$process.Id;arguments=$args;started_utc=(Get-Date).ToUniversalTime().ToString('o')} | ConvertTo-Json | Set-Content -LiteralPath "$logRoot/process.json"
        if (-not $process.WaitForExit(55000)) {
            $process.Refresh()
            if (-not $process.HasExited) { Stop-Process -Id $process.Id }
            throw "Capture timed out; stopped only tracked capture PID $($process.Id)"
        }
        if ($process.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $output)) { throw "Capture failed: $profile/$view, see $logRoot" }
        $log=Get-Content -LiteralPath "$logRoot/runtime.log" -Raw
        if ($log -match 'SCRIPT ERROR|Parse Error' -or $log -notmatch 'CAPTURE ') { throw "Capture script failed: $profile/$view" }
        $sha=(Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash.ToLowerInvariant()
        $receipt+=@{profile=$profile;view=$view;path=$output;sha256=$sha;renderer='Godot editor runtime / OpenGL Compatibility';automated_scene_driver=$true;physical_device=$false}
        Write-Output "Captured $profile/$view -> $output"
    }
}
$receipt | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $projectRoot 'build/captures/latest-manifest.json') -Encoding utf8
