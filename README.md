# backup-simples-windows
Script basico para fazer backup de pastas entre dois servidores feito por: 
Victor Hugo Benevides Esteves
-------------------------------------------------------

Como executar o Script,
no Powershell como Administrador digite

powershell -ExecutionPolicy Bypass -File "C:\scriptBackup\backup_v2.ps1"

obs: o comando é tudo em 1 linha

--------------------------------------------------------------------------------------------------------------

Path Notes:

O que esse script faz

Para cada uma das 3 pastas:

1. verifica se a pasta existe no servidor 1 do que tem as pastas que deseja copiar
2. verifica se o compartilhamento \\SERVIDOR2\Backup está acessível

3. se já existir no servidor de Backup:

\\SERVIDOR2\Backup\Pasta1
\\SERVIDOR2\Backup\Pasta2
\\SERVIDOR2\Backup\Pasta3

ele apaga a pasta antiga inteira

4. copia novamente a pasta atual do servidor do Infomed
5. grava tudo no log

--------------------------------------------------------------------------------------------------------------

Estrutura final no servidor de Backup

Depois de rodar, o destino ficará assim:

\\SERVIDOR2\Backup\_OLD_Pasta1
\\SERVIDOR2\Backup\_OLD_Pasta2
\\SERVIDOR2\Backup\_OLD_Pasta3
\\SERVIDOR2\Backup\Pasta1
\\SERVIDOR2\Backup\Pasta2
\\SERVIDOR2\Backup\Pasta3
\\SERVIDOR2\Backup\Logs

Ou seja, sempre com a versão mais atual.

--------------------------------------------------------------------------------------------------------------

Onde fica o log

O log será salvo localmente no servidor 1 em:

C:\LogsBackup

Com nome tipo:

backup_2026-03-24_16-30-00.log

--------------------------------------------------------------------------------------------------------------

Explicando o ExecutionPolicy Bypass

O Windows às vezes bloqueia scripts .ps1.

Esse comando:

-ExecutionPolicy Bypass

permite executar somente naquela chamada, sem mudar permanentemente a política do sistema.

--------------------------------------------------------------------------------------------------------------

A versão v2 do script faz as seguintes novas funções:

-Cria backup temporário antes de excluir o antigo, caso de sucesso com o backup novo , ai sim exclui o antigo.
-Cria também a pasta de log no \\SERVIDOR2.
