# download URLs

# these are version dependent and may change often
$URL_7zip_main = "https://www.7-zip.org/a/7z1900-x64.exe"

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
    rm 7za.exe  # we don't need the old standalone version any longer
}
