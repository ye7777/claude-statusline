$input = $Input | Out-String
if (-not $input) { return }

$data = $input | ConvertFrom-Json -ErrorAction SilentlyContinue
if (-not $data) { return }

# --- Data extraction ---
$five_pct = $data.rate_limits.five_hour.used_percentage
$five_at  = $data.rate_limits.five_hour.resets_at
$week_pct = $data.rate_limits.seven_day.used_percentage
$week_at  = $data.rate_limits.seven_day.resets_at
$cwd      = if ($data.workspace.current_dir) { $data.workspace.current_dir } else { $data.cwd }
$model    = $data.model.display_name
$ctx_pct  = $data.context_window.used_percentage
$effort   = $data.effort.level

# --- Colors (ANSI) ---
$e       = [char]27
$reset   = "$e[0m"
$dim     = "$e[2m"
$cyan    = "$e[36m"
$yellow  = "$e[33m"
$magenta = "$e[35m"
$white   = "$e[37m"
$sep     = "$dim | $reset"

# --- Helper: format remaining time ---
function fmt_remaining($target) {
    $now  = [int][DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $diff = $target - $now
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
    $ctx_int = [math]::Round($ctx_pct)
    $f_context = "${white}context:${ctx_int}%$reset"
} else {
    $f_context = "${dim}context:--$reset"
}

# --- Field: working directory ---
$f_path = "$cyan$cwd$reset"

# --- Field: 5-hour limit ---
if ($null -ne $five_pct) {
    $five_int = [math]::Round($five_pct)
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
    $week_int = [math]::Round($week_pct)
    $f_weekly = "${yellow}weekly:${week_int}%$reset"
    if ($week_at) {
        $remaining = fmt_remaining $week_at
        $f_weekly += "${dim}(reset in $remaining)$reset"
    }
} else {
    $f_weekly = "${dim}weekly:--$reset"
}

Write-Host "$f_model$f_effort$sep$f_context$sep$f_path$sep$f_5h$sep$f_weekly" -NoNewline
