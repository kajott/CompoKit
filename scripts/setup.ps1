# download URLs

# these are version dependent and may change often
$URL_7zip_main = "https://www.7-zip.org/a/7z1900-x64.exe"
$URL_totalcmd = "https://totalcommander.ch/win/tcmd922ax64.exe"

# these are generic and not likely to change
$URL_7zip_bootstrap = "https://www.7-zip.org/a/7za920.zip"

###############################################################################

# setup and helper functions

# set up directories
$baseDir = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$tempDir = Join-Path $baseDir "temp"
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

# download a file into the temp directory and return its path
function download($url) {
    mkdir_s $tempDir
    $filename = Join-Path $tempDir $url.split("?")[0].split("#")[0].trim("/").split("/")[-1]
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
    $cab = Join-Path $tempDir "tcmd.cab"
    if (needed($cab)) {
        cd $tempDir
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
