#!/usr/bin/env pwsh
#Requires -Version 6

################################################################################################
#
# Title:        AIQ-Node-FC.ps1
# Author:       Ben Horner
# Date:         2021-09-11
# Description:  Get all nodes from a single cluster UUID and compare
#		        current and peak performance CPU figures plus flag FCP traffic
# Thanks:       Thank you to Adrian Bronder for the original API auth code
#               github.com/AdrianBronder
#
# APIs:         /v1/tokens/accessToken
#               /v1/clusterview/resolver
#               /v1/performance-data/graphs
#               /v3/search/aggregate
#
# URLs:         https://mysupport.netapp.com/myautosupport/dist/index.html#/apiservices
#               https://mysupport.netapp.com/myautosupport/dist/index.html#/apidocs/serviceList
#
################################################################################################

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ENDPOINT = "https://api.activeiq.netapp.com"


### Step 1 - Check Credentials
if ( -not (Test-Path .\tokens.json) ){
    @{"access_token"=""; "refresh_token"=""} | ConvertTo-Json | Out-File .\tokens.json
}
$TOKENS = Get-Content -Raw -Path .\tokens.json | ConvertFrom-Json

if ( [string]::IsNullOrEmpty($TOKENS.refresh_token) ){
    $TOKENS.refresh_token = Read-Host -Prompt "Enter your Active IQ API 'REFRESH' token: "
}


### Step 2 - Generate an access token
$ACCESS_API = $ENDPOINT+"/v1/tokens/accessToken"
$HEADERS = @{
    "accept" = "application/json"
    "Content-Type" = "application/json"
}
$POST_DATA = @{
    "refresh_token" = $TOKENS.refresh_token
}

$REST_RESPONSE = Invoke-RestMethod -Uri $ACCESS_API -Headers $HEADERS -Body ($POST_DATA|ConvertTo-Json) -Method POST
$TOKENS.access_token = $REST_RESPONSE.access_token
$TOKENS.refresh_token = $REST_RESPONSE.refresh_token

$TOKENS | ConvertTo-Json | Out-File .\tokens.json
$HEADERS.Add("authorizationToken", $TOKENS.access_token)


### Step 3 - Get cluster name and resolve to cluster UUID
Clear-Host
$SEARCH_CLUSTER_NAME = Read-Host -Prompt "Enter a cluster name"
$DATE_RANGE = Read-Host -Prompt "Number of day's data for analysis (from today)"
$START_DATE = (Get-Date).AddDays(-$DATE_RANGE).ToString("yyyy-MM-dd")
$END_DATE = (Get-Date).ToString("yyyy-MM-dd")

# Search with given criteria against /v3/search/aggregate API and store results in $REST_SEARCH_RESPONSE
$API_SEARCH = $ENDPOINT+"/v3/search/aggregate?cluster="+$SEARCH_CLUSTER_NAME
$REST_SEARCH_RESPONSE = Invoke-RestMethod -Uri $API_SEARCH -Headers $HEADERS -Method GET

# If multiple clusters match search string, then present options
if ($REST_SEARCH_RESPONSE.results.count -gt 1){
    Write-Host "Multiple clusters were found" -ForegroundColor Yellow
    Write-Host "Please select a cluster" -ForegroundColor Yellow
    for($i = 0; $i -lt $REST_SEARCH_RESPONSE.results.count; $i++){
        Write-Host "$($i): $($REST_SEARCH_RESPONSE.results[$i].name)"
    }
    $selection = Read-Host -Prompt "Enter the number of the cluster you want to choose"

# Store cluster UUID in $CLUSTER_UUID
    $CLUSTER_UUID = $REST_SEARCH_RESPONSE.results.id[$selection]
}
    else {
        $CLUSTER_UUID = $REST_SEARCH_RESPONSE.results.id
    }


### Step 4 - Get all node details for provided cluster UUID from /v1/clusterview/resolver API and store results in $REST_RESOLVER_RESPONSE
$RESOLVER_API = $ENDPOINT+"/v1/clusterview/resolver/"+$CLUSTER_UUID
$REST_RESOLVER_RESPONSE = Invoke-RestMethod -Uri $RESOLVER_API -Headers $HEADERS -Method GET
Clear-Host

### Step 5 - Get performance data for each node within the cluster
$TABLE = @()
$FCP = "No"
foreach ($NODE in $REST_RESOLVER_RESPONSE.clusters.nodes ) {
    Clear-Host
    Write-host "Found"$REST_RESOLVER_RESPONSE.clusters.nodes.Count"nodes in cluster"$REST_RESOLVER_RESPONSE.clusters.name
    Write-Host "Processing node"$NODE.name

    # Gather performance data for node protocols
    $PROTOCOL_API = $ENDPOINT+"/v1/performance-data/graphs?graphName=node_protocol_iops&serialNumber="+$NODE.serial+"&startDate="+(Get-Date).AddDays(-7).ToString("yyyy-MM-dd")+"&endDate=$END_DATE"
    $REST_RESPONSE_PROTOCOL = Invoke-RestMethod -Uri $PROTOCOL_API -Headers $HEADERS -Method GET

    # Gather performance data for given node
    $GRAPH_API = $ENDPOINT+"/v1/performance-data/graphs?graphName=node_headroom_cpu_utilization&serialNumber="+$NODE.serial+"&startDate=$START_DATE&endDate=$END_DATE"
    $REST_RESPONSE = Invoke-RestMethod -Uri $GRAPH_API -Headers $HEADERS -Method GET

    # Extract performance statistics from data returned for each node and store results
    $RESULT_CPU = $REST_RESPONSE.results.counterData.PSObject.Properties.Value | Measure-Object -AllStats -Property current_utilization
    $RESULT_PEAK = $REST_RESPONSE.results.counterData.PSObject.Properties.Value | Measure-Object -AllStats -Property peak_performance
    $FCP_AVERAGE = $REST_RESPONSE_PROTOCOL.results.counterData.PSObject.Properties.Value | Measure-Object -AllStats -Property fcp_ops

    if ($FCP_AVERAGE.sum -gt 0)
        {
            $FCP="Yes"
        }
    

    # Set advice flags for nodes close to or over peak performance
    $HEADROOM = "Node has headroom available  "
    $CPU_VARIANCE = "CPU usage is steady"
    if ($RESULT_CPU.Average -gt ($result_peak.Average - 3))
    {
        $HEADROOM = "** Node is over worked  "
    }
    else {
        if ($RESULT_CPU.Average -lt ($RESULT_PEAK.Average) -and ($RESULT_CPU.Average -ge ($RESULT_PEAK.Average - 10))) 
        {
            $HEADROOM = "* Node is close to limit  "
        }
    }
    if ($RESULT_CPU.StandardDeviation -gt 4)
    {
        $CPU_VARIANCE = "* CPU usage is highly variable  "
    }

    # Place all data into table
    $TABLE += (
        [pscustomobject]@{
            Node_Name=$NODE.name
            Node_Model=$NODE.model
            Node_Serial=$NODE.serial
            CPU_Utilisation_Average=($RESULT_CPU.Average/100).ToString("P2")
            Peak_Performance_Average=($RESULT_PEAK.Average/100).ToString("P2")
            Node_Headroom=($HEADROOM)
            Variance=($CPU_VARIANCE)
            FCP=($FCP)}
    )
}

### Step 6 -  Display results
start-sleep 1
Clear-Host
Write-host ""
Write-host "Displaying results for all"$REST_RESOLVER_RESPONSE.clusters.nodes.Count"nodes in cluster"$REST_RESOLVER_RESPONSE.clusters.name
Write-host "ONTAP version for this cluster is"$REST_RESOLVER_RESPONSE.clusters.version
Write-host ""
Write-output $TABLE | Format-Table
Write-host ""