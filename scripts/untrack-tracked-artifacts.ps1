<#
  Script: untrack-tracked-artifacts.ps1
  Purpose: Remove tracked build/test artifacts (node_modules, test-results, previews) from git index
  Usage: Run from repository root in PowerShell (Windows PowerShell 5.1 / PowerShell 7+)

  This script performs the following actions:
  - Runs `git rm --cached` for common tracked artifact patterns
  - Commits the removals with a sensible message
  - Prints verification instructions

  IMPORTANT: This will stage deletions and create a commit. Review changes before pushing.
#>

Set-StrictMode -Version Latest

if (-not (Test-Path .git)) { Write-Error "Not a git repo (no .git folder found). Run from repository root."; exit 1 }

Write-Host "This script will remove tracked build/test artifacts from git index and commit the change." -ForegroundColor Yellow
Write-Host "Review the list below and press Enter to continue or Ctrl+C to abort."
@(
  'admin-web/node_modules',
  'admin-web/node_modules/**',
  'admin-web/test-results',
  'admin-web/test-results.xml',
  'test-results.xml',
  'last-run-tests*.json',
  'readme_preview_*.html',
  '.readme_preview*.html'
) | ForEach-Object { Write-Host " - $_" }

Read-Host "Press Enter to continue"

# Helper to run git commands and ignore non-fatal failures
function Run-Git([string[]] $args) {
  try {
    & git @args 2>$null
  } catch {
    # ignore failures (file might not be tracked)
  }
}

# Remove cached copies from git index (leave files on disk if present locally)
Run-Git @('rm', '-r', '--cached', 'admin-web/node_modules')
Run-Git @('rm', '--cached', 'admin-web/test-results.xml')
Run-Git @('rm', '--cached', 'test-results.xml')
Run-Git @('rm', '-r', '--cached', 'admin-web/test-results')
Run-Git @('rm', '-r', '--cached', '*last-run-tests*.json')
Run-Git @('rm', '-r', '--cached', 'readme_preview_*.html')
Run-Git @('rm', '-r', '--cached', '.readme_preview*.html')

Write-Host "Staged removals. Showing git status:" -ForegroundColor Cyan
try { & git status --porcelain } catch {}

Write-Host "Creating commit 'chore: remove tracked build/test artifacts and add .gitignore'" -ForegroundColor Cyan
try { & git add .gitignore .dockerignore } catch {}
try {
  & git commit -m "chore: remove tracked build/test artifacts and add .gitignore"
} catch {
  Write-Host "No changes to commit or commit failed." -ForegroundColor Yellow
}

Write-Host "Done. Next steps:" -ForegroundColor Green
Write-Host " - Inspect the commit: git show --name-only HEAD";
Write-Host " - If all looks good, push: git push origin $(git rev-parse --abbrev-ref HEAD)";
Write-Host " - If you want to re-add removed files to disk but keep them untracked, restore them from your local backups.";

exit 0
