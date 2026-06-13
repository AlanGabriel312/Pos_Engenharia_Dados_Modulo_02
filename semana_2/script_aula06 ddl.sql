-- =====================================================================
-- DATA MART DE EMPENHOS — GOVERNO DO ESTADO DO CEARÁ
-- Script 01: Criação do Schema e Tabelas
-- Modelo: Star Schema (Kimball)
-- Banco:  PostgreSQL 14+
-- =====================================================================

-- ─────────────────────────────────────────────────────────────────────
-- SCHEMA DEDICADO
-- ─────────────────────────────────────────────────────────────────────
CREATE SCHEMA IF NOT EXISTS dm;
COMMENT ON SCHEMA dm IS 'Data Mart de Empenhos do Estado do Ceará';


-- =====================================================================
-- DIMENSÕES
-- =====================================================================

-- ─────────────────────────────────────────────────────────────────────
-- DIM_TEMPO
-- Calendário completo — uma linha por dia
-- Grain: dia
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS dm.dim_tempo (
    sk_tempo        INTEGER         PRIMARY KEY,        -- surrogate key: YYYYMMDD
    data_completa   DATE            NOT NULL UNIQUE,
    dia             SMALLINT        NOT NULL,
    mes_num         SMALLINT        NOT NULL,
    mes_nome        VARCHAR(20)     NOT NULL,
    trimestre       SMALLINT        NOT NULL CHECK (trimestre BETWEEN 1 AND 4),
    semestre        SMALLINT        NOT NULL CHECK (semestre BETWEEN 1 AND 2),
    ano             SMALLINT        NOT NULL,
    dia_semana      VARCHAR(20)     NOT NULL,
    flag_fds        SMALLINT        NOT NULL DEFAULT 0 CHECK (flag_fds IN (0,1))
);

COMMENT ON TABLE  dm.dim_tempo           IS 'Dimensão calendário — grain: dia';
COMMENT ON COLUMN dm.dim_tempo.sk_tempo  IS 'Surrogate key no formato YYYYMMDD';
COMMENT ON COLUMN dm.dim_tempo.flag_fds  IS '1 = fim de semana, 0 = dia útil';


-- ─────────────────────────────────────────────────────────────────────
-- DIM_UNIDADE_GESTORA
-- Órgãos e entidades do Estado que realizam despesas
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS dm.dim_unidade_gestora (
    sk_ug           SERIAL          PRIMARY KEY,
    codigo_ug       VARCHAR(20)     NOT NULL UNIQUE,
    nome_ug         VARCHAR(200)    NOT NULL,
    -- campos enriquecíveis via join com unidade_gestora (produção)
    sigla_ug        VARCHAR(30),
    tipo_ug         VARCHAR(50),
    poder           VARCHAR(50),
    orgao_superior  VARCHAR(200),
    municipio       VARCHAR(100)
);

COMMENT ON TABLE dm.dim_unidade_gestora IS 'Dimensão das unidades gestoras do Estado';


-- ─────────────────────────────────────────────────────────────────────
-- DIM_CREDOR
-- Fornecedores e beneficiários dos empenhos
-- SCD Tipo 1 (sobrescreve) — nome pode mudar sem impacto histórico
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS dm.dim_credor (
    sk_credor       SERIAL          PRIMARY KEY,
    documento       VARCHAR(20)     NOT NULL UNIQUE,   -- CNPJ ou CPF
    nome_credor     VARCHAR(200)    NOT NULL,
    tipo_pessoa     VARCHAR(10)     DEFAULT 'JURIDICA' CHECK (tipo_pessoa IN ('FISICA','JURIDICA')),
    uf_credor       CHAR(2)
);

COMMENT ON TABLE  dm.dim_credor          IS 'Dimensão de credores (SCD Tipo 1)';
COMMENT ON COLUMN dm.dim_credor.documento IS 'CNPJ (14 dígitos) ou CPF (11 dígitos)';


-- ─────────────────────────────────────────────────────────────────────
-- DIM_NATUREZA_DESPESA
-- Classificação econômica da despesa (cat.grp.mod.elem)
-- Ex: 3.3.90.39 = Despesas Correntes > Outras Desp. Correntes > Outros S. Terceiros
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS dm.dim_natureza_despesa (
    sk_natureza             SERIAL          PRIMARY KEY,
    codigo_natureza         VARCHAR(20)     NOT NULL UNIQUE,
    categoria               CHAR(1),        -- 3 = Despesas Correntes, 4 = Capital
    grupo                   CHAR(1),        -- 1=Pessoal, 2=Juros, 3=OutrasDespCorr...
    modalidade_aplicacao    VARCHAR(5),     -- 90 = Aplicações Diretas
    elemento                VARCHAR(5),     -- 39 = Outros Serv. de Terceiros PJ
    descricao_categoria     VARCHAR(80),
    descricao_grupo         VARCHAR(80),
    descricao_elemento      VARCHAR(80)
);

COMMENT ON TABLE dm.dim_natureza_despesa IS 'Classificação econômica da despesa';


-- ─────────────────────────────────────────────────────────────────────
-- DIM_FONTE_RECURSO
-- Origem dos recursos que financiam a despesa
-- Ex: 5.00 = Recursos Próprios, 7.59 = Transferências Federais
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS dm.dim_fonte_recurso (
    sk_fonte            SERIAL          PRIMARY KEY,
    codigo_fonte        VARCHAR(10)     NOT NULL UNIQUE,
    tipo_fonte          CHAR(1),        -- 1=Ord, 5=Próprios, 6=Vinculados, 7=Transf.Fed
    subtipo_fonte       VARCHAR(5),
    descricao_fonte     VARCHAR(100)
);

COMMENT ON TABLE dm.dim_fonte_recurso IS 'Fonte de recurso que financia a despesa';


-- ─────────────────────────────────────────────────────────────────────
-- DIM_PROGRAMA_TRABALHO
-- Programa / ação orçamentária da despesa
-- Hierarquia: esfera > órgão > unid.orçamentária > função > subfunção > programa > ação
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS dm.dim_programa_trabalho (
    sk_programa             SERIAL          PRIMARY KEY,
    codigo_programa         VARCHAR(60)     NOT NULL UNIQUE,
    esfera                  VARCHAR(5),     -- 01 = Estadual
    orgao                   VARCHAR(15),
    unidade_orcamentaria    VARCHAR(15),
    funcao                  VARCHAR(5),     -- 03 = Essencial à Justiça
    subfuncao               VARCHAR(5),     -- 126 = Tecnologia da Informação
    programa                VARCHAR(10),
    acao                    VARCHAR(10)
);

COMMENT ON TABLE dm.dim_programa_trabalho IS 'Programa de trabalho orçamentário (classificação funcional)';


-- ─────────────────────────────────────────────────────────────────────
-- DIM_PRODUTO
-- Produto ou serviço adquirido via empenho
-- Origem: coluna "produto" (JSON) da tabela empenhos
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS dm.dim_produto (
    sk_produto          SERIAL          PRIMARY KEY,
    id_produto_origem   INTEGER         UNIQUE,        -- ID do sistema de origem
    nome_produto        VARCHAR(300)    NOT NULL,
    unidade_fornecimento VARCHAR(30)
);

COMMENT ON TABLE dm.dim_produto IS 'Produto ou serviço adquirido (origem: coluna produto JSON)';


-- =====================================================================
-- TABELA FATO
-- =====================================================================

-- ─────────────────────────────────────────────────────────────────────
-- FATO_EMPENHO
-- Grain: um registro por empenho (parcela)
-- Métricas: valor_empenhado (aditiva)
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS dm.fato_empenho (
    sk_empenho                  BIGSERIAL       PRIMARY KEY,

    -- Chaves estrangeiras para dimensões
    sk_tempo_emissao            INTEGER         REFERENCES dm.dim_tempo(sk_tempo),
    sk_tempo_contabilizacao     INTEGER         REFERENCES dm.dim_tempo(sk_tempo),
    sk_ug                       INTEGER         REFERENCES dm.dim_unidade_gestora(sk_ug),
    sk_credor                   INTEGER         REFERENCES dm.dim_credor(sk_credor),
    sk_natureza                 INTEGER         REFERENCES dm.dim_natureza_despesa(sk_natureza),
    sk_fonte                    INTEGER         REFERENCES dm.dim_fonte_recurso(sk_fonte),
    sk_programa                 INTEGER         REFERENCES dm.dim_programa_trabalho(sk_programa),
    sk_produto                  INTEGER         REFERENCES dm.dim_produto(sk_produto),

    -- Dimensões degeneradas (atributos sem dimensão própria)
    codigo_empenho              VARCHAR(20)     NOT NULL,
    modalidade                  VARCHAR(20),    -- ORDINARIO, ESTIMATIVO, GLOBAL
    status_documento            VARCHAR(30),    -- CONTABILIZADO, CANCELADO
    tipo_alteracao              VARCHAR(20),    -- NENHUMA, ANULACAO
    cod_parcela                 VARCHAR(20),    -- degenerate dimension

    -- Métricas
    valor_empenhado             NUMERIC(18,2),  -- ADITIVA: soma em todas as dimensões

    -- Atributo de particionamento
    ano_exercicio               SMALLINT        NOT NULL
);

COMMENT ON TABLE  dm.fato_empenho               IS 'Fato empenho — grain: uma linha por empenho/parcela';
COMMENT ON COLUMN dm.fato_empenho.valor_empenhado IS 'Métrica aditiva — pode ser somada em qualquer dimensão';
COMMENT ON COLUMN dm.fato_empenho.codigo_empenho  IS 'Dimensão degenerada — código do empenho no sistema de origem';
COMMENT ON COLUMN dm.fato_empenho.cod_parcela     IS 'Dimensão degenerada — código da parcela';


-- =====================================================================
-- ÍNDICES
-- =====================================================================

-- Acesso por data (queries temporais são as mais frequentes)
CREATE INDEX IF NOT EXISTS idx_fato_tempo_emissao  ON dm.fato_empenho(sk_tempo_emissao);
CREATE INDEX IF NOT EXISTS idx_fato_tempo_contab   ON dm.fato_empenho(sk_tempo_contabilizacao);

-- Acesso por dimensões analíticas principais
CREATE INDEX IF NOT EXISTS idx_fato_ug             ON dm.fato_empenho(sk_ug);
CREATE INDEX IF NOT EXISTS idx_fato_credor         ON dm.fato_empenho(sk_credor);
CREATE INDEX IF NOT EXISTS idx_fato_natureza       ON dm.fato_empenho(sk_natureza);
CREATE INDEX IF NOT EXISTS idx_fato_fonte          ON dm.fato_empenho(sk_fonte);
CREATE INDEX IF NOT EXISTS idx_fato_programa       ON dm.fato_empenho(sk_programa);

-- Índice parcial para status mais consultado
CREATE INDEX IF NOT EXISTS idx_fato_contabilizado
    ON dm.fato_empenho(sk_ug, sk_tempo_emissao)
    WHERE status_documento = 'CONTABILIZADO';

-- Índice composto para queries com ano + UG
CREATE INDEX IF NOT EXISTS idx_fato_ano_ug
    ON dm.fato_empenho(ano_exercicio, sk_ug);

-- Lookups nas dimensões
CREATE INDEX IF NOT EXISTS idx_dim_tempo_ano_mes
    ON dm.dim_tempo(ano, mes_num);

CREATE INDEX IF NOT EXISTS idx_dim_ug_codigo
    ON dm.dim_unidade_gestora(codigo_ug);

CREATE INDEX IF NOT EXISTS idx_dim_credor_doc
    ON dm.dim_credor(documento);


-- =====================================================================
-- MATERIALIZED VIEW — Totais pré-agregados (atualizar mensalmente)
-- =====================================================================
CREATE MATERIALIZED VIEW IF NOT EXISTS dm.mv_empenho_ug_mes AS
SELECT
    t.ano,
    t.mes_num,
    t.mes_nome,
    t.trimestre,
    u.codigo_ug,
    u.nome_ug,
    n.codigo_natureza,
    COUNT(*)                    AS qtd_empenhos,
    SUM(f.valor_empenhado)      AS total_empenhado,
    AVG(f.valor_empenhado)      AS media_valor,
    MIN(f.valor_empenhado)      AS menor_valor,
    MAX(f.valor_empenhado)      AS maior_valor
FROM dm.fato_empenho         f
JOIN dm.dim_tempo            t ON t.sk_tempo = f.sk_tempo_emissao
JOIN dm.dim_unidade_gestora  u ON u.sk_ug    = f.sk_ug
JOIN dm.dim_natureza_despesa n ON n.sk_natureza = f.sk_natureza
WHERE f.status_documento = 'CONTABILIZADO'
GROUP BY t.ano, t.mes_num, t.mes_nome, t.trimestre,
         u.codigo_ug, u.nome_ug, n.codigo_natureza;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_ug_mes
    ON dm.mv_empenho_ug_mes(ano, mes_num, codigo_ug, codigo_natureza);

COMMENT ON MATERIALIZED VIEW dm.mv_empenho_ug_mes
    IS 'Totais pré-agregados por UG e mês. Refresh: REFRESH MATERIALIZED VIEW CONCURRENTLY dm.mv_empenho_ug_mes;';