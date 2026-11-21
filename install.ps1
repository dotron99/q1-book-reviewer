# Install the q1-book-reviewer skill into the personal skill folders of
# the agent tools found on this machine. Does not need administrator rights.
# Safe to re-run. Re-running replaces the installed copy of this skill.
#
# One-line install:
#   irm https://raw.githubusercontent.com/dotron99/q1-book-reviewer/main/install.ps1 | iex
# Uninstall from a checkout:
#   .\install.ps1 -Uninstall
# Uninstall from the one-liner:
#   $Q1BookReviewerUninstall = $true; irm https://raw.githubusercontent.com/dotron99/q1-book-reviewer/main/install.ps1 | iex

& {
  param(
    [switch]$Symlink,
    [switch]$Copy,
    [switch]$All,
    [switch]$ClaudeOnly,
    [switch]$CodexOnly,
    [switch]$CursorOnly,
    [switch]$GeminiOnly,
    [switch]$CopilotOnly,
    [switch]$LegacyCodex,
    [switch]$Uninstall,
    [switch]$DryRun,
    [switch]$Help
  )

  $ErrorActionPreference = "Stop"
  $RepoSlug = "dotron99/q1-book-reviewer"
  $RepoHttp = "https://github.com/$RepoSlug"
  $ArchiveRef = if ($env:Q1_BOOK_REVIEWER_REF) { $env:Q1_BOOK_REVIEWER_REF } else { "main" }
  $SkillName = "q1-book-reviewer"
  $CleanupDir = $null
  $IsFileRun = [bool]$PSCommandPath

  function Show-Usage {
    @"
Usage: install.ps1 [options]

Install q1-book-reviewer for the agent tools found on this machine.

The installer looks for Claude Code, Codex, Cursor, Gemini CLI and
GitHub Copilot, then installs the skill for each one it finds.
If none are found, it installs to the standard Claude Code and Codex
personal folders so the skill is ready when you use those tools.

Options:
  -Symlink        Link to a local clone instead of copying
                  (only when this script is run from a checkout)
  -Copy           Copy the skill folder (default)
  -All            Install for every supported tool, even if not detected
  -ClaudeOnly     Install only for Claude Code
  -CodexOnly      Install only for Codex
  -CursorOnly     Install only for Cursor
  -GeminiOnly     Install only for Gemini CLI
  -CopilotOnly    Install only for GitHub Copilot
  -LegacyCodex    Also install to the older Codex path
                  (~/.codex/skills, or `$env:CODEX_HOME\skills if set)
  -Uninstall      Remove this skill from the installer destinations
  -DryRun         Show what would happen, without changing files
  -Help           Show this help
"@
  }

  function Invoke-Fail([string]$Message) {
    Write-Error "install.ps1: $Message"
    if ($IsFileRun) { exit 1 }
    throw "install.ps1: $Message"
  }

  function Test-Cmd([string]$Name) {
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
  }

  # Honour variables set before "irm ... | iex".
  if ($Q1BookReviewerUninstall) { $Uninstall = $true }
  if ($Q1BookReviewerDryRun) { $DryRun = $true }
  if ($Q1BookReviewerAll) { $All = $true }
  if ($Q1BookReviewerSymlink) { $Symlink = $true }
  if ($Q1BookReviewerLegacyCodex) { $LegacyCodex = $true }

  if ($Help) {
    Show-Usage
    return
  }

  $onlyCount = @($ClaudeOnly, $CodexOnly, $CursorOnly, $GeminiOnly, $CopilotOnly) | Where-Object { $_ } | Measure-Object | Select-Object -ExpandProperty Count
  if ($onlyCount -gt 1) {
    Invoke-Fail "use only one -*Only option"
  }

  if (-not $HOME) { Invoke-Fail "HOME is not set" }
  if (-not (Test-Path -LiteralPath $HOME -PathType Container)) {
    Invoke-Fail "HOME is not a directory: $HOME"
  }

  function Get-ClaudeParent {
    if ($env:CLAUDE_CONFIG_DIR) { return (Join-Path $env:CLAUDE_CONFIG_DIR "skills") }
    return (Join-Path $HOME ".claude\skills")
  }

  function Get-LegacyCodexParent {
    if ($env:CODEX_HOME) { return (Join-Path $env:CODEX_HOME "skills") }
    return (Join-Path $HOME ".codex\skills")
  }

  function Test-ThisSkill([string]$Dir) {
    $skillFile = Join-Path $Dir "SKILL.md"
    if (-not (Test-Path -LiteralPath $skillFile -PathType Leaf)) { return $false }
    return [bool](Select-String -LiteralPath $skillFile -Pattern '^name:\s*q1-book-reviewer\s*$' -Quiet)
  }

  function Get-SkillFromRoot([string]$Root) {
    $path = Join-Path $Root "skills\$SkillName\SKILL.md"
    if (Test-Path -LiteralPath $path -PathType Leaf) {
      return (Join-Path $Root "skills\$SkillName")
    }
    return $null
  }

  function Find-LocalSkill {
    if ($PSScriptRoot) {
      $found = Get-SkillFromRoot $PSScriptRoot
      if ($found) { return $found }
    }
    $cwd = (Get-Location).Path
    $found = Get-SkillFromRoot $cwd
    if ($found) { return $found }
    return Get-SkillFromRoot (Join-Path $cwd $SkillName)
  }

  function Get-RemoteSkill {
    try {
      [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    } catch {}
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("q1-book-reviewer-src-" + [guid]::NewGuid().ToString("n"))
    New-Item -ItemType Directory -Path $tmp | Out-Null
    $script:CleanupDir = $tmp
    $zip = Join-Path $tmp "src.zip"
    $urls = @(
      "$RepoHttp/archive/refs/heads/$ArchiveRef.zip",
      "$RepoHttp/archive/refs/tags/$ArchiveRef.zip"
    )
    $downloaded = $false
    foreach ($url in $urls) {
      try {
        Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
        $downloaded = $true
        break
      } catch {}
    }
    if (-not $downloaded) {
      Invoke-Fail "could not download $RepoSlug ($ArchiveRef)"
    }
    $unpack = Join-Path $tmp "unpack"
    Expand-Archive -LiteralPath $zip -DestinationPath $unpack
    $root = Get-ChildItem -LiteralPath $unpack -Directory | Select-Object -First 1
    if (-not $root) { Invoke-Fail "downloaded archive was empty" }
    $found = Get-SkillFromRoot $root.FullName
    if (-not $found) { Invoke-Fail "downloaded repository is missing skills\$SkillName" }
    return $found
  }

  function Test-Claude { return [bool]($env:CLAUDE_CONFIG_DIR) -or (Test-Cmd "claude") -or (Test-Path -LiteralPath (Join-Path $HOME ".claude")) }
  function Test-Codex { return [bool]($env:CODEX_HOME) -or (Test-Cmd "codex") -or (Test-Path -LiteralPath (Join-Path $HOME ".codex")) -or (Test-Path -LiteralPath (Join-Path $HOME ".agents")) }
  function Test-Cursor { return (Test-Cmd "cursor") -or (Test-Cmd "cursor-agent") -or (Test-Path -LiteralPath (Join-Path $HOME ".cursor")) }
  function Test-Gemini { return (Test-Cmd "gemini") -or (Test-Path -LiteralPath (Join-Path $HOME ".gemini")) }
  function Test-Copilot { return (Test-Cmd "copilot") -or (Test-Path -LiteralPath (Join-Path $HOME ".copilot")) }

  function Get-InstallTargets {
    $wantClaude = $false
    $wantCodex = $false
    $wantCursor = $false
    $wantGemini = $false
    $wantCopilot = $false

    if ($ClaudeOnly) { $wantClaude = $true }
    elseif ($CodexOnly) { $wantCodex = $true }
    elseif ($CursorOnly) { $wantCursor = $true }
    elseif ($GeminiOnly) { $wantGemini = $true }
    elseif ($CopilotOnly) { $wantCopilot = $true }
    elseif ($All) {
      $wantClaude = $true; $wantCodex = $true; $wantCursor = $true; $wantGemini = $true; $wantCopilot = $true
    }
    else {
      if (Test-Claude) { $wantClaude = $true }
      if (Test-Codex) { $wantCodex = $true }
      if (Test-Cursor) { $wantCursor = $true }
      if (Test-Gemini) { $wantGemini = $true }
      if (Test-Copilot) { $wantCopilot = $true }
      if (-not ($wantClaude -or $wantCodex -or $wantCursor -or $wantGemini -or $wantCopilot)) {
        Write-Host "No supported tools were detected. Installing to the standard Claude Code and Codex folders."
        $wantClaude = $true
        $wantCodex = $true
      }
    }

    $items = @()
    if ($wantCodex -or $wantCursor -or $wantGemini) {
      $items += [pscustomobject]@{ Tool = "shared"; Path = (Join-Path $HOME ".agents\skills\$SkillName") }
    }
    if ($wantClaude) {
      $items += [pscustomobject]@{ Tool = "Claude Code"; Path = (Join-Path (Get-ClaudeParent) $SkillName) }
    }
    if ($wantCursor) {
      $items += [pscustomobject]@{ Tool = "Cursor"; Path = (Join-Path $HOME ".cursor\skills\$SkillName") }
    }
    if ($wantCopilot) {
      $items += [pscustomobject]@{ Tool = "GitHub Copilot"; Path = (Join-Path $HOME ".copilot\skills\$SkillName") }
    }
    if ($LegacyCodex -or $env:CODEX_HOME) {
      if ($wantCodex -or $LegacyCodex) {
        $items += [pscustomobject]@{ Tool = "Codex (older path)"; Path = (Join-Path (Get-LegacyCodexParent) $SkillName) }
      }
    }
    # Deduplicate by path.
    $seen = @{}
    $unique = @()
    foreach ($item in $items) {
      $key = [System.IO.Path]::GetFullPath($item.Path)
      if (-not $seen.ContainsKey($key)) {
        $seen[$key] = $true
        $unique += $item
      }
    }
    return $unique
  }

  function Get-KnownPaths {
    @(
      (Join-Path (Get-ClaudeParent) $SkillName),
      (Join-Path $HOME ".agents\skills\$SkillName"),
      (Join-Path (Get-LegacyCodexParent) $SkillName),
      (Join-Path $HOME ".cursor\skills\$SkillName"),
      (Join-Path $HOME ".gemini\skills\$SkillName"),
      (Join-Path $HOME ".copilot\skills\$SkillName")
    ) | Select-Object -Unique
  }

  function Confirm-Replace([string]$Dest) {
    if (-not (Test-Path -LiteralPath $Dest)) { return }
    if (Test-ThisSkill $Dest) { return }
    Invoke-Fail "refusing to replace $Dest (it does not look like $SkillName). Remove it by hand if that is intentional."
  }

  function Install-Copy([string]$Dest, [string]$Source) {
    $parent = Split-Path -Parent $Dest
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("q1-book-reviewer-" + [guid]::NewGuid().ToString("n"))
    New-Item -ItemType Directory -Path $tmp | Out-Null
    $staged = Join-Path $tmp $SkillName
    Copy-Item -LiteralPath $Source -Destination $staged -Recurse
    if (Test-Path -LiteralPath $Dest) {
      Remove-Item -LiteralPath $Dest -Recurse -Force
    }
    Move-Item -LiteralPath $staged -Destination $Dest
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Installed copy at $Dest"
  }

  function Install-Link([string]$Dest, [string]$Target) {
    $parent = Split-Path -Parent $Dest
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    if (Test-Path -LiteralPath $Dest) {
      $existing = Get-Item -LiteralPath $Dest
      if ($existing.LinkType -eq "SymbolicLink" -and $existing.Target -eq $Target) {
        Write-Host "Already linked: $Dest -> $Target"
        return
      }
      Remove-Item -LiteralPath $Dest -Recurse -Force
    }
    try {
      New-Item -ItemType SymbolicLink -Path $Dest -Target $Target | Out-Null
      Write-Host "Linked $Dest -> $Target"
    } catch {
      Write-Host "Could not create a symlink at $Dest; installing a copy instead."
      Install-Copy $Dest $Target
    }
  }

  try {
    if ($Uninstall) {
      $found = $false
      foreach ($dest in Get-KnownPaths) {
        if (-not (Test-Path -LiteralPath $dest)) { continue }
        if (-not (Test-ThisSkill $dest)) {
          Write-Host "Skipping $dest (it does not look like $SkillName)"
          continue
        }
        $found = $true
        if ($DryRun) {
          Write-Host "dry-run: remove $dest"
        } else {
          Remove-Item -LiteralPath $dest -Recurse -Force
          Write-Host "Removed $dest"
        }
      }
      if (-not $found) {
        Write-Host "No installed $SkillName skill was found."
      }
      return
    }

    $skillSrc = Find-LocalSkill
    if (-not $skillSrc) {
      if ($Symlink) {
        Invoke-Fail "-Symlink needs a local checkout; download-based installs can only copy"
      }
      if ($DryRun) {
        Write-Host "dry-run: would download $RepoSlug ($ArchiveRef)"
        $skillSrc = "(downloaded skills\$SkillName)"
      } else {
        $skillSrc = Get-RemoteSkill
      }
    }
    if (-not $DryRun) {
      if (-not (Test-Path -LiteralPath (Join-Path $skillSrc "SKILL.md"))) {
        Invoke-Fail "skill folder not found at $skillSrc"
      }
      if (-not (Test-ThisSkill $skillSrc)) {
        Invoke-Fail "source folder is missing a q1-book-reviewer SKILL.md"
      }
      $skillSrc = (Resolve-Path -LiteralPath $skillSrc).Path
    }

    $targets = @(Get-InstallTargets)
    if ($targets.Count -eq 0) { Invoke-Fail "no installation targets selected" }

    $canonical = ($targets | Where-Object { $_.Path -like "*\.agents\skills\*" } | Select-Object -First 1).Path
    if (-not $canonical) { $canonical = $targets[0].Path }

    if ($DryRun) {
      foreach ($item in $targets) {
        Write-Host ("dry-run: install for {0} at {1}" -f $item.Tool, $item.Path)
      }
      return
    }

    foreach ($item in $targets) {
      $dest = $item.Path
      Confirm-Replace $dest
      if ($dest -eq $canonical) {
        if ($Symlink -and -not $Copy) {
          Install-Link $dest $skillSrc
        } else {
          Install-Copy $dest $skillSrc
        }
        $canonical = (Resolve-Path -LiteralPath $dest).Path
      } else {
        Install-Link $dest $canonical
      }
      Write-Host "  ($($item.Tool))"
    }

    Write-Host ""
    Write-Host "Start a new session and invoke the skill as /q1-book-reviewer (Claude Code or Cursor) or `$q1-book-reviewer (Codex)."
  }
  finally {
    if ($script:CleanupDir -and (Test-Path -LiteralPath $script:CleanupDir)) {
      Remove-Item -LiteralPath $script:CleanupDir -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
} @args
