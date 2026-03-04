# Flatten nested yearly gzip assets into a single-level assets/prices folder.
# Before: assets/prices/KR/{ticker}/{year}.json.gz
# After : assets/prices/KR_{ticker}_{year}.json.gz

$ErrorActionPreference = 'Stop'
$base = Join-Path $PSScriptRoot '..\assets\prices'
$base = (Resolve-Path $base).Path

function Move-MarketFiles {
  param(
    [Parameter(Mandatory = $true)] [string] $Market
  )

  $marketDir = Join-Path $base $Market
  if (-not (Test-Path $marketDir)) {
    Write-Host "[skip] market directory missing: $marketDir"
    return
  }

  Get-ChildItem $marketDir -Directory | ForEach-Object {
    $ticker = $_.Name

    Get-ChildItem $_.FullName -File -Filter *.json.gz | ForEach-Object {
      # Remove .json.gz suffix safely.
      $year = $_.Name -replace '\.json\.gz$', ''
      $newName = "${Market}_${ticker}_${year}.json.gz"
      $destination = Join-Path $base $newName

      if (Test-Path $destination) {
        throw "Destination already exists: $destination"
      }

      Move-Item -Path $_.FullName -Destination $destination
      Write-Host "[moved] $($_.FullName) -> $destination"
    }
  }

  # Remove empty per-ticker directories after move.
  Get-ChildItem $marketDir -Directory | ForEach-Object {
    if (-not (Get-ChildItem $_.FullName -Force | Select-Object -First 1)) {
      Remove-Item $_.FullName -Force
      Write-Host "[removed] empty dir $($_.FullName)"
    }
  }

  # Remove empty market directory if it has no children.
  if (-not (Get-ChildItem $marketDir -Force | Select-Object -First 1)) {
    Remove-Item $marketDir -Force
    Write-Host "[removed] empty market dir $marketDir"
  }
}

Move-MarketFiles -Market 'KR'
Move-MarketFiles -Market 'US'

Write-Host '[done] flat asset transform completed.'
