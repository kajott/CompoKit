<#
.synopsis
    CompoKit setup script
.description
    This script installs all components of CompoKit.
    By default, only the required programs are downloaded and installed into
    the 'bin' directory; optionally, additional programs and music files
    can be installed too.
.parameter Help
    Display this help text and exit.
.parameter List
    Don't install anything, just print a list of installable packages.
.parameter Packages
    One or more "packages" to be installed. A package can either be a
    program name, or "all" for all essential programs, or "music" for
    the background music files. The default is "all".
.parameter Reconfigure
    Force re-writing the selected packages' configuration files.
    Note that all former contents of these files (i.e. any configuration
    settings the user has performed) are lost!
.parameter Reinstall
    Force redownloading, reinstallation and reconfiguration of the
    selected packages.
#>

param(
    [switch] [Alias("h")] $Help,
    [switch] [Alias("l")] $List,
    [switch] [Alias("c")] $Reconfigure,
    [switch] [Alias("u")] $Reinstall,
    [parameter(ValueFromRemainingArguments=$true)] [string[]] $Packages
)
if (-not $Packages.Count) { $Packages = @("all") }

###############################################################################


##### download URLs #####

# some special syntax options are supported in these URLs:
# - a download filename can be specified explicitly by appending it after
#   a pipe sign ('|') [the default is to derive the download filename from
#   the last path component of the URL]
# - SourceForge downloads (which usually have unwieldy URLs ending in
#   "/download" instead of a proper filename) can be written as
#   "SourceForge:projectname/path/to/file.zip"


# the following URLs are version dependent and may change often;
# below every link, there's another (version independent) URL from which
# the actual download link can be found

$URL_7zip_main = "https://www.7-zip.org/a/7z2201-x64.exe"
# https://www.7-zip.org/ -> latest stable version, .exe 64-bit x64

$URL_totalcmd = "https://totalcommander.ch/win/tcmd1051x64.exe"
# https://www.ghisler.com/download.htm -> 64-bit only

$URL_npp = "https://github.com/notepad-plus-plus/notepad-plus-plus/releases/download/v8.4.5/npp.8.4.5.portable.minimalist.7z"
# http://notepad-plus-plus.org/downloads/ -> latest release -> mini-portable / minimalist 7z

$URL_sumatra = "https://www.sumatrapdfreader.org/dl/rel/3.4.6/SumatraPDF-3.4.6-64.zip"
# https://www.sumatrapdfreader.org/download-free-pdf-viewer.html -> 64-bit builds, portable version

$URL_mpc_hc = "https://github.com/clsid2/mpc-hc/releases/download/1.9.23/MPC-HC.1.9.23.x64.zip"
# https://github.com/clsid2/mpc-hc/releases -> latest x64.zip

$URL_vlc = "https://mirror.netcologne.de/videolan.org/vlc/last/win64/vlc-3.0.17.4-win64.7z"
# https://mirror.netcologne.de/videolan.org/vlc/last/win64/ -> latest *-win64.7z

$URL_mpv = "https://sourceforge.net/projects/mpv-player-windows/files/64bit/mpv-x86_64-20220925-git-56e24d5.7z/download"
# https://sourceforge.net/projects/mpv-player-windows/files/64bit/ -> latest .7z

$URL_xmplay = "http://uk.un4seen.com/files/xmplay38.zip"
# https://www.un4seen.com/xmplay.html -> small download button (top center)

$URL_xmp_sid = "http://support.xmplay.com/files/12/xmp-sidex__v2.0_rev3.0%20final.zip"
# https://www.un4seen.com/xmplay.html#plugins -> SIDex input plugin -> download

$URL_libopenmpt = "https://lib.openmpt.org/files/libopenmpt/bin/libopenmpt-0.6.5+release.bin.windows.zip"
# https://lib.openmpt.org/libopenmpt/download/ -> xmp-openmpt for Windows 7+ (x86 + SSE2)

$URL_dosbox_vanilla = "https://sourceforge.net/projects/dosbox/files/dosbox/0.74-3/DOSBox0.74-3-win32-installer.exe/download"
# https://sourceforge.net/projects/dosbox/files/dosbox/ -> latest version -> Win32 installer

$URL_dosbox_x = "https://github.com/joncampbell123/dosbox-x/releases/download/dosbox-x-v0.84.3/dosbox-x-vsbuild-win64-20220901232730.zip"
# https://github.com/joncampbell123/dosbox-x/releases -> latest dosbox-x-vsbuild-win64-*.zip

$URL_winuae = "https://download.abime.net/winuae/releases/WinUAE4910_x64.zip"
# http://www.winuae.net/download/ -> zip-archive (64 bit)

$URL_tic80 = "https://github.com/nesbox/TIC-80/releases/download/v1.0.2164/tic80-v1.0-win.zip"
# https://github.com/nesbox/TIC-80/releases -> latest *-win.zip

$URL_microw8 = "https://github.com/exoticorn/microw8/releases/download/v0.2.2/microw8-0.2.2-windows.zip"
# https://github.com/exoticorn/microw8/releases -> latest *-windows.zip

$URL_ansilove = "https://github.com/kajott/ansilove-nogd/releases/download/v0.1/ansilove.exe"
# https://github.com/kajott/ansilove-nogd/releases -> latest ansilove.exe

$URL_pixelview = "https://github.com/kajott/PixelView/releases/download/v1.0/pixelview.exe"
# https://github.com/kajott/PixelView/releases -> latest pixelview.exe

$URL_capturinha = "https://github.com/kebby/Capturinha/releases/download/v0.4.1/Capturinha.zip"
# https://github.com/kebby/Capturinha/releases -> latest .zip

$URL_ffmpeg = "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-n4.4-latest-win64-gpl-shared-4.4.zip"
# https://github.com/BtbN/FFmpeg-Builds/releases -> latest ffmpeg-n4.4-...-win64-gpl-shared-4.4.zip
# NOTE: this must match with the version number indicated in Capturinha's release notes above!

$URL_python = "https://www.python.org/ftp/python/3.10.7/python-3.10.7-embed-amd64.zip"
# https://python.org/ -> Downloads -> Windows -> Latest Python 3 Release -> Windows embeddable package (64-bit)


# these are generic and not likely to change
# (either because they always point to the latest version,
# or because the software hasn't been changed in years)
$URL_7zip_bootstrap = "https://www.7-zip.org/a/7za920.zip"
$URL_xmp_flac = "http://uk.un4seen.com/files/xmp-flac.zip"
$URL_xmp_opus = "http://uk.un4seen.com/files/xmp-opus.zip"
$URL_xmp_ym = "https://www.un4seen.com/stuff/xmp-ym.zip"
$URL_xnview = "https://download.xnview.com/XnView-win-small.zip"
$URL_compoview = "https://files.scene.org/get:nl-http/resources/graphics/compoview_v1_02b.zip"
$URL_gliss = "https://www.emphy.de/~mfie/foo/gliss.exe"
$URL_acidview = "https://sourceforge.net/projects/acidview6-win32/files/acidview6-win32/6.10/avw-610.zip/download"
$URL_sahli = "https://github.com/m0qui/Sahli/archive/master.zip|Sahli-master.zip"
$URL_typr = "https://github.com/mog/typr/archive/master.zip|typr-master.zip"
$URL_youtube_dl = "https://yt-dl.org/downloads/latest/youtube-dl.exe"
$URL_yt_dlp = "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe"
$URL_vice = "https://sourceforge.net/projects/vice-emu/files/releases/binaries/windows/WinVICE-3.1-x64.7z/download"
$URL_a500rom = "https://www.ikod.se/wp-content/uploads/files/Kickstart-v1.3-rev34.5-1987-Commodore-A500-A1000-A2000-CDTV.rom"


# list of file extensions which are recognized as playable music files
$musicFileTypes = "mp3 mp2 m4a aac ogg oga wma asf wav aif aiff opus flac mod xm stm s3m it".Split()


###############################################################################


# setup and helper functions

# set up directories
$global:_pkgstatuses = @()
$baseDir = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$cacheDir = Join-Path $baseDir "temp"
$tempDir = Join-Path $cacheDir "temp_extract"
$binDir = Join-Path $baseDir "bin"
$musicDir = Join-Path $baseDir "music"
cd $baseDir

# add the bin directory to the PATH while we're working on it
if (-not ($env:Path).Contains($binDir)) {
    Set-Item -Path Env:Path -Value ($binDir + ";" + $Env:Path)
}

# write a status message
function status($msg) {
    Write-Host -ForegroundColor DarkCyan $msg
}

# write an error message
function error($msg) {
    Write-Host -ForegroundColor Yellow -BackgroundColor DarkRed ("ERROR: " + $msg)
}

# write a package status message
function pkgstatus($msg) {
    if ($global:_pkgstatuses -contains $msg) { return }
    $global:_pkgstatuses += , $msg
    Write-Host -ForegroundColor Magenta $msg
}

# check if a file or directory doesn't already exist
function need {
    param([string] $File, [string[]] $For, [switch] $Config, [switch] $Always, [switch] $NoOverwrite)

    # is the package this check is for being processed at all?
    $requested = (-not $For) -or ($For | where { $Packages -contains $_})
    if (-not ($Always -or $requested)) {
        return $false
    }

    # check whether this file needs to be produced
    $needed = ((-not (Test-Path -LiteralPath $File)) `
           -or ($Reinstall -and $requested -and -not $NoOverwrite) `
           -or ($Config -and $requested -and $Reconfigure))

    # generate status message
    if ($needed -and $For) {
        $status = if ($Config) {"Configuring: "} else {"Installing: "}
        pkgstatus ($status + $For[0])
    }

    return $needed
}

# create a directory if it doesn't exist
function mkdir_s($dir) {
    if (-not (Test-Path $dir)) {
        status ("Creating Directory: " + $dir)
        mkdir $dir > $null
    }
}

# move a file to its target location; remove the target first if necessary
function mv_f($src, $dest) {
    if ((Get-Item $dest -ErrorAction SilentlyContinue) -is [System.IO.DirectoryInfo]) {
        $dest = Join-Path $dest (Split-Path -Leaf $src)
    }
    if (Test-Path -LiteralPath $dest) {
        rm -LiteralPath $dest -Recurse -ErrorAction SilentlyContinue > $null
    }
    mv -LiteralPath $src $dest > $null
}

# remove temporary extraction directory again
function remove_temp {
    if (Test-Path $tempDir) {
        rm -Recurse -Force $tempDir > $null
    }
}

# get the path of the first subdirectory inside a directory
function subdir_of($dir) {
    $sub = Get-ChildItem $dir -Attributes Directory | select -First 1
    return Join-Path $dir $sub.Name
}

# extract the extension from a file name
function get_ext($path) {
    $x = ([string]$path).Replace("\", "/").Split("/")[-1].Split(".")
    if ($x.Count -gt 1) { return $x[-1].ToLower() }
}

# check wheter a file is a music file
function is_music($path) {
    $f = ([string]$path).Replace("\", "/").Split("/")[-1].ToLower()
    if ($f.StartsWith("mod.")) { return $true }  # old Amiga .mod syntax
    $f = $f.Split(".")
    return ($f.Count -gt 1 -and $musicFileTypes -Contains $f[-1])
}

# split a URL into a (URL, filename) tuple
function parse_url($url) {
    # check for filename override
    $parts = $url.split("|")
    if ($parts.Count -gt 1) {
        $url = $parts[0]
        $filename = $parts[-1]
    }
    elseif ($url.ToLower().EndsWith("/download")) {
        # SourceForge-style URL that ends with "/download"
        $filename = $url.Split("/")[-2]
    }
    else {
        # normal URL
        $filename = $url.Split("?")[0].Split("#")[0].Trim("/").Split("/")[-1]
    }
    return @($url, $filename)
}

# download a file into the temp directory and return its path
function download($url) {
    $url, $filename = parse_url $url
    $filename = Join-Path $cacheDir $filename
    if ($Reinstall -or -not (Test-Path $filename)) {
        status ("Downloading: " + $url)
        mkdir_s $cacheDir
        $tempfile = $filename + ".part"
        if (Test-Path -LiteralPath $tempfile) { rm $tempfile >$null }
        try {
            (New-Object System.Net.WebClient).DownloadFile($url, $tempfile)
        }
        catch {
            error ("failed to download " + $url + "`n(this may cause some subsequent errors, which may be ignored)")
            return ""
        }
        mv_f $tempfile $filename
    }
    return $filename
}

# extract (specific files from) an archive, disregarding paths
function extract {
    Param(
        [string] $archive,
        [parameter(ValueFromRemainingArguments=$true)] [string[]] $items
    )
    if (-not $archive) { return }
    status ("Extracting: " + $archive)
    7z -y e $archive @items > $null
}

# get a list of all files in an archive
function archive_contents($archive) {
    7z l -slt -ba $archive | Select-String -Pattern "Path =" | % { ([string]$_).Split("=")[-1].Trim() }
}

# extract an archive into a temporary directory and return its path
function extract_temp($archive) {
    if (-not $archive) { return }
    remove_temp
    mkdir $tempDir > $null
    status ("Extracting: " + $archive)
    $cwd = pwd
    cd $tempDir
    7z -y x $archive > $null
    cd $cwd.Path
    return $tempDir
}

# move a bunch of files from the source directory to the current directory
function collect($fromDir, $items) {
    $targetDir = (pwd).Path
    cd $fromDir
    foreach ($item in $items) {
        mv_f $item (Join-Path $targetDir $item)
    }
    cd $targetDir
}

# move all files from a directory into the current directory
function collect_all($fromDir) {
    Get-ChildItem $fromDir | % { mv_f $_.FullName $_.Name }
}

# create a text file with specific content (if it doesn't exist already)
function config() {
    param([string] $File, [string] $Contents, [string[]] $For)
    if (need $File -For $For -Config) {
        status ("Creating File: " + $File)
        New-Item -Name $File -Force -Value $Contents > $null
    }
}

###############################################################################


# -Help and -List modes
if ($Help) {
    Get-Help $PSCommandPath -Detailed
    exit
}
if ($List) {
    $all = @()
    $others = @()
    Get-Content -LiteralPath $PSCommandPath | % {
        if ($_ -match '-for ([a-z0-9,+-]+)') {
            $pkgs = $matches[1] -split ","
            if ($pkgs -contains "all") {
                $all += $pkgs
            } else {
                $others += $pkgs
            }
        }
    }
    Write-Host -ForegroundColor Yellow "Packages that are installed by default (part of metapackage 'all'):"
    Write-Host ("  " + ($all | sort | ? { $_ -ne "all" } | select -Unique))
    Write-Host -ForegroundColor Yellow "Packages that must be installed explicitly:"
    Write-Host ("  " + ($others | sort | select -Unique))
    exit
}


###############################################################################


# populate the bin directory
mkdir_s $binDir
cd $binDir
$hadCache = Test-Path $cacheDir


##### 7-zip #####

if (need "7z.exe" -for 7zip,all -always) {
    # bootstrapping: download the old 9.20 x86 executable first;
    # it's the only one that comes in .zip format and can be extracted
    # by PowerShell itself
    $f = download $URL_7zip_bootstrap
    status("Extracting: " + $f)
    Expand-Archive -Path $f -DestinationPath . > $null
    rm @("7-zip.chm", "license.txt", "readme.txt")  # remove unwanted stuff

    # now we can download and extract the current version
    $f = download $URL_7zip_main
    status ("Extracting: " + $f)
    7za -y e $f 7z.dll 7z.exe 7zFM.exe 7zG.exe > $null
    rm "7za.exe" >$null  # we don't need the old standalone version any longer
}


##### Total Commander #####

if (need "totalcmd64.exe" -for totalcmd,all) {
    # tcmd's download file is an installer that contains a .cab file
    # with the actual data; thus we need to extract the .cab first
    $cab = Join-Path $cacheDir "tcmd.cab"
    if (-not (Test-Path $cab)) {
        cd $cacheDir
        extract (download $URL_totalcmd) INSTALL.CAB
        mv_f INSTALL.CAB $cab
        cd $binDir
    }

    # now we can extract the actual files, but we need to turn
    # their names into lowercase too
    $tcfiles = @(
        "TOTALCMD64.EXE", "TOTALCMD64.EXE.MANIFEST",
        "WCMZIP64.DLL", "UNRAR64.DLL", "TC7Z64.DLL", "TCLZMA64.DLL", "TCUNZL64.DLL",
        "NOCLOSE64.EXE", "TCMADM64.EXE", "TOTALCMD.INC"
    )
    extract $cab @tcfiles
    foreach ($f in $tcfiles) {
        mv $f $f.ToLower() -ErrorAction SilentlyContinue > $null
    }
}
config "wincmd.ini" -for totalcmd,all @"
[Configuration]
UseIniInProgramDir=7
UseNewDefFont=1
FirstTime=0
FirstTimeIconLib=0
onlyonce=1
ShowHiddenSystem=1
UseTrash=0
AltSearch=3
Editor=notepad++.exe "%1"
[AllResolutions]
FontName=Segoe UI
FontSize=10
FontWeight=400
FontNameWindow=Segoe UI
FontSizeWindow=10
FontWeightWindow=400
FontNameDialog=Segoe UI
FontSizeDialog=9
[Shortcuts]
F2=cm_RenameSingleFile
[Colors]
InverseCursor=1
ThemedCursor=0
InverseSelection=0
BackColor=6316128
BackColor2=-1
ForeColor=14737632
MarkColor=65280
CursorColor=10526880
CursorText=16777215
[right]
path=$baseDir
"@
config "wcx_ftp.ini" -for totalcmd,all @"
[default]
pasvmode=1
"@


##### Notepad++, SumatraPDF #####

if (need "notepad++.exe" -for notepad++,all) {
    extract (download $URL_npp) notepad++.exe SciLexer.dll doLocalConf.xml langs.model.xml stylers.model.xml
    mv_f langs.model.xml   langs.xml
    mv_f stylers.model.xml stylers.xml
}

if (need "SumatraPDF.exe" -for sumatrapdf,all) {
    extract (download $URL_sumatra)
    mv SumatraPDF*.exe SumatraPDF.exe
}
config "SumatraPDF-settings.txt" -for sumatrapdf,all @"
UiLanguage = en
CheckForUpdates = false
RememberStatePerDocument = false
DefaultDisplayMode = single page
"@


##### MPC-HC #####

if (need "mpc-hc64.exe" -for mpc-hc,all) {
    collect (extract_temp (download $URL_mpc_hc)) @(
        "LAVFilters64", "Shaders", "Shaders11",
        "D3DCompiler_47.dll", "D3DX9_43.dll",
        "mpc-hc64.exe"
    )
    remove_temp
}
config "mpc-hc64.ini" -for mpc-hc,all @"
[Settings]
AfterPlayback=0
AllowMultipleInstances=0
ExitFullscreenAtTheEnd=0
LaunchFullScreen=1
Loop=0
LoopMode=1
LoopNum=0
MenuLang=0
ShowOSD=0
TrayIcon=0
UpdaterAutoCheck=0
LogoExt=0
LogoID2=206
DSVidRen=13
DX9Resizer=4
SynchronizeClock=1
SynchronizeDisplay=0
SynchronizeNearest=0
[Commands2]
CommandMod0=816 1 51 "" 5 0 0 0
"@
# cf. https://www.pouet.net/topic.php?which=11591&page=18#c553418


##### VLC #####

if (need "vlc\vlc.exe" -for vlc) {
    $tmpdir = (extract_temp (download $URL_vlc))
    $vlcver = Get-ChildItem -LiteralPath $tmpdir -Filter "vlc-*" -Name
    mv_f (Join-Path $tmpdir $vlcver) vlc
    remove_temp
}
config "vlc\vlcrc" -for vlc @"
[core]
fullscreen=1
osd=0
video-title-show=0
playlist-cork=0
#start-paused=1  #buggy: doesn't autostart
[qt]
qt-system-tray=0
#qt-fs-controller=0
qt-updates-notif=0
qt-privacy-ask=0
"@


##### MPV #####

if (need "mpv.exe" -for mpv) {
    extract (download $URL_mpv) mpv.exe
    mkdir_s portable_config
}
config "portable_config\mpv.conf" -for mpv @"
fullscreen=yes
pause=yes
"@


##### XMPlay #####

if (need "xmplay.exe" -for xmplay,all -NoOverwrite) {
    extract (download $URL_xmplay) xmplay.exe xmp-zip.dll xmp-wma.dll
}
if (need "xmp-wma.dll" -for xmplay,all) {
    # These DLLs are normally included in the XMPlay download archive,
    # but as long as we're shipping an unreleased custom build of xmplay.exe,
    # we need to extract them from the archive to be feature-complete.
    extract (download $URL_xmplay) xmp-zip.dll xmp-wma.dll
}
if (need "xmp-openmpt.dll" -for xmplay,all) {
    extract (download $URL_libopenmpt) XMPlay/openmpt-mpg123.dll XMPlay/xmp-openmpt.dll
}
if (need "xmp-flac.dll" -for xmplay,all) {
    extract (download $URL_xmp_flac) xmp-flac.dll
}
if (need "xmp-opus.dll" -for xmplay,all) {
    extract (download $URL_xmp_opus) xmp-opus.dll
}
if (need "xmp-sidex.dll" -for xmplay,all) {
    extract (download $URL_xmp_sid) xmp-sidex.dll
}
if (need "xmp-ym.dll" -for xmplay,all) {
    extract (download $URL_xmp_ym) xmp-ym.dll
}
config "xmplay.ini" -for xmplay,all @"
[XMPlay]
PluginTypes=786D702D6F70656E6D70742E646C6C006D6F642073336D20786D20697400
MODmode=2
InfoTextSize=3
Info=-2147220736
MultiInstance=0
AutoSet=1
Bubbles=1
TitleTray=0
[SID_27]
config=00FF70FF7F095000002C018813B80B1932
[OpenMPT]
UseAmigaResampler=1
"@
if (need -config "xmplay.set" -for xmplay,all) {
    # XMPlay's preset file is an ugly binary blob :(
    status ("Creating File: xmplay.set")
    $data = [byte[]] @()
    foreach ($spec in @("IT:8:100", "MOD:1:20", "S3M:8:100", "XM:8:100")) {
        $fmt, $interpol, $stereo = $spec.Split(":")
        $cfg = "xmp-openmpt.dll`0<settings InterpolationFilterLength=`"$interpol`" StereoSeparation_Percent=`"$stereo`"/>`0"
        $item = [System.Text.Encoding]::UTF8.GetBytes($fmt)
        $item += [byte[]] @(0, ($cfg.Length + 2), 0,0,0, $cfg.Length, 0)
        $item += [System.Text.Encoding]::UTF8.GetBytes($cfg)
        $data += [byte[]] @(($item.Count + 4), 0, 3, 0x20) + $item
    }
    $data | Set-Content -Path "xmplay.set" -Encoding Byte
}


##### XnView #####

if (need "xnview.exe" -for xnview,all) {
    extract (download $URL_xnview) XnView/xnview.exe XnView/xnview.exe.manifest
}
config "xnview.ini" -for xnview,all @"
[Cache]
SavingMode=1
[Start]
ParamsSavingMode=1
SavingMode=1
BToolBar=0
VToolBar=0
TabBar=0
LaunchTimes=1
ShowAgain=268435422
InFullscreen=1
Only1ESC=1
ENTER=0
MMB=2
Filter0=65
Filter1=65
Filter2=64
Filter3=1
[Browser]
AutoPlay=0
ShowPreview=0
UseFileDB=0
UseShadow=0
FlatStyle=1
Spacing=2
IconHeight=128
IconWidth=192
IconInfo=0
UseColor=0
UseBackgroundColor=1
BackgroundColor=6316128
PreviewColor=6316128
TextBackColor=6316128
TextColor=14737632
ThumbConfig=11
[View]
PlayMovie=0
PlaySound=0
BackgroundColor=6316128
OneViewMultiple=1
OnlyOneView=1
RightButtonFlag=1
ShowText=0
DirKeyVFlag=1
[Cache]
IsActive=0
[Full]
UseDelay=0
[File]
LosslessBak=0
"@


##### CompoView, GLISS, ACiDview, AnsiLove #####

if (need "compoview_64.exe" -for compoview,all) {
    extract (download $URL_compoview) compoview/compoview_64.exe
}
if (need "pixelview.exe" -for pixelview,all) {
    mv_f (download $URL_pixelview) .
}
if (need "gliss.exe" -for gliss,all) {
    mv_f (download $URL_gliss) .
}
if (need "ACiDview.exe" -for acidview,all) {
    extract (download $URL_acidview) ACiDview.exe
}
if (need "ansilove.exe" -for ansilove,all) {
    mv_f (download $URL_ansilove) .
}


##### Sahli, typr #####

cd $baseDir

if (need "Sahli" -for sahli,all) {
    mv_f (subdir_of (extract_temp (download $URL_sahli))) "Sahli"
    remove_temp
}
config "Sahli/_run.cmd" -for sahli,all @"
@echo off
set chrome="%ProgramW6432%\Google\Chrome\Application\chrome.exe"
if not exist %chrome% set chrome="%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"
start "" %chrome% ^
--user-data-dir="%TEMP%\compokit_chrome_profile" ^
--allow-file-access-from-files ^
--start-fullscreen --kiosk ^
"file://%~dp0/index.html"
"@

if (need "typr" -for typr,all) {
    mv_f (subdir_of (extract_temp (download $URL_typr))) "typr"
    remove_temp
}
config "typr/_run.cmd" -for typr,all @"
@echo off
set chrome="%ProgramW6432%\Google\Chrome\Application\chrome.exe"
if not exist %chrome% set chrome="%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"
start "" %chrome% ^
--user-data-dir="%TEMP%\compokit_chrome_profile" ^
--allow-file-access-from-files ^
--start-fullscreen --kiosk ^
"file://%~dp0/index.html"
"@

cd $binDir


##### DOSBox(-X) #####

if (need "dosbox.exe" -for dosbox,all) {
    extract (download $URL_dosbox_vanilla) DOSBox.exe SDL.dll SDL_net.dll
}
if (need "dosbox-x.exe" -for dosbox-x,all) {
    extract (download $URL_dosbox_x) bin/x64/Release/dosbox-x.exe
}


##### VICE #####

if (need "VICE/x64.exe" -for vice,all) {
    mv_f (subdir_of (extract_temp (download $URL_vice))) "VICE"
    remove_temp
}
config "VICE/vice.ini" -for vice,all @"
[C64]
FullscreenWidth=1920
FullscreenHeight=1080
FullscreenRefreshRate=50
ConfirmOnExit=0
VICIIColorBrightness=750
VICIIFilter=0
[C64SC]
FullscreenWidth=1920
FullscreenHeight=1080
FullscreenRefreshRate=50
ConfirmOnExit=0
VICIIColorBrightness=750
VICIIFilter=0
[PLUS4]
FullscreenWidth=1920
FullscreenHeight=1080
FullscreenRefreshRate=50
ConfirmOnExit=0
TEDColorBrightness=750
TEDFilter=0
[VIC20]
FullscreenWidth=1920
FullscreenHeight=1080
FullscreenRefreshRate=50
ConfirmOnExit=0
VICColorBrightness=750
VICFilter=0
"@


##### WinUAE #####

if (need "winuae64.exe" -for winuae,all) {
    extract (download $URL_winuae) winuae64.exe
}
if (need "kickstart13.rom" -for winuae,all) {
    mv_f (download $URL_a500rom) kickstart13.rom
}
config "winuae.ini" -for winuae,all @"
[WinUAE]
ConfigFileFolder=
PathMode=WinUAE
RelativePaths=1
"@


##### TIC-80, MicroW8 #####

if (need "tic80.exe" -for tic80,all) {
    extract (download $URL_tic80) tic80.exe
}

if (need "uw8.exe" -for microw8,all) {
    extract (download $URL_microw8) microw8-windows/uw8.exe
}


##### FFmpeg and some other multimedia stuff #####

if (need "ffmpeg.exe" -for ffmpeg,capturinha,all) {
    collect_all (Join-Path (subdir_of (extract_temp (download $URL_ffmpeg))) bin)
    remove_temp
}
if (need "Capturinha.exe" -for capturinha,all) {
    extract (download $URL_capturinha) Capturinha.exe vcruntime140.dll vcruntime140_1.dll
}
if (need "youtube-dl.exe" -for youtube-dl) {
    mv_f (download $URL_youtube_dl) .
}
if (need "yt-dlp.exe" -for yt-dlp,music,all) {
    mv_f (download $URL_yt_dlp) .
}


##### Python #####

if (need "python/python.exe" -for python) {
    mv_f (extract_temp (download $URL_python)) python
}
config "python.cmd" -for python @"
@"%~dp0\python\python.exe" %*
"@


##### Background Music #####

if ($Packages -contains "music") {
    mkdir_s $musicDir
    $targetDir = $musicDir
    foreach ($line in (Get-Content (Join-Path $musicDir "download.txt"))) {
        # pre-parse the line
        $line = $line.Trim()
        if ((-not $line) -or $line.StartsWith("#") -or $line.StartsWith(";")) {
            continue  # empty line or comment
        }

        # subdirectory header?
        if ($line.StartsWith("[") -and $line.EndsWith("]")) {
            $targetDir = Join-Path $musicDir ($line.Substring(1, $line.Length - 2))
            mkdir_s $targetDir
            continue
        }

        # split line into "URL -> targetFile" tuple
        $x = $line -split "->" | % { $_.Trim() }
        if ($x.Count -gt 1) {
            $url, $targetFile = $x
        } else {
            $url = $line
            $targetFile = $null
        }

        # URLs may be relative to scene.org's party directory tree
        if (-not $url.Contains("://")) {
            $url = "http://archive.scene.org/pub/parties/" + $url
        }
        $dummy, $downloadFile = parse_url $url

        # perform special handling for SoundCloud links
        $ytdl = $false
        if ($url.Contains("soundcloud.com/")) { $ytdl = $true; $downloadFile += ".mp3" }
    
        # is the target already a music file?
        $archive = -not (is_music $downloadFile)
        if ((-not $archive) -and (-not $targetFile)) {
            $targetFile = $downloadFile
        }

        # is the target file already present?
        if ($targetFile -and (Test-Path -LiteralPath (Join-Path $targetDir $targetFile))) {
            continue
        }

        # not there yet -> download it
        pkgstatus "Downloading music ..."
        if ($ytdl) {
            status ("Downloading: " + $url)
            $downloadFile = Join-Path $cacheDir $downloadFile
            yt-dlp -f bestaudio -q -o $downloadFile $url
        } else {
            $downloadFile = download $url
        }
        if (-not $downloadFile) { continue }

        # if it's a music file, move it where it belongs and be done with it
        if (-not $archive) {
            mv_f $downloadFile (Join-Path $targetDir $targetFile)
            continue
        }

        # otherwise, search the archive
        $contents = archive_contents $downloadFile
        if (-not $contents) {
            error ("could not list contents of archive file " + $downloadFile)
            continue
        }

        # does anything there match the target file name?
        if ($targetFile) {
            $m = $targetFile.ToLower().Replace("\", "/")
            $extractFile = $contents | where { $_.ToLower().Replace("\", "/").Contains($m) } | select -First 1
        } else {
            $extractFile = $null
        }

        # no target file name match -> use any music file that matches
        if (-not $extractFile) {
           $extractFile = $contents | where { is_music $_ } | select -First 1
        }
        if (-not $extractFile) {
            error ($downloadFile + " does not contain any music files")
            continue
        }

        # build final file name
        $extractBase = Split-Path -Leaf $extractFile
        if (-not $targetFile) {
            $targetFile = $extractBase
        }
        $targetPath = Join-Path $targetDir $targetFile

        # final check: does the target already exist?
        if (Test-Path -LiteralPath $targetPath) {
            continue
        }
    
        # extract temporary file and move it into place
        status ("Extracting: " + $downloadFile + " -> " + $targetFile)
        7z -y e "-o$cacheDir" $downloadFile $extractFile > $null
        $extractPath = Join-Path $cacheDir $extractBase
        if (-not (Test-Path -LiteralPath $extractPath)) {
            error ("could not extract " + $extractFile + " from " + $downloadFile)
            continue
        }
        mv_f $extractPath $targetPath
    }   # end of music loop
}   # end of if ($Packages -contains music)


##### Done! #####

cd $baseDir
if (-not $global:_pkgstatuses) {
    Write-Host -ForegroundColor DarkGreen "Nothing to do."
} elseif ((-not $hadCache) -and (Test-Path $cacheDir)) {
    Write-Host -ForegroundColor Green "Everything set up. You can now delete the temp directory if you like:"
    Write-Host -ForegroundColor Green "   rmdir /s /q $cacheDir"
}
