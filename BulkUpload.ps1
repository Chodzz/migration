Import-Module Sharegate
$Location = Split-Path $psISE.CurrentFile.FullPath
Push-Location
$csvFile = $Location+'\BulkUpload.csv'
$table = Import-Csv $csvFile -Delimiter ","
$mypassword = ConvertTo-SecureString 'pass' -AsPlainText -Force
$myuser = 'user'
$copysettings = New-CopySettings -OnContentItemExists IncrementalUpdate
$propertyTemplate = New-PropertyTemplate -AuthorsAndTimestamps
Set-Variable dstSite, dstList, dstLib, result
foreach ($row in $table)
{
    if ($row.Status -notmatch "Upload")
    {
        Try
        {
          Clear-Variable dstSite, dstList, dstLib, result
          $dstLib = Split-Path $row.DestinationPath -Leaf
          $dstSite = Connect-Site -Url $row.DestinationPath -UserName $myuser -Password $mypassword -AllowConnectionFallback -WarningAction Ignore
          $ID = Get-List -Site $dstSite | Where-Object { $_.RootFolder.Split("/")[3] -eq $dstLib }
          #$ID = Get-List -Site $dstSite | Where-Object -Property Address -match $dstLib | Select-Object Id -First 1
          $dstList = Get-List -Site $dstSite -Id $ID.Id
          $result = Import-Document -WarningAction Ignore -SourceFolder $row.SourcePath -DestinationList $dstList -CopySettings $copysettings -Template $propertyTemplate -TaskName $row.SourcePath -WaitForImportCompletion
          Write-Host 'Copied' $row.SourcePath 'to:' -ForegroundColor Green
          Write-Host $dstList.Address.AbsoluteUri 
          $row.Status = 'Upload'
          $table | Export-Csv $csvFile -Delimiter ',' -NoType
        }
        Catch [Sharegate.Common.Exceptions.SGInvalidOperationException]
        {
          Write-Host 'An Error occured in:' $row.SourcePath 'File not found' -ForegroundColor Red 
          $row.Status = 'Error'
          $table | Export-Csv $csvFile -Delimiter ',' -NoType
        } 
        Catch
        {
          Write-Host 'An Error occured in:' $row.DestinationPath 'Library or site do not exist' -ForegroundColor Red 
          $row.Status = 'Error'
          $table | Export-Csv $csvFile -Delimiter ',' -NoType
        }                  
    }
    else
    {
        Write-Host 'Skipping:' -ForegroundColor Cyan
        Write-Host $row.DestinationPath
        continue
    }
}
