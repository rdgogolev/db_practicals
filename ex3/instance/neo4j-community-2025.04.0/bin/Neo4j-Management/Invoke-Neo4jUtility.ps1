# Copyright (c) "Neo4j"
# Neo4j Sweden AB [https://neo4j.com]
#
# This file is part of Neo4j.
#
# Neo4j is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.


<#
.SYNOPSIS
Invokes various Neo4j Utilities

.DESCRIPTION
Invokes various Neo4j Utilities.  This is a generic utility function called by the external functions e.g. Admin

.PARAMETER Command
A string of the command to run.

.PARAMETER CommandArgs
Command line arguments to pass to the utility

.OUTPUTS
System.Int32
0 = Success
non-zero = an error occured

.NOTES
Only supported on version 4.x Neo4j Community and Enterprise Edition databases

.NOTES
This function is private to the powershell module

#>
function Invoke-Neo4jUtility
{
  [CmdletBinding(SupportsShouldProcess = $false,ConfirmImpact = 'Low')]
  param(
    [Parameter(Mandatory = $false,ValueFromPipeline = $false,Position = 0)]
    [string]$Command = ''

    ,[Parameter(Mandatory = $false,ValueFromRemainingArguments = $true)]
    [object[]]$CommandArgs = @()
  )

  begin
  {
  }

  process
  {
    # The powershell command line interpreter converts comma delimited strings into a System.Object[] array
    # Search the CommandArgs array and convert anything that's System.Object[] back to a string type
    for ($index = 0; $index -lt $CommandArgs.Length; $index++) {
      if ($CommandArgs[$index] -is [array]) {
        [string]$CommandArgs[$index] = $CommandArgs[$index] -join ','
      }
    }

    # Determine the Neo4j Home Directory.  Uses the NEO4J_HOME environment variable or a parent directory of this script
    $Neo4jHome = Get-Neo4jEnv 'NEO4J_HOME'
    if (($Neo4jHome -eq $null) -or (-not (Test-Path -Path $Neo4jHome))) {
      $Neo4jHome = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    }
    if ($Neo4jHome -eq $null) { throw "Could not determine the Neo4j home Directory.  Set the NEO4J_HOME environment variable and retry" }

    $GetJavaParams = @{}
    switch ($Command.Trim().ToLower())
    {
      "admintool" {
        Write-Verbose "Admintool command specified"
        $GetJavaParams = @{
          StartingClass = 'org.neo4j.server.startup.Neo4jAdminCommand';
        }
        break
      }
       "server" {
        Write-Verbose "Server command specified"
        $GetJavaParams = @{
          StartingClass = 'org.neo4j.server.startup.Neo4jCommand';
        }
        break
      }
      default {
        Write-Host "Unknown utility $Command"
        return 255
      }
    }

    # Generate the required Java invocation
    $JavaCMD = Get-Java -Neo4jHome $Neo4jHome @GetJavaParams
    if ($JavaCMD -eq $null) { throw 'Unable to locate Java' }

    $ShellArgs = $JavaCMD.args
    if ($ShellArgs -eq $null) { $ShellArgs = @() }

    # Parameters need to be wrapped in double quotes to avoid issues in case they contain spaces.
    # https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.management/start-process?view=powershell-7#parameters
    # https://github.com/PowerShell/PowerShell/issues/5576
    foreach ($CmdArg in $CommandArgs) {
      if ($CmdArg -match '^".*"$' -or $CmdArg -match "^'.*'$") {
        $ShellArgs += $CmdArg
      } else {
        $ShellArgs += "`"$CmdArg`""
      }
    }

    Write-Verbose "Starting neo4j utility using command line $($JavaCMD.java) $ShellArgs"
    $result = (Start-Process -FilePath $JavaCMD.java -ArgumentList $ShellArgs -Wait -NoNewWindow -Passthru -WorkingDirectory $Neo4jHome )
    return $result.exitCode
  }

  end
  {
  }
}

function Get-Java
{
  [CmdletBinding(SupportsShouldProcess = $false,ConfirmImpact = 'Low',DefaultParameterSetName = 'Default')]
  param(
    [string]$Neo4jHome = '',
    [string]$StartingClass
  )

  process
  {
    $javaPath = ''
    $javaCMD = ''

    $EnvJavaHome = Get-Neo4jEnv 'JAVA_HOME'

    # Is JAVA specified in an environment variable
    if (($javaPath -eq '') -and ($EnvJavaHome -ne $null))
    {
      $javaPath = $EnvJavaHome
    }

    # Attempt to find JDK in registry
    $regKey = 'Registry::HKLM\SOFTWARE\JavaSoft\JDK'
    if (($javaPath -eq '') -and (Test-Path -Path $regKey))
    {
      $regJavaVersion = ''
      try
      {
        $regJavaVersion = [string](Get-ItemProperty -Path $regKey -ErrorAction 'Stop').CurrentVersion
        if ($regJavaVersion -ne '')
        {
          $javaPath = [string](Get-ItemProperty -Path "$regKey\$regJavaVersion" -ErrorAction 'Stop').JavaHome
        }
      }
      catch
      {
        #Ignore any errors
        $javaPath = ''
      }
    }

    # Attempt to find JRE in registry
    $regKey = 'Registry::HKLM\SOFTWARE\JavaSoft\JRE'
    if (($javaPath -eq '') -and (Test-Path -Path $regKey))
    {
      $regJavaVersion = ''
      try
      {
        $regJavaVersion = [string](Get-ItemProperty -Path $regKey -ErrorAction 'Stop').CurrentVersion
        if ($regJavaVersion -ne '')
        {
          $javaPath = [string](Get-ItemProperty -Path "$regKey\$regJavaVersion" -ErrorAction 'Stop').JavaHome
        }
      }
      catch
      {
        #Ignore any errors
        $javaPath = ''
      }
    }

    # Attempt to find JDK in registry (32bit JDK on 64bit OS)
    $regKey = 'Registry::HKLM\SOFTWARE\Wow6432Node\JavaSoft\JDK'
    if (($javaPath -eq '') -and (Test-Path -Path $regKey))
    {
      $regJavaVersion = ''
      try
      {
        $regJavaVersion = [string](Get-ItemProperty -Path $regKey -ErrorAction 'Stop').CurrentVersion
        if ($regJavaVersion -ne '')
        {
          $javaPath = [string](Get-ItemProperty -Path "$regKey\$regJavaVersion" -ErrorAction 'Stop').JavaHome
        }
      }
      catch
      {
        #Ignore any errors
        $javaPath = ''
      }
    }

    # Attempt to find JRE in registry (32bit JRE on 64bit OS)
    $regKey = 'Registry::HKLM\SOFTWARE\Wow6432Node\JavaSoft\JRE'
    if (($javaPath -eq '') -and (Test-Path -Path $regKey))
    {
      $regJavaVersion = ''
      try
      {
        $regJavaVersion = [string](Get-ItemProperty -Path $regKey -ErrorAction 'Stop').CurrentVersion
        if ($regJavaVersion -ne '')
        {
          $javaPath = [string](Get-ItemProperty -Path "$regKey\$regJavaVersion" -ErrorAction 'Stop').JavaHome
        }
      }
      catch
      {
        #Ignore any errors
        $javaPath = ''
      }
    }

    # Attempt to find Java in the search path
    if ($javaPath -eq '')
    {
      $javaExe = (Get-Command 'java.exe' -ErrorAction SilentlyContinue)
      if ($javaExe -ne $null)
      {
        $javaCMD = $javaExe.Path
        $javaPath = Split-Path -Path $javaCMD -Parent
      }
    }

    if ($javaPath -eq '') { Write-Error "Unable to determine the path to java.exe"; return $null }
    if ($javaCMD -eq '') { $javaCMD = "$javaPath\bin\java.exe" }
    if (-not (Test-Path -Path $javaCMD)) { Write-Error "Could not find java at $javaCMD"; return $null }

    Write-Verbose "Java detected at '$javaCMD'"

    # Shell arguments for the Neo4jServer
    $ShellArgs = @()
    $ClassPath = "$($Neo4jHome)/lib/*"
    $ShellArgs = @("-cp `"$($ClassPath)`"")
	  $ShellArgs += @("-Dbasedir=`"$Neo4jHome`"")
    $ShellArgs += @($StartingClass)
    Write-Output @{ 'java' = $javaCMD; 'args' = $ShellArgs }
  }
}

function Invoke-ExternalCommand
{
  [CmdletBinding(SupportsShouldProcess = $false,ConfirmImpact = 'Low')]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false,Position = 0)]
    [string]$Command = '',

    [Parameter(Mandatory = $false,ValueFromRemainingArguments = $true)]
    [Object[]]$CommandArgs = @()
  )

  process
  {
    # Merge Command and CommandArgs into a single array that each element
    # is checked against a space and surrounded with double quoates if
    # they are already not
    $ComSpecArgs = @()
    if ($Command -match ' ' -and -not ($Command -match '\".+\"'))
    {
      $ComSpecArgs += "`"$Command`""
    }
    else
    {
      $ComSpecArgs += $Command
    }

    foreach ($Arg in $CommandArgs)
    {
      if ($Arg -match ' ' -and -not ($Arg -match '\".+\"'))
      {
        $ComSpecArgs += "`"$Arg`""
      }
      else
      {
        $ComSpecArgs += $Arg
      }
    }
    $ComSpecArgs += "2>&1"

    Write-Verbose "Invoking $ComSpecArgs"
    # cmd.exe is a bit picky about its translation of command line arguments
    # to the actual command to be executed and this is the only one that
    # found to be running both on Windows 7 and Windows 10
    # /S is required not to transform contents of $ComSpecArgs and to be used 
    # as it is.
    $Output = & $env:ComSpec /S /C """ " $ComSpecArgs " """
    Write-Verbose "Command returned with exit code $LastExitCode"

    Write-Output @{ 'exitCode' = $LastExitCode; 'capturedOutput' = $Output }
  }
}

function Get-Neo4jEnv
{
  [CmdletBinding(SupportsShouldProcess = $false,ConfirmImpact = 'Low')]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false,Position = 0)]
    [string]$Name
  )

  process {
    Get-ChildItem -Path Env: |
    Where-Object { $_.Name.ToUpper() -eq $Name.ToUpper() } |
    Select-Object -First 1 |
    ForEach-Object { $_.value }
  }
}

# SIG # Begin signature block
# MIInagYJKoZIhvcNAQcCoIInWzCCJ1cCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCC/szyZjVgtle8/
# eQRHJeC0+TMW2NpwZH82x3glqhGPQqCCIPYwggWNMIIEdaADAgECAhAOmxiO+dAt
# 5+/bUOIIQBhaMA0GCSqGSIb3DQEBDAUAMGUxCzAJBgNVBAYTAlVTMRUwEwYDVQQK
# EwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xJDAiBgNV
# BAMTG0RpZ2lDZXJ0IEFzc3VyZWQgSUQgUm9vdCBDQTAeFw0yMjA4MDEwMDAwMDBa
# Fw0zMTExMDkyMzU5NTlaMGIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2Vy
# dCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xITAfBgNVBAMTGERpZ2lD
# ZXJ0IFRydXN0ZWQgUm9vdCBHNDCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoC
# ggIBAL/mkHNo3rvkXUo8MCIwaTPswqclLskhPfKK2FnC4SmnPVirdprNrnsbhA3E
# MB/zG6Q4FutWxpdtHauyefLKEdLkX9YFPFIPUh/GnhWlfr6fqVcWWVVyr2iTcMKy
# unWZanMylNEQRBAu34LzB4TmdDttceItDBvuINXJIB1jKS3O7F5OyJP4IWGbNOsF
# xl7sWxq868nPzaw0QF+xembud8hIqGZXV59UWI4MK7dPpzDZVu7Ke13jrclPXuU1
# 5zHL2pNe3I6PgNq2kZhAkHnDeMe2scS1ahg4AxCN2NQ3pC4FfYj1gj4QkXCrVYJB
# MtfbBHMqbpEBfCFM1LyuGwN1XXhm2ToxRJozQL8I11pJpMLmqaBn3aQnvKFPObUR
# WBf3JFxGj2T3wWmIdph2PVldQnaHiZdpekjw4KISG2aadMreSx7nDmOu5tTvkpI6
# nj3cAORFJYm2mkQZK37AlLTSYW3rM9nF30sEAMx9HJXDj/chsrIRt7t/8tWMcCxB
# YKqxYxhElRp2Yn72gLD76GSmM9GJB+G9t+ZDpBi4pncB4Q+UDCEdslQpJYls5Q5S
# UUd0viastkF13nqsX40/ybzTQRESW+UQUOsxxcpyFiIJ33xMdT9j7CFfxCBRa2+x
# q4aLT8LWRV+dIPyhHsXAj6KxfgommfXkaS+YHS312amyHeUbAgMBAAGjggE6MIIB
# NjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBTs1+OC0nFdZEzfLmc/57qYrhwP
# TzAfBgNVHSMEGDAWgBRF66Kv9JLLgjEtUYunpyGd823IDzAOBgNVHQ8BAf8EBAMC
# AYYweQYIKwYBBQUHAQEEbTBrMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdp
# Y2VydC5jb20wQwYIKwYBBQUHMAKGN2h0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNv
# bS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcnQwRQYDVR0fBD4wPDA6oDigNoY0
# aHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENB
# LmNybDARBgNVHSAECjAIMAYGBFUdIAAwDQYJKoZIhvcNAQEMBQADggEBAHCgv0Nc
# Vec4X6CjdBs9thbX979XB72arKGHLOyFXqkauyL4hxppVCLtpIh3bb0aFPQTSnov
# Lbc47/T/gLn4offyct4kvFIDyE7QKt76LVbP+fT3rDB6mouyXtTP0UNEm0Mh65Zy
# oUi0mcudT6cGAxN3J0TU53/oWajwvy8LpunyNDzs9wPHh6jSTEAZNUZqaVSwuKFW
# juyk1T3osdz9HNj0d1pcVIxv76FQPfx2CWiEn2/K2yCNNWAcAgPLILCsWKAOQGPF
# mCLBsln1VWvPJ6tsds5vIy30fnFqI2si/xK4VC0nftg62fC2h5b9W9FcrBjDTZ9z
# twGpn1eqXijiuZQwggauMIIElqADAgECAhAHNje3JFR82Ees/ShmKl5bMA0GCSqG
# SIb3DQEBCwUAMGIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMx
# GTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xITAfBgNVBAMTGERpZ2lDZXJ0IFRy
# dXN0ZWQgUm9vdCBHNDAeFw0yMjAzMjMwMDAwMDBaFw0zNzAzMjIyMzU5NTlaMGMx
# CzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjE7MDkGA1UEAxMy
# RGlnaUNlcnQgVHJ1c3RlZCBHNCBSU0E0MDk2IFNIQTI1NiBUaW1lU3RhbXBpbmcg
# Q0EwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDGhjUGSbPBPXJJUVXH
# JQPE8pE3qZdRodbSg9GeTKJtoLDMg/la9hGhRBVCX6SI82j6ffOciQt/nR+eDzMf
# UBMLJnOWbfhXqAJ9/UO0hNoR8XOxs+4rgISKIhjf69o9xBd/qxkrPkLcZ47qUT3w
# 1lbU5ygt69OxtXXnHwZljZQp09nsad/ZkIdGAHvbREGJ3HxqV3rwN3mfXazL6IRk
# tFLydkf3YYMZ3V+0VAshaG43IbtArF+y3kp9zvU5EmfvDqVjbOSmxR3NNg1c1eYb
# qMFkdECnwHLFuk4fsbVYTXn+149zk6wsOeKlSNbwsDETqVcplicu9Yemj052FVUm
# cJgmf6AaRyBD40NjgHt1biclkJg6OBGz9vae5jtb7IHeIhTZgirHkr+g3uM+onP6
# 5x9abJTyUpURK1h0QCirc0PO30qhHGs4xSnzyqqWc0Jon7ZGs506o9UD4L/wojzK
# QtwYSH8UNM/STKvvmz3+DrhkKvp1KCRB7UK/BZxmSVJQ9FHzNklNiyDSLFc1eSuo
# 80VgvCONWPfcYd6T/jnA+bIwpUzX6ZhKWD7TA4j+s4/TXkt2ElGTyYwMO1uKIqjB
# Jgj5FBASA31fI7tk42PgpuE+9sJ0sj8eCXbsq11GdeJgo1gJASgADoRU7s7pXche
# MBK9Rp6103a50g5rmQzSM7TNsQIDAQABo4IBXTCCAVkwEgYDVR0TAQH/BAgwBgEB
# /wIBADAdBgNVHQ4EFgQUuhbZbU2FL3MpdpovdYxqII+eyG8wHwYDVR0jBBgwFoAU
# 7NfjgtJxXWRM3y5nP+e6mK4cD08wDgYDVR0PAQH/BAQDAgGGMBMGA1UdJQQMMAoG
# CCsGAQUFBwMIMHcGCCsGAQUFBwEBBGswaTAkBggrBgEFBQcwAYYYaHR0cDovL29j
# c3AuZGlnaWNlcnQuY29tMEEGCCsGAQUFBzAChjVodHRwOi8vY2FjZXJ0cy5kaWdp
# Y2VydC5jb20vRGlnaUNlcnRUcnVzdGVkUm9vdEc0LmNydDBDBgNVHR8EPDA6MDig
# NqA0hjJodHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkUm9v
# dEc0LmNybDAgBgNVHSAEGTAXMAgGBmeBDAEEAjALBglghkgBhv1sBwEwDQYJKoZI
# hvcNAQELBQADggIBAH1ZjsCTtm+YqUQiAX5m1tghQuGwGC4QTRPPMFPOvxj7x1Bd
# 4ksp+3CKDaopafxpwc8dB+k+YMjYC+VcW9dth/qEICU0MWfNthKWb8RQTGIdDAiC
# qBa9qVbPFXONASIlzpVpP0d3+3J0FNf/q0+KLHqrhc1DX+1gtqpPkWaeLJ7giqzl
# /Yy8ZCaHbJK9nXzQcAp876i8dU+6WvepELJd6f8oVInw1YpxdmXazPByoyP6wCeC
# RK6ZJxurJB4mwbfeKuv2nrF5mYGjVoarCkXJ38SNoOeY+/umnXKvxMfBwWpx2cYT
# gAnEtp/Nh4cku0+jSbl3ZpHxcpzpSwJSpzd+k1OsOx0ISQ+UzTl63f8lY5knLD0/
# a6fxZsNBzU+2QJshIUDQtxMkzdwdeDrknq3lNHGS1yZr5Dhzq6YBT70/O3itTK37
# xJV77QpfMzmHQXh6OOmc4d0j/R0o08f56PGYX/sr2H7yRp11LB4nLCbbbxV7HhmL
# NriT1ObyF5lZynDwN7+YAN8gFk8n+2BnFqFmut1VwDophrCYoCvtlUG3OtUVmDG0
# YgkPCr2B2RP+v6TR81fZvAT6gt4y3wSJ8ADNXcL50CN/AAvkdgIm2fBldkKmKYcJ
# RyvmfxqkhQ/8mJb2VVQrH4D6wPIOK+XW+6kvRBVK5xMOHds3OBqhK/bt1nz8MIIG
# sDCCBJigAwIBAgIQCK1AsmDSnEyfXs2pvZOu2TANBgkqhkiG9w0BAQwFADBiMQsw
# CQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cu
# ZGlnaWNlcnQuY29tMSEwHwYDVQQDExhEaWdpQ2VydCBUcnVzdGVkIFJvb3QgRzQw
# HhcNMjEwNDI5MDAwMDAwWhcNMzYwNDI4MjM1OTU5WjBpMQswCQYDVQQGEwJVUzEX
# MBUGA1UEChMORGlnaUNlcnQsIEluYy4xQTA/BgNVBAMTOERpZ2lDZXJ0IFRydXN0
# ZWQgRzQgQ29kZSBTaWduaW5nIFJTQTQwOTYgU0hBMzg0IDIwMjEgQ0ExMIICIjAN
# BgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA1bQvQtAorXi3XdU5WRuxiEL1M4zr
# PYGXcMW7xIUmMJ+kjmjYXPXrNCQH4UtP03hD9BfXHtr50tVnGlJPDqFX/IiZwZHM
# gQM+TXAkZLON4gh9NH1MgFcSa0OamfLFOx/y78tHWhOmTLMBICXzENOLsvsI8Irg
# nQnAZaf6mIBJNYc9URnokCF4RS6hnyzhGMIazMXuk0lwQjKP+8bqHPNlaJGiTUyC
# EUhSaN4QvRRXXegYE2XFf7JPhSxIpFaENdb5LpyqABXRN/4aBpTCfMjqGzLmysL0
# p6MDDnSlrzm2q2AS4+jWufcx4dyt5Big2MEjR0ezoQ9uo6ttmAaDG7dqZy3SvUQa
# khCBj7A7CdfHmzJawv9qYFSLScGT7eG0XOBv6yb5jNWy+TgQ5urOkfW+0/tvk2E0
# XLyTRSiDNipmKF+wc86LJiUGsoPUXPYVGUztYuBeM/Lo6OwKp7ADK5GyNnm+960I
# HnWmZcy740hQ83eRGv7bUKJGyGFYmPV8AhY8gyitOYbs1LcNU9D4R+Z1MI3sMJN2
# FKZbS110YU0/EpF23r9Yy3IQKUHw1cVtJnZoEUETWJrcJisB9IlNWdt4z4FKPkBH
# X8mBUHOFECMhWWCKZFTBzCEa6DgZfGYczXg4RTCZT/9jT0y7qg0IU0F8WD1Hs/q2
# 7IwyCQLMbDwMVhECAwEAAaOCAVkwggFVMBIGA1UdEwEB/wQIMAYBAf8CAQAwHQYD
# VR0OBBYEFGg34Ou2O/hfEYb7/mF7CIhl9E5CMB8GA1UdIwQYMBaAFOzX44LScV1k
# TN8uZz/nupiuHA9PMA4GA1UdDwEB/wQEAwIBhjATBgNVHSUEDDAKBggrBgEFBQcD
# AzB3BggrBgEFBQcBAQRrMGkwJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2lj
# ZXJ0LmNvbTBBBggrBgEFBQcwAoY1aHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29t
# L0RpZ2lDZXJ0VHJ1c3RlZFJvb3RHNC5jcnQwQwYDVR0fBDwwOjA4oDagNIYyaHR0
# cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZFJvb3RHNC5jcmww
# HAYDVR0gBBUwEzAHBgVngQwBAzAIBgZngQwBBAEwDQYJKoZIhvcNAQEMBQADggIB
# ADojRD2NCHbuj7w6mdNW4AIapfhINPMstuZ0ZveUcrEAyq9sMCcTEp6QRJ9L/Z6j
# fCbVN7w6XUhtldU/SfQnuxaBRVD9nL22heB2fjdxyyL3WqqQz/WTauPrINHVUHmI
# moqKwba9oUgYftzYgBoRGRjNYZmBVvbJ43bnxOQbX0P4PpT/djk9ntSZz0rdKOtf
# JqGVWEjVGv7XJz/9kNF2ht0csGBc8w2o7uCJob054ThO2m67Np375SFTWsPK6Wrx
# oj7bQ7gzyE84FJKZ9d3OVG3ZXQIUH0AzfAPilbLCIXVzUstG2MQ0HKKlS43Nb3Y3
# LIU/Gs4m6Ri+kAewQ3+ViCCCcPDMyu/9KTVcH4k4Vfc3iosJocsL6TEa/y4ZXDlx
# 4b6cpwoG1iZnt5LmTl/eeqxJzy6kdJKt2zyknIYf48FWGysj/4+16oh7cGvmoLr9
# Oj9FpsToFpFSi0HASIRLlk2rREDjjfAVKM7t8RhWByovEMQMCGQ8M4+uKIw8y4+I
# Cw2/O/TOHnuO77Xry7fwdxPm5yg/rBKupS8ibEH5glwVZsxsDsrFhsP2JjMMB0ug
# 0wcCampAMEhLNKhRILutG4UI4lkNbcoFUCvqShyepf2gpx8GdOfy1lKQ/a+FSCH5
# Vzu0nAPthkX0tGFuv2jiJmCG6sivqf6UHedjGzqGVnhOMIIGvDCCBKSgAwIBAgIQ
# C65mvFq6f5WHxvnpBOMzBDANBgkqhkiG9w0BAQsFADBjMQswCQYDVQQGEwJVUzEX
# MBUGA1UEChMORGlnaUNlcnQsIEluYy4xOzA5BgNVBAMTMkRpZ2lDZXJ0IFRydXN0
# ZWQgRzQgUlNBNDA5NiBTSEEyNTYgVGltZVN0YW1waW5nIENBMB4XDTI0MDkyNjAw
# MDAwMFoXDTM1MTEyNTIzNTk1OVowQjELMAkGA1UEBhMCVVMxETAPBgNVBAoTCERp
# Z2lDZXJ0MSAwHgYDVQQDExdEaWdpQ2VydCBUaW1lc3RhbXAgMjAyNDCCAiIwDQYJ
# KoZIhvcNAQEBBQADggIPADCCAgoCggIBAL5qc5/2lSGrljC6W23mWaO16P2RHxjE
# iDtqmeOlwf0KMCBDEr4IxHRGd7+L660x5XltSVhhK64zi9CeC9B6lUdXM0s71EOc
# Re8+CEJp+3R2O8oo76EO7o5tLuslxdr9Qq82aKcpA9O//X6QE+AcaU/byaCagLD/
# GLoUb35SfWHh43rOH3bpLEx7pZ7avVnpUVmPvkxT8c2a2yC0WMp8hMu60tZR0Cha
# V76Nhnj37DEYTX9ReNZ8hIOYe4jl7/r419CvEYVIrH6sN00yx49boUuumF9i2T8U
# uKGn9966fR5X6kgXj3o5WHhHVO+NBikDO0mlUh902wS/Eeh8F/UFaRp1z5SnROHw
# SJ+QQRZ1fisD8UTVDSupWJNstVkiqLq+ISTdEjJKGjVfIcsgA4l9cbk8Smlzddh4
# EfvFrpVNnes4c16Jidj5XiPVdsn5n10jxmGpxoMc6iPkoaDhi6JjHd5ibfdp5uzI
# Xp4P0wXkgNs+CO/CacBqU0R4k+8h6gYldp4FCMgrXdKWfM4N0u25OEAuEa3Jyidx
# W48jwBqIJqImd93NRxvd1aepSeNeREXAu2xUDEW8aqzFQDYmr9ZONuc2MhTMizch
# NULpUEoA6Vva7b1XCB+1rxvbKmLqfY/M/SdV6mwWTyeVy5Z/JkvMFpnQy5wR14GJ
# cv6dQ4aEKOX5AgMBAAGjggGLMIIBhzAOBgNVHQ8BAf8EBAMCB4AwDAYDVR0TAQH/
# BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAgBgNVHSAEGTAXMAgGBmeBDAEE
# AjALBglghkgBhv1sBwEwHwYDVR0jBBgwFoAUuhbZbU2FL3MpdpovdYxqII+eyG8w
# HQYDVR0OBBYEFJ9XLAN3DigVkGalY17uT5IfdqBbMFoGA1UdHwRTMFEwT6BNoEuG
# SWh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRHNFJTQTQw
# OTZTSEEyNTZUaW1lU3RhbXBpbmdDQS5jcmwwgZAGCCsGAQUFBwEBBIGDMIGAMCQG
# CCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wWAYIKwYBBQUHMAKG
# TGh0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRHNFJT
# QTQwOTZTSEEyNTZUaW1lU3RhbXBpbmdDQS5jcnQwDQYJKoZIhvcNAQELBQADggIB
# AD2tHh92mVvjOIQSR9lDkfYR25tOCB3RKE/P09x7gUsmXqt40ouRl3lj+8QioVYq
# 3igpwrPvBmZdrlWBb0HvqT00nFSXgmUrDKNSQqGTdpjHsPy+LaalTW0qVjvUBhcH
# zBMutB6HzeledbDCzFzUy34VarPnvIWrqVogK0qM8gJhh/+qDEAIdO/KkYesLyTV
# OoJ4eTq7gj9UFAL1UruJKlTnCVaM2UeUUW/8z3fvjxhN6hdT98Vr2FYlCS7Mbb4H
# v5swO+aAXxWUm3WpByXtgVQxiBlTVYzqfLDbe9PpBKDBfk+rabTFDZXoUke7zPgt
# d7/fvWTlCs30VAGEsshJmLbJ6ZbQ/xll/HjO9JbNVekBv2Tgem+mLptR7yIrpaid
# RJXrI+UzB6vAlk/8a1u7cIqV0yef4uaZFORNekUgQHTqddmsPCEIYQP7xGxZBIhd
# mm4bhYsVA6G2WgNFYagLDBzpmk9104WQzYuVNsxyoVLObhx3RugaEGru+SojW4dH
# PoWrUhftNpFC5H7QEY7MhKRyrBe7ucykW7eaCuWBsBb4HOKRFVDcrZgdwaSIqMDi
# CLg4D+TPVgKx2EgEdeoHNHT9l3ZDBD+XgbF+23/zBjeCtxz+dL/9NWR6P2eZRi7z
# cEO1xwcdcqJsyz/JceENc2Sg8h3KeFUCS7tpFk7CrDqkMIIHOzCCBSOgAwIBAgIQ
# CNezVplzvr4IEkTYn0fO/TANBgkqhkiG9w0BAQsFADBpMQswCQYDVQQGEwJVUzEX
# MBUGA1UEChMORGlnaUNlcnQsIEluYy4xQTA/BgNVBAMTOERpZ2lDZXJ0IFRydXN0
# ZWQgRzQgQ29kZSBTaWduaW5nIFJTQTQwOTYgU0hBMzg0IDIwMjEgQ0ExMB4XDTI0
# MDkwMzAwMDAwMFoXDTI1MTIwMjIzNTk1OVowgcMxEzARBgsrBgEEAYI3PAIBAxMC
# VVMxGTAXBgsrBgEEAYI3PAIBAhMIRGVsYXdhcmUxHTAbBgNVBA8MFFByaXZhdGUg
# T3JnYW5pemF0aW9uMRAwDgYDVQQFEwc1MDA3NTY0MQswCQYDVQQGEwJVUzETMBEG
# A1UECBMKQ2FsaWZvcm5pYTESMBAGA1UEBxMJU2FuIE1hdGVvMRQwEgYDVQQKEwtO
# ZW80aiwgSW5jLjEUMBIGA1UEAxMLTmVvNGosIEluYy4wggGiMA0GCSqGSIb3DQEB
# AQUAA4IBjwAwggGKAoIBgQDU9BVLGb4ZJbftCD9CCPu3XGy/JY52KJMFEVgGWV4w
# /H0Eg2kf4/xWPrIFh1JkiTCAzhwpmMdrIxSUkBq+1vinN2tDfy8VY/u8RWCAQ8Tv
# BapZn9cwXxf8L306zUh8plhRMpCFS3CrJVVA0qfm0DaO0Rhbjd5MDz/Aj2VuJOcM
# y83bJxWUu5zCGpx7vwaPjoV5ESXX1eaoX1bC+pmdlmZdp5N1s5c81GmzLvlzazd8
# DwBVqY5o4vEi2W3A8jmVrfJaubUkf+qsA2Uclupp0lDbx3Ht7LrxCgZ0KgWmwaqv
# 2nC6hmTQrhIqlQC2FLx48M7da2K4p09D1itWuauEVslWH7id6e6JbpmVYfD5hfMQ
# OXoNGOP4XMc34aIStbcSwcPYNKMu8tyAhir7L7JmgquMAmmG7juAoJHkgLpaZPid
# /jqQoG2kJzt6kC70X1FJXGjGsl6aATiBhEhOP59yenaQ+JukwLAOWq7s2kUdBqEn
# CpeNeu4B4m19WMfG46353G8CAwEAAaOCAgIwggH+MB8GA1UdIwQYMBaAFGg34Ou2
# O/hfEYb7/mF7CIhl9E5CMB0GA1UdDgQWBBRHf5d9ChMYqzWs/7n6SLsBjD8c7jA9
# BgNVHSAENjA0MDIGBWeBDAEDMCkwJwYIKwYBBQUHAgEWG2h0dHA6Ly93d3cuZGln
# aWNlcnQuY29tL0NQUzAOBgNVHQ8BAf8EBAMCB4AwEwYDVR0lBAwwCgYIKwYBBQUH
# AwMwgbUGA1UdHwSBrTCBqjBToFGgT4ZNaHR0cDovL2NybDMuZGlnaWNlcnQuY29t
# L0RpZ2lDZXJ0VHJ1c3RlZEc0Q29kZVNpZ25pbmdSU0E0MDk2U0hBMzg0MjAyMUNB
# MS5jcmwwU6BRoE+GTWh0dHA6Ly9jcmw0LmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRy
# dXN0ZWRHNENvZGVTaWduaW5nUlNBNDA5NlNIQTM4NDIwMjFDQTEuY3JsMIGUBggr
# BgEFBQcBAQSBhzCBhDAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQu
# Y29tMFwGCCsGAQUFBzAChlBodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGln
# aUNlcnRUcnVzdGVkRzRDb2RlU2lnbmluZ1JTQTQwOTZTSEEzODQyMDIxQ0ExLmNy
# dDAJBgNVHRMEAjAAMA0GCSqGSIb3DQEBCwUAA4ICAQB20+Psman8GIP8YyGCn7MY
# zN7APgla/xwN4/KztW/HGk3325EOHbO61f+5iRsvjdEJAZDalwVjUTYS6mf/6tPY
# JAIGSyvuZnNK3VxXsLdFSLT66CWH0y8S1r0JFfJbUBIfWmINmS0+/1YFAiLxCkUS
# GXkHpP2PdHj3n4N67IYNV3y81e0BSPzYewXlBrum78GB8aoESUXIKUSn/wuIPDRo
# lxZFp53ZMNV21ozdcp752MmmA8Gk7iD7r+QFEX/rthxq6yJssaMWjGxMmBzIkNeW
# aXyyrOsYCK3SZBpTK3Qfg0Gj26VJyE4WgaIyIvnVI+WIrlRCODLqniqyRKlyRSoa
# 62qkFdHfL6so5NSy2zlZ68FeO3PF5MgjL16wWWs1pVFSxr61nmdVF2e+umH9/Pon
# dGepLA8amo5eJrUL9/HTdIEBuTq4i/1m782sQmgO5bAjR6l1Dz67dDhv6guSnKJL
# dW7uTO0fVkTMOKFJ5F9kWZi7LabSQ1Qvvuo+RTLTub28UGLAhSkaz3K2vDxC6MUd
# LyzsDpL3z5MiOLkNsgxXNKgfKlbD21FEJdIAeeJJYA3opCcZTq6DHyDWHoAZMAbO
# th4sn9nHhi/TYApvTJFD6H/Zoa+3nsdTvyCCpUTec9U4VesvLcwBXrKXGq73j8eT
# a6fs66An3YhisKEb9mneRTGCBcowggXGAgEBMH0waTELMAkGA1UEBhMCVVMxFzAV
# BgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMUEwPwYDVQQDEzhEaWdpQ2VydCBUcnVzdGVk
# IEc0IENvZGUgU2lnbmluZyBSU0E0MDk2IFNIQTM4NCAyMDIxIENBMQIQCNezVplz
# vr4IEkTYn0fO/TANBglghkgBZQMEAgEFAKB8MBAGCisGAQQBgjcCAQwxAjAAMBkG
# CSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQBgjcCAQsxDjAMBgorBgEE
# AYI3AgEVMC8GCSqGSIb3DQEJBDEiBCDAVgeWCz587DrrIwCP2j/W7+xmYMv5J61i
# uVZXN3IWQDANBgkqhkiG9w0BAQEFAASCAYB6wK1gA84VClj29zSlmQYZcI936lq4
# /TWOwBkPQt0E8/bzAKnBS+ZUWGK3tgsMNDjObjz1gGrHb+97MFwm2jzo6/kt+8jM
# evlrdWf9WXFbvJAoHGGainwHOJjQKV3mxxKupGOMn0yyJuOD8+TX0WVoPVqlHzdo
# 2YGnbe626o1viBDurlUS3GPl/WnGN7QEQ/3QZz8/EUiWhzHRVBE75fVmnqlnixM6
# cdp4gS3i0aZJZViFHK+e29r92CU2UGOx5odZ2Dhz2xnXCj3mH5H7cP1tEqjO603F
# nozx0nkPLvwxUUJwFFwyhElbZqupONtbFVTOceSUSWNivzhRgNCqgP5jl5vVDewS
# bv93S8e2CcbHTmKGufnmBGGE5smuQN6s6JqWvAxx2bFGO7AdAPbGgrmYkVMyzZKV
# nDDsbKLzz5mswrGfFs+tB1waweUEz+ISRbHleWGgBSt8vzGC6eeDQH4+Pu/8kug1
# d0xxF5IvA92cFHGkzQ5HG9uGA+ZMQNn7sh2hggMgMIIDHAYJKoZIhvcNAQkGMYID
# DTCCAwkCAQEwdzBjMQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIElu
# Yy4xOzA5BgNVBAMTMkRpZ2lDZXJ0IFRydXN0ZWQgRzQgUlNBNDA5NiBTSEEyNTYg
# VGltZVN0YW1waW5nIENBAhALrma8Wrp/lYfG+ekE4zMEMA0GCWCGSAFlAwQCAQUA
# oGkwGAYJKoZIhvcNAQkDMQsGCSqGSIb3DQEHATAcBgkqhkiG9w0BCQUxDxcNMjUw
# NDI0MjAzMDE0WjAvBgkqhkiG9w0BCQQxIgQgF0i21uZjk8D9OQhn4QnIN6LBsztf
# 43oLXb1k81sHm6kwDQYJKoZIhvcNAQEBBQAEggIAsmsjPcXR14cKYOQHyTt5J2iD
# 1XypRn5D62IDLP6jGXCtM2lfLP9W6bvVdiRlFPcpdrWbjTXM+MF56Ldi7RSOTWIf
# 2Yc0jKDd32rt9NUzjdw3JRkzasoaEqGyP+b7Ttk4ZoAcXArFVJ3KhqA+sA+c4NGV
# xFwBX6sgJBGFurFjqVKPaLp2Az79Bxh+CbFe6RaYYVLktBbkV5gVrTiuZlrHJMe3
# yOwZWNYzdJD3EYGnIF8hdPPA81plrLqD8/0c91fvuXnYBDwWTElJDc2zBCwh54Yw
# MV6Jnpekk34FG2zUwImUeydw62n5qPdbn1prpg/Pn4GxXBR70JOgIyYneQYUiI5s
# 9tVZCL4gcWfQdIclWzvTQ7Y9EsXV4priIsdjRpCOJ4vn3X8scl43kPv5wIat6ez5
# gpc0kmMCRwyOjYC5lOQYyK8M0u7xfTG6jVgqALg4vRTzt+t3BdP+S3K5coiwpLKa
# E8aY/nvHc+OpiZYZgSkHx7u08ZH9T7nWUWPkXDOmA2e+jI6FoGCyamvU9uYAcMqQ
# PAHhb+AeI1Q2V6ynkYGR6FPO5XxFqoBVbVZJqjzdqTYe/F8RNhsHHJDYBtHyiVTa
# Ap8JIxrDPYeLP4PRLR6qp9LdBt0wEEXmiqcj0pkyoGw6Te5WZ6AfFdO2aKtC4urt
# fVE7hIoDNc+WZw8Bmdc=
# SIG # End signature block
