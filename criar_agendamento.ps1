# ============================================
# CRIA/ATUALIZA A TAREFA AGENDADA DO BACKUP
# Executar UMA VEZ, como Administrador, no Servidor 1.
#
# A tarefa roda todo SABADO as 06:00 com o MESMO usuario
# que tem as credenciais do \\SERVER salvas no Windows
# (Gerenciador de Credenciais), pois essas credenciais sao por usuario.
# ============================================

$NomeTarefa   = "Backup Seguro Semanal"
$PastaScript  = "C:\scriptBackup"
$CaminhoScript = Join-Path $PastaScript "backup_v2.ps1"
$Horario      = "06:00"

# Verifica se esta rodando como administrador
$Principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Execute este script como Administrador." -ForegroundColor Red
    exit 1
}

if (-not (Test-Path -LiteralPath $CaminhoScript)) {
    Write-Host "Script de backup nao encontrado: $CaminhoScript" -ForegroundColor Red
    exit 1
}

# Usuario que tem as credenciais da rede salvas (padrao: usuario atual)
$UsuarioAtual = "$env:USERDOMAIN\$env:USERNAME"
Write-Host "Informe o usuario que possui as credenciais do \\SERVER salvas no Windows."
Write-Host "Padrao sugerido: $UsuarioAtual"
$Credencial = Get-Credential -UserName $UsuarioAtual -Message "Usuario e senha que a tarefa agendada vai usar"
if (-not $Credencial) {
    Write-Host "Operacao cancelada." -ForegroundColor Yellow
    exit 1
}

# Acao: o mesmo comando usado na execucao manual
$Acao = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$CaminhoScript`"" `
    -WorkingDirectory $PastaScript

# Gatilho: todo sabado as 06:00
$Gatilho = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Saturday -At $Horario

# Configuracoes:
# - StartWhenAvailable: se o servidor estiver desligado as 06:00, roda assim que ligar
# - ExecutionTimeLimit: encerra se passar de 12 horas
# - MultipleInstances IgnoreNew: nao abre segunda instancia pelo agendador
$Configuracoes = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Hours 12) `
    -MultipleInstances IgnoreNew `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries

# Registra com usuario + senha = "Executar estando o usuario conectado ou nao".
# Isso carrega o perfil do usuario, permitindo usar as credenciais salvas do Windows.
Register-ScheduledTask `
    -TaskName $NomeTarefa `
    -Description "Backup seguro das pastas para \\SERVER (backup_v2.ps1) - todo sabado as $Horario" `
    -Action $Acao `
    -Trigger $Gatilho `
    -Settings $Configuracoes `
    -User $Credencial.UserName `
    -Password $Credencial.GetNetworkCredential().Password `
    -RunLevel Highest `
    -Force | Out-Null

Write-Host ""
Write-Host "Tarefa '$NomeTarefa' criada/atualizada com sucesso." -ForegroundColor Green
Get-ScheduledTask -TaskName $NomeTarefa | Get-ScheduledTaskInfo |
    Select-Object TaskName, NextRunTime, LastRunTime, LastTaskResult | Format-List

Write-Host "Para testar agora: Start-ScheduledTask -TaskName `"$NomeTarefa`""
