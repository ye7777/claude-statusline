$ErrorActionPreference = 'Continue'
try {
    [Console]::InputEncoding  = [System.Text.UTF8Encoding]::new($false)
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
} catch {}
$logFile = "$env:USERPROFILE\.claude\statusline-debug.log"

function Write-Log($msg) {
    try {
        $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        Add-Content -Path $logFile -Value "[$ts] $msg" -ErrorAction SilentlyContinue
    } catch {}
}

try {
    $raw = ""
    try {
        $stdin = [Console]::OpenStandardInput()
        $ms = New-Object System.IO.MemoryStream
        $buf = New-Object byte[] 8192
        while (($n = $stdin.Read($buf, 0, $buf.Length)) -gt 0) {
            $ms.Write($buf, 0, $n)
        }
        $raw = [System.Text.Encoding]::UTF8.GetString($ms.ToArray())
        $ms.Dispose()
    } catch {
        Write-Log "stdin read error: $_"
    }
    if (-not $raw) {
        try {
            $fallback = $Input | Out-String
            if ($fallback) {
                $candidates = @($fallback)
                foreach ($cp in @(932, 65001, 0)) {
                    try {
                        $enc = if ($cp -eq 0) { [System.Text.Encoding]::Default } else { [System.Text.Encoding]::GetEncoding($cp) }
                        $bytes = $enc.GetBytes($fallback)
                        $candidates += [System.Text.Encoding]::UTF8.GetString($bytes)
                    } catch {}
                }
                foreach ($c in $candidates) {
                    if ($c -match '^\s*\{') {
                        try {
                            $null = $c | ConvertFrom-Json -ErrorAction Stop
                            $raw = $c
                            break
                        } catch {}
                    }
                }
                if (-not $raw) { $raw = $fallback }
            }
        } catch {
            Write-Log "input fallback error: $_"
        }
    }

    if (-not $raw) {
        Write-Log "empty stdin"
        Write-Output "[no input]"
        return
    }

    Write-Log "input: $($raw.Trim())"

    try {
        $data = $raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        Write-Log "json parse error: $_"
        Write-Output "[json error]"
        return
    }

    # --- Data extraction ---
    $five_pct = $null; $five_at = $null
    $week_pct = $null; $week_at = $null
    if ($data.PSObject.Properties.Name -contains 'rate_limits' -and $data.rate_limits) {
        if ($data.rate_limits.PSObject.Properties.Name -contains 'five_hour' -and $data.rate_limits.five_hour) {
            $five_pct = $data.rate_limits.five_hour.used_percentage
            $five_at  = $data.rate_limits.five_hour.resets_at
        }
        if ($data.rate_limits.PSObject.Properties.Name -contains 'seven_day' -and $data.rate_limits.seven_day) {
            $week_pct = $data.rate_limits.seven_day.used_percentage
            $week_at  = $data.rate_limits.seven_day.resets_at
        }
    }

    $cwd = $null
    if ($data.PSObject.Properties.Name -contains 'workspace' -and $data.workspace -and $data.workspace.current_dir) {
        $cwd = $data.workspace.current_dir
    } elseif ($data.PSObject.Properties.Name -contains 'cwd') {
        $cwd = $data.cwd
    }

    $model = $null
    if ($data.PSObject.Properties.Name -contains 'model' -and $data.model) {
        $model = $data.model.display_name
    }

    $ctx_pct = $null
    if ($data.PSObject.Properties.Name -contains 'context_window' -and $data.context_window) {
        $ctx_pct = $data.context_window.used_percentage
    }

    $effort = $null
    if ($data.PSObject.Properties.Name -contains 'effort' -and $data.effort) {
        $effort = $data.effort.level
    }

    # --- Colors (ANSI) ---
    $e       = [char]27
    $reset   = "$e[0m"
    $dim     = "$e[2m"
    $cyan    = "$e[36m"
    $yellow  = "$e[33m"
    $magenta = "$e[35m"
    $white   = "$e[37m"
    $sep     = "$dim | $reset"

    function fmt_remaining($target) {
        try {
            $targetSec = $null
            if ($target -is [int] -or $target -is [long] -or $target -is [double]) {
                $targetSec = [int64]$target
            } elseif ($target -is [string]) {
                $parsed = 0L
                if ([int64]::TryParse($target, [ref]$parsed)) {
                    $targetSec = $parsed
                } else {
                    $dt = [DateTimeOffset]::Parse($target)
                    $targetSec = $dt.ToUnixTimeSeconds()
                }
            } else {
                return "?"
            }
            $now  = [int64][DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
            $diff = $targetSec - $now
            if ($diff -le 0) { return "now" }
            if ($diff -ge 86400) {
                $d = [math]::Floor($diff / 86400)
                $h = [math]::Floor(($diff % 86400) / 3600)
                if ($h -gt 0) { return "${d}d${h}h" } else { return "${d}d" }
            } elseif ($diff -ge 3600) {
                $h = [math]::Floor($diff / 3600)
                $m = [math]::Floor(($diff % 3600) / 60)
                if ($m -gt 0) { return "${h}h${m}m" } else { return "${h}h" }
            } else {
                $m = [math]::Floor($diff / 60)
                return "${m}m"
            }
        } catch {
            Write-Log "fmt_remaining error for target=$target : $_"
            return "?"
        }
    }

    # --- Field: model ---
    if ($model) {
        $f_model = "$magenta$model$reset"
    } else {
        $f_model = "${dim}no model$reset"
    }

    # --- Field: thinking effort ---
    $f_effort = if ($effort) { "$white`:$effort$reset" } else { "" }

    # --- Field: context usage ---
    if ($null -ne $ctx_pct) {
        $ctx_int = [math]::Round([double]$ctx_pct)
        $f_context = "${white}context:${ctx_int}%$reset"
    } else {
        $f_context = "${dim}context:--$reset"
    }

    # --- Field: working directory ---
    $f_path = if ($cwd) { "$cyan$cwd$reset" } else { "${dim}no-cwd$reset" }

    # --- Field: 5-hour limit ---
    if ($null -ne $five_pct) {
        $five_int = [math]::Round([double]$five_pct)
        $f_5h = "${yellow}5h:${five_int}%$reset"
        if ($five_at) {
            $remaining = fmt_remaining $five_at
            $f_5h += "${dim}(reset in $remaining)$reset"
        }
    } else {
        $f_5h = "${dim}5h:--$reset"
    }

    # --- Field: weekly limit ---
    if ($null -ne $week_pct) {
        $week_int = [math]::Round([double]$week_pct)
        $f_weekly = "${yellow}weekly:${week_int}%$reset"
        if ($week_at) {
            $remaining = fmt_remaining $week_at
            $f_weekly += "${dim}(reset in $remaining)$reset"
        }
    } else {
        $f_weekly = "${dim}weekly:--$reset"
    }

    $line = "$f_model$f_effort$sep$f_context$sep$f_path$sep$f_5h$sep$f_weekly"
    Write-Output $line
}
catch {
    Write-Log "fatal: $_ ; stack: $($_.ScriptStackTrace)"
    Write-Output "[statusline error - see statusline-debug.log]"
}
