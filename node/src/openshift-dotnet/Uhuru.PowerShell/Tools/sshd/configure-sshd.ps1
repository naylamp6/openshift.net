param (
    $targetDirectory = $( Read-Host "Path to target sshd installation dir (c:\cygwin\installation\)" ),
    $user = $( Read-Host "Username that will have access to the server (administrator)" ),
    $windowsUser = $( Read-Host "Corresponding Windows user (administrator)" ),
    $userHomeDir = $( Read-Host "User home directory (c:\cygwin\administrator_home)" ),
    $userShell = $( Read-Host "User's shell (/bin/bash)" )
)

$currentDir = split-path $SCRIPT:MyInvocation.MyCommand.Path -parent
Import-Module (Join-Path $currentDir '..\..\common\openshift-common.psd1') -DisableNameChecking

$targetDirectory = Get-NotEmpty $targetDirectory "c:\cygwin\installation\"
$user = Get-NotEmpty $user "administrator"
$windowsUser = Get-NotEmpty $windowsUser "administrator"
$userHomeDir = Get-NotEmpty $userHomeDir "c:\cygwin\administrator_home"
$userShell = Get-NotEmpty $userShell "/bin/bash"

Write-Host 'Using installation dir: ' -NoNewline
Write-Host $targetDirectory -ForegroundColor Yellow

$sshdBinary = Join-Path $targetDirectory 'usr\sbin\sshd.exe'
$cygpathBinary = Join-Path $targetDirectory 'bin\cygpath.exe'
$chmodBinary = Join-Path $targetDirectory 'bin\chmod.exe'
$passwdFile = Join-Path $targetDirectory 'etc\passwd'

if (((Test-Path $sshdBinary) -ne $true) -or ((Test-Path $cygpathBinary) -ne $true) -or ((Test-Path $chmodBinary) -ne $true))
{
   Write-Host "Could not find necessary binaries in '$targetDirectory'. Aborting." -ForegroundColor Red
   exit 1
}

try
{
    $objUser = New-Object System.Security.Principal.NTAccount($windowsUser)
    $strSID = $objUser.Translate([System.Security.Principal.SecurityIdentifier])
    $userSID = $strSID.Value
}
catch
{
    Write-Host "Could not get SID for user '$windowsUser'. Aborting." -ForegroundColor Red
    exit 1
}

$usersGroupSID = Get-NoneGroupSID

Write-Host "Creating user home directory ..."
mkdir -Path $userHomeDir -ErrorAction SilentlyContinue > $null

Write-Host "Setting up empty 'authorized_keys' file ..."

$sshDir = Join-Path $userHomeDir '.ssh'
$authorized_keys = Join-Path $sshDir 'authorized_keys'

if ((Test-Path $authorized_keys) -eq $false)
{
    mkdir -Path $sshDir -ErrorAction SilentlyContinue > $null
    echo '' | Out-File $authorized_keys -Encoding Ascii
}

$keysFileLinux = & $cygpathBinary $authorized_keys
& $chmodBinary 600 $keysFileLinux

Write-Host "Setting up user in passwd file ..."
$uid = $userSID.Split('-')[-1]
$gid = $usersGroupSID.Split('-')[-1]
$userHomeDirLinux = & $cygpathBinary $userHomeDir

$userShell = & $cygpathBinary $userShell

Add-Content $passwdFile "${user}:unused:${uid}:${gid}:${windowsUser},${userSID}:${userHomeDirLinux}:${userShell}"

Write-Host "Setting up user as owner of his home dir ..."

Set-Owner $windowsUser $userHomeDir
