# Nota Técnica — Gravar dados e logs no microSD com CODESYS (ST)

**Autor:** AnnibalHAbreu  
**Data:** 2025-12-05  
**Versão:** 1.0

Resumo  
Explica como gravar arquivos (logs, CSV, parâmetros) em um cartão microSD a partir de código Structured Text (ST) no CODESYS, cobrindo bibliotecas a usar, caminhos de arquivo, exemplos práticos (abrir, anexar, escrever, fechar), rotação de arquivos, buffering para proteção de flash e considerações de segurança/robustez.

---

## Índice
- [Pré-requisitos e bibliotecas](#pré-requisitos-e-bibliotecas)  
- [Identificar o caminho (mount point) do microSD](#identificar-o-caminho-mount-point-do-microsd)  
- [Boas práticas de escrita em microSD](#boas-práticas-de-escrita-em-microsd)  
- [API recomendada: SysFile (CODESYS)](#api-recomendada-sysfile-codesys)  
- [Exemplo prático: gravação simples (append) — ST](#exemplo-prático-gravação-simples-append---st)  
- [Exemplo prático: logger com buffering, rotação e flush periódico](#exemplo-prático-logger-com-buffering-rotação-e-flush-periódico)  
- [Tratamento de erros e watchdogs](#tratamento-de-erros-e-watchdogs)  
- [Atomicidade e rotação segura de arquivos](#atomicidade-e-rotação-segura-de-arquivos)  
- [Considerações finais e checklist de implantação](#considerações-finais-e-checklist-de-implantação)

---

## Pré-requisitos e bibliotecas

1. CODESYS runtime com suporte a sistema de arquivos e acesso ao microSD (ex.: WAGO, Beckhoff, CODESYS Control for Linux/Win com driver de SD).  
2. Bibliotecas a incluir no POU / projeto:
   - `SysFile` (CODESYS standard) — functions: SysFileOpen, SysFileWrite, SysFileClose, SysFileGetSize, SysFileDelete, SysFileRename, SysFileGetLastError.
   - `SysTimeRtc` / `SysTime` (opcional) — para obter timestamp legível.
   - `SysLib` ou `Strings` / utilitários de conversão (dependendo do projeto) para formar WSTRINGs/byte arrays.
3. microSD formatado (recomendado FAT32) e com permissões de escrita no target.

---

## Identificar o caminho (mount point) do microSD

- O caminho/drive para microSD depende do fabricante/target:
  - WAGO: frequentemente `SD0:/` ou `SD:/` — verificar Device Web ou Device Tree.
  - CODESYS Control Win: geralmente um caminho do Windows `C:\...` ou o drive letter atribuído ao cartão (ex.: `E:\logs\log.csv`).
  - Em Linux-based runtimes: `/mnt/sdcard/` ou similar.
- Teste manualmente criando um arquivo via interface do controlador (File System) ou via FTP/SSH para descobrir o mount path.
- Sempre use caminhos absolutos (com subdiretório) e verifique existência do diretório (criar se necessário).

Exemplo de caminho:
- `SD0:/logs/mylog.csv`  (WAGO estilo)
- `E:\logs\mylog.csv`    (Windows style)

---

## Boas práticas de escrita em microSD

- Minimize gravações diretas em flash (usar buffer em RAM e flush periódico).
- Evite gravações a cada mudança de UI (usar botão "Salvar" para parâmetros).
- Agrupe múltiplos valores em uma única escrita.
- Rotacione arquivos por tamanho ou data para evitar arquivos gigantes (ex: `log_20251205_12.csv`).
- Escrever em arquivo temporário e renomear para garantir atomicidade.
- Use append para logs e crie cabeçalho CSV na primeira criação.
- Verifique espaço livre antes de gravar.
- Teste integrity: ler de volta ocasionalmente / checksum.

---

## API recomendada: SysFile (CODESYS)

Principais funções (SysFile):
- SysFileOpen(pwszFileName : WSTRING; eOpenMode : SysFileOpenMode) : UDINT
  - modos: ReadOnly, WriteOnlyCreate, WriteOnlyAppend, ReadWriteCreate, ReadWriteAppend
- SysFileWrite(hFile : UDINT; pBuffer : POINTER TO BYTE; nToWrite : UDINT; pWritten : POINTER TO UDINT) : UDINT
- SysFileClose(hFile : UDINT) : UDINT
- SysFileGetSize(hFile : UDINT; pSize : POINTER TO UDINT) : UDINT
- SysFileRename / SysFileDelete
- SysFileGetLastError() — para diagnóstico

Observação sobre strings:  
- WSTRING em CODESYS é UTF-16LE (2 bytes por caractere). Escrever WSTRING diretamente com SysFileWrite grava UTF-16LE. Se você quer UTF-8/ASCII no arquivo (recomendado para interoperabilidade), converta explicitamente (biblioteca ou rotina) antes de escrever.

Exemplo simples: gravar WSTRING direto (arquivo conterá UTF-16LE).

---

## Exemplo prático: gravação simples (append) — ST

Descrição: abrir arquivo no modo append, escrever uma linha com timestamp e fechar.

```iecst
// POU: PLC_PRG (ST)
// Bibliotecas necessárias:
//   - SysFile
//   - SysTimeRtc (opcional para timestamp legível)

VAR
    hFile       : UDINT := 0;
    written     : UDINT := 0;
    filePath    : WSTRING(255) := 'SD0:/logs/mylog.csv'; // ajustar conforme target
    line        : WSTRING(256);
    nBytes      : UDINT;
    result      : UDINT;
    dt          : DATE_AND_TIME;
    timeStr     : WSTRING(50);
    firstRun    : BOOL := FALSE;
END_VAR

// Função de conversão do timestamp (depende da biblioteca SysTimeRtc disponível)
// Aqui assumimos existência de SysTimeRtcRead + SysTimeRtcToString (ou implemente sua própria)
dt := SysTimeRtcRead(); // do SysTimeRtc

// Exemplo simples de criar uma linha CSV (essa concatenação usa a função CONCAT, 
// que pode vir das bibliotecas de strings; adapte se necessário)
timeStr := SysTimeRtcToString(dt); // se função disponível
line := CONCAT(timeStr, ' , ');
line := CONCAT(line, 'Temperatura: ');
line := CONCAT(line, REAL_TO_WSTRING(25.3)); // exemplo valor
line := CONCAT(line, '\r\n'); // nova linha

// Abrir em append (cria arquivo se não existir)
hFile := SysFileOpen(filePath, SysFileOpenMode.WriteOnlyAppend);

// Verificar handle
IF hFile = 0 THEN
    // tratar erro: recuperar SysFileGetLastError()
ELSE
    // calcular bytes a escrever (WSTRING -> bytes UTF-16LE)
    nBytes := UDINT_TO_UDINT(LEN(line)) * 2; // cada char = 2 bytes
    result := SysFileWrite(hFile, ADR(line), nBytes, ADR(written));
    // checar result e written
    SysFileClose(hFile);
END_IF
```

Comentários:
- `SysFileOpen` retorna um handle (UDINT). Alguns targets usam `0` como inválido; verifique documentação do seu runtime.
- `ADR(line)` passa ponteiro ao primeiro caractere do WSTRING; escrevemos `LEN(line)*2` bytes (UTF-16LE).
- Para gerar UTF-8, converta WSTRING->UTF8 byte array antes do SysFileWrite (biblioteca de utilitários ou função própria).

---

## Exemplo prático: logger com buffering, rotação e flush periódico

Descrição: FB que mantém buffer em RAM (WSTRING), faz append ao buffer frequentemente, e periodicamente (ou quando buffer estoura) grava no microSD. Implementa rotação por tamanho.

```iecst
FUNCTION_BLOCK FB_SDLogger
VAR_INPUT
    Enable      : BOOL;
END_VAR

VAR
    filePathBase    : WSTRING(128) := 'SD0:/logs/log';
    fileExt         : WSTRING(10)  := '.csv';
    currentPath     : WSTRING(255);
    buffer          : WSTRING(4000); // buffer em RAM
    bufferLen       : UDINT := 0;    // número de chars no buffer
    maxBufferChars  : UDINT := 2000; // ajuste
    flushPeriod     : TIME := T#5s;   // flush a cada 5s
    flushTimer      : TON;
    hFile           : UDINT := 0;
    written         : UDINT;
    maxFileSize     : UDINT := 1024 * 1024 * 5; // 5 MB
    tempPath        : WSTRING(255);
    fileIndex       : UINT := 0;
    isOpen          : BOOL := FALSE;
END_VAR

// Inicialização (uma vez)
IF NOT Enable THEN
    // nada
ELSE
    IF NOT isOpen THEN
        // montar nome de arquivo atual (ex.: log_0.csv)
        currentPath := CONCAT(filePathBase, '_');
        currentPath := CONCAT(currentPath, UINT_TO_WSTRING(fileIndex));
        currentPath := CONCAT(currentPath, fileExt);
        // open in append (or create)
        hFile := SysFileOpen(currentPath, SysFileOpenMode.WriteOnlyAppend);
        IF hFile <> 0 THEN
            isOpen := TRUE;
        ELSE
            // tratar erro
        END_IF
    END_IF
END_IF

// Função pública: AppendLine (chamar de outros POUs)
METHOD AppendLine
VAR_INPUT
    line : WSTRING;
END_VAR
// Append to buffer
buffer := CONCAT(buffer, line);
bufferLen := LEN(buffer);

// Se buffer grande, forçar flush
IF bufferLen >= maxBufferChars THEN
    self.Flush(); // chamar método interno
END_IF

// Flush periódico via timer
flushTimer(IN := TRUE, PT := flushPeriod);
IF flushTimer.Q THEN
    self.Flush();
    flushTimer(IN := FALSE); // reinicia timer
END_IF

// Método Flush (grava buffer no arquivo)
METHOD Flush : BOOL
VAR
    bytesToWrite : UDINT;
    w : UDINT;
    res : UDINT;
    size : UDINT;
END_VAR
IF NOT isOpen THEN
    // tenta abrir
    hFile := SysFileOpen(currentPath, SysFileOpenMode.WriteOnlyAppend);
    IF hFile = 0 THEN
        Flush := FALSE;
        RETURN;
    ELSE
        isOpen := TRUE;
    END_IF
END_IF

// Verificar rotação por tamanho
res := SysFileGetSize(hFile, ADR(size));
IF (res = 0) AND (size >= maxFileSize) THEN
    // fechar, renomear, incrementar índice e abrir novo
    SysFileClose(hFile);
    tempPath := CONCAT(currentPath, '.old');
    SysFileRename(currentPath, tempPath);
    fileIndex := fileIndex + 1;
    currentPath := CONCAT(filePathBase, '_');
    currentPath := CONCAT(currentPath, UINT_TO_WSTRING(fileIndex));
    currentPath := CONCAT(currentPath, fileExt);
    hFile := SysFileOpen(currentPath, SysFileOpenMode.WriteOnlyCreate);
    isOpen := (hFile <> 0);
END_IF

// Escrever buffer (UTF-16LE)
bytesToWrite := LEN(buffer) * 2; // chars * 2 bytes
res := SysFileWrite(hFile, ADR(buffer), bytesToWrite, ADR(w));
IF res = 0 THEN
    // sucesso
    // esvaziar buffer
    buffer := '';
    bufferLen := 0;
    Flush := TRUE;
ELSE
    // erro
    Flush := FALSE;
END_IF
```

Notas:
- Este exemplo é um esqueleto; adapte tratamento de erros, retries e conversões.
- Se preferir arquivos UTF-8, implemente conversão de WSTRING para UTF8 (byte array) antes de SysFileWrite.
- Rotação: simples renomeação; para robustez, escrever em arquivo temporário e renomear depois de fechar.

---

## Tratamento de erros e watchdogs

- Sempre checar o valor de retorno de SysFile* e `SysFileGetLastError()` para diagnóstico.  
- Monitor de espaço livre: se disco ficar cheio, enviar alarme e parar gravações.  
- Watchdog de escrita: se não conseguir gravar por N tentativas, acionar alarme operador.  
- Registro de falhas local em RAM (circular buffer) para diagnóstico até que SD volte disponível.

---

## Atomicidade e rotação segura de arquivos

- Técnica segura para evitar arquivos corrompidos:
  1. Escrever em arquivo temporário `log.tmp` (ou `log_YYYYMMDD.tmp`).
  2. Fechar o arquivo.
  3. Renomear `log.tmp` → `log_YYYYMMDD.csv` (SysFileRename).
- Ao appendar grande quantidade: escrever em `file.new`, depois renomear e deletar antigo.
- Para updates de firmware / powerloss: ter journal (arquivo de transações) e aplicar/reconstruir na inicialização se necessário.

---

## Considerações sobre formato (UTF-16 vs UTF-8)

- Escrever WSTRING via `SysFileWrite(ADR(wstring), LEN*2)` produz **UTF‑16LE**. Muitos editores conseguem ler, mas sistemas externos preferem **UTF‑8** ou **ASCII**.  
- Para gerar UTF‑8:
  - Use biblioteca de conversão (se disponível) ou implemente conversão manual (mapear codepoints; not trivial se houver caracteres Unicode).  
  - Depois escreva o array de bytes UTF-8 com `SysFileWrite`.

---

## Performance e desgaste do microSD

- Bufferizar e agrupar escritas para reduzir número de operações.  
- Não use `SysFileOpen`/`SysFileClose` para cada linha — mantenha arquivo aberto e só feche em flush/rotação/shutdown.  
- Evite écritas contínuas em pequenos blocos (muitos pequenos writes) — preferir uma escrita maior de vez em quando.  
- Considere usar FIFO em RAM e um worker que grava periodicamente.

---

## Checklist de implantação

- [ ] Confirmar caminho do microSD no target (testar manualmente).  
- [ ] Incluir bibliotecas `SysFile` e `SysTimeRtc` no projeto.  
- [ ] Testar criação, escrita, leitura e remoção de arquivos via CODESYS.  
- [ ] Implementar buffering e flush periódico (ex.: a cada 5 s ou 100 linhas).  
- [ ] Implementar rotação de arquivos por tamanho/data.  
- [ ] Testar cenários: remoção/remoção do cartão durante gravação, falta de espaço, reboot durante escrita.  
- [ ] Instrumentar logs de diagnóstico (erros de FS).  
- [ ] Documentar no manual do sistema instruções para manutenção do microSD (format, mount, backup).

---

## Exemplo rápido de checklist de código a testar

- Criar arquivo no SD  
- Escrever 100 linhas CSV com timestamp  
- Fechar e reabrir; ler e verificar contagem de linhas  
- Simular disco cheio e verificar comportamento (não travar o PLC)  
- Remover SD durante gravação e reconectar; garantir recuperação

---

## Conclusão

Gravar logs em microSD a partir do CODESYS é direto quando se usa `SysFile`. As principais preocupações são:
- Escolher o caminho correto do dispositivo (mount point);  
- Minimizar e agrupar gravações para proteger a memória flash;  
- Implementar buffering, flush periódico, rotação e tratamento robusto de erros;  
- Garantir interoperabilidade de encoding (UTF-8 recomendado);  
- Testar sob condições reais (powerloss, remoção do cartão).

Se quiser, eu posso:
- Gerar um FB completo pronto para importação no seu projeto (FB_SDLogger com interface pública AppendLine/Flush/Rotate);  
- Fornecer um utilitário de conversão WSTRING→UTF8 em ST;  
- Preparar um diagrama de fluxo de logs (buffer → flush → rotate → archive).

Qual desses prefere que eu gere agora?