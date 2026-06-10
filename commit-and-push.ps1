# commit-and-push.ps1
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Invoke-Git {
    param([string[]]$GitArgs)
    & git @GitArgs
    if ($LASTEXITCODE -ne 0) { throw "Git error: git $($GitArgs -join ' ')" }
}

# Проверка, что мы в git-репозитории
Invoke-Git @("rev-parse", "--is-inside-work-tree") *> $null

# Проверка наличия изменений
$status = @(Invoke-Git @("status", "--porcelain"))
if ($status.Count -eq 0) {
    Write-Host "Нет изменений для коммита." -ForegroundColor Yellow
    exit 0
}

# === Логика версии (твоя текущая) ===
$versionPattern = '^\d+\.\d{2}$'
$tags = @(Invoke-Git @("tag", "--list"))
$versionTags = @(
    foreach ($tag in $tags) {
        if ($tag -match $versionPattern) {
            $parts = $tag -split '\.'
            [PSCustomObject]@{ Tag = $tag; Major = [int]$parts[0]; Minor = [int]$parts[1] }
        }
    }
)

if ($versionTags.Count -eq 0) {
    $major = 1; $minor = 0
} else {
    $last = $versionTags | Sort-Object Major, Minor -Descending | Select-Object -First 1
    $major = $last.Major
    $minor = $last.Minor + 1
    if ($minor -gt 99) { $major++; $minor = 0 }
}

$newVersion = "{0}.{1:D2}" -f $major, $minor

# Защита от перезаписи тега
if (@(Invoke-Git @("tag", "--list", $newVersion)).Count -gt 0) {
    throw "Тег $newVersion уже существует!"
}

# === Основные действия ===
Invoke-Git @("add", "-A")
Invoke-Git @("commit", "-m", $newVersion)
Invoke-Git @("tag", $newVersion)

Write-Host "✓ Commit и тег $newVersion созданы локально" -ForegroundColor Green

# === Пуш на GitHub ===
Write-Host "→ Отправляем на GitHub..." -ForegroundColor Cyan

# Первый раз нужно привязать ветку (если ещё не сделано)
$branch = Invoke-Git @("branch", "--show-current")
try {
    Invoke-Git @("push", "-u", "origin", $branch)
} catch {
    Invoke-Git @("push", "origin", $branch)
}

# Пушим тег отдельно
Invoke-Git @("push", "origin", $newVersion)

Write-Host "✅ Всё успешно отправлено на GitHub! Версия: $newVersion" -ForegroundColor Green