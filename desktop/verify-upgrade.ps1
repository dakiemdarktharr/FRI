param(
  [Parameter(Mandatory=$true)][string]$Before,
  [Parameter(Mandatory=$true)][string]$After,
  [string]$BeforeVersion='0.1.9',
  [string]$AfterVersion='0.2.0',
  [string]$TestRoot='D:\FRI-work\installer-check'
)
$ErrorActionPreference='Stop'
$workspace = [IO.Path]::GetFullPath('D:\FRI-work\')
$root = [IO.Path]::GetFullPath($TestRoot)
if (-not $root.StartsWith($workspace,[StringComparison]::OrdinalIgnoreCase)) { throw 'Installer test must remain in D:\FRI-work.' }
$install = Join-Path $root 'FRI'
$profile = Join-Path $root 'profile'
if (Test-Path -LiteralPath $install) { throw 'Use a fresh test directory; this script does not delete pre-existing application folders.' }
$registered = @(Get-ItemProperty HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* -ErrorAction SilentlyContinue | Where-Object PSChildName -eq 'a5c099da-0d7f-522d-acec-f6e5539502b6')
if($registered.Count){throw 'An existing FRI installation is registered. Refusing to replace it during an isolated test.'}
New-Item -ItemType Directory -Force -Path $root,$profile | Out-Null
$exe = Join-Path $install 'FRI.exe'
$installed = $false
try {
  $first=Start-Process -FilePath (Resolve-Path -LiteralPath $Before) -ArgumentList @('/S','/currentuser',"/D=$install") -WindowStyle Hidden -Wait -PassThru
  if($first.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $exe)){throw 'Initial installation failed.'}
  $installed=$true
  & node "$PSScriptRoot/upgrade-probe.cjs" $exe $profile seed $BeforeVersion
  if($LASTEXITCODE -ne 0){throw 'Initial installed app probe failed.'}
  $obsolete=Join-Path $install 'obsolete-upgrade-test.txt'
  Set-Content -LiteralPath $obsolete -Value 'Test-only obsolete application file'
  $second=Start-Process -FilePath (Resolve-Path -LiteralPath $After) -ArgumentList @('/S','/currentuser',"/D=$install") -WindowStyle Hidden -Wait -PassThru
  if($second.ExitCode -ne 0){throw 'Upgrade installation failed.'}
  if(Test-Path -LiteralPath $obsolete){throw 'Old application file was not removed.'}
  & node "$PSScriptRoot/upgrade-probe.cjs" $exe $profile verify $AfterVersion
  if($LASTEXITCODE -ne 0){throw 'Upgraded app did not preserve its data.'}
  $entries=@(Get-ItemProperty HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object PSChildName -eq 'a5c099da-0d7f-522d-acec-f6e5539502b6')
  if($entries.Count -ne 1 -or $entries[0].DisplayVersion -ne $AfterVersion){throw 'Expected one registered new version.'}
  $receipt=[ordered]@{date=(Get-Date -Format o);from=$BeforeVersion;to=$AfterVersion;installPath=$install;oldFilesRemoved=$true;registryEntries=$entries.Count;calendarPreserved=$true;settingsPreserved=$true;installerExitCodes=@($first.ExitCode,$second.ExitCode)}
  $receipt | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $root 'receipt.json')
  $receipt | ConvertTo-Json
} finally {
  if($installed){
    $resolved=[IO.Path]::GetFullPath($install)
    if(-not $resolved.StartsWith($root+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Unexpected uninstall path.'}
    $entry=@(Get-ItemProperty HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* -ErrorAction SilentlyContinue | Where-Object PSChildName -eq 'a5c099da-0d7f-522d-acec-f6e5539502b6')
    if($entry.Count -eq 1 -and $entry[0].UninstallString.StartsWith('"'+(Join-Path $resolved 'Uninstall FRI.exe')+'"',[StringComparison]::OrdinalIgnoreCase)){
      $uninstaller=Join-Path $resolved 'Uninstall FRI.exe'
      if(Test-Path -LiteralPath $uninstaller){Start-Process -FilePath $uninstaller -ArgumentList '/S','/currentuser' -WindowStyle Hidden -Wait | Out-Null}
    }
  }
}
