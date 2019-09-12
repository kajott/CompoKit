# download URLs

# these are version dependent and may change often
$URL_7zip_main = "https://www.7-zip.org/a/7z1900-x64.exe"
$URL_totalcmd = "https://totalcommander.ch/win/tcmd922ax64.exe"
$URL_mpc_hc = "https://binaries.mpc-hc.org/MPC%20HomeCinema%20-%20x64/MPC-HC_v1.7.13_x64/MPC-HC.1.7.13.x64.7z"
$URL_xmplay = "http://uk.un4seen.com/files/xmplay38.zip"
$URL_libopenmpt = "https://lib.openmpt.org/files/libopenmpt/bin/libopenmpt-0.4.6+release.bin.win.zip"

# these are generic and not likely to change
$URL_7zip_bootstrap = "https://www.7-zip.org/a/7za920.zip"
$URL_xmp_sid = "https://bitbucket.org/ssz/public-files/downloads/xmp-sid.zip"
$URL_xmp_ahx = "https://bitbucket.org/ssz/public-files/downloads/xmp-ahx.zip"
$URL_xmp_ym = "https://www.un4seen.com/stuff/xmp-ym.zip"
$URL_xnview = "https://download.xnview.com/XnView-win-small.zip"
$URL_compoview = "https://files.scene.org/get:nl-http/resources/graphics/compoview_v1_02b.zip"
$URL_gliss = "https://www.emphy.de/~mfie/foo/gliss_new.exe|gliss.exe"

# a note about the URLs above:
# if a suitable download file name isn't derivable from the URL,
# it can be specified manually by appending it after a pipe sign ('|')

###############################################################################

# setup and helper functions

# set up directories
$baseDir = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$cacheDir = Join-Path $baseDir "temp"
$tempDir = Join-Path $cacheDir "temp_extract"
$binDir = Join-Path $baseDir "bin"
cd $baseDir

# add the bin directory to the PATH while we're working on it
if (-not ($env:Path).Contains($binDir)) {
    Set-Item -Path Env:Path -Value ($binDir + ";" + $Env:Path)
}

# check if a file or directory doesn't already exist
function needed($obj) {
    return -not (Test-Path $obj)
}

# write a status message
function status($msg) {
    Write-Host -ForegroundColor DarkCyan $msg
}

# create a directory if it doesn't exist
function mkdir_s($dir) {
    if (needed($dir)) {
        status ("Creating Directory: " + $dir)
        mkdir $dir > $null
    }
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

# download a file into the temp directory and return its path
function download($url) {
    mkdir_s $cacheDir
    $parts = $url.split("|")
    if ($parts.Count -gt 1) {
        $url = $parts[0]
        $filename = $parts[-1]
    }
    else {
        $filename = $url.split("?")[0].split("#")[0].trim("/").split("/")[-1]
    }
    $filename = Join-Path $cacheDir $filename
    if (needed($filename)) {
        status ("Downloading: " + $url)
        (New-Object System.Net.WebClient).DownloadFile($url, $filename)
    }
    return $filename
}

# extract (specific files from) an archive, disregarding paths
function extract {
    Param(
        [string] $archive,
        [parameter(ValueFromRemainingArguments=$true)] [string[]] $args
    )
    status ("Extracting: " + $archive)
    7z -y e $archive @args > $null
}

# extract an archive into a temporary directory and return its path
function extract_temp($archive) {
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
        if (-not (Test-Path (Join-Path $targetDir $item))) {
            mv $item $targetDir
        }
    }
    cd $targetDir
}

# create a text file with specific content (if it doesn't exist already)
function config($filename, $contents="") {
    if (needed($filename)) {
        status ("Creating File: " + $filename)
        New-Item -Name $filename -Value $contents > $null
    }
}

###############################################################################

# populate the bin directory
mkdir_s $binDir
cd $binDir


##### 7-zip #####

if (needed("7z.exe")) {
    # bootstrapping: download the old 9.20 x86 executable first;
    # it's the only one that comes in .zip format and can be extracted
    # by PowerShell itself
    $f = download $URL_7zip_bootstrap
    status("Extracting: " + $f)
    Expand-Archive -Path $f -DestinationPath . > $null
    rm @("7-zip.chm", "license.txt", "readme.txt")  # remove unwanted stuff

    # now we can download the current version
    extract (download $URL_7zip_main) 7z.dll 7z.exe 7zFM.exe 7zG.exe
    rm "7za.exe"  # we don't need the old standalone version any longer
}


##### Total Commander #####

if (needed("totalcmd64.exe")) {
    # tcmd's download file is an installer that contains a .cab file
    # with the actual data; thus we need to extract the .cab first
    $cab = Join-Path $cacheDir "tcmd.cab"
    if (needed($cab)) {
        cd $cacheDir
        extract (download $URL_totalcmd) INSTALL.CAB
        mv INSTALL.CAB $cab
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
    foreach ($f in $tcfiles) { mv $f $f.ToLower() }
}
config "wincmd.ini" @"
[Configuration]
UseIniInProgramDir=7
UseNewDefFont=1
FirstTime=0
FirstTimeIconLib=0
ShowHiddenSystem=1
UseTrash=0
AltSearch=3
[AllResolutions]
FontName=Fixedsys
FontSize=9
FontWeight=400
FontNameWindow=Fixedsys
FontSizeWindow=9
FontWeightWindow=400
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
config "wcx_ftp.ini" @"
[default]
pasvmode=1
"@


##### MPC-HC #####

if (needed("mpc-hc64.exe")) {
    collect (subdir_of (extract_temp (download $URL_mpc_hc))) @(
        "LAVFilters64", "Shaders",
        "D3DCompiler_43.dll", "d3dx9_43.dll",
        "mpc-hc64.exe"
    )
    remove_temp
}
config "mpc-hc64.ini" @"
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


##### XMPlay #####

if (needed("xmplay.exe")) {
    extract (download $URL_xmplay) xmplay.exe xmp-zip.dll xmp-wma.dll
}
if (needed("xmp-openmpt.dll")) {
    extract (download $URL_libopenmpt) XMPlay/openmpt-mpg123.dll XMPlay/xmp-openmpt.dll
}
if (needed("xmp-sid.dll")) {
    extract (download $URL_xmp_sid) xmp-sid.dll
}
if (needed("xmp-ahx.dll")) {
    extract (download $URL_xmp_ahx) xmp-ahx.dll
}
if (needed("xmp-ym.dll")) {
    extract (download $URL_xmp_ym) xmp-ym.dll
}
config "xmplay.ini" @"
[XMPlay]
PluginTypes=786D702D6F70656E6D70742E646C6C006D6F6420786D20697400
MODmode=2
InfoTextSize=3
Info=-2147220736
[SID_27]
config=00FF70FF7F095000002C018813B80B1932
"@


##### XnView #####

if (needed("xnview.exe")) {
    extract (download $URL_xnview) XnView/xnview.exe XnView/xnview.exe.manifest
}
config "xnview.ini" @"
[Cache]
SavingMode=1
[Start]
ParamsSavingMode=1
SavingMode=1
BToolBar=0
VToolBar=0
TabBar=0
LaunchTimes=1
ShowAgain=268435423
ENTER=0
MMB=2
Only1ESC=0
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
[Cache]
IsActive=0
[Full]
UseDelay=0
[File]
LosslessBak=0
"@


##### CompoView, GLISS #####

if (needed("compoview_64.exe")) {
    extract (download $URL_compoview) compoview/compoview_64.exe
}
if (needed("gliss.exe")) {
    mv (download $URL_gliss) .
}
