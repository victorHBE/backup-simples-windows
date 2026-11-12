# 🧩 Backup & Restore com PowerShell (Ambiente Windows)

Projeto de automação para **backup e restore seguro de sistemas críticos** em ambiente Windows, utilizando PowerShell e boas práticas de infraestrutura.

---

## 🚀 Visão Geral

Este projeto foi desenvolvido para garantir:

* 🔒 Integridade dos dados
* 🔄 Continuidade operacional
* 🛡️ Segurança no acesso
* 📊 Rastreabilidade via logs

---

## 🏗️ Arquitetura

### 🔹 Servidor 1 (Produção)

Contém os sistemas ativos:

* `C:\(Sua pasta 1)`
* `C:\(Sua pasta 2)`
* `C:\(Sua pasta 3)`

---

### 🔹 Servidor 2 (Backup)

Compartilhamento de rede (Nome ilustrativo, colocar seu nome de servidor e pasta):

```
\\SERVER\Backup
```

Com acesso restrito por usuário dedicado.

---

## 🔐 Segurança

* Usuário exclusivo: `Seu usuário`
* Autenticação via `cmdkey`
* Remoção de acesso `Everyone`
* Controle via permissões NTFS + Compartilhamento

---

## 📦 Backup (PowerShell)

### 🔄 Fluxo do processo

1. Obtém trava de execução (Mutex) — aborta se já houver um backup rodando
2. Copia arquivos para `_TEMP`
3. Renomeia produção → `_OLD`
4. Promove `_TEMP` → produção
5. Remove versões antigas
6. Gera logs

### 🔒 Trava contra execução simultânea

O `backup_v2.ps1` impede que dois backups rodem ao mesmo tempo (ex.: execução manual enquanto a tarefa agendada de sábado está em andamento).

* Usa um Mutex do Windows chamado `Global\BackupSeguro_v2`
* Se a trava já estiver em uso, registra `WARNING` no log e encerra com código `2`, sem tocar nos arquivos
* Se uma execução anterior morreu sem liberar a trava (trava abandonada), ela é recuperada automaticamente e um `WARNING` é registrado
* Todo o processo fica dentro de `try/finally`, garantindo que a trava seja liberada em qualquer saída (sucesso ou erro)

### 🔢 Códigos de saída (`backup_v2.ps1`)

| Código | Significado |
|--------|-------------|
| `0` | Backup concluído com sucesso |
| `1` | Erro (rede inacessível, origem inexistente, falha no robocopy ou na troca de pastas) |
| `2` | Já existe um backup em execução — execução abortada |

### ✅ Benefícios

* Evita corrupção de dados
* Não sobrescreve diretamente
* Processo seguro para produção
* Permite rollback manual

---

## 🔁 Restore (PowerShell)

### 🔄 Fluxo do processo

1. Valida backup na rede
2. Copia para `_RESTORE_TEMP`
3. Renomeia produção → `_RESTORE_OLD`
4. Promove `_RESTORE_TEMP` → produção
5. Mantém `_RESTORE_OLD` para contingência
6. Gera logs

---

## ⏰ Agendamento Automático

O script `criar_agendamento.ps1` cria (ou atualiza) uma tarefa no **Agendador de Tarefas do Windows** para executar o backup automaticamente.

### 📅 Configuração padrão

* **Nome da tarefa:** `Backup Seguro Semanal`
* **Frequência:** todo **sábado às 06:00**
* **Comando executado:** `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\scriptBackup\backup_v2.ps1"`

### ✅ Requisitos

* Executar **uma vez**, como **Administrador**, no Servidor 1
* O `backup_v2.ps1` deve estar em `C:\scriptBackup`
* Informar o **mesmo usuário** que possui a credencial do `\\SERVER` salva via `cmdkey` (as credenciais do Windows são por usuário). O script sugere o usuário atual por padrão.

### ⚙️ Comportamento da tarefa

* Roda com o usuário **conectado ou não** (carrega o perfil, permitindo usar as credenciais salvas)
* Executa com privilégios elevados (`RunLevel Highest`)
* `StartWhenAvailable`: se o servidor estiver desligado no horário, executa assim que ligar
* Limite de execução de **12 horas**
* Não abre uma segunda instância pelo agendador (`MultipleInstances IgnoreNew`) — somado à trava Mutex do `backup_v2.ps1`
* Executar o script novamente apenas **atualiza** a tarefa existente

### ✏️ Personalização

No início do `criar_agendamento.ps1`:

* `$NomeTarefa` — nome da tarefa
* `$PastaScript` — pasta onde está o `backup_v2.ps1`
* `$Horario` — horário de execução
* Dia da semana: parâmetro `-DaysOfWeek` em `New-ScheduledTaskTrigger`

---

## 📁 Estrutura

### Backup (Servidor 2)

```
Backup/
├── (Sua pasta 1)
├── (Sua pasta 2)
├── (Sua pasta 3)
```

### Restore (Servidor 1)

```
C:\
├── (Sua pasta 1)
├── (Sua pasta 2)
├── (Sua pasta 3)
├── _RESTORE_OLD_(Sua pasta)_YYYY-MM-DD
```

---

## 🧾 Logs

Logs automáticos para auditoria:

* Backup: `C:\LogsBackup`
* Restore: `C:\LogsRestore`

---

## ▶️ Execução

### 🔐 1. Configurar credencial de acesso (Servidor 1)

Antes de executar os scripts, é necessário configurar a autenticação para acesso ao servidor de backup:

```powershell
cmdkey /add:SERVER /user:SERVER\backup /pass:SUA_SENHA
```

📌 Isso permite que o script acesse automaticamente o compartilhamento de rede sem solicitar login.

---

### 📦 2. Executar Backup

```powershell
powershell -ExecutionPolicy Bypass -File "C:\scriptBackup\backup_v2.ps1"
```

---

### 🔁 3. Executar Restore

```powershell
powershell -ExecutionPolicy Bypass -File "C:\scriptBackup\restore_backup.ps1"
```

---

### ⏰ 4. Agendar backup semanal

Abra o PowerShell **como Administrador** e execute:

```powershell
powershell -ExecutionPolicy Bypass -File "C:\scriptBackup\criar_agendamento.ps1"
```

Comandos úteis para gerenciar a tarefa:

```powershell
# Executar a tarefa agora (teste)
Start-ScheduledTask -TaskName "Backup Seguro Semanal"

# Ver próxima execução e resultado da última
Get-ScheduledTask -TaskName "Backup Seguro Semanal" | Get-ScheduledTaskInfo

# Remover o agendamento
Unregister-ScheduledTask -TaskName "Backup Seguro Semanal" -Confirm:$false
```

📌 Em `LastTaskResult`: `0` = sucesso, `1` = erro, `2` = já havia backup em execução.

---

### 🧪 5. Validar acesso à rede (opcional)

```powershell
Test-Path "\\SERVER\Backup"
```

Se retornar `True`, a conexão está funcionando corretamente.

---

### 🧹 6. (Opcional) Remover credencial

```powershell
cmdkey /delete:SERVER
```


## ⚠️ Boas Práticas

Antes de executar:

* Encerrar usuários do sistema
* Garantir arquivos não estejam em uso
* Validar acesso à rede

Após execução:

* Validar funcionamento
* Remover `_OLD` somente após validação

---

## 💡 Diferenciais Técnicos

* Estrutura segura (_TEMP → _OLD → Produção)
* Controle de erros
* Logs detalhados
* Segurança de acesso na rede
* Agendamento semanal automático
* Proteção contra execução simultânea
* Padrão aplicável em ambiente corporativo

---

## 📝 Histórico de mudanças

### 12/11/2026

* **Novo:** `criar_agendamento.ps1` — cria/atualiza a tarefa agendada `Backup Seguro Semanal` (sábados às 06:00), executando com o usuário que possui as credenciais da rede.
* **Alterado:** `backup_v2.ps1` — adicionada trava contra execução simultânea (Mutex `Global\BackupSeguro_v2`), com novo código de saída `2` e liberação garantida da trava via `try/finally`.

---

## 👨‍💻 Autor

**Victor Hugo**
Analista de TI

---

## 📌 Observação

Projeto desenvolvido para uso em ambiente corporativo, com foco em segurança e confiabilidade.
