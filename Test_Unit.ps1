# PDFium.DLLをビルドするためのスクリプト -- depot_toolsをインクルードする
# パラメーター
param (
    # オプション: x86 | x64
    [string]$Arch = 'x64',
    # 予約パラメーター
    [string]$Wrapper_Branch = ' '
)

# Project Name
$Project_Name = 'PdfiumSharp.Test'

# ビルドディレクトリー
$BuildDir = (Get-Location).path

# コンフィグ
Write-Host "Architecture: " $Arch
Write-Host "Directory to Build: " $BuildDir

# Restore NuGet packages. This us used for NUnit3 
Write-Host "Restore NuGet Packages - NUnit3"
dotnet restore 

# Visual Studio MSI-Builder - コンパイラーを設定する
Write-Host "Locate VS 2017 MSBuilder.exe"
function buildVS {
    param (
        [parameter(Mandatory=$true)]
        [String] $path,

        [parameter(Mandatory=$false)]
        [bool] $clean = $true
    )
    process {
        $msBuildExe = Resolve-Path "${env:ProgramFiles(x86)}/Microsoft Visual Studio/2017/*/MSBuild/*/bin/msbuild.exe" -ErrorAction SilentlyContinue

        if ($clean) {
            Write-Host "Cleaning $($path)" -foregroundcolor green
            & "$($msBuildExe)" "$($path)" /t:Clean /m /p:Configuration=Release,Platform=$Arch /v:n
        }

        Write-Host "Building $($path)" -foregroundcolor green
        & "$($msBuildExe)" "$($path)" /t:Build /m /p:Configuration=Release,Platform=$Arch /v:n
    }
}

# DLLが存在するかチェックしWrapper/Libへコピーする
Write-Host "Checking for PDFium.DLL library..."

if ($Arch -eq 'x64') {
    $OUT_DLL_DIR = $BuildDir + '/Lib/x64'
}
elseif ($Arch -eq 'x86') {
    $OUT_DLL_DIR = $BuildDir + '/Lib/x86'
}
else {
    Write-Host "Arch not defined or invalid..."
    Exit
}

# solutionをコピーする
Write-Host "Copy pdfium DLL to PdfiumSharp.Test solution project"

$Lib_Dir = $BuildDir+"/"+$Project_Name+"/lib/"+$Arch

if ([System.IO.Directory]::Exists( $Lib_Dir )) {
    Set-Location $Lib_Dir
}
else {
    New-Item -Path $Lib_Dir -ItemType Directory
    Set-Location $Lib_Dir
}

if (Test-Path -Path $OUT_DLL_DIR'/pdfium.dll') {
    Copy-Item $OUT_DLL_DIR'/pdfium.dll' -Destination $Lib_Dir
}


# Build the unit test project
buildVS -path "$BuildDir/$Project_Name/$Project_Name.csproj"

# Make the test
Set-Location $BuildDir/$Project_Name

nunit3-console "bin/$Arch/Release/$Project_Name.dll"


Set-Location $BuildDir

ls