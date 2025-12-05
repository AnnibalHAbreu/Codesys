# Nota Técnica — Ordem e Boas Práticas de Declaração de Variáveis no CODESYS (IEC 61131‑3)

**Autor:** AnnibalHAbreu  
**Data:** 2025-12-05  
**Versão:** 1.0

Resumo  
Esta nota técnica documenta a ordem recomendada de declaração de variáveis em POUs (FUNCTION_BLOCK, FUNCTION, PROGRAM) e em GVLs (Global Variable Lists) no ambiente CODESYS / IEC 61131‑3, explica o significado de cada seção de variável, exemplifica com código Structured Text (ST) e lista boas práticas, armadilhas comuns e um checklist de migração/implantação.

---

## Sumário
- [1. Objetivo](#1-objetivo)  
- [2. Visão geral das seções de variáveis](#2-visão-geral-das-seções-de-variáveis)  
- [3. Ordem recomendada por POU](#3-ordem-recomendada-por-pou)  
- [4. Descrição de cada seção](#4-descrição-de-cada-seção)  
- [5. Exemplos práticos em ST (FUNCTION_BLOCK / FUNCTION / PROGRAM / GVL)](#5-exemplos-práticos-em-st-function_block--function--program--gvl)  
- [6. Atributos e declarações especiais (AT, RETAIN, PERSISTENT, BYTE_ORDER)](#6-atributos-e-declarações-especiais-at-retain-persistent-byte_order)  
- [7. Boas práticas e regras de estilo](#7-boas-práticas-e-regras-de-estilo)  
- [8. Armadilhas e cuidados comuns](#8-armadilhas-e-cuidados-comuns)  
- [9. Checklist de migração / implantação](#9-checklist-de-migração--implantação)  
- [10. Templates prontos](#10-templates-prontos)  
- [11. Referências rápidas](#11-referências-rápidas)

---

## 1. Objetivo
Fornecer orientações claras e práticas sobre a ordem e o uso de blocos de declaração de variáveis em CODESYS, de forma a melhorar legibilidade, evitar erros de escopo e garantir comportamento previsível de inicialização e persistência.

---

## 2. Visão geral das seções de variáveis
As seções mais comuns (por POU ou GVL) são:

- VAR_INPUT — parâmetros de entrada (somente leitura dentro do POU)  
- VAR_OUTPUT — parâmetros de saída (o POU fornece)  
- VAR_IN_OUT — parâmetros por referência (passagem por referência)  
- VAR — variáveis locais / estado interno (FB: persistem enquanto a instância existir)  
- VAR_TEMP — variáveis temporárias (não persistem; uso para cálculos transitórios)  
- VAR CONSTANT — constantes locais (quando aplicável)  
- VAR RETAIN / VAR PERSISTENT — variáveis que persistem após reset/energia (quando suportado)  
- VAR_EXTERNAL — referência a variáveis definidas externamente (GVL)  
- VAR_GLOBAL, VAR_GLOBAL CONSTANT, VAR_GLOBAL RETAIN — declarações em GVL (Global Variable List)

Observação: a sintaxe exata pode variar ligeiramente com a versão do CODESYS. Sempre valide na sua versão.

---

## 3. Ordem recomendada por POU
(esta é a ordem que recomendo seguir por clareza e convenção)

1. VAR_INPUT  
2. VAR_OUTPUT  
3. VAR_IN_OUT  
4. VAR_CONSTANT (opcional)  
5. VAR (estado local / variáveis persistentes de instância)  
6. VAR_RETAIN / VAR_PERSISTENT (quando aplicável, ou em blocos separados)  
7. VAR_TEMP  
8. VAR_EXTERNAL (quando necessário)

Explicação: colocar os parâmetros de interface (input/output/in_out) no topo facilita a leitura da interface do POU. Em seguida, o estado (VAR) e variáveis de retenção. VAR_TEMP por fim porque são auxiliares de execução.

---

## 4. Descrição de cada seção

- VAR_INPUT  
  - Entradas fornecidas pelo chamador.  
  - Somente leitura dentro do POU (boa prática: não modificar).  
  - Usado para parâmetros funcionais do bloco.

- VAR_OUTPUT  
  - Saídas que o POU atribui.  
  - Representam resultados, estados ou sinais a serem lidos pelo chamador.

- VAR_IN_OUT  
  - Passagem por referência. Alterações visíveis ao chamador.  
  - Usar com cuidado (efeito colateral).

- VAR  
  - Variáveis locais ou de estado.  
  - Em FUNCTION_BLOCK representam estado persistente da instância.  
  - Em FUNCTION são locais re-inicializadas a cada chamada (não persistem entre chamadas).

- VAR_TEMP  
  - Para variáveis temporárias de execução.  
  - Geralmente não possuem garantia de valor inicial.  
  - Não usar para estado que deva persistir.

- VAR_CONSTANT / CONSTANT (quando suportado)  
  - Constantes locais. Recomenda-se declarar constantes globais em GVL ou em blocos TYPE/CONST separados.

- VAR RETAIN / VAR PERSISTENT  
  - Variáveis que devem reter valor após power-cycle ou reset parcial.  
  - Usar apenas para valores realmente necessários (ex.: acumuladores, flags de modo).  
  - Algumas CPUs implementam limites/áreas específicas para retain.

- VAR_EXTERNAL  
  - Declaração usada para referenciar variáveis globais declaradas em outro POU/GVL.  
  - Não define a variável, apenas a referencia.

- VAR_GLOBAL / GVL  
  - Global Variable List (arquivo .gvl) contém VAR_GLOBAL, VAR_GLOBAL CONSTANT e VAR_GLOBAL RETAIN.  
  - Preferir variáveis globais apenas quando necessário (diagnóstico, parâmetros de sistema).

---

## 5. Exemplos práticos em ST (FUNCTION_BLOCK / FUNCTION / PROGRAM / GVL)

### 5.1 FUNCTION_BLOCK — exemplo completo
```iecst
FUNCTION_BLOCK FB_Pump
VAR_INPUT
    Enable      : BOOL;
    SP_kW       : REAL;    // setpoint [kW]
END_VAR

VAR_OUTPUT
    RunCmd      : BOOL;
    Status      : INT;
END_VAR

VAR_IN_OUT
    SharedCfg   : CONFIG_TYPE; // referenciado por referência
END_VAR

VAR
    Integral    : REAL;   // estado interno -> persiste na instância
    PrevErr     : REAL;
    InitDone    : BOOL := FALSE; // inicialização controlada
END_VAR

VAR_TEMP
    tmpSum      : REAL;   // cálculo temporário
    tmpLimit    : REAL;
END_VAR
END_FUNCTION_BLOCK
```

### 5.2 FUNCTION — exemplo
```iecst
FUNCTION AddInts : INT
VAR_INPUT
    A : INT;
    B : INT;
END_VAR

VAR
    tmp : INT;
END_VAR

tmp := A + B;
AddInts := tmp;
END_FUNCTION
```

### 5.3 PROGRAM — exemplo (top-level)
```iecst
PROGRAM PLC_PRG
VAR
    cycleCounter : UDINT := 0;
    pumpFB       : FB_Pump; // instância do FB
    setLocalSP   : REAL := 10.0;
END_VAR

// lógica do programa...
```

### 5.4 GVL — Global Variable List (GlobalVariables.gvl)
```iecst
VAR_GLOBAL CONSTANT
    PI        : REAL := 3.141592653589793;
END_VAR

VAR_GLOBAL RETAIN
    TotalEnergy_kWh : REAL := 0.0; // persiste entre ciclos
END_VAR

VAR_GLOBAL
    SystemMode : INT := 0;
    DebugEnable: BOOL := FALSE;
END_VAR
```

### 5.5 VAR_EXTERNAL — uso
```iecst
// em um POU qualquer
VAR_EXTERNAL
    SystemMode : INT; // referenciando o SystemMode do GVL
END_VAR
```

---

## 6. Atributos e declarações especiais (AT, RETAIN, PERSISTENT, BYTE_ORDER)

- AT %QX, %MX, %MW, %MD, %IB, etc.  
  - Mapear variáveis a endereços físicos (uso em I/O diretas e integração com hardware).  
  - Use com cuidado e documente o mapeamento.

- RETAIN / PERSISTENT  
  - VAR RETAIN / VAR_GLOBAL RETAIN retêm valores após reset/energia (dependente do hardware).  
  - Verifique capacidade de memória de retenção do controlador.

- PERSISTENT vs RETAIN  
  - Alguns targets usam PERSISTENT (armazenamento em flash) — considerar limites de ciclos de gravação.

- BYTE_ORDER  
  - Ao mapear WORDS para FLOAT32/INT32 leia a ordem de bytes do dispositivo; use conversões explícitas (WORD -> DWORD -> REAL) com parâmetros de ordem.

- IEC_DERIVE, DERIVE, e outros atributos de compilador  
  - Usados para gerar metadados; evite abusar sem entender o impacto.

---

## 7. Boas práticas e regras de estilo

- Sempre declare VAR_INPUT / VAR_OUTPUT no topo do POU (documenta interface).  
- Use nomes descritivos e prefixos (ex.: bEnable, rSetpoint_kW, iStatus).  
- Inicialize variáveis quando apropriado (ex.: := 0, := FALSE) — lembre que VAR_TEMP e VAR em FUNCTION podem não ser inicializados conforme o contexto.  
- Evite VAR_GLOBAL excessivo; prefira passagem por parâmetros (VAR_IN_OUT) quando possível.  
- Use VAR RETAIN apenas quando necessário (evitar writes flash constantes).  
- Documente cada variável com comentário (propósito, unidade, escala).  
- Separe constantes em um GVL CONSTANT ou em um arquivo de TYPE/CONSTANT.  
- Evite usar VAR_EXTERNAL se a arquitetura puder ser redesenhada para injeção de dependências via parâmetros.

---

## 8. Armadilhas e cuidados comuns

- Confundir VAR (estado do FB) com VAR em FUNCTION (não persistente).  
- Acreditar que VAR_TEMP é sempre inicializado — não confie em valores iniciais para lógica crítica.  
- Declarar muitos VAR_GLOBALs e criar acoplamento indesejado.  
- Usar RETAIN sem conhecer limites do controlador (memória de retenção limitada).  
- Mapear variáveis com AT sem documentar offsets/endereços — causa dificuldade de manutenção.  
- Alterar ordem de declaração esperando que inicialização siga ordem — compilador/target podem tratar inicialização de forma diferente.

---

## 9. Checklist de migração / implantação

Antes de mover variáveis para GVL ou refatorar POUs:

- [ ] Identificar variáveis que realmente precisam ser globais.  
- [ ] Converter constantes para GVL CONSTANT.  
- [ ] Mover estado persistente de FBs para VAR (FB) ou VAR RETAIN conforme necessidade.  
- [ ] Substituir VAR_GLOBAL por VAR_IN_OUT quando possível (reduz acoplamento).  
- [ ] Verificar inicialização/retentividade em CPU alvo.  
- [ ] Documentar endereços AT e blocos RETAIN.  
- [ ] Testar inicialização a frio e warm restart (validação de RETAIN).  
- [ ] Incluir comentários para cada variável com unidade e escala.

---

## 10. Templates prontos

### 10.1 Template FUNCTION_BLOCK completo
```iecst
FUNCTION_BLOCK FB_Template
VAR_INPUT
    bEnable    : BOOL;
    rSP        : REAL;
END_VAR

VAR_OUTPUT
    bRunning   : BOOL;
    iStatus    : INT;
END_VAR

VAR_IN_OUT
    cfg        : CONFIG_TYPE;
END_VAR

VAR
    rIntegral  : REAL := 0.0;
    rPrevErr   : REAL := 0.0;
    bInitDone  : BOOL := FALSE;
END_VAR

VAR_TEMP
    rTmp       : REAL;
END_VAR
END_FUNCTION_BLOCK
```

### 10.2 Template PROGRAM
```iecst
PROGRAM PLC_PRG
VAR
    mainCounter : UDINT := 0;
    fbControl   : FB_Template;
END_VAR

// lógica...
```

### 10.3 Template GVL
```iecst
VAR_GLOBAL CONSTANT
    MAX_POWER_kW : REAL := 100.0;
END_VAR

VAR_GLOBAL RETAIN
    AccumulatedEnergy_kWh : REAL := 0.0;
END_VAR

VAR_GLOBAL
    SystemMode : INT := 0; // 0 = Manual, 1 = Automatic
END_VAR
```

---

## 11. Referências rápidas

- IEC 61131‑3 — Programming languages — Structured Text / VAR semantics  
- CODESYS Documentation — Variable Declaration and Retain Memory  
- Manuais do fabricante do controlador — limites e políticas RETAIN/PERSISTENT  
- Exemplos CODESYS: GVL e POUs templates

---

## 12. Conclusão
Seguir uma ordem lógica e consistente de declaração de variáveis melhora legibilidade, facilita a manutenção e reduz erros de escopo/initialization. Use GVLs com parcimônia, prefira parâmetros bem definidos (VAR_INPUT/VAR_OUTPUT/VAR_IN_OUT) e aplique RETAIN apenas quando necessário e compatível com o hardware.

---

Se desejar, eu gero:
- Um arquivo `.st` com esses templates já populado;  
- Um checklist exportável (CSV) com variáveis a migrar;  
- Exemplos adicionais com conversão de WORD->REAL respeitando byte order.  

Qual opção prefere?  