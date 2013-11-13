Set-StrictMode -Version 3

$currentDir = split-path $SCRIPT:MyInvocation.MyCommand.Path -parent

. (Join-Path $currentDir "template-mechanism.ps1")
. (Join-Path $currentDir "cygwin-passwd.ps1")
. (Join-Path $currentDir "file-ownership.ps1")

function Get-NotEmpty($a, $b) 
{ 
    if ([string]::IsNullOrWhiteSpace($a)) 
    { 
        $b 
    } else 
    { 
        $a 
    }
}


Export-ModuleMember Write-Template
Export-ModuleMember Run-Template
Export-ModuleMember Get-NotEmpty
Export-ModuleMember Get-NoneGroupSID
Export-ModuleMember Get-SSHDUser
Export-ModuleMember Get-SSHDUsers
Export-ModuleMember Set-Owner