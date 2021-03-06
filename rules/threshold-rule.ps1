Import-Module "$PSScriptRoot\Alert-Module.psm1" -Force

# ---------------------- Script Configuration ----------------------

$ruleName = "Average time-taken"
$ruleType = "threshold"

$runEvery = 2 # Script runs every x minute(s). Set to 1 for testing purpose
$alertInterval = 4 # silence alerts within x minutes from previous alerts. Set to 0 for testing purpose
                   # Delete the cache folder whenever this setting is changed
$maxAlertInterval = 60 # maximum minutes to silence exponential alerts. Set to 0 to disable this feature.
                       # $alertInterval will be doubled when $elapsedTime < ($alertInterval * 2) till 
                       # it reaches $maxAlertInterval

$offSchedules = "weeknight", "weekend" # No alert during specified schedules
                       
$bufferTime = 5 # search for data within x minute(s) from $runTime. The time frame in ES query must be manually updated

# Notification settings
$emailEnabled = $true  # $true/$false
$alertLevel = "info"

# Comma-separated Emails
$recipients = "admin@example.com", "admin_2@example.com"

# Log settings
$logRotation = $true

# Misc configuration
$eventThreshold = 5000 # compare query response against this threshold
$ignoredTerms = "" # Ignore specified terms

# Elasticsearch query configuration
$indexPrefix = "logstash_iis-"
$indexTimeString = (Get-Date).ToUniversalTime().ToString("yyyy.MM.dd")
$serverAddr = "192.168.1.10:9200"
$esUrl = "http://$serverAddr/$indexPrefix$indexTimeString/_search"

## Query body
$requestBody = @"
{
  "size": 0,
  "query": {
    "range": {
      "@timestamp": {
        "gte": "now-$($bufferTime)m",
        "lte": "now"
      }
    }
  },
  "aggs": {
    "terms_agg": {
      "terms": {
        "field": "s-computername",
        "size": 100,
        "order": {
          "avg_agg": "desc"
        }
      },
      "aggs": {
        "avg_agg": {
          "avg": {
            "field": "time-taken"
          }
        }
      }
    }
  }
}
"@

# ---------------------- Script Implementation ----------------------

# Check script runtime interval
$runTime = Get-Date
If ( ($runTime.Minute % $runEvery) -ne 0 ) {
    "Wrong runtime interval. Script exits"
    Exit
}

Invoke-LogRotation # depends on $logRotation

# Query against Elasticsearch and process response
## Execute Elasticsearch query
$esResponse = Invoke-RestMethod -URI $esUrl -TimeoutSec 60 -Method Post -ContentType 'application/json' -Body $requestBody

## Process response
$esResponse.aggregations.terms_agg.buckets.GetEnumerator() | foreach {    
    $Term = $_.Key
    $Value = [int]($_.avg_agg | select -ExpandProperty value)
        
    
    If (($Value -gt $eventThreshold) -and (Test-AlertAttempt -Term $Term -Value $Value) -eq "True") {
        Write-Warning "$Term : $Value"
        Send-Email
    }

}