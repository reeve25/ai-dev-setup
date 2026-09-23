# PowerShell profile - rebuilt 2026-09-23 by Claude (old version backed up in ~/.config/ai-cleanup)
#   claude / cc / ffc -> Main chain via 9router if $ClaudeViaRouter is true (Opus 5.5 -> Opus 5 -> GPT-5.6 Sol ->
#                        Antigravity -> Kiro -> Flash, switching automatically in the same chat), else Claude Pro direct
#   claude9           -> always the Main chain;  claude-direct -> always Claude Pro direct
#   codex             -> ChatGPT Plus directly;  codex9 -> Codex via 9router
#   Test-Opus55Router -> checks whether 9router can reach Opus 5.5

$global:NineRouterCombo = 'Main'
$global:ClaudeViaRouter = $true   # set by setup: true = claude/cc/ffc go through the Main chain (seamless fallback)
$global:NineRouterArgs = @('--tray', '--skip-update', '--no-browser', '--host', '127.0.0.1')

function Test-NineRouter {
    $c = New-Object Net.Sockets.TcpClient
    try { return $c.ConnectAsync('127.0.0.1', 20128).Wait(300) } catch { return $false } finally { $c.Dispose() }
}

function Start-NineRouter {
    if (Test-NineRouter) { return $true }
    $exe = Get-Command 9router -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $exe) { return $false }
    Write-Host 'Starting 9router...' -ForegroundColor DarkGray
    Start-Process -WindowStyle Hidden -FilePath $exe.Source -ArgumentList $global:NineRouterArgs
    for ($i = 0; $i -lt 90; $i++) { Start-Sleep -Milliseconds 500; if (Test-NineRouter) { return $true } }
    return $false
}

function Get-RealCommand([string]$name) {
    (Get-Command $name -CommandType Application, ExternalScript -ErrorAction Stop | Select-Object -First 1).Source
}

function Invoke-ClaudeRouted {
    $exe = Get-RealCommand 'claude'
    $key = [Environment]::GetEnvironmentVariable('NINE_ROUTER_API_KEY', 'User')
    if (-not $key -or -not (Start-NineRouter)) {
        Write-Warning '9router unavailable - using Claude Pro directly'
        & $exe @args
        return
    }
    $vars = @{
        ANTHROPIC_BASE_URL             = 'http://127.0.0.1:20128/v1'
        ANTHROPIC_AUTH_TOKEN           = $key
        ANTHROPIC_MODEL                = $global:NineRouterCombo
        ANTHROPIC_DEFAULT_OPUS_MODEL   = $global:NineRouterCombo
        ANTHROPIC_DEFAULT_SONNET_MODEL = $global:NineRouterCombo
        ANTHROPIC_DEFAULT_FABLE_MODEL  = 'cc/claude-fable-5'
        ANTHROPIC_DEFAULT_HAIKU_MODEL  = 'cc/claude-haiku-4-5-20251001'
        CLAUDE_CODE_MAX_CONTEXT_TOKENS = '200000'
        # Claude Code disables MCP/tool deferral for non-Anthropic base URLs; 9router passes tool_reference
        # blocks through fine (tested 2026-09-23), and it cuts the per-request prompt ~42k -> ~26k tokens.
        ENABLE_TOOL_SEARCH             = 'true'
    }
    $saved = @{}
    foreach ($n in $vars.Keys) { $saved[$n] = [Environment]::GetEnvironmentVariable($n, 'Process'); [Environment]::SetEnvironmentVariable($n, $vars[$n], 'Process') }
    try { & $exe @args }
    finally { foreach ($n in $vars.Keys) { [Environment]::SetEnvironmentVariable($n, $saved[$n], 'Process') } }
}

function Invoke-ClaudeDefault { if ($global:ClaudeViaRouter) { Invoke-ClaudeRouted @args } else { & (Get-RealCommand 'claude') @args } }
function claude        { Invoke-ClaudeDefault @args }
function cc            { Invoke-ClaudeDefault @args }
function claude9       { Invoke-ClaudeRouted @args }
function claude-direct { & (Get-RealCommand 'claude') @args }

function ffc {
    # FantasyFootball was archived 2026-09-18 (folder left empty); ff-arbitrage is the live project
    Set-Location 'C:\Users\reeve\Documents\ff-arbitrage'
    Invoke-ClaudeDefault @args
}

function Test-Opus55Router {
    if (-not (Start-NineRouter)) { Write-Warning '9router not running'; return }
    $key = [Environment]::GetEnvironmentVariable('NINE_ROUTER_API_KEY', 'User')
    $body = '{"model":"cc/claude-opus-5-5","max_tokens":2048,"stream":false,"messages":[{"role":"user","content":"Reply with your exact model id only."}]}'
    try {
        $r = Invoke-RestMethod -Method Post -Uri 'http://127.0.0.1:20128/v1/messages' -ContentType 'application/json' -Body $body -Headers @{ 'x-api-key' = $key; Authorization = "Bearer $key"; 'anthropic-version' = '2023-06-01' }
        Write-Host ("OK via 9router -> model: " + $r.model + " | reply: " + ($r.content | Where-Object type -eq 'text' | Select-Object -ExpandProperty text)) -ForegroundColor Green
    } catch { Write-Host ("FAILED: " + $_.Exception.Message + " " + $_.ErrorDetails.Message) -ForegroundColor Red }
}

function codex9 {
    if (-not (Start-NineRouter)) { Write-Warning '9router unavailable - run plain codex instead'; return }
    & (Get-RealCommand 'codex') --profile 9router @args
}
