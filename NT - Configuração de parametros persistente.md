# Nota Técnica — Parâmetro de Sistema Persistente para IHM no CODESYS

**Autor:** AnnibalHAbreu  
**Data:** 2025-12-05  
**Versão:** 1.0

Resumo  
Explica como declarar, expor à IHM e persistir um parâmetro do sistema que possa ser definido/alterado via IHM e que mantenha o valor após reset/desligamento do PLC (persistência). Inclui exemplos práticos em Structured Text (GVL + lógica de persistência), considerações sobre RETAIN vs PERSISTENT, desgaste de memória flash, atomicidade, validação e boas práticas de UX na IHM.

---

## 1. Requisitos funcionais (resumo)
- Usuário ajusta um parâmetro via IHM (ex.: porcentagem limite, modo, setpoint).
- Valor novo deve ser aplicado imediatamente na aplicação (runtime).
- Valor somente é gravado de forma persistente após confirmação (evitar gravações contínuas).
- Valor persistente sobrevive a reboot/desligamento do PLC.
- Evitar desgaste excessivo de flash (minimizar gravações).
- Oferecer mecanismo de confirmação/rollback e indicação de status na IHM.

---

## 2. Conceitos CODESYS relevantes

- VAR_GLOBAL RETAIN / VAR_GLOBAL PERSISTENT
  - VAR_GLOBAL RETAIN: armazena valor em área de retenção (RAM retida por bateria ou área não volátil); comportamento depende do target.
  - VAR_GLOBAL PERSISTENT: algumas plataformas usam este atributo para persistência em flash; comportamento dependente do runtime/target.
- VAR (runtime): variável em uso normal — muda rapidamente e não necessariamente é persistida.
- Estratégia recomendada: separar variável runtime (usada pela aplicação) da variável persistente (RETAIN). Faça confirmação explícita para gravar persistente.
- Evitar gravações constantes em RETAIN/PERSISTENT: dependendo do hardware, gravações podem causar desgaste em memória flash.

---

## 3. Padrão recomendado (arquitetura)

- GVL (Global Variable List) declara:
  - `Param_Runtime` — variável usada pela aplicação e IHM (não necessariamente retain).
  - `Param_Persist` — variável `VAR_GLOBAL RETAIN` (persistente) que guarda o valor confirmado.
  - `Param_SaveRequest` — flag (boolean) acionada pela IHM para solicitar gravação persistente.
  - `Param_SaveAck` / `Param_SaveError` — flags de status para feedback na IHM.
- Startup:
  - Ao inicializar, copiar `Param_Persist` → `Param_Runtime`.
- Flow de alteração:
  1. Usuário altera `Param_Runtime` via IHM (edição).
  2. A aplicação usa imediatamente `Param_Runtime` (sem gravar persistente).
  3. Usuário confirma ("Salvar") → IHM aciona `Param_SaveRequest := TRUE`.
  4. Procedimento de gravação valida, grava `Param_Persist := Param_Runtime`, sinaliza `Param_SaveAck := TRUE` ou `Param_SaveError := TRUE`.
  5. Opcional: gravação com debounce para evitar múltiplas gravações consecutivas.
- Proteção:
  - Validação de range antes de gravar.
  - Retry limitado em falhas.
  - Registro de versão do parâmetro se houver mudanças de estrutura.

---

## 4. Exemplo prático (GVL + lógica ST)

Abaixo um exemplo realista em ST. Ajuste nomes/types conforme seu projeto.

```iecst
// File: GlobalParameters.gvl
VAR_GLOBAL
    // Variável usada em tempo de execução (visível na IHM)
    SysParam_SetpointPct_Runtime : REAL := 50.0; // % (0..100)

    // Flag de controle exposta à IHM
    SysParam_SaveRequest : BOOL := FALSE;  // IHM seta TRUE para pedir persistência
    SysParam_SaveAck     : BOOL := FALSE;  // Aplique ACK quando gravação suceder
    SysParam_SaveError   : BOOL := FALSE;  // Indica falha ao tentar salvar
END_VAR

VAR_GLOBAL RETAIN
    // Valor persistente que sobrevive reboot
    SysParam_SetpointPct_Persist : REAL := 50.0; // valor salvo
    // Pode declarar também um número de versão para migração
    SysParam_Version : UINT := 1;
END_VAR
```

Máquina simples para gerenciar o pedido de gravação (em um POU, executando em Task de aplicação):

```iecst
PROGRAM ParamPersistenceManager
VAR
    saveTimeout : TON;
    retryCount  : INT := 0;
    MAX_RETRIES : INT := 2;
    VALID_MIN   : REAL := 0.0;
    VALID_MAX   : REAL := 100.0;
END_VAR

// On startup (executar uma vez) copie persistente para runtime
IF NOT FirstScanDone THEN
    SysParam_SetpointPct_Runtime := SysParam_SetpointPct_Persist;
    FirstScanDone := TRUE;
END_IF

// Se a IHM pedir salvar:
IF SysParam_SaveRequest THEN
    // Clear status flags
    SysParam_SaveAck := FALSE;
    SysParam_SaveError := FALSE;

    // Validação de range
    IF (SysParam_SetpointPct_Runtime >= VALID_MIN) AND (SysParam_SetpointPct_Runtime <= VALID_MAX) THEN
        // Gravar no campo persistente
        SysParam_SetpointPct_Persist := SysParam_SetpointPct_Runtime;

        // Opcional: incrementar versão para migração futura
        SysParam_Version := SysParam_Version + 1;

        // Sinalizar sucesso
        SysParam_SaveAck := TRUE;
        SysParam_SaveError := FALSE;

        // Limpar pedido de gravação (IHM deve ler ACK antes de resetar)
        SysParam_SaveRequest := FALSE;

    ELSE
        // Valor inválido — não gravar
        SysParam_SaveAck := FALSE;
        SysParam_SaveError := TRUE;
        // manter SysParam_SaveRequest TRUE para que IHM possa tratar erro
    END_IF
END_IF
```

Observações:
- A atribuição a `SysParam_SetpointPct_Persist` grava o valor em área retain/persistent gerenciada pelo runtime.
- Em alguns targets, a escrita em RETAIN pode ser gravada a cada mudança em RAM retida; em outros, RETAIN é mantido em RAM de bateria. Consulte seu hardware.
- Para targets que escrevem em flash, minimizar frequência de gravação é essencial (usar botão "Salvar" em vez de gravar a cada alteração de campo).

---

## 5. Exemplo com "Salvar com confirmação" (melhor prática UX)

Fluxo IHM:
- Usuário edita campo `SysParam_SetpointPct_Runtime` (ou uma cópia local na IHM).
- Ao clicar "Aplicar" a aplicação usa o valor (temporariamente).
- Ao clicar "Salvar" na IHM, `SysParam_SaveRequest := TRUE`.
- A aplicação executa validação e grava `SysParam_SetpointPct_Persist`.
- A aplicação coloca `SysParam_SaveAck := TRUE` por N segundos; IHM exibe "Salvo com sucesso" e limpa o pedido.

Código ST (palavras-chave):
```iecst
// Em loop principal
IF SysParam_SaveRequest THEN
    IF Validate(SysParam_SetpointPct_Runtime) THEN
        SysParam_SetpointPct_Persist := SysParam_SetpointPct_Runtime;
        SysParam_SaveAck := TRUE;
        SysParam_SaveRequest := FALSE;
    ELSE
        SysParam_SaveError := TRUE;
        // manter SaveRequest para que IHM mostre erro
    END_IF
END_IF
```

Sugestão: após SysParam_SaveAck = TRUE, use um temporizador ou campo de status para indicar ACK por 2–5 segundos, então limpar SysParam_SaveAck.

---

## 6. RETAIN vs PERSISTENT — diferenças e implicações

- RETAIN: geralmente memorizado em RAM retida (bateria/RTC) ou em área não volátil do controlador; leitura rápida; gravações não necessariamente escrevem flash a cada alteração (depende do target). Ideal para variáveis que mudam ocasionalmente.
- PERSISTENT: algumas implementações escrevem persistent em flash; útil quando RETAIN não sobrevive a certas condições (ex.: firmware update). Porém, gravações em flash têm ciclo de escrita limitado.
- Recomendações:
  - Verifique documentação do fabricante do PLC (CODESYS runtime target) para entender o comportamento exato de RETAIN/PERSISTENT.
  - Se o target grava RETAIN em RAM retida, você tem menos preocupação com desgaste de flash.
  - Se grava em flash, minimize gravações: use confirmação manual e debounce.

---

## 7. Considerações sobre desgaste de memória (flash)

- Flash tem limite de ciclos de escrita (ex.: 10000 a 100000 ciclos dependendo do tipo).
- Evite gravações automáticas a cada pequena alteração de parâmetro (ex.: sliders na IHM).
- Padrões para minimizar desgaste:
  - Gravação apenas quando usuário confirma ("Salvar").
  - Debounce: só gravar se valor diferir do persistido por mais que threshold e se último save tiver ocorrido há mais que X segundos.
  - Agrupar múltiplos parâmetros em único bloco persistente (economiza writes).
  - Implementar contadores de gravação e alarmes se alto número de writes detectado.

Exemplo de debounce lógico:
```iecst
IF (ABS(SysParam_SetpointPct_Runtime - SysParam_SetpointPct_Persist) > 0.1) AND (TimeSinceLastSave > T#30s) THEN
    // permitir gravação automática (se desejado)
END_IF
```

---

## 8. Atomicidade, versionamento e migração

- Se persistir estrutura de múltiplos parâmetros, grave um bloco único (registro/struct) para garantir atomicidade — evita estados parciais após falha no meio da gravação.
- Use campo `Version` (UINT) para permitir migração de dados persistent quando atualizar aplicação:
  - Ao detectar versão antiga no boot, executar rotina de migração (transformar valores antigos para novo formato).
- Exemplo de struct persistente:

```iecst
TYPE T_ParamBlock :
STRUCT
    SetpointPct : REAL;
    Mode        : BYTE;
    Version     : UINT;
END_STRUCT
END_TYPE

VAR_GLOBAL RETAIN
    SysParamBlock : T_ParamBlock := (SetpointPct := 50.0, Mode := 0, Version := 1);
END_VAR
```

---

## 9. Expor variáveis na IHM (CODESYS Visualization / Webvisu / HMI device)

- Em CODESYS Visualization você pode ligar diretamente controles a variáveis globais (GVL). Expor `SysParam_SetpointPct_Runtime` para edição e `SysParam_SaveAck`/`SaveError` para feedback.
- Melhor UX:
  - Campo de edição do valor + botão "Aplicar" (aplica em runtime).
  - Botão "Salvar" (dispara `SysParam_SaveRequest`).
  - Indicadores "Valor salvo" / "Erro ao salvar".
  - Bloqueio de edição enquanto gravação em curso (disable controls enquanto `SysParam_SaveRequest = TRUE`).
- Segurança: proteja funções de gravação com senha/nível de usuário se necessário.

---

## 10. Segurança, concorrência e acesso remoto

- Se existir múltiplas fontes de alteração (IHM local, IHM remota, serviço SCADA), definir regras de prioridade e controle de concorrência:
  - Usar flags `LastWriterTimestamp` e `LastWriterID` para auditoria.
  - Implementar lock/lease se necessário (`Param_EditLock` boolean com timestamp).
- Registro de alterações (audit trail) útil para troubleshooting:
  - Guardar histórico com quem, quando e valor anterior.

---

## 11. Boas práticas resumidas

- Separe runtime vs persistente; não escreva persistente a cada alteração.
- Use confirmação explícita para salvar em memória não volátil.
- Valide valores antes de persistir.
- Debounce e agrupe gravações para proteger flash.
- Expor variáveis claras na IHM com feedback (ACK/Erro).
- Versão do bloco persistente para permitir migração.
- Testar reboot frio/warm para garantir comportamento esperado.

---

## 12. Checklist rápido para implementar parâmetro persistente

- [ ] Declarar `VAR_GLOBAL RETAIN` (ou PERSISTENT se necessário) para o valor salvo.  
- [ ] Declarar `VAR_GLOBAL` runtime para uso imediato e edição pela IHM.  
- [ ] Implementar rotina de cópia no startup: `Persist -> Runtime`.  
- [ ] Implementar fluxo de SaveRequest/SaveAck com validação e retry.  
- [ ] Expor variáveis na IHM (edição, aplicar, salvar, feedback).  
- [ ] Adicionar debounce/limitação de gravações para proteger flash.  
- [ ] Testar: alteração, salvar, reboot, validar persistência e rollback.  
- [ ] Documentar no manual de operação instruções de como salvar parâmetros.

---

## 13. Conclusão

Para um parâmetro que o usuário deve alterar pela IHM e que precisa sobreviver a reset/desligamento, a prática segura é:

1. Declarar uma variável persistente (`VAR_GLOBAL RETAIN` / PERSISTENT) que armazena o valor confirmado.  
2. Expor e usar uma variável runtime (não persistente) para edição/aplicação imediata.  
3. Forçar gravação persistente somente quando o usuário confirmar (botão "Salvar") ou seguindo regras controladas (debounce, agrupamento).  
4. Tratar validação, versionamento e prevenção de gravações excessivas para reduzir desgaste de memória.

---

Se quiser, eu gero agora:
- Um arquivo `GlobalParameters.gvl` pronto para importar no seu projeto;  
- A tela modelo da IHM (Visualização CODESYS) com botões "Aplicar" e "Salvar" ligada às variáveis;  
- Um exemplo de rotina de migração de versão para o bloco persistente.  

Qual opção prefere que eu gere automaticamente?  