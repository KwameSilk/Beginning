# PDFium.DLLをビルドするためのスクリプト -- depot_toolsをインクルードする
# パラメーター
param (
    # オプション: x86 | x64
    [string]$Arch = 'x64',
    # Chromium/3907: https://pdfium.googlesource.com/pdfium/
    [string]$Pdfium_Branch = 'eb590e0e22e9119779befd7d5d6763b0dac91119',
    # Depot_tools: https://chromium.googlesource.com/chromium/tools/depot_tools/f73f0f401a6b895ebb32839e1b82e4e42bfb6dea
    [string]$Depot_Branch = 'f73f0f401a6b895ebb32839e1b82e4e42bfb6dea'
)

# ビルドディレクトリー
$BuildDir = (Get-Location).path

# コンフィグ
Write-Host "Architecture: " $Arch
Write-Host "PDFium branch: " $Pdfium_Branch
Write-Host "Depot_tools branch: " $Depot_Branch
Write-Host "Directory to Build: " $BuildDir

# Depot_toolsのチェックをする
Write-Host "Checking for depot_tools directory ..."

# 環境変数を設定する
$env:Path = "$BuildDir/depot_tools;$env:Path"
$env:DEPOT_TOOLS_WIN_TOOLCHAIN = "0"
$env:DEPOT_TOOLS_UPDATE = "0"

#"depot_tools"ディレクトリーがあるかチェックする
if ([System.IO.Directory]::Exists($BuildDir+'/depot_tools')) {
    Write-Host "Directory found!"
    Set-Location $BuildDir'/depot_tools'
}
else {
    # googleリポジトリーからdepot_toolsをダウンロードする
    Write-Host "Directory not Found"

    git clone -q --branch=master https://chromium.googlesource.com/chromium/tools/depot_tools

    Set-Location $BuildDir'/depot_tools'

    git status

    # アクティブのbranchを設定する
    git checkout $Depot_Branch
}

Write-Host "Testing 'gclient' command for the first time. This will configure python and git on Windows"
gclient
# depot_toolsのセットアップ終了

# PDFiumのセットアップリポジトリー
Set-Location $BuildDir

# ダウンロードとセットアップをする(時間が掛かる)
Write-Host "Checking PDFium repository branch: " $Pdfium_Branch

gclient config --unmanaged https://pdfium.googlesource.com/pdfium.git

gclient sync --revision "$Pdfium_Branch" -R

# BUILD.gnのパッチ
Set-Location $BuildDir'/pdfium'

# BUILD.gnのパッチを開始する
Write-Host "Start patching BUILD.gn"

# オリジナルファイルをコピーする
if (-Not (Test-Path -Path $BuildDir'/pdfium/BUILD.ORG.gn')) {
    Copy-Item './BUILD.gn' './BUILD.ORG.gn'
}

# ファイル名を設定する
$File = './BUILD.ORG.gn'
$FileOut = './BUILD.mod.gn'

# ファイルを処理し結果を$NewContentに割り当てる
$NewContent = Get-Content -Path $File |
    ForEach-Object {
        # 存在行を出力する

        # 行がマッチする場合
        if ($_ -match ([regex]::Escape('PNG_USE_READ_MACROS'))) {
            # 出力行を追加する
            $_
            ' "FPDFSDK_EXPORTS",'
        }

        elseif ($_ -match ('jumbo_component.+')) {
            # 出力行を追加する
            'shared_library("pdfium") {'
        }

        elseif ($_ -match ('complete_static_lib.+')) {
            # 出力行を追加する
            ' complete_shared_lib = true'
        }

        elseif ($_ -match ([regex]::Escape('public_configs = [ ":pdfium_public_config" ]'))) {
            # 出力行を追加する
            $_
            ' sources = []'
        }

        else { $_ }

    }

# $NewContentの内容をファイルに書く
$NewContent | Out-File -FilePath $FileOut -Encoding Default -Force

Copy-Item './BUILD.mod.gn' './BUILD.gn' -Force

Write-Host "Finish patching BUILD.gn"

# pdfview.hのパッチ

Write-Host "Start patching fpdfview.h"

Set-Location $BuildDir'/pdfium/public'

# オリジナルファイルをコピーする
if (-Not (Test-Path -Path $BuildDir'/pdfium/public/fpdfview.ORG.h')) {
    Copy-Item './fpdfview.h' './fpdfview.ORG.h'
}

# ファイル名を設定する
$File = './fpdfview.ORG.h'
$FileOut = './fpdfview.mod.h'

# ファイルを処理し結果を$NewContentに割り当てる
$NewContent = Get-Content -Path $File |
    ForEach-Object {
        # 存在行を出力する

        # 行がマッチする場合
        if ($_ -match ('^' + [regex]::Escape('#if defined(COMPONENT_BUILD)'))) {
            # 出力行を追加する
            '//#if defined(COMPONENT_BUILD)'
        }

        elseif ($_ -match ('^' + [regex]::Escape('#endif  // defined(WIN32)'))) {
            # 出力行を追加する
            $_
            '/**'
        }

        elseif ($_ -match ('^'+ [regex]::Escape('#endif  // defined(COMPONENT_BUILD)'))) {
            # 出力行を追加する
            $_
            '**/'
        }

        else { $_ }
    }

# $NewContentの内容をファイルに書く
$NewContent | Out-File -FilePath $FileOut -Encoding Default -Force

Copy-Item './fpdfview.mod.h' './fpdfview.h' -Force

Write-Host "Finish patching fpdfview.h"

# fpdfview.hのパッチを開始する
Set-Location $BuildDir'/pdfium'

if ($Arch -eq 'x64') {
    $GN_ARGS = 'is_component_build = false is_official_build = true is_debug = false pdf_enable_v8 = false pdf_enable_xfa = false pdf_is_standalone = true current_cpu=\"x64\" target_cpu=\"x64\" '
    $GN_OUTDIR = 'out/sharedReleasex64'
    $OUT_DLL_DIR = $BuildDir + '/Lib/x64'
}
elseif ($Arch -eq 'x86') {
    $GN_ARGS = 'is_component_build = false is_official_build = true is_debug = false pdf_enable_v8 = false pdf_enable_xfa = false pdf_is_standalone = true current_cpu=\"x86\" target_cpu=\"x86\" '
    $GN_OUTDIR = 'out/sharedReleasex86'
    $OUT_DLL_DIR = $BuildDir + '/Lib/x86'
}
else {
    Write-Host "Arch not defined or invalid..."
    Exit
}

# 'gn'コマンドのコンフィグ
Write-Host 'Configure gn with --args='$GN_ARGS
gn gen $GN_OUTDIR --args=$GN_ARGS

# コンパイルする
Write-Host 'Compiling with ninja... '
ninja -C $GN_OUTDIR  pdfium

# ディレクトリーが存在するかをチェックする
if ([System.IO.Directory]::Exists($OUT_DLL_DIR)) {
    Set-Location $OUT_DLL_DIR
}
else {
    New-Item -Path $OUT_DLL_DIR -ItemType Directory
    Set-Location $OUT_DLL_DIR
}

# 出力ライブラリをLib/x64orLib/x86にコピーする
Write-Host 'Copy DLL files output to:' $OUT_DLL_DIR

Copy-Item -Path "$BuildDir/pdfium/$GN_OUTDIR/pdfium.*" -Destination $OUT_DLL_DIR

Set-Location $BuildDir
