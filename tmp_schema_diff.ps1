# Compare JPA entity columns vs database/*.sql CREATE TABLE columns
# (ASCII only: Windows PowerShell reads .ps1 as ANSI, so non-ASCII would break parsing)
$ErrorActionPreference = 'Stop'
$root = 'F:\lao-cn-APP'

function ToSnake([string]$s) {
  # 注意：PowerShell 的 -replace 默认**不区分大小写**，这里必须用 -creplace，
  # 否则 [A-Z] 会连小写字母一起匹配，version 会被拆成 v_er_si_on。
  (($s -creplace '([a-z0-9])([A-Z])', '$1_$2') -creplace '([A-Z]+)([A-Z][a-z])', '$1_$2').ToLower()
}

# ---------- 1) parse entities ----------
$entities = @{}
$baseCols = @()
$baseFile = Join-Path $root 'spring-backend\src\main\java\com\laos\agri\entity\BaseEntity.java'
if (Test-Path $baseFile) {
  $lines = Get-Content $baseFile
  foreach ($l in $lines) {
    if ($l -match '@Column\(name\s*=\s*"([^"]+)"') { $baseCols += $Matches[1] }
    elseif ($l -match 'private\s+[\w<>\.\s]+?\s+(\w+)\s*;') { $baseCols += (ToSnake $Matches[1]) }
  }
}

Get-ChildItem (Join-Path $root 'spring-backend\src\main\java\com\laos\agri\entity') -Filter *.java |
  Where-Object { $_.Name -notin @('BaseEntity.java','Permission.java','UserRole.java','DataGrade.java','SourceType.java') } |
  ForEach-Object {
    $text = Get-Content $_.FullName
    $table = $null; $schema = $null; $extendsBase = $false
    foreach ($l in $text) {
      if ($l -match '@Table\(name\s*=\s*"([^"]+)"(,\s*schema\s*=\s*"([^"]+)")?') {
        $table = $Matches[1]; if ($Matches[3]) { $schema = $Matches[3] }
      }
      if ($l -match 'class\s+\w+\s+extends\s+BaseEntity') { $extendsBase = $true }
    }
    if (-not $table) { return }

    $cols = @()
    $pending = $null
    foreach ($raw in $text) {
      $l = $raw.Trim()
      if ($l -match '^@Column\(name\s*=\s*"([^"]+)"') { $pending = $Matches[1]; continue }
      if ($l -match '^@Column\(') { $pending = $null; continue }
      if ($l -match '^(private|protected)\s+[\w<>\[\]\.\s]+?\s+(\w+)\s*(=|;)') {
        $field = $Matches[2]
        $cols += $(if ($pending) { $pending } else { ToSnake $field })
        $pending = $null
      }
      if ($l -match '^\}') { break }
    }
    if ($extendsBase) { $cols += $baseCols }
    $key = if ($schema) { "$schema.$table" } else { $table }
    $entities[$key] = ($cols | Sort-Object -Unique)
  }

# ---------- 2) parse SQL ----------
$sqlTables = @{}
Get-ChildItem (Join-Path $root 'database') -Filter *.sql | ForEach-Object {
  $raw = Get-Content $_.FullName -Raw
  foreach ($m in [regex]::Matches($raw, '(?s)CREATE TABLE (?:IF NOT EXISTS )?([\w\."]+)\s*\((.*?)\n\s*\);')) {
    $tbl = $m.Groups[1].Value.Trim('"')
    if (-not $tbl.Contains('.')) { $tbl = "core.$tbl" }
    $cols = @()
    foreach ($line in ($m.Groups[2].Value -split "`n")) {
      $t = ($line -replace '--.*$', '').Trim()
      if (-not $t) { continue }
      if ($t -match '^(CONSTRAINT|PRIMARY|FOREIGN|UNIQUE|CHECK|EXCLUDE)\b') { continue }
      if ($t -match '^([a-zA-Z_]\w*)\s') { $cols += $Matches[1] }
    }
    if ($sqlTables.ContainsKey($tbl)) { $sqlTables[$tbl] = ($sqlTables[$tbl] + $cols | Sort-Object -Unique) }
    else { $sqlTables[$tbl] = ($cols | Sort-Object -Unique) }
  }
  foreach ($m in [regex]::Matches($raw, '(?i)ALTER TABLE ([\w\."]+)\s+ADD COLUMN (?:IF NOT EXISTS )?([a-zA-Z_]\w*)')) {
    $tbl = $m.Groups[1].Value.Trim('"')
    $col = $m.Groups[2].Value
    if ($sqlTables.ContainsKey($tbl)) { $sqlTables[$tbl] = ($sqlTables[$tbl] + $col | Sort-Object -Unique) }
  }
}

# ---------- 3) diff ----------
Write-Host "================ entity columns missing in SQL ================"
$anyMissing = $false
foreach ($k in ($entities.Keys | Sort-Object)) {
  $cands = @($k)
  if (-not $k.Contains('.')) { $cands += "core.$k" }
  $sqlKey = $cands | Where-Object { $sqlTables.ContainsKey($_) } | Select-Object -First 1
  if (-not $sqlKey) { Write-Host ("  ?? {0,-38} no CREATE TABLE found" -f $k); continue }
  $missing = $entities[$k] | Where-Object { $_ -notin $sqlTables[$sqlKey] }
  if ($missing) {
    $anyMissing = $true
    Write-Host ("  XX {0,-38} missing {1}: {2}" -f $k, $missing.Count, ($missing -join ', '))
  } else {
    Write-Host ("  OK {0,-38} match ({1} cols)" -f $k, $entities[$k].Count)
  }
}
if (-not $anyMissing) { Write-Host "`n  all match" }
