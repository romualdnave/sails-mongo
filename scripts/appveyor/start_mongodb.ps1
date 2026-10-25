# Start a local mongod on 127.0.0.1:27017.
#
# `services: mongodb` does nothing on the Visual Studio 2026 image (the Windows
# service is not registered), so mongod is started by hand instead.
# https://github.com/appveyor/ci/issues/4004

$ErrorActionPreference = 'Stop'
$mongoVersion = '8.2.3'

# Look for a preinstalled mongod, then fall back to downloading one.
$mongod = $null
$cmd = Get-Command mongod -ErrorAction SilentlyContinue
if ($cmd) { $mongod = $cmd.Source }
if (-not $mongod) {
  foreach ($dir in 'C:\mongodb', 'C:\Program Files\MongoDB', 'C:\tools\mongodb') {
    if (Test-Path $dir) {
      $found = Get-ChildItem $dir -Recurse -Filter mongod.exe -ErrorAction SilentlyContinue | Select-Object -First 1
      if ($found) { $mongod = $found.FullName; break }
    }
  }
}
if (-not $mongod) {
  Write-Host "No preinstalled mongod found, downloading MongoDB $mongoVersion"
  $zip = Join-Path $env:TEMP 'mongodb.zip'
  $dest = 'C:\mongodb-download'
  (New-Object Net.WebClient).DownloadFile("https://fastdl.mongodb.org/windows/mongodb-windows-x86_64-$mongoVersion.zip", $zip)
  Expand-Archive $zip -DestinationPath $dest -Force
  $mongod = (Get-ChildItem $dest -Recurse -Filter mongod.exe | Select-Object -First 1).FullName
}
Write-Host "Using $mongod"
& $mongod --version

New-Item -ItemType Directory -Force C:\data\db | Out-Null
Start-Process $mongod -ArgumentList '--dbpath C:\data\db --bind_ip 127.0.0.1' -WindowStyle Hidden

# Wait until mongod accepts connections (up to 60s).
for ($i = 0; $i -lt 30; $i++) {
  try {
    $client = New-Object Net.Sockets.TcpClient('127.0.0.1', 27017)
    $client.Close()
    Write-Host 'mongod is accepting connections'
    exit 0
  } catch {
    Start-Sleep -Seconds 2
  }
}
Write-Error 'mongod did not start within 60s'
exit 1
