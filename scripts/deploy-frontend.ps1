$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

function Assert-Ok($step) {
    if ($LASTEXITCODE -ne 0) { throw "$step failed (exit code $LASTEXITCODE)" }
}

aws sts get-caller-identity | Out-Null
Assert-Ok "AWS login check (is AWS_PROFILE set?)"

# Read deployment targets from Terraform outputs
Push-Location "$root\terraform"
try {
    $bucket = terraform output -raw site_bucket_name; Assert-Ok "terraform output"
    $distId = terraform output -raw cloudfront_distribution_id; Assert-Ok "terraform output"
    $region = terraform output -raw aws_region; Assert-Ok "terraform output"
} finally { Pop-Location }

# Build the static site
Push-Location "$root\frontend"
try {
    if (-not (Test-Path node_modules)) { npm ci; Assert-Ok "npm ci" }
    Remove-Item Env:NEXT_PUBLIC_API_URL -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force .next, out -ErrorAction SilentlyContinue
    npm run build; Assert-Ok "npm run build"
} finally { Pop-Location }

# Safety check: the production build must never point at the local mock API
$leak = Get-ChildItem "$root\frontend\out" -Recurse -File | Select-String -Pattern "localhost:3001" -List
if ($leak) {
    $files = ($leak.Path | Sort-Object -Unique) -join ", "
    throw "Build output contains localhost:3001 in: $files. Check frontend\.env* files."
}

# Upload and refresh the CDN
aws s3 sync "$root\frontend\out" "s3://$bucket" --delete --region $region; Assert-Ok "s3 sync"
aws cloudfront create-invalidation --distribution-id $distId --paths "/*" | Out-Null; Assert-Ok "cache invalidation"

Write-Host "Deployed to s3://$bucket and invalidated CloudFront cache."