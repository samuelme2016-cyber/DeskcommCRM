# Cria o .env.local para rodar o CRM no PC SEM Docker (sem WhatsApp), usando um
# projeto Supabase na nuvem. As chaves sao digitadas AQUI, no terminal: nao
# passam pelo chat. Rode na pasta do projeto:
#
#   powershell -ExecutionPolicy Bypass -File darkcom\configurar-local.ps1
#
# (Arquivo em ASCII de proposito: o PowerShell 5.1 le script sem BOM como ANSI.)

$ErrorActionPreference = "Stop"
$raiz = Split-Path -Parent $PSScriptRoot
$destino = Join-Path $raiz ".env.local"

function Segredo([string]$pergunta) {
  $s = Read-Host $pergunta -AsSecureString
  $b = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($s)
  try { return ([Runtime.InteropServices.Marshal]::PtrToStringBSTR($b)).Trim() }
  finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($b) }
}
function Recebido([string]$v) { Write-Host ("   ok - recebido ({0} caracteres)" -f $v.Length) -ForegroundColor Green }
function Aleatorio([int]$bytes) {
  $b = New-Object byte[] $bytes
  [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($b)
  return [Convert]::ToBase64String($b)
}

Write-Host ""
Write-Host "=== Darkcom CRM - configuracao local (sem Docker) ===" -ForegroundColor Cyan
Write-Host "Campos secretos NAO mostram nada enquanto voce cola. Cole UMA vez e de Enter."
Write-Host "Colar no PowerShell: botao direito do mouse."
Write-Host ""

if (Test-Path $destino) {
  $r = Read-Host "Ja existe um .env.local. Substituir? (s/n)"
  if ($r -ne "s") { Write-Host "Nada alterado."; exit 0 }
  Copy-Item $destino "$destino.bak" -Force
  Write-Host "   copia do antigo salva em .env.local.bak"
}

# 1. Project URL
do {
  $url = (Read-Host "1/6 Project URL do Supabase (https://xxxx.supabase.co)").Trim().TrimEnd("/")
  $okUrl = $url -match '^https://[a-z0-9]+\.supabase\.co$'
  if (-not $okUrl) { Write-Host "   Formato esperado: https://xxxx.supabase.co" -ForegroundColor Yellow }
} until ($okUrl)
$ref = ($url -replace '^https://', '') -replace '\.supabase\.co$', ''

# 2. anon / publishable
do {
  $anon = (Read-Host "2/6 Chave anon public (eyJ... ou sb_publishable_...)").Trim()
  $okAnon = $anon.StartsWith("eyJ") -or $anon.StartsWith("sb_publishable_")
  if (-not $okAnon) { Write-Host "   Essa nao parece a chave anon." -ForegroundColor Yellow }
} until ($okAnon)
Recebido $anon

# 3. service_role / secret
do {
  $service = Segredo "3/6 Chave service_role (secreta; eyJ... ou sb_secret_...)"
  $okSvc = ($service.StartsWith("eyJ") -or $service.StartsWith("sb_secret_")) -and ($service -ne $anon)
  if (-not $okSvc) { Write-Host "   Essa nao parece a service_role (ou e igual a anon)." -ForegroundColor Yellow }
} until ($okSvc)
Recebido $service

# 4. connection string (Session pooler)
do {
  $db = Segredo "4/6 Connection string do Session pooler (pode colar com [YOUR-PASSWORD])"
  $okDb = $db -match '^postgres(ql)?://' -and $db -match 'pooler\.supabase\.com'
  if ($db -match '@db\.') { Write-Host "   Essa e a 'Direct connection' (so IPv6). Use a do Session pooler." -ForegroundColor Yellow; $okDb = $false }
  elseif (-not $okDb) { Write-Host "   Esperado: postgresql://postgres.xxxx:...@aws-...pooler.supabase.com:5432/postgres" -ForegroundColor Yellow }
} until ($okDb)
Recebido $db
if ($db.Contains("[YOUR-PASSWORD]")) {
  $senhaBanco = Segredo "   Senha do banco (a do passo 'Database Password')"
  Recebido $senhaBanco
  $db = $db.Replace("[YOUR-PASSWORD]", [Uri]::EscapeDataString($senhaBanco))
}

# 5-6. primeiro admin
do {
  $email = (Read-Host "5/6 E-mail do admin (para entrar no CRM)").Trim()
  $okEmail = $email -match '^[^@\s]+@[^@\s]+\.[^@\s]+$'
} until ($okEmail)
do {
  $senha = Segredo "6/6 Senha do admin (minimo 8 caracteres)"
  if ($senha.Length -lt 8) { Write-Host "   Minimo 8 caracteres." -ForegroundColor Yellow }
} until ($senha.Length -ge 8)
Recebido $senha

$interno = Aleatorio 32
$linhas = @(
  "DESKCOMM_ENV_MODE=local-sem-docker",
  "# Gerado por darkcom/configurar-local.ps1 em $(Get-Date -Format s). NAO versionar.",
  "NEXT_PUBLIC_SUPABASE_URL=$url",
  "NEXT_PUBLIC_SUPABASE_ANON_KEY=$anon",
  "SUPABASE_SERVICE_ROLE_KEY=$service",
  "SUPABASE_DB_URL=$db",
  "SUPABASE_DB_ADMIN_URL=$db",
  "SUPABASE_PROJECT_REF=$ref",
  "NEXT_PUBLIC_APP_URL=http://localhost:3000",
  "NEXT_PUBLIC_ADMIN_URL=http://localhost:3000",
  "INTERNAL_SECRET=$interno",
  "INTERNAL_CRON_SECRET=$interno",
  "LGPD_SIGNING_KEY=$interno",
  "TENANT_PROVISIONING_SECRET=$(Aleatorio 32)",
  "IMPERSONATE_COOKIE_SECRET=$(Aleatorio 32)",
  "CPF_ENCRYPTION_KEY=$(Aleatorio 32)",
  "WAHA_BYO_ENCRYPTION_KEY=$(Aleatorio 32)",
  "AI_CRED_AES_KEY=$(Aleatorio 32)",
  "NUVEMSHOP_OAUTH_ENCRYPTION_KEY=$(Aleatorio 32)",
  "# Sem Docker nao ha WhatsApp (WAHA) nem Redis: o rate limit usa memoria.",
  "WAHA_API_BASE_URL=",
  "WAHA_API_KEY=",
  "WAHA_WEBHOOK_BASE_URL=http://localhost:3000",
  "UPSTASH_REDIS_REST_URL=",
  "UPSTASH_REDIS_REST_TOKEN=",
  "SENTRY_DSN=off",
  "APP_LOCALE=pt-BR",
  "# Usado uma vez para criar o admin; o assistente apaga estas linhas depois.",
  "OWNER_EMAIL=$email",
  "OWNER_PASSWORD=$senha",
  "OWNER_ORG_NAME=Darkcom"
)
[IO.File]::WriteAllText($destino, (($linhas -join "`n") + "`n"), (New-Object Text.UTF8Encoding($false)))

Write-Host ""
Write-Host "Pronto! .env.local criado. Volte ao chat e diga 'configurei'." -ForegroundColor Green
