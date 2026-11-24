$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root
$python = Join-Path $root 'rapidocr-env\Scripts\python.exe'
if (-not (Test-Path -LiteralPath $python)) { throw '先运行 setup-rapidocr.cmd 安装发布环境。' }

$stage = Join-Path $root 'dist\package'
$workerDist = Join-Path $root 'work\rapidocr-dist'
$workerBuild = Join-Path $root 'work\rapidocr-build'
$workRoot = Join-Path $root 'work'
foreach ($path in @($stage, $workerDist, $workerBuild)) {
    $full = [IO.Path]::GetFullPath($path)
    if (-not ($full.StartsWith(([IO.Path]::GetFullPath((Join-Path $root 'dist')) + '\'), [StringComparison]::OrdinalIgnoreCase) -or
               $full.StartsWith(([IO.Path]::GetFullPath($workRoot) + '\'), [StringComparison]::OrdinalIgnoreCase))) {
        throw "清理路径超出构建目录: $full"
    }
    if (Test-Path -LiteralPath $full) { Remove-Item -LiteralPath $full -Recurse -Force }
}
New-Item -ItemType Directory -Path $stage -Force | Out-Null
New-Item -ItemType Directory -Path $workRoot -Force | Out-Null

& $python -m PyInstaller --noconfirm --clean --onedir --name rapidocr-worker `
    --distpath $workerDist --workpath $workerBuild --specpath $workRoot `
    --collect-all rapidocr (Join-Path $root 'tools\rapidocr_bridge.py')
if ($LASTEXITCODE -ne 0) { throw 'RapidOCR 打包失败。' }
Copy-Item -LiteralPath (Join-Path $workerDist 'rapidocr-worker') -Destination (Join-Path $stage 'rapidocr-worker') -Recurse

$fw = 'C:\Windows\Microsoft.NET\Framework64\v4.0.30319'
$wm = 'C:\Windows\System32\WinMetadata'
$refs = @('System.dll','System.Core.dll','System.Drawing.dll','System.Windows.Forms.dll','System.Web.Extensions.dll',
    "$fw\System.Runtime.dll", "$fw\System.Threading.Tasks.dll", "$fw\System.Runtime.WindowsRuntime.dll",
    "$wm\Windows.Foundation.winmd", "$wm\Windows.Media.winmd", "$wm\Windows.Graphics.winmd",
    "$wm\Windows.Storage.winmd", "$wm\Windows.Globalization.winmd")
$cscArgs = @('/nologo','/target:winexe','/codepage:65001','/optimize+','/utf8output',
    "/win32icon:$root\ClipShelf.ico", "/out:$stage\ClipShelf.exe") +
    ($refs | ForEach-Object { '/r:' + $_ }) + @((Join-Path $root 'src\ClipShelf.cs'))
& "$fw\csc.exe" @cscArgs
if ($LASTEXITCODE -ne 0) { throw 'ClipShelf 编译失败。' }
Copy-Item -LiteralPath (Join-Path $root 'LICENSE') -Destination (Join-Path $stage 'LICENSE.txt')
Copy-Item -LiteralPath (Join-Path $root 'README.md') -Destination (Join-Path $stage 'README.md')
Copy-Item -LiteralPath (Join-Path $root 'THIRD_PARTY.md') -Destination (Join-Path $stage 'THIRD_PARTY.md')
$licenses = Join-Path $stage 'third-party-licenses'
$sitePackages = Join-Path $root 'rapidocr-env\Lib\site-packages'
foreach ($package in (Get-ChildItem -LiteralPath $sitePackages -Directory -Filter '*.dist-info')) {
    foreach ($file in (Get-ChildItem -LiteralPath $package.FullName -Recurse -File | Where-Object { $_.Name -match '^(LICENSE|NOTICE|COPYING)' })) {
        $relative = $file.FullName.Substring($package.FullName.Length).TrimStart('\')
        $target = Join-Path $licenses (Join-Path $package.Name $relative)
        New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
        Copy-Item -LiteralPath $file.FullName -Destination $target
    }
}
$pythonHome = & $python -c 'import sys; print(sys.base_prefix)'
$pythonLicense = Join-Path $pythonHome 'LICENSE.txt'
if (Test-Path -LiteralPath $pythonLicense) {
    Copy-Item -LiteralPath $pythonLicense -Destination (Join-Path $licenses 'Python-3.12-LICENSE.txt')
}
$zip = Join-Path $root 'dist\ClipShelf-1.4.5-portable.zip'
if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip
Write-Output "RELEASE OK: $zip"
