# ============================================
# BACKUP SEGURO / Pasta1
# MELHOR PRATICA DA VERSAO 2: MANTEM _OLD ATE A PROXIMA EXECUCAO 
# ============================================

# Lista das pastas de origem no Servidor 1
# Cada item tem:
# - Nome: nome que sera usado no destino
# - Caminho: pasta real de origem
$PastasOrigem = @(
    @{ Nome = "Pasta1"; Caminho = "C:\Pasta1" },
    @{ Nome = "Pasta2"; Caminho = "C:\Pasta2" },
    @{ Nome = "Pasta3"; Caminho = "C:\Pasta3" }
)

# Caminho base do compartilhamento no Servidor 2
$DestinoBase   = "\\SERVER\BackupI"

# Pasta onde os logs tambem serao copiados na rede
$PastaLogsRede = "\\SERVER\Backup\Logs"

# Pasta local no Servidor 1 para guardar os logs
$LogDir        = "C:\Logs"

# Data/hora usada para nomear logs e pastas _OLD
$DataHora      = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

# Caminho completo do arquivo de log local
$LogFile       = Join-Path $LogDir "backup_producao_$DataHora.log"

# ============================================
# FUNCAO DE LOG
# ============================================
# Escreve mensagens:
# - na tela
# - no arquivo de log local
# Niveis usados:
# - INFO
# - WARNING
# - ERROR
function Escrever-Log {
    param(
        [string]$Mensagem,
        [string]$Nivel = "INFO"
    )

    $Linha = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Nivel] $Mensagem"
    Write-Host $Linha

    # Grava no log somente se o caminho do log estiver valido
    if (-not [string]::IsNullOrWhiteSpace($LogFile)) {
        Add-Content -LiteralPath $LogFile -Value $Linha
    }
}

# ============================================
# FUNCAO PARA LIMPAR PASTAS _OLD ANTIGAS
# ============================================
# Essa funcao procura backups antigos de execucoes anteriores
# com nome no padrao:
# _OLD_Brix_*
# _OLD_Infomed_*
# _OLD_GerenciadorAgendamentoInfomed_*
#
# Ela tenta remover essas pastas antigas antes do backup atual.
# Se nao conseguir, registra WARNING no log e segue o processo.
function Remover-PastasOldAntigas {
    param(
        [string]$DestinoBase,
        [array]$PastasBase
    )

    Escrever-Log "Iniciando limpeza de pastas _OLD de execucoes anteriores."

    foreach ($Pasta in $PastasBase) {
        $Nome = $Pasta.Nome
        $Padrao = "_OLD_${Nome}_*"

        try {
            # Lista somente diretorios dentro do destino base
            # e filtra pelo padrao do nome OLD
            $PastasOld = Get-ChildItem -LiteralPath $DestinoBase -Directory -Force -ErrorAction Stop |
                Where-Object { $_.Name -like $Padrao }

            # Se nao encontrar nada, apenas registra no log
            if (-not $PastasOld -or $PastasOld.Count -eq 0) {
                Escrever-Log "Nenhuma pasta OLD antiga encontrada para $Nome."
                continue
            }

            foreach ($Old in $PastasOld) {
                $Removido = $false
                Escrever-Log "Tentando remover pasta OLD antiga: $($Old.FullName)"

                # Faz ate 3 tentativas de remocao
                # Isso ajuda em casos de atraso de rede ou arquivos presos momentaneamente
                for ($Tentativa = 1; $Tentativa -le 3; $Tentativa++) {
                    try {
                        Escrever-Log "Tentativa $Tentativa para remover $($Old.Name)"
                        Remove-Item -LiteralPath $Old.FullName -Recurse -Force -ErrorAction Stop
                        Start-Sleep -Seconds 2

                        # Confirma se a pasta realmente sumiu
                        if (-not (Test-Path -LiteralPath $Old.FullName)) {
                            Escrever-Log "Pasta OLD removida com sucesso: $($Old.Name)"
                            $Removido = $true
                            break
                        }
                        else {
						Escrever-Log "A pasta ainda existe apos a tentativa ${Tentativa}: $($Old.Name)" "WARNING"
                        }
                    }
                    catch {
                        Escrever-Log "Falha ao remover $($Old.Name) na tentativa ${Tentativa}: $($_.Exception.Message)" "WARNING"
                        Start-Sleep -Seconds 2
                    }
                }

                # Se nao conseguiu remover apos 3 tentativas, apenas registra no log
                if (-not $Removido) {
                    Escrever-Log "Nao foi possivel remover a pasta OLD antiga: $($Old.FullName)" "WARNING"
                }
            }
        }
        catch {
		Escrever-Log "Erro ao procurar pastas OLD para ${Nome}: $($_.Exception.Message)" "WARNING"
        }
    }

    Escrever-Log "Finalizada a limpeza de pastas _OLD antigas."
}

# ============================================
# PREPARACAO DO LOG
# ============================================
# Cria a pasta de log local se ela nao existir
if (-not (Test-Path -LiteralPath $LogDir)) {
    New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
}

# Cria o arquivo de log da execucao atual
New-Item -Path $LogFile -ItemType File -Force | Out-Null

Escrever-Log "===================================================="
Escrever-Log "INICIO DO BACKUP SEGURO"
Escrever-Log "Destino base: $DestinoBase"
Escrever-Log "Arquivo de log local: $LogFile"
Escrever-Log "===================================================="

# ============================================
# VALIDACOES INICIAIS
# ============================================

# Valida se a variavel de destino base foi preenchida
if ([string]::IsNullOrWhiteSpace($DestinoBase)) {
    Escrever-Log "Variavel DestinoBase esta vazia." "ERROR"
    exit 1
}

# Valida se o compartilhamento de rede esta acessivel
if (-not (Test-Path -LiteralPath $DestinoBase)) {
    Escrever-Log "Destino de rede inacessivel: $DestinoBase" "ERROR"
    exit 1
}

# Valida se todas as pastas de origem existem
foreach ($Pasta in $PastasOrigem) {
    if (-not (Test-Path -LiteralPath $Pasta.Caminho)) {
        Escrever-Log "Pasta de origem nao encontrada: $($Pasta.Caminho)" "ERROR"
        exit 1
    }
}

# ============================================
# LIMPEZA DAS _OLD DA EXECUCAO ANTERIOR
# ============================================
# Antes de iniciar o backup atual, tenta remover OLD antigas
Remover-PastasOldAntigas -DestinoBase $DestinoBase -PastasBase $PastasOrigem

# ============================================
# PROCESSAMENTO DAS PASTAS
# ============================================
foreach ($Pasta in $PastasOrigem) {
    $Nome           = $Pasta.Nome
    $Origem         = $Pasta.Caminho

    # Caminho final no destino
    $DestinoFinal   = Join-Path $DestinoBase $Nome

    # Caminho temporario usado para copiar primeiro com seguranca
    $DestinoTemp    = Join-Path $DestinoBase "_TEMP_$Nome"

    # Nome da pasta OLD gerada na execucao atual
    $DestinoOldNome = "_OLD_${Nome}_$DataHora"

    # Caminho completo da pasta OLD
    $DestinoOld     = Join-Path $DestinoBase $DestinoOldNome

    Escrever-Log "----------------------------------------------------"
    Escrever-Log "Processando pasta: $Nome"
    Escrever-Log "Origem       : $Origem"
    Escrever-Log "Destino final: $DestinoFinal"
    Escrever-Log "Destino temp : $DestinoTemp"
    Escrever-Log "Destino old  : $DestinoOld"

    # ============================================
    # LIMPEZA PREVENTIVA DE TEMP ANTIGO
    # ============================================
    # Se sobrou TEMP de execucao anterior, remove antes de continuar
    if (Test-Path -LiteralPath $DestinoTemp) {
        Escrever-Log "Encontrada pasta temporaria antiga. Removendo: $DestinoTemp" "WARNING"
        try {
            Remove-Item -LiteralPath $DestinoTemp -Recurse -Force -ErrorAction Stop
            Start-Sleep -Seconds 1
            Escrever-Log "Pasta temporaria antiga removida com sucesso."
        }
        catch {
            Escrever-Log "Falha ao remover pasta temporaria antiga: $($_.Exception.Message)" "ERROR"
            exit 1
        }
    }

    # ============================================
    # 1. COPIAR PARA TEMPORARIO
    # ============================================
    # O backup nao copia direto para a pasta final.
    # Primeiro copia para _TEMP_*, para evitar perda do backup atual caso algo falhe.
    Escrever-Log "Iniciando copia para a area temporaria."

    $Argumentos = @(
        "`"$Origem`"",
        "`"$DestinoTemp`"",
        "/MIR",
        "/R:2",
        "/W:2",
        "/COPY:DAT",
        "/DCOPY:DAT",
        "/NP",
        "/TEE",
        "/LOG+:`"$LogFile`""
    )

    try {
        $Processo = Start-Process -FilePath "robocopy.exe" -ArgumentList $Argumentos -Wait -NoNewWindow -PassThru
        $CodigoSaida = $Processo.ExitCode
    }
    catch {
        Escrever-Log "Erro ao executar robocopy para $Nome" "ERROR"
        Escrever-Log "Detalhes: $($_.Exception.Message)" "ERROR"
        exit 1
    }

    # No robocopy, codigos menores que 8 sao sucesso ou sucesso com observacao
    if ($CodigoSaida -ge 8) {
        Escrever-Log "Falha na copia temporaria de $Nome. Codigo Robocopy: $CodigoSaida" "ERROR"
        exit 1
    }

    Escrever-Log "Copia temporaria concluida com sucesso para $Nome. Codigo Robocopy: $CodigoSaida"

    # Confirma se a pasta TEMP foi realmente criada
    if (-not (Test-Path -LiteralPath $DestinoTemp)) {
        Escrever-Log "A pasta temporaria nao foi criada apos a copia: $DestinoTemp" "ERROR"
        exit 1
    }

    # ============================================
    # 2. RENOMEAR DESTINO FINAL PARA _OLD
    # ============================================
    # Se ja existe backup oficial no destino, ele vira _OLD
    # Isso preserva a versao anterior antes de promover a nova
    if (Test-Path -LiteralPath $DestinoFinal) {
        Escrever-Log "Backup atual encontrado. Renomeando para seguranca: $DestinoOldNome"
        try {
            Rename-Item -LiteralPath $DestinoFinal -NewName $DestinoOldNome -ErrorAction Stop
            Start-Sleep -Seconds 1
            Escrever-Log "Backup anterior renomeado com sucesso."
        }
        catch {
            Escrever-Log "Falha ao renomear backup atual para OLD: $($_.Exception.Message)" "ERROR"

            # Se der erro na troca, remove o TEMP para nao deixar lixo
            if (Test-Path -LiteralPath $DestinoTemp) {
                try {
                    Remove-Item -LiteralPath $DestinoTemp -Recurse -Force -ErrorAction Stop
                    Escrever-Log "Pasta temporaria removida apos falha na troca."
                }
                catch {
                    Escrever-Log "Nao foi possivel remover a pasta temporaria apos falha: $($_.Exception.Message)" "WARNING"
                }
            }

            exit 1
        }
    }
    else {
        # Se nao existe pasta final, significa implantacao inicial
        Escrever-Log "Nao existe backup anterior para $Nome. Sera feita a implantacao inicial."
    }

    # ============================================
    # 3. RENOMEAR TEMP PARA OFICIAL
    # ============================================
    # Depois de copiar com sucesso para TEMP,
    # a TEMP e renomeada para o nome oficial da pasta
    Escrever-Log "Promovendo pasta temporaria para producao."
    try {
        Rename-Item -LiteralPath $DestinoTemp -NewName $Nome -ErrorAction Stop
        Start-Sleep -Seconds 1
        Escrever-Log "Nova pasta promovida com sucesso para: $DestinoFinal"
    }
    catch {
        Escrever-Log "Falha ao promover a pasta temporaria para o destino final: $($_.Exception.Message)" "ERROR"

        # Se falhar ao promover TEMP para oficial, tenta rollback da pasta OLD
        if (Test-Path -LiteralPath $DestinoOld) {
            Escrever-Log "Tentando rollback do backup antigo." "WARNING"
            try {
                Rename-Item -LiteralPath $DestinoOld -NewName $Nome -ErrorAction Stop
                Escrever-Log "Rollback executado com sucesso."
            }
            catch {
                Escrever-Log "Falha no rollback: $($_.Exception.Message)" "ERROR"
            }
        }

        exit 1
    }

    # ============================================
    # 4. MANTER _OLD ATE A PROXIMA EXECUCAO
    # ============================================
    # A pasta OLD nao e apagada na mesma execucao.
    # Isso e proposital para contingencia e para evitar problemas com arquivos travados.
    if (Test-Path -LiteralPath $DestinoOld) {
        Escrever-Log "Backup anterior mantido temporariamente para contingencia: $DestinoOld"
        Escrever-Log "Essa pasta sera removida automaticamente na proxima execucao, se possivel."
    }

    Escrever-Log "Pasta $Nome processada com sucesso."
}

Escrever-Log "===================================================="
Escrever-Log "BACKUP FINALIZADO COM SUCESSO"
Escrever-Log "Arquivo de log local: $LogFile"
Escrever-Log "===================================================="

# ============================================
# COPIAR LOG PARA A REDE
# ============================================
# Ao final, copia o log local para a pasta de logs na rede
try {
    if ([string]::IsNullOrWhiteSpace($PastaLogsRede)) {
        throw "A variavel PastaLogsRede esta vazia."
    }

    # Cria a pasta Logs na rede se ela nao existir
    if (-not (Test-Path -LiteralPath $PastaLogsRede)) {
        New-Item -Path $PastaLogsRede -ItemType Directory -Force -ErrorAction Stop | Out-Null
        Start-Sleep -Seconds 1
    }

    # Monta o caminho final do arquivo de log na rede
    $NomeArquivoLog = Split-Path -Path $LogFile -Leaf
    $DestinoLogRede = Join-Path $PastaLogsRede $NomeArquivoLog

    if ([string]::IsNullOrWhiteSpace($DestinoLogRede)) {
        throw "O caminho final do log na rede ficou vazio."
    }

    # Copia o log local para a rede
    Copy-Item -LiteralPath $LogFile -Destination $DestinoLogRede -Force -ErrorAction Stop
    Escrever-Log "Log copiado com sucesso para a rede: $DestinoLogRede"
}
catch {
    # Se falhar a copia do log, registra WARNING mas nao derruba o backup
    Escrever-Log "Falha ao copiar o log para a rede: $($_.Exception.Message)" "WARNING"
}

# Encerramento do script com codigo de sucesso
exit 0
