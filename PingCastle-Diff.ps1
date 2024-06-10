param (
    [Parameter(Mandatory=$true)][string]$new_name,
    [Parameter(Mandatory=$true)][string]$old_name
)

$new_name
$old_name

### EDIT THIS PARAMETERS ###
$teams = 1
$teamsUri = "..."
$print_current_result = 1 #print result of the new report (latest pingcastle scan)
### END ###

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

#region Variable
$ReportFolder = "Reports"
$pingCastleReportFullpath = Join-Path $PSScriptRoot ('{0}.html' -f $new_name)
$pingCastleReportXMLFullpath = Join-Path $PSScriptRoot ('{0}.xml' -f $new_name)

$pingCastleReportDate = Get-Date -UFormat %Y%m%d_%H%M%S
$pingCastleReportFileNameDate = ('{0}_{1}' -f $pingCastleReportDate, ('{0}.html' -f $new_name))
$pingCastleReportFileNameDateXML = ('{0}_{1}' -f $pingCastleReportDate, ('{0}.xml' -f $new_name))

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
<#$headers = @{
    Authorization="Bearer $slackToken"
}#>

$sentNotification = $false

$splatProcess = @{
    WindowStyle = 'Hidden'
    Wait        = $true
}

$BodyTeams = @"
{
   text:'Domain *domain_env* - date_scan - *Global Score abc* : 
- Score: *[cbd Trusts | def Stale Object | asx Privileged Group | dse Anomalies]*
- add_new_vuln
"@

# function send to webhook
Function Send_WebHook($body, $connector) {
    if ($teams -and $connector -eq "teams") {
        Write-Host "Sending to teams"
        return Invoke-RestMethod -Method post -ContentType 'application/Json' -Body $body -Uri $teamsUri
    }
}

# function update body
Function Update_Body($body, $connector) {
        if ($connector -eq "teams") {
            return $body.Replace("abc",$str_total_point).Replace("cbd", $str_trusts).Replace("def", $str_staleObject).Replace("asx", $str_privilegeAccount).Replace("dse", $str_anomalies).Replace("domain_env", $domainName).Replace("date_scan", $dateScan.ToString("dd/MM/yyyy"))
        }
}

# function to deal with color
Function Add_Color($p){
    if ($p -is [ValueType]) {
        $point = $p
    } else {
        $p1 = $p | Measure-Object -Sum Points
        $point = $p1.Sum
    }

    if ($point -ge 75) {
        return [string]$point + " :red_circle:"
    } elseIf ($point -ge 50 -and $point -lt 75) {
        return [string]$point + " :large_orange_circle:"
    } elseIf ($point -ge 25 -and $point -lt 50) {
        return [string]$point + " :large_yellow_circle:"
    } elseIf ($point -ge 0 -and $point -lt 25) {
        return [string]$point + " :large_green_circle:"
    } else {
        return [string]$point + " :large_green_circle:"
    }
}

# function extract HealthcheckRiskRule data
Function ExtractXML($xml,$category) {
    $value = $xml.HealthcheckRiskRule | Select-Object Category, Points, Rationale, RiskId | Where-Object Category -eq $category 
    if ($value -eq $null)
    {
        $value = New-Object psobject -Property @{
            Category = $category
            Points = 0
        }
    }
    return $value
}

# function to calc sum from xml
Function CaclSumGroup($a,$b,$c,$d) {
    $a1 = $a | Measure-Object -Sum Points
    $b1 = $b | Measure-Object -Sum Points
    $c1 = $c | Measure-Object -Sum Points
    $d1 = $d | Measure-Object -Sum Points
    return $a1.Sum + $b1.Sum + $c1.Sum + $d1.Sum 
}

# function to calc sum from one source
Function IsEqual($a,$b) {
    [int]$a1 = $a | Measure-Object -Sum Points | Select-Object -Expand Sum
    [int]$b1 = $b | Measure-Object -Sum Points | Select-Object -Expand Sum
    if($a1 -eq $b1) {
        return 1
    }
    return 0
}

# function to get diff between two reports
Function DiffReport($xml1,$xml2,$action) {

    $result = ""
    Foreach ($rule in $xml1) {
        $found = 0
        Foreach ($rule2 in $xml2) {
            if ($rule.RiskId -and $rule2.RiskId) {
                # if not warning and ...
                if ($action -ne ":arrow_forward:" -and ($rule2.RiskId -eq $rule.RiskId)) {
                    $found = 1
                    break
                # else if warning and                       
                } elseIf ($action -eq ":arrow_forward:" -and ($rule2.RiskId -eq $rule.RiskId) -and ($rule2.Rationale -ne $rule.Rationale)) {
                    Write-Host $action  + " *+" + $rule.Points + "* - " + $rule.Rationale $rule2.Rationale
                    $found = 2
                    break   
                }
            }
        }
        if ($found -eq 0 -and $rule.Rationale -and $action -ne ":arrow_forward:") {
            Write-Host $action  + " *+" + $rule.Points + "* - " + $rule.Rationale  $rule2.RiskId $rule.RiskId
            If ($action -eq ":heavy_exclamation_mark:") {
                $result = $result + $action  + " *+" + $rule.Points + "* - " + $rule.Rationale + "`n"
            } else {
                $result = $result + $action  + " *-" + $rule.Points + "* - " + $rule.Rationale + "`n"
            }
        } elseIf ($found -eq 2 -and $rule.Rationale) {
            $result = $result + $action  + " *" + $rule.Points + "* - " + $rule.Rationale + "`n"
        }
    } 
    return $result   
}

# Check if NEW report exists
foreach ($pingCastleTestFile in ($pingCastleReportFullpath, $pingCastleReportXMLFullpath)) {
    if (-not (Test-Path $pingCastleTestFile)) {
        Write-Error -Message ("Report file not found {0}" -f $pingCastleTestFile)
    }
}

# Get content on XML file
try {
    $contentPingCastleReportXML = $null
    $contentPingCastleReportXML = (Select-Xml -Path $pingCastleReportXMLFullpath -XPath "/HealthcheckData/RiskRules").node
    $domainName = (Select-Xml -Path $pingCastleReportXMLFullpath -XPath "/HealthcheckData/DomainFQDN").node.InnerXML
    $dateScan = [datetime](Select-Xml -Path $pingCastleReportXMLFullpath -XPath "/HealthcheckData/GenerationDate").node.InnerXML
    # get metrics
    $Anomalies = ExtractXML $contentPingCastleReportXML "Anomalies"
    $PrivilegedAccounts = ExtractXML $contentPingCastleReportXML "PrivilegedAccounts"
    $StaleObjects = ExtractXML $contentPingCastleReportXML "StaleObjects"
    $Trusts = ExtractXML $contentPingCastleReportXML "Trusts"
    $total_point = CaclSumGroup $Trusts $StaleObjects $PrivilegedAccounts $Anomalies 
}
catch {
    Write-Error -Message ("Unable to read the content of the xml file {0}" -f $pingCastleReportXMLFullpath)
}

$str_total_point = Add_Color $total_point
$str_trusts = Add_Color $Trusts
$str_staleObject = Add_Color $StaleObjects
$str_privilegeAccount = Add_Color $PrivilegedAccounts
$str_anomalies = Add_Color $Anomalies
$BodyTeams = Update_Body $BodyTeams "teams"

$old_report_xml = Join-Path $PSScriptRoot ('{0}.xml' -f $old_name)
$old_report_html = Join-Path $PSScriptRoot ('{0}.html' -f $old_name)
# Check if OLD report exists
foreach ($pingCastleTestFileOld in ($old_report_html, $old_report_xml)) {
    if (-not (Test-Path $pingCastleTestFileOld)) {
        Write-Error -Message ("Report file not found {0}" -f $pingCastleTestFileOld)
    }
}
$current_scan = ""
$final_thread = ""

$newCategoryContent = $Anomalies + $PrivilegedAccounts + $StaleObjects + $Trusts 
Foreach ($rule in $newCategoryContent) {

    $action = ":heavy_exclamation_mark: *+"
    if ($rule.RiskId) {
        $current_scan = $current_scan + $action + $rule.Points + "* - " + $rule.Rationale + "`n"
    }
}
#$current_scan = "`n`---`n" + $current_scan
    # Get content of previous PingCastle score
try {
    $pingCastleOldReportXMLFullpath = $old_report_xml
    $contentOldPingCastleReportXML = (Select-Xml -Path $pingCastleOldReportXMLFullpath -XPath "/HealthcheckData/RiskRules").node
    $Anomalies_old = ExtractXML $contentOldPingCastleReportXML "Anomalies"  
    $PrivilegedAccounts_old = ExtractXML $contentOldPingCastleReportXML "PrivilegedAccounts" 
    $StaleObjects_old = ExtractXML $contentOldPingCastleReportXML "StaleObjects" 
    $Trusts_old = ExtractXML $contentOldPingCastleReportXML "Trusts" 
    $previous_score = CaclSumGroup $Trusts_old $StaleObjects_old $PrivilegedAccounts_old $Anomalies_old

    Write-Host "Previous score " $previous_score
    Write-Host "Current score " $total_point
}
catch {
    Write-Error -Message ("Unable to read the content of the xml file {0}" -f $old_report_xml)
}
    
$newCategoryContent = $Anomalies + $PrivilegedAccounts + $StaleObjects + $Trusts 
$oldCategoryContent = $Anomalies_old + $PrivilegedAccounts_old + $StaleObjects_old + $Trusts_old 

$addedVuln = DiffReport $newCategoryContent $oldCategoryContent ":heavy_exclamation_mark:"
$removedVuln = DiffReport $oldCategoryContent $newCategoryContent ":white_check_mark:"
$warningVuln = DiffReport $newCategoryContent $oldCategoryContent ":arrow_forward:"

# write message regarding previous score
if ([int]$previous_score -eq [int]$total_point -and (IsEqual $StaleObjects_old $StaleObjects) -and (IsEqual $PrivilegedAccounts_old $PrivilegedAccounts) -and (IsEqual $Anomalies_old $Anomalies) -and (IsEqual $Trusts_old $Trusts)) {
    if ($addedVuln -or $removedVuln -or $warningVuln) {
        $sentNotification = $True
        $BodyTeams = $BodyTeams.Replace("add_new_vuln", "There is no new vulnerability yet some rules have changed !")
    } else {
        $sentNotification = $False
        $BodyTeams = $BodyTeams.Replace("add_new_vuln", "There is no new vulnerability ! &#129395;")

    }
} elseIf  ([int]$previous_score -lt [int]$total_point) {
    Write-Host "rage"
    $sentNotification = $true
    $BodyTeams = $BodyTeams.Replace("add_new_vuln", "New rules flagged **+" + [string]([int]$total_point-[int]$previous_score) + " points** &#128544; `n`n")
} elseIf  ([int]$previous_score -gt [int]$total_point) {
    Write-Host "no rage"
    $sentNotification = $true
    $BodyTeams = $BodyTeams.Replace("add_new_vuln", "Yeah, some improvement have been made *-" +  [string]([int]$previous_score-[int]$total_point) + " points* &#128516; `n`n")
} else {
    Write-Host "same global score but different score in categories"
    $sentNotification = $true
    $BodyTeams = $BodyTeams.Replace("add_new_vuln", "New rules flagged but also some fix, yet same score than previous scan `n`n")
}
$final_thread = $addedVuln + $removedVuln + $warningVuln
#}

$logreport = $PSScriptRoot + "\\scan.log"

# If content is same, don't sent report
if ($sentNotification -eq $false) {
    #Remove-Item ("{0}.{1}" -f (Join-Path $PingCastle.ProgramPath $PingCastle.ReportFileName), '*')
    Write-Information "Same value on PingCastle report."
    "Last scan " + $dateScan | out-file -append $logreport 
    exit
}

# Move report to logs directory
try {
    Write-Information "Sending information by email, webhook, etc..."
    if ($teams) {
        $current_scan = $current_scan.replace("'", "\'")
        $final_thread = $final_thread.replace("'", "\'")
        if ($print_current_result) {
            $BodyTeams = $BodyTeams + $final_thread + "`n`---`n" + "**All the matched rules from the latest scan**`n" + $current_scan + "'}"
        }
        else {
            $BodyTeams = $BodyTeams + $final_thread + "'}"
        }
        $BodyTeams = $BodyTeams.Replace("*","**").Replace("`n","`n`n")
        $BodyTeams = $BodyTeams.Replace(":red_circle:","&#128308;").Replace(":large_orange_circle:","&#128992;").Replace(":large_yellow_circle:","&#128993;").Replace(":large_green_circle:","&#128994;")
        $BodyTeams = $BodyTeams.Replace(":heavy_exclamation_mark:", "&#10071;").Replace(":white_check_mark:", "&#9989;").Replace(":arrow_forward:", "&#128312;")
        $r = Send_WebHook $BodyTeams "teams"
    }
    # write log report
    "Last scan " + $dateScan | out-file -append $logreport 
    $log = $BodyTeams 
    $log = $log + $final_thread
    $log = $log.Replace("*","").Replace(":large_green_circle:","").Replace(":large_orange_circle:","").Replace(":large_yellow_circle:","").Replace(":red_circle:","").Replace(":heavy_exclamation_mark:","!").Replace(":white_check_mark:","-").Replace(":arrow_forward:",">").Replace(":tada:","")
    $log = $log.Replace("{","").Replace("   text:'","").Replace("&#129395;","")
    $log | out-file -append $logreport

    $log
}
catch {
    Write-Error -Message ("Error for move report file to logs directory {0}" -f $pingCastleReportFullpath)
}