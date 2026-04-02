#requires -RunAsAdministrator
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

# ============================================
# CONFIGURACOES
# ============================================
$PastasRestore = @(
    @{ Nome = "Pasta1"; OrigemBackup = "\\SERVERVM\BackupInfomed\Pasta1"; DestinoLocal = "C:\Pasta1" },
    @{ Nome = "Pasta2"; OrigemBackup = "\\SERVERVM\BackupInfomed\Pasta2"; DestinoLocal = "C:\Pasta2" },
    @{ Nome = "Pasta3"; OrigemBackup = "\\SERVERVM\BackupInfomed\Pasta3"; DestinoLocal = "C:\Pasta3" }
)

$LogDir = "C:\LogsRestoreInfomed"
$DataHora = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$LogFile = Join-Path $LogDir "restore_infomed_$DataHora.log"

# ============================================
# FUNCAO DE LOG
# ============================================
function Escrever-Log {
    param(
        [string]$Mensagem,
        [string]$Nivel = "INFO"
    )

    $Linha = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Nivel] $Mensagem"
    Write-Host $Linha
    Add-Content -LiteralPath $LogFile -Value $Linha
}

# ============================================
# FUNCAO PARA GARANTIR PASTA
# ============================================
function Garantir-Pasta {
    param([string]$Caminho)

    if (-not (Test-Path -LiteralPath $Caminho)) {
        New-Item -Path $Caminho -ItemType Directory -Force | Out-Null
    }
}

# ============================================
# FUNCAO PARA REMOVER PASTA COM TENTATIVAS
# ============================================
function Remover-PastaComTentativas {
    param(
        [string]$Caminho,
        [int]$Tentativas = 3
    )

    for ($i = 1; $i -le $Tentativas; $i++) {
        try {
            if (Test-Path -LiteralPath $Caminho) {
                Remove-Item -LiteralPath $Caminho -Recurse -Force -ErrorAction Stop
                Start-Sleep -Seconds 2
            }

            if (-not (Test-Path -LiteralPath $Caminho)) {
                return $true
            }
        }
        catch {
            Escrever-Log "Falha ao remover ${Caminho} na tentativa ${i}: $($_.Exception.Message)" "WARNING"
            Start-Sleep -Seconds 2
        }
    }

    return $false
}

# ============================================
# PREPARO
# ============================================
Garantir-Pasta -Caminho $LogDir
New-Item -Path $LogFile -ItemType File -Force | Out-Null

Escrever-Log "===================================================="
Escrever-Log "INICIO DO RESTORE SEGURO"
Escrever-Log "Computador: $env:COMPUTERNAME"
Escrever-Log "Usuario   : $env:USERNAME"
Escrever-Log "Log       : $LogFile"
Escrever-Log "===================================================="

# ============================================
# VALIDACOES INICIAIS
# ============================================
foreach ($Pasta in $PastasRestore) {
    if (-not (Test-Path -LiteralPath $Pasta.OrigemBackup)) {
        Escrever-Log "Origem de backup nao encontrada: $($Pasta.OrigemBackup)" "ERROR"
        exit 1
    }
}

# ============================================
# PROCESSAMENTO
# ============================================
foreach ($Pasta in $PastasRestore) {
    $Nome = $Pasta.Nome
    $OrigemBackup = $Pasta.OrigemBackup
    $DestinoLocal = $Pasta.DestinoLocal

    $DestinoTemp = "C:\_RESTORE_TEMP_$Nome"
    $DestinoOld  = "C:\_RESTORE_OLD_${Nome}_$DataHora"

    Escrever-Log "----------------------------------------------------"
    Escrever-Log "Processando restore da pasta: $Nome"
    Escrever-Log "Origem backup : $OrigemBackup"
    Escrever-Log "Destino local : $DestinoLocal"
    Escrever-Log "Destino temp  : $DestinoTemp"
    Escrever-Log "Destino old   : $DestinoOld"

    # Limpeza preventiva do TEMP
    if (Test-Path -LiteralPath $DestinoTemp) {
        Escrever-Log "Encontrada pasta TEMP antiga de restore. Removendo: $DestinoTemp" "WARNING"
        $TempRemovido = Remover-PastaComTentativas -Caminho $DestinoTemp
        if (-not $TempRemovido) {
            Escrever-Log "Nao foi possivel remover TEMP antiga: $DestinoTemp" "ERROR"
            exit 1
        }
    }

    # ============================================
    # 1. COPIAR BACKUP PARA TEMP LOCAL
    # ============================================
    Escrever-Log "Copiando backup para area temporaria local"

    $Argumentos = @(
        "`"$OrigemBackup`"",
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
        Escrever-Log "Erro ao executar robocopy para restore de ${Nome}: $($_.Exception.Message)" "ERROR"
        exit 1
    }

    if ($CodigoSaida -ge 8) {
        Escrever-Log "Falha na copia do backup para TEMP de ${Nome}. Codigo Robocopy: $CodigoSaida" "ERROR"
        exit 1
    }

    if (-not (Test-Path -LiteralPath $DestinoTemp)) {
        Escrever-Log "A pasta TEMP de restore nao foi criada: $DestinoTemp" "ERROR"
        exit 1
    }

    Escrever-Log "Copia para TEMP concluida com sucesso para ${Nome}. Codigo Robocopy: $CodigoSaida"

    # ============================================
    # 2. RENOMEAR DESTINO ATUAL PARA OLD
    # ============================================
    if (Test-Path -LiteralPath $DestinoLocal) {
        Escrever-Log "Renomeando pasta atual para seguranca: $DestinoOld"
        try {
            Rename-Item -LiteralPath $DestinoLocal -NewName (Split-Path -Path $DestinoOld -Leaf) -ErrorAction Stop
            Start-Sleep -Seconds 1
            Escrever-Log "Pasta atual renomeada com sucesso para OLD"
        }
        catch {
            Escrever-Log "Falha ao renomear pasta atual para OLD em ${Nome}: $($_.Exception.Message)" "ERROR"

            if (Test-Path -LiteralPath $DestinoTemp) {
                $TempRemovido = Remover-PastaComTentativas -Caminho $DestinoTemp
                if ($TempRemovido) {
                    Escrever-Log "TEMP removida apos falha na troca"
                }
            }

            exit 1
        }
    }
    else {
        Escrever-Log "Pasta atual nao existe. Restore sera implantacao direta."
    }

    # ============================================
    # 3. PROMOVER TEMP PARA DESTINO OFICIAL
    # ============================================
    Escrever-Log "Promovendo TEMP para pasta oficial"
    try {
        Rename-Item -LiteralPath $DestinoTemp -NewName $Nome -ErrorAction Stop
        Start-Sleep -Seconds 1
        Escrever-Log "Restore promovido com sucesso para ${DestinoLocal}"
    }
    catch {
        Escrever-Log "Falha ao promover TEMP para oficial em ${Nome}: $($_.Exception.Message)" "ERROR"

        # Rollback
        if (Test-Path -LiteralPath $DestinoOld) {
            Escrever-Log "Tentando rollback da pasta antiga" "WARNING"
            try {
                Rename-Item -LiteralPath $DestinoOld -NewName $Nome -ErrorAction Stop
                Escrever-Log "Rollback executado com sucesso"
            }
            catch {
                Escrever-Log "Falha no rollback em ${Nome}: $($_.Exception.Message)" "ERROR"
            }
        }

        exit 1
    }

    # ============================================
    # 4. MANTER OLD PARA CONTINGENCIA
    # ============================================
    if (Test-Path -LiteralPath $DestinoOld) {
        Escrever-Log "Pasta OLD mantida para contingencia: $DestinoOld"
    }

    Escrever-Log "Restore da pasta ${Nome} concluido com sucesso"
}

Escrever-Log "===================================================="
Escrever-Log "RESTORE FINALIZADO COM SUCESSO"
Escrever-Log "Recomenda-se validar o sistema antes de remover as pastas _RESTORE_OLD"
Escrever-Log "===================================================="

exit 0