# setup_hooks.ps1
# Setup Git Hooks locally for the developer

$gitHooksDir = Join-Path (Get-Location) ".git\hooks"
$srcHooksDir = Join-Path (Get-Location) "git_hooks"

if (Test-Path $gitHooksDir) {
    Copy-Item -Path (Join-Path $srcHooksDir "*") -Destination $gitHooksDir -Force
    Write-Host "? Git hooks successfully set up in .git/hooks!" -ForegroundColor Green
} else {
    Write-Host "? .git directory not found. Please run git init first." -ForegroundColor Red
}
