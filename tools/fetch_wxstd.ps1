#!/usr/bin/env powershell
# Fetches wxWidgets locale .po files from the wxWidgets GitHub repository and
# compiles them to .mo files for use in the Aegisub Windows installer.
#
# Output: src/mo/wxstd-{lang}.mo
# These are referenced by packages/win_installer/fragment_translations.iss
# under the ENABLE_WX_TRANSLATIONS block.
#
# Usage: .\tools\fetch_wxstd.ps1 -SourceRoot <path-to-aegisub-source>

param (
    [Parameter(Position = 0)]
    [string]$SourceRoot = (Split-Path $PSScriptRoot -Parent)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# wxWidgets branch to fetch translations from
$WxBranch = "3.2"
$WxLocaleBase = "https://raw.githubusercontent.com/wxWidgets/wxWidgets/$WxBranch/locale"

# Output directory
$MoDir = Join-Path $SourceRoot "src\mo"
if (!(Test-Path $MoDir)) {
    New-Item -ItemType Directory -Path $MoDir | Out-Null
    Write-Host "Created directory: $MoDir"
}

# Mapping: Aegisub locale name -> wxWidgets .po filename (without .po extension)
# Only includes languages where wxWidgets has a translation available.
$LocaleMap = [ordered]@{
    "ar"      = "ar"
    "ca"      = "ca"
    "cs"      = "cs"
    "da"      = "da"
    "de"      = "de"
    "el"      = "el"
    "es"      = "es"
    "eu"      = "eu"
    "fa"      = "fa_IR"
    "fi"      = "fi"
    "fr_FR"   = "fr"
    "gl"      = "gl_ES"
    "hu"      = "hu"
    "id"      = "id"
    "it"      = "it"
    "ja"      = "ja"
    "ko"      = "ko_KR"
    "lt"      = "lt"
    "nl"      = "nl"
    "pl"      = "pl"
    "pt_BR"   = "pt_BR"
    "pt_PT"   = "pt"
    "ru"      = "ru"
    "sr_RS"   = "sr"
    "tr"      = "tr"
    "uk_UA"   = "uk"
    "vi"      = "vi"
    "zh_CN"   = "zh_CN"
    "zh_TW"   = "zh_TW"
}

# Check that msgfmt is available
$MsgFmt = Get-Command "msgfmt" -ErrorAction SilentlyContinue
if ($null -eq $MsgFmt) {
    Write-Error @"
msgfmt not found. Please install gettext tools:
  - Via Chocolatey: choco install gettext
  - Via Scoop:      scoop install gettext
  - Via MSYS2/Git Bash: pacman -S gettext
"@
    Exit 1
}

$TempDir = Join-Path $env:TEMP "aegisub-wxstd-$([System.Guid]::NewGuid().ToString('N').Substring(0,8))"
New-Item -ItemType Directory -Path $TempDir | Out-Null

try {
    $Success = 0
    $Failed = 0

    foreach ($entry in $LocaleMap.GetEnumerator()) {
        $AegiLang  = $entry.Key
        $WxPoName  = $entry.Value
        $PoUrl     = "$WxLocaleBase/$WxPoName.po"
        $TempPo    = Join-Path $TempDir "$WxPoName.po"
        $OutputMo  = Join-Path $MoDir "wxstd-$AegiLang.mo"

        Write-Host "Fetching $WxPoName.po -> wxstd-$AegiLang.mo ... " -NoNewline

        try {
            Invoke-WebRequest -Uri $PoUrl -OutFile $TempPo -UseBasicParsing -ErrorAction Stop

            & msgfmt -o $OutputMo $TempPo
            if ($LASTEXITCODE -ne 0) {
                throw "msgfmt exited with code $LASTEXITCODE"
            }

            Write-Host "OK" -ForegroundColor Green
            $Success++
        }
        catch {
            Write-Host "FAILED: $_" -ForegroundColor Red
            $Failed++
        }
    }

    Write-Host ""
    Write-Host "Done: $Success compiled, $Failed failed."
    Write-Host "Output directory: $MoDir"

    if ($Failed -gt 0) {
        Exit 1
    }
}
finally {
    Remove-Item -Recurse -Force $TempDir -ErrorAction SilentlyContinue
}
