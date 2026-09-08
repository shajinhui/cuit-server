param(
  [Parameter(Mandatory = $true)]
  [string]$RepositoryUrl,
  [string]$Branch = 'ios-port',
  [int]$Attempts = 8
)

$ErrorActionPreference = 'Stop'
$proxyHost = '127.0.0.1'
$proxyPort = 7890
$proxyUrl = "http://${proxyHost}:$proxyPort"
$remote = 'ios-build'

git rev-parse --is-inside-work-tree | Out-Null

$existingUrl = git remote get-url $remote 2>$null
if ($LASTEXITCODE -eq 0) {
  git remote set-url $remote $RepositoryUrl
} else {
  git remote add $remote $RepositoryUrl
}

for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
  Write-Host "Push attempt $attempt of $Attempts (direct)..."
  git -c http.proxy= -c https.proxy= push --set-upstream $remote "HEAD:$Branch"
  if ($LASTEXITCODE -eq 0) {
    Write-Host "Pushed to $RepositoryUrl on branch $Branch."
    exit 0
  }

  $clashAvailable = Test-NetConnection -ComputerName $proxyHost -Port $proxyPort -InformationLevel Quiet -WarningAction SilentlyContinue
  if ($clashAvailable) {
    Write-Host "Direct push failed; trying Clash at $proxyUrl..."
    git -c "http.proxy=$proxyUrl" -c "https.proxy=$proxyUrl" push --set-upstream $remote "HEAD:$Branch"
    if ($LASTEXITCODE -eq 0) {
      Write-Host "Pushed to $RepositoryUrl on branch $Branch."
      exit 0
    }
  } else {
    Write-Warning "Clash is not listening on ${proxyHost}:$proxyPort."
  }

  if ($attempt -lt $Attempts) {
    Write-Warning 'Push was interrupted. Reconnect Clash if needed; retrying in 5 seconds.'
    Start-Sleep -Seconds 5
  }
}

throw "GitHub push failed after $Attempts attempts. Re-run this command later; the local commit is unchanged."
