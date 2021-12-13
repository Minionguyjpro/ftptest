function Get-DirectoryContent {

<#
    .SYNOPSIS
     
        Function to get directory content
    .EXAMPLE
     
        Get-DirectoryContent -Path "C:\" -HeaderName "poshserver.net" -RequestURL "http://poshserver.net" -SubfolderName "/"
		
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param (

    [Parameter(
        Mandatory = $true,
        HelpMessage = 'Directory Path')]
    [string]$Path,

    [Parameter(
        Mandatory = $false,
        HelpMessage = 'Header Name')]
    [string]$HeaderName,

    [Parameter(
        Mandatory = $false,
        HelpMessage = 'Request URL')]
    [string]$RequestURL,
	
    [Parameter(
        Mandatory = $false,
        HelpMessage = 'Subfolder Name')]
    [string]$SubfolderName,

    [string]$Root
)

@"
<html>
<head>
<title>$($HeaderName)</title>
</head>
<body>
<h1>$($HeaderName) - $($SubfolderName)</h1>
<hr>
"@
@"
<a href="./../">[To Parent Directory]</a><br><br>
<table cellpadding="5">
"@
$Files = (Get-ChildItem "$Path")
foreach ($File in $Files)
{
$FileURL = ($File.FullName -replace [regex]::Escape($Root), "" ) -replace "\\","/"
if (!$File.Length) { $FileLength = "[dir]" } else { $FileLength = $File.Length }
@"
<tr>
<td align="right">$($File.LastWriteTime)</td>
<td align="right">$($FileLength)</td>
<td align="left"><a href="$($FileURL)">$($File.Name)</a></td>
</tr>
"@
}
@"
</table>
<hr>
</body>
</html>
"@
}

[System.Reflection.Assembly]::LoadWithPartialName("System.Web")

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:8080/")
$listener.AuthenticationSchemes = [System.Net.AuthenticationSchemes]::IntegratedWindowsAuthentication
$listener.Start()

New-PSDrive -Name FileServe -PSProvider FileSystem -Root $PWD.Path
$Root = $PWD.Path
cd FileServe:\

do {
    $context = $listener.GetContext()
    $requestUrl = $context.Request.Url
    $response = $context.Response
    $context.User.Identity.Impersonate()

    Write-Host "> $requestUrl"
    $Content = ""

    $localPath = $requestUrl.LocalPath
    try{
        $RequestedItem = Get-Item -LiteralPath "FileServe:\$localPath" -Force -ErrorAction Stop
        $FullPath = $RequestedItem.FullName
        if($RequestedItem.Attributes -match "Directory") {
            $Content = Get-DirectoryContent -Path $FullPath -HeaderName "PowerShell FileServer" -RequestURL "http://localhost:8080" -SubfolderName $localPath -Root $Root
            $Encoding = [system.Text.Encoding]::UTF8
            $Content = $Encoding.GetBytes($Content)
            $response.ContentType = "text/html"
        } else {
            $Content = [System.IO.File]::ReadAllBytes($FullPath)
            $response.ContentType = [System.Web.MimeMapping]::GetMimeMapping($FullPath)
        }
    } catch [System.UnauthorizedAccessException] {
        Write-Host "Access Denied"
        Write-Host "Current user:  $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)"
        Write-Host "Requested File: FileServe:\$localPath"
        $response.StatusCode = 404
        $Content = [System.Text.Encoding]::UTF8.GetBytes("<h1>404 - Page not found</h1>")
    } catch [System.Management.Automation.ItemNotFoundException] {
        Write-Host "No route found for:  FileServe:\$localPath"
        $response.StatusCode = 404
        $Content = [System.Text.Encoding]::UTF8.GetBytes("<h1>404 - Page not found</h1>")
    } catch {
        $_
        $Content =  "$($_.InvocationInfo.MyCommand.Name) : $($_.Exception.Message)"
        $Content +=  "$($_.InvocationInfo.PositionMessage)"
        $Content +=  "    + $($_.CategoryInfo.GetMessage())"
        $Content +=  "    + $($_.FullyQualifiedErrorId)"

        $Content = [System.Text.Encoding]::UTF8.GetBytes($Content)
        $response.StatusCode = 500
    }


    $response.ContentLength64 = $Content.Length
    $response.OutputStream.Write($Content, 0, $Content.Length)
    $response.Close()

    $responseStatus = $response.StatusCode
    Write-Host "< $responseStatus"
} while ($listener.IsListening)
