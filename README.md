# 🧩 Backup & Restore Seguro com PowerShell (Ambiente Windows)

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

1. Copia arquivos para `_TEMP`
2. Renomeia produção → `_OLD`
3. Promove `_TEMP` → produção
4. Remove versões antigas
5. Gera logs

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
powershell -ExecutionPolicy Bypass -File "C:\scriptBackup\backup.ps1"
```

---

### 🔁 3. Executar Restore

```powershell
powershell -ExecutionPolicy Bypass -File "C:\scriptBackup\restore_producao.ps1"
```

---

### 🧪 4. Validar acesso à rede (opcional)

```powershell
Test-Path "\\SERVER\Backup"
```

Se retornar `True`, a conexão está funcionando corretamente.

---

### 🧹 5. (Opcional) Remover credencial

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
* Padrão aplicável em ambiente corporativo

---

## 👨‍💻 Autor

**Victor Hugo**
Analista de TI

---

## 📌 Observação

Projeto desenvolvido para uso em ambiente corporativo, com foco em segurança e confiabilidade.
