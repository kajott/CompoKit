# download URLs

# these are version dependent and may change often
$URL_7zip_main = "https://www.7-zip.org/a/7z1900-x64.exe"
$URL_totalcmd = "https://totalcommander.ch/win/tcmd922ax64.exe"
$URL_mpc_hc = "https://binaries.mpc-hc.org/MPC%20HomeCinema%20-%20x64/MPC-HC_v1.7.13_x64/MPC-HC.1.7.13.x64.7z"

# these are generic and not likely to change
$URL_7zip_bootstrap = "https://www.7-zip.org/a/7za920.zip"

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
    $filename = Join-Path $cacheDir $url.split("?")[0].split("#")[0].trim("/").split("/")[-1]
    if (needed($filename)) {
        status ("Downloading: " + $url)
        (New-Object System.Net.WebClient).DownloadFile($url, $filename)
    }
    return $filename
}

# extract (specific files from) an archive
function extract {
    Param(
        [string]$archive,
        [parameter(ValueFromRemainingArguments = $true)]
        [string[]]$args
    )
    status ("Extracting: " + $archive)
    7z -y x $archive @args > $null
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

