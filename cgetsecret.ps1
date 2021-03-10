 
# Copyright 2020 Centrify Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

param(  [Parameter(Mandatory=$true)]
        [string]$tenant,

        [Parameter(Mandatory=$true)]
        [string]$app,

        [Parameter(Mandatory=$true)]
        [string]$scope,

        [Parameter(Mandatory=$true)]
        [string]$credentials,

        [Parameter(Mandatory=$true)]
        [string]$secret,

        [switch]$diags = $false )

$url = "https://" + $tenant
$uri = $url + "/oauth2/token/" + $app
$headers = @{ "Authorization" = "Basic " + $credentials }
$data = @{ "grant_type" = "client_credentials"; "scope" = $scope}
$Arguments = @{ 'PageNumber' = '1'; 'PageSize' = '100'; 'Limit' = '100000'; 'SortBy' = ''; 'direction' = 'False'; 'Caching' = '-1' }


if ($diags) { write-host("Getting bearer token from " + $uri) }
try { $auth = Invoke-WebRequest -Method post -Uri $uri -Body $data -Headers $headers -UseBasicParsing } 
catch { write-host("ERROR: failed to get OAuth2 token " +  $_.Exception.Message);exit 1 }
if ($diags) { write-host("Token obtained OK" ) }


$AuthRes = $auth.Content | ConvertFrom-Json
$token = $AuthRes.access_token
$uri = $url + "/Redrock/query"
if ($diags) { write-host($token ) }
$headers = @{ "Authorization" = "Bearer $token"; "X-CENTRIFY-NATIVE-CLIENT" = "true" }

$body = @{ "Script" = "select DataVault.ID from DataVault where SecretName = '" + $secret + "'"; "Args" = $Arguments }

if ($diags) { write-host("Getting [" + $Secret + "] ID from Redrock " + $uri);write-host (ConvertTo-Json $body) }
try { $SecretQuery = Invoke-RestMethod -Method post -Uri $uri -Body (ConvertTo-Json $body) -Headers $headers -contenttype "application/json" }

catch { 
	write-host("ERROR: redrock query failed getting secrets ID " +  $_.Exception.Message)
	write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__ 
    write-Host "StatusDescription:" $_.Exception.Response.StatusDescription
	exit 1
	}

if (-Not $SecretQuery.Result.Results.Row.ID ) { Write-Host ("ERROR: unable to find [" + $secret + "], object not found");exit 1 }

$uri = $url + "/ServerManage/RetrieveSecretContents"
$body = @{ "ID" = $SecretQuery.Result.Results.Row.ID; "Args" = $Arguments }

if ($diags) { write-host("Attempting to get secret [" + $secret + ":" + $SecretQuery.Result.Results.Row.ID + "]") }

try { $GetSecret = Invoke-RestMethod -Method post -Uri $uri -Body (ConvertTo-Json $body) -Headers $headers -contenttype "application/json" }
catch { write-host("ERROR: RetrieveSecretContents failed " +  $_.Exception.Message);exit 1 }

if ( [System.String]::IsNullOrEmpty($GetSecret.Result)) { write-host("ERROR: " + $GetSecret.Message);exit 1 }
if ( $GetSecret.Result.SecretFileName ) { write-host("ERROR: unsupported secret type [file]");exit 1 }
write-host($GetSecret.Result.SecretText)
