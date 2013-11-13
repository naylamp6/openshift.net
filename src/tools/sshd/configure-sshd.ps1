param (
    $targetDirectory = $( Read-Host "Path to target sshd installation dir (c:\cygwin\installation\)" ),
    $listenAddress = $( Read-Host "Interface to listen on (0.0.0.0)" ),
    $port = $( Read-Host "Port to listen on (22)" ),
    $user = $( Read-Host "Username that will have access to the server (administrator)" ),
    $windowsUser = $( Read-Host "Corresponding Windows user (administrator)" ),
    $userHomeDir = $( Read-Host "User home directory (c:\cygwin\administrator_home)" )
)

$currentDir = split-path $SCRIPT:MyInvocation.MyCommand.Path -parent
Import-Module (Join-Path $currentDir '..\..\powershell_common\openshift-common.psm1')

$targetDirectory = Get-NotEmpty $targetDirectory "c:\cygwin\installation\"
$listenAddress = Get-NotEmpty $listenAddress "0.0.0.0"
$port = Get-NotEmpty $port "22"
$user = Get-NotEmpty $user "administrator"
$windowsUser = Get-NotEmpty $windowsUser "administrator"
$userHomeDir = Get-NotEmpty $userHomeDir "c:\cygwin\administrator_home"

Write-Host 'Using installation dir: ' -NoNewline
Write-Host $targetDirectory -ForegroundColor Yellow

$sshdBinary = Join-Path $targetDirectory 'usr\sbin\sshd.exe'
$keygenBinary = Join-Path $targetDirectory 'bin\ssh-keygen.exe'
$cygpathBinary = Join-Path $targetDirectory 'bin\cygpath.exe'
$passwdFile = Join-Path $targetDirectory 'etc\passwd'
$chown = Join-Path $targetDirectory 'bin\chown.exe'

if (((Test-Path $sshdBinary) -ne $true) -or ((Test-Path $keygenBinary) -ne $true) -or ((Test-Path $cygpathBinary) -ne $true))
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

Write-Host "Creating host keys ..."

$sshdEtc = Join-Path $userHomeDir '.sshd_etc'

mkdir -Path $sshdEtc -ErrorAction SilentlyContinue > $null

$rsaKeyFile = Join-Path $sshdEtc 'ssh_host_rsa_key'
$dsaKeyFile = Join-Path $sshdEtc 'ssh_host_dsa_key'
$ecdsaKeyFile = Join-Path $sshdEtc 'ssh_host_ecdsa_key'

rm $rsaKeyFile -Force -ErrorAction SilentlyContinue > $null
rm $dsaKeyFile -Force -ErrorAction SilentlyContinue > $null
rm $ecdsaKeyFile -Force -ErrorAction SilentlyContinue > $null

$env:CYGWIN = 'nodosfilewarning'

Write-Host "Creating RSA key ..."
Start-Process $keygenBinary "-t rsa -q -f '$rsaKeyFile' -C '' -N ''" -NoNewWindow
Write-Host "Creating DSA key ..."
Start-Process $keygenBinary "-t dsa -q -f '$dsaKeyFile' -C '' -N ''" -NoNewWindow
Write-Host "Creating ECDSA key ..."
Start-Process $keygenBinary "-t ecdsa -q -f '$ecdsaKeyFile' -C '' -N ''" -NoNewWindow

Write-Host "Host keys created." -ForegroundColor Green 

Write-Host "Configuring sshd ..."

Write-Template (Join-Path $currentDir 'sshd_config.template') (Join-Path $sshdEtc 'sshd_config') {
    $rsaKeyLinuxPath = & $cygpathBinary $rsaKeyFile
    $dsaKeyLinuxPath = & $cygpathBinary $dsaKeyFile
    $ecdsaLinuxPath = & $cygpathBinary $ecdsaKeyFile
} 

Write-Host "Setting up empty 'authorized_keys' file ..."

$sshDir = Join-Path $userHomeDir '.ssh'
$authorized_keys = Join-Path $sshDir 'authorized_keys'

if ((Test-Path $authorized_keys) -eq $false)
{
    mkdir -Path $sshDir -ErrorAction SilentlyContinue > $null
    echo '' | Out-File $authorized_keys -Encoding Ascii
}

Write-Host "Setting up user in passwd file ..."
$uid = $userSID.Split('-')[-1]
$gid = $usersGroupSID.Split('-')[-1]
$userHomeDirLinux = & $cygpathBinary $userHomeDir

Add-Content $passwdFile "`n${user}:unused:${uid}:${gid}:${windowsUser},${userSID}:${userHomeDirLinux}:/bin/bash"

Write-Host "Setting up user as owner of his home dir ..."

Set-Owner $windowsUser $userHomeDir
