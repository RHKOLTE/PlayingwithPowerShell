# Base SCIM endpoint
$baseUrl = "https://aonawkage.accounts.ondemand.com"

# Disable SSL cert validation (not recommended for production)
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

# OAuth2 Token
$tokenUrl = "$baseUrl/oauth2/token"
$clientId = "3bf2917e-baab-436f-a917-fsfdsafsa"
$clientSecret = "L_CtlnvS1Utw6Hl=fsafdsafdsafsa.cORj=G"

$body = @{
    grant_type    = "client_credentials"
    client_id     = $clientId
    client_secret = $clientSecret
}

$response = Invoke-RestMethod -Method Post -Uri $tokenUrl -Body $body -ContentType "application/x-www-form-urlencoded"

if (-not $response.access_token) {
    Write-Error "Failed to retrieve access token."
    exit 1
}

$accessToken = $response.access_token
Write-Host "Access token acquired. ${accessToken}"

$headers = @{ Authorization = "Bearer $accessToken" }

# Output files
$userCsv = "scim_users.csv"
$groupCsv = "groups.csv"
$user2groupCsv = "user2group.csv"

# Clean existing files
$userCsv, $groupCsv, $user2groupCsv | ForEach-Object { if (Test-Path $_) { Remove-Item $_ } }

# --------------------
# Step 1: Fetch Users
# --------------------
$usersEndpoint = "$($baseUrl)/scim/Users"
$startIndex = 1
$countPerPage = 10
$totalResults = $null
$firstPage = $true
$userGroupLinks = @()

do {
    $url = "$($usersEndpoint)?startIndex=$startIndex&count=$countPerPage"
    Write-Host "🔄 Fetching users from: $url"

    try {
        $usersResponse = Invoke-RestMethod -Uri $url -Method Get -Headers $headers
    } catch {
        Write-Error "❌ Failed to fetch users at index ${startIndex}: $_"
        break
    }

    if ($usersResponse.Resources) {
        # Export users
        $userExport = $usersResponse.Resources | ForEach-Object {
            $user = $_
            $primaryEmail = ($user.emails | Where-Object { $_.primary -eq $true } | Select-Object -First 1).value
            [PSCustomObject]@{
                Username    = $user.userName
                DisplayName = $user.displayName
                Email       = $primaryEmail
                Active      = $user.active
            }
        }

        $userExport | Export-Csv -Path $userCsv -NoTypeInformation -Encoding UTF8 -Append:(!$firstPage)
        $firstPage = $false

        # Build user-group mapping
        foreach ($user in $usersResponse.Resources) {
            $username = $user.userName
            foreach ($group in $user.groups) {
                if ($group.value -and $group.display) {
                    $userGroupLinks += [PSCustomObject]@{
                        Username  = $username
                        GroupId   = $group.value
                        GroupName = $group.display
                    }
                }
            }
        }
    }

    $totalResults = $usersResponse.totalResults
    $startIndex += $countPerPage

} while ($startIndex -le $totalResults)

Write-Host "✅ Users exported to $userCsv"

# --------------------
# Step 2: Fetch Groups
# --------------------
$groupsEndpoint = "$($baseUrl)/scim/Groups"
$startIndex = 1
$countPerPage = 10
$totalResults = $null
$firstPage = $true
$groupList = @()

do {
    $url = "$($groupsEndpoint)?startIndex=$startIndex&count=$countPerPage"
    Write-Host "🔄 Fetching groups from: $url"

    try {
        $groupsResponse = Invoke-RestMethod -Uri $url -Method Get -Headers $headers
    } catch {
        Write-Error "❌ Failed to fetch groups at index ${startIndex}: $_"
        break
    }

    if ($groupsResponse.Resources) {
        foreach ($group in $groupsResponse.Resources) {
            $groupList += [PSCustomObject]@{
                GroupId    = $group.id
                GroupName  = $group.displayName
                Description = $group.description
                MemberCount = ($group.members | Measure-Object).Count
            }
        }
    }

    $totalResults = $groupsResponse.totalResults
    $startIndex += $countPerPage

} while ($startIndex -le $totalResults)

$groupList | Export-Csv -Path $groupCsv -NoTypeInformation -Encoding UTF8
Write-Host "✅ Groups exported to $groupCsv"

# --------------------
# Step 3: User to Group Mapping
# --------------------
$userGroupLinks | Export-Csv -Path $user2groupCsv -NoTypeInformation -Encoding UTF8
Write-Host "✅ User-to-Group mapping exported to $user2groupCsv"
