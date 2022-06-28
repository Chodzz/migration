#$Path = "D:\PenangCommon\SHE" ; Get-ChildItem -Directory  -path $Path | Select-Object {$_.FullName} #| Out-File ".\List.csv"
#Import-Module Sharegate #Set-ExecutionPolicy -ExecutionPolicy Unrestricted
#Clear-Variable dstSite, dstList -ErrorAction Ignore
$ExportReport = "off" #Export-Report to Excell
$Timer = "off"
if ($Timer -eq 'on') {
    $current = Get-Date
    $end = Get-Date -Month 06 -Day 28 -Year 2022 -Hour 19 -Minute 00
    $diff= New-TimeSpan -Start $current -End $end
    Write-Host Current Time and date: $current, End Time $end ,Timer is set to $diff
    Start-Sleep -s $diff.TotalSeconds
}

#User&Pass - Migration Account 1
$myuser = 'Mail'
$mypassword = ConvertTo-SecureString 'Pass' -AsPlainText -Force

#CSV
$Location = Split-Path $psISE.CurrentFile.FullPath ; Push-Location $Location
$csvFile = $Location+'\BulkUpload.csv'
$table = Import-Csv $csvFile -Delimiter ","

#Parameters
#$TimeRangeFilter = (Get-Date).AddDays(-40)
#$propertyTemplate = New-PropertyTemplate -VersionHistory -VersionLimit 1 -AuthorsAndTimestamps SameAsCurrent -Permissions Ignore -From $TimeRangeFilter
$copysettings = New-CopySettings -OnContentItemExists IncrementalUpdate
$propertyTemplate = New-PropertyTemplate -AuthorsAndTimestamps

Set-Variable dstSite, dstList, dstLib
foreach ($row in $table)
{
    if ($row.Status -notmatch "Upload")
    {
        #Start Time
        $StartTime = Get-date #"{0:G}" -f (Get-date)
        Write-Host Start Time: $StartTime
        $LogTime = (Get-Date (Get-Date ).AddHours(-24) -format "dd-MM_HH.mm.ss")

        Write-Host $row.SourcePath
        Write-Host $row.DestinationPath

        Clear-Variable dstSite, dstList, dstLib -ErrorAction Ignore
        $dstLib = Split-Path $row.DestinationPath -Leaf
        $dstSite = Connect-Site -Url $row.DestinationPath -UserName $myuser -Password $mypassword -AllowConnectionFallback -WarningAction Ignore
        $ID = Get-List -Site $dstSite | Where-Object -Property RootFolder -match $dstLib | Select-Object Id -First 1
        $dstList = Get-List -Site $dstSite -Id $ID.Id 
        $result = Import-Document -SourceFolder $row.SourcePath -DestinationList $dstList -CopySettings $copysettings -Template $propertyTemplate -TaskName $row.SourcePath -WarningAction Ignore
        $result
        Write-Host 
        Write-Output $dstList.Address.AbsoluteUri
        $row.Status = 'Upload'+$row.Status
        $table | Export-Csv ./BulkUpload.csv -Delimiter ',' -NoType

        #Time Elapsed
        $FinishTime = Get-date #"{0:G}" -f (Get-date)
        Write-Host Start Time: $StartTime 
        Write-Host End Time: $FinishTime
        Write-Host "Time elapsed: $(New-Timespan $StartTime $FinishTime)" -f White -b cyan `n

        #Log
        if ($ExportReport -eq 'on') { Export-Report -CopyResult $result -Path ".\$dstLib-$LogTime.xlsx" } #-DefaultColumns
    }
    else
    {
    Write-Host
    Write-Host $row.DestinationPath - Allredy Copy -ForegroundColor Cyan
    }
}
