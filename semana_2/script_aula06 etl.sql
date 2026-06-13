-- =====================================================================
-- DATA MART DE EMPENHOS — Script 02: Carga via INSERT INTO ... SELECT
-- Fonte: tabelas públicas do schema public
--   • public.empenhos
--   • public.unidade_gestora
-- Banco: PostgreSQL 14+
-- =====================================================================
-- ORDEM DE EXECUÇÃO (respeita dependências de FK):
--   1. dim_tempo
--   2. dim_unidade_gestora
--   3. dim_credor
--   4. dim_natureza_despesa
--   5. dim_fonte_recurso
--   6. dim_programa_trabalho
--   7. dim_produto
--   8. fato_empenho	
--   9. refresh mv_empenho_ug_mes
-- =====================================================================

BEGIN;

-- ─────────────────────────────────────────────────────────────────────
-- 1. DIM_TEMPO
-- Gera um calendário completo para o intervalo de anos presentes
-- nos empenhos. Usa generate_series para não depender de tabela aux.
-- ─────────────────────────────────────────────────────────────────────
INSERT INTO dm.dim_tempo (
    sk_tempo, data_completa, dia, mes_num, mes_nome,
    trimestre, semestre, ano, dia_semana, flag_fds
)
SELECT
    TO_CHAR(d, 'YYYYMMDD')::INTEGER         AS sk_tempo,
    d::DATE                                 AS data_completa,
    EXTRACT(DAY   FROM d)::SMALLINT         AS dia,
    EXTRACT(MONTH FROM d)::SMALLINT         AS mes_num,
    TO_CHAR(d, 'TMMonth')                   AS mes_nome,
    EXTRACT(QUARTER FROM d)::SMALLINT       AS trimestre,
    CASE WHEN EXTRACT(MONTH FROM d) <= 6
         THEN 1 ELSE 2 END::SMALLINT        AS semestre,
    EXTRACT(YEAR  FROM d)::SMALLINT         AS ano,
    TO_CHAR(d, 'TMDay')                     AS dia_semana,
    CASE WHEN EXTRACT(ISODOW FROM d) IN (6,7)
         THEN 1 ELSE 0 END::SMALLINT        AS flag_fds
FROM generate_series(
    DATE_TRUNC('year', (SELECT MIN(dataemissao::date) FROM public.empenhos)),
    DATE_TRUNC('year', (SELECT MAX(dataemissao::date) FROM public.empenhos))
        + INTERVAL '1 year - 1 day',
    INTERVAL '1 day'
) AS d
ON CONFLICT (sk_tempo) DO NOTHING;

-- ─────────────────────────────────────────────────────────────────────
-- 2. DIM_UNIDADE_GESTORA
-- Fonte primária: public.unidade_gestora (dados mais completos)
-- Fallback: public.empenhos (UGs ausentes no cadastro)
-- ─────────────────────────────────────────────────────────────────────
INSERT INTO dm.dim_unidade_gestora (
    codigo_ug, nome_ug, sigla_ug, tipo_ug, poder, municipio
)
SELECT DISTINCT ON (codigo_ug)
    codigo_ug, nome_ug, sigla_ug, tipo_ug, poder, municipio
FROM (
    -- Prioridade 1: tabela de cadastro
    SELECT
        ug.codigo        AS codigo_ug,
        ug.titulo        AS nome_ug,
        ug.sigla         AS sigla_ug,
        ug.tipoug        AS tipo_ug,
        ug.nomepoder     AS poder,
        ug.nomemunicipio AS municipio,
        1                AS prioridade
    FROM public.unidade_gestora ug
    WHERE ug.codigo IS NOT NULL

    UNION ALL

    -- Prioridade 2: fallback dos empenhos
    SELECT
        e.codigoug  AS codigo_ug,
        e.nomeug    AS nome_ug,
        NULL, NULL, NULL, NULL,
        2           AS prioridade
    FROM public.empenhos e
    WHERE e.codigoug IS NOT NULL
) src
ORDER BY codigo_ug, prioridade
ON CONFLICT (codigo_ug) DO UPDATE SET
    nome_ug   = EXCLUDED.nome_ug,
    sigla_ug  = COALESCE(EXCLUDED.sigla_ug,  dm.dim_unidade_gestora.sigla_ug),
    tipo_ug   = COALESCE(EXCLUDED.tipo_ug,   dm.dim_unidade_gestora.tipo_ug),
    poder     = COALESCE(EXCLUDED.poder,     dm.dim_unidade_gestora.poder),
    municipio = COALESCE(EXCLUDED.municipio, dm.dim_unidade_gestora.municipio);

-- ─────────────────────────────────────────────────────────────────────
-- 3. DIM_CREDOR
-- Deduplica por documento. Usa o nome mais recente (SCD Tipo 1).
-- Detecta pessoa física: CPF tem 11 dígitos numéricos.
-- ─────────────────────────────────────────────────────────────────────
INSERT INTO dm.dim_credor (
    documento, nome_credor, tipo_pessoa
)
SELECT
    codigocredor AS documento,
    (ARRAY_AGG(nomecredor ORDER BY dataemissao DESC NULLS LAST))[1] AS nome_credor,
    CASE WHEN LENGTH(REGEXP_REPLACE(codigocredor, '\D', '', 'g')) = 11
         THEN 'FISICA' ELSE 'JURIDICA'
    END AS tipo_pessoa
FROM public.empenhos
WHERE codigocredor IS NOT NULL
  AND codigocredor <> 'NULL'
GROUP BY codigocredor
ON CONFLICT (documento) DO UPDATE SET
    nome_credor = EXCLUDED.nome_credor;

-- ─────────────────────────────────────────────────────────────────────
-- 4. DIM_NATUREZA_DESPESA
-- Extrai classificador tipo 33 do JSON e decompõe a hierarquia.
-- ─────────────────────────────────────────────────────────────────────
INSERT INTO dm.dim_natureza_despesa (
    codigo_natureza,
    categoria, grupo, modalidade_aplicacao, elemento,
    descricao_categoria, descricao_grupo, descricao_elemento
)
SELECT DISTINCT
    clf->>'nomeClassificador'               AS codigo_natureza,
    clf->'valoresClassificador'->>0         AS categoria,
    clf->'valoresClassificador'->>1         AS grupo,
    clf->'valoresClassificador'->>2         AS modalidade_aplicacao,
    clf->'valoresClassificador'->>3         AS elemento,

    CASE clf->'valoresClassificador'->>0
        WHEN '3' THEN 'Despesas Correntes'
        WHEN '4' THEN 'Despesas de Capital'
        WHEN '9' THEN 'Reserva de Contingência'
    END AS descricao_categoria,

    CASE clf->'valoresClassificador'->>1
        WHEN '1' THEN 'Pessoal e Encargos Sociais'
        WHEN '2' THEN 'Juros e Encargos da Dívida'
        WHEN '3' THEN 'Outras Despesas Correntes'
        WHEN '4' THEN 'Investimentos'
        WHEN '5' THEN 'Inversões Financeiras'
        WHEN '6' THEN 'Amortização da Dívida'
    END AS descricao_grupo,

    NULL AS descricao_elemento

FROM public.empenhos e,
     LATERAL jsonb_array_elements(e.classificadores::jsonb) AS clf
WHERE (clf->>'codigoTipoClassificador')::int = 33
  AND clf->>'nomeClassificador' IS NOT NULL
ON CONFLICT (codigo_natureza) DO NOTHING;

-- ─────────────────────────────────────────────────────────────────────
-- 5. DIM_FONTE_RECURSO
-- Extrai classificador tipo 28 do JSON.
-- ─────────────────────────────────────────────────────────────────────
INSERT INTO dm.dim_fonte_recurso (
    codigo_fonte, tipo_fonte, subtipo_fonte, descricao_fonte
)
SELECT DISTINCT
    clf->>'nomeClassificador'           AS codigo_fonte,
    clf->'valoresClassificador'->>0     AS tipo_fonte,
    clf->'valoresClassificador'->>1     AS subtipo_fonte,
    CASE clf->'valoresClassificador'->>0
        WHEN '1' THEN 'Recursos Ordinários'
        WHEN '2' THEN 'Recursos Vinculados'
        WHEN '3' THEN 'Recursos Próprios Estaduais'
        WHEN '5' THEN 'Recursos Próprios'
        WHEN '6' THEN 'Recursos Vinculados Estaduais'
        WHEN '7' THEN 'Transferências Federais'
        WHEN '8' THEN 'Operações de Crédito'
        ELSE          'Outros Recursos'
    END AS descricao_fonte
FROM public.empenhos e,
     LATERAL jsonb_array_elements(e.classificadores::jsonb) AS clf
WHERE (clf->>'codigoTipoClassificador')::int = 28
  AND clf->>'nomeClassificador' IS NOT NULL
ON CONFLICT (codigo_fonte) DO NOTHING;

-- ─────────────────────────────────────────────────────────────────────
-- 6. DIM_PROGRAMA_TRABALHO
-- Extrai classificador tipo 67 e decompõe a hierarquia funcional:
-- esfera.orgao.unid_orc.funcao.subfuncao.programa.acao
-- ─────────────────────────────────────────────────────────────────────
INSERT INTO dm.dim_programa_trabalho (
    codigo_programa,
    esfera, orgao, unidade_orcamentaria,
    funcao, subfuncao, programa, acao
)
SELECT DISTINCT
    clf->>'nomeClassificador'           AS codigo_programa,
    clf->'valoresClassificador'->>0     AS esfera,
    clf->'valoresClassificador'->>1     AS orgao,
    clf->'valoresClassificador'->>2     AS unidade_orcamentaria,
    clf->'valoresClassificador'->>3     AS funcao,
    clf->'valoresClassificador'->>4     AS subfuncao,
    clf->'valoresClassificador'->>5     AS programa,
    clf->'valoresClassificador'->>6     AS acao
FROM public.empenhos e,
     LATERAL jsonb_array_elements(e.classificadores::jsonb) AS clf
WHERE (clf->>'codigoTipoClassificador')::int = 67
  AND clf->>'nomeClassificador' IS NOT NULL
ON CONFLICT (codigo_programa) DO NOTHING;

-- ─────────────────────────────────────────────────────────────────────
-- 7. DIM_PRODUTO
-- Explode o array JSON da coluna "produto".
-- ON CONFLICT garante idempotência em recargas incrementais.
-- ─────────────────────────────────────────────────────────────────────
INSERT INTO dm.dim_produto (
    id_produto_origem, nome_produto, unidade_fornecimento
)
WITH produtos_dedup AS (
    -- DISTINCT ON garante uma linha por id, priorizando
    -- o empenho mais recente (dataemissao DESC)
    SELECT DISTINCT ON ((prod->>'id')::INTEGER)
        (prod->>'id')::INTEGER                           AS id_produto_origem,
        prod->>'nomeProdutoGenerico'                     AS nome_produto,
        NULLIF(prod->>'unidadeFornecimentoGenerico', '') AS unidade_fornecimento
    FROM public.empenhos e,
         LATERAL jsonb_array_elements(e.produto::jsonb) AS prod
    WHERE prod->>'id' IS NOT NULL
      AND prod->>'nomeProdutoGenerico' IS NOT NULL
    ORDER BY (prod->>'id')::INTEGER, e.dataemissao DESC NULLS LAST
)
SELECT * FROM produtos_dedup
ON CONFLICT (id_produto_origem) DO UPDATE SET
    nome_produto         = EXCLUDED.nome_produto,
    unidade_fornecimento = EXCLUDED.unidade_fornecimento;

-- ─────────────────────────────────────────────────────────────────────
-- 8. FATO_EMPENHO
-- Une todas as dimensões resolvendo as surrogate keys via JOIN.
-- CTEs intermediárias isolam a extração do JSON para clareza.
-- ON CONFLICT DO NOTHING: seguro para recargas incrementais.
-- ─────────────────────────────────────────────────────────────────────
INSERT INTO dm.fato_empenho (
    sk_tempo_emissao,
    sk_tempo_contabilizacao,
    sk_ug,
    sk_credor,
    sk_natureza,
    sk_fonte,
    sk_programa,
    sk_produto,
    codigo_empenho,
    modalidade,
    status_documento,
    tipo_alteracao,
    cod_parcela,
    valor_empenhado,
    ano_exercicio
)
WITH

-- Resolve um classificador de cada tipo por empenho (via MAX para pegar o único valor)
clf_por_empenho AS (
    SELECT
        e.id,
        MAX(CASE WHEN (clf->>'codigoTipoClassificador')::int = 33
                 THEN clf->>'nomeClassificador' END) AS natureza,
        MAX(CASE WHEN (clf->>'codigoTipoClassificador')::int = 28
                 THEN clf->>'nomeClassificador' END) AS fonte,
        MAX(CASE WHEN (clf->>'codigoTipoClassificador')::int = 67
                 THEN clf->>'nomeClassificador' END) AS programa
    FROM public.empenhos e,
         LATERAL jsonb_array_elements(e.classificadores::jsonb) AS clf
    GROUP BY e.id
),

-- Primeiro produto de cada empenho (DISTINCT ON garante apenas um)
prod_por_empenho AS (
    SELECT DISTINCT ON (e.id)
        e.id,
        (prod->>'id')::INTEGER AS id_produto
    FROM public.empenhos e,
         LATERAL jsonb_array_elements(e.produto::jsonb) AS prod
    WHERE prod->>'id' IS NOT NULL
    ORDER BY e.id, (prod->>'id')::INTEGER
)

SELECT
    TO_CHAR(e.dataemissao::date, 'YYYYMMDD')::INTEGER   AS sk_tempo_emissao,

    CASE WHEN e.datacontabilizacao IS NOT NULL
              AND e.datacontabilizacao <> 'NULL'
         THEN TO_CHAR(e.datacontabilizacao::date, 'YYYYMMDD')::INTEGER
    END                                                  AS sk_tempo_contabilizacao,

    ug.sk_ug,
    cr.sk_credor,
    nat.sk_natureza,
    fnt.sk_fonte,
    prg.sk_programa,
    prd.sk_produto,

    e.codigo            AS codigo_empenho,
    e.modalidade,
    e.statusdocumento   AS status_documento,
    e.tipoalteracao     AS tipo_alteracao,
    e.codparcela        AS cod_parcela,
    e.valor             AS valor_empenhado,
    e.ano               AS ano_exercicio

FROM public.empenhos                  e
JOIN  dm.dim_unidade_gestora   ug  ON ug.codigo_ug          = e.codigoug
LEFT JOIN dm.dim_credor        cr  ON cr.documento           = e.codigocredor
LEFT JOIN clf_por_empenho      cp  ON cp.id                  = e.id
LEFT JOIN dm.dim_natureza_despesa  nat ON nat.codigo_natureza = cp.natureza
LEFT JOIN dm.dim_fonte_recurso     fnt ON fnt.codigo_fonte    = cp.fonte
LEFT JOIN dm.dim_programa_trabalho prg ON prg.codigo_programa = cp.programa
LEFT JOIN prod_por_empenho     pp  ON pp.id                  = e.id
LEFT JOIN dm.dim_produto       prd ON prd.id_produto_origem  = pp.id_produto

ON CONFLICT DO NOTHING;

COMMIT;

-- ─────────────────────────────────────────────────────────────────────
-- 9. REFRESH DA MATERIALIZED VIEW
-- Executar fora da transação principal.
-- CONCURRENTLY não bloqueia leituras durante o refresh.
-- ─────────────────────────────────────────────────────────────────────
REFRESH MATERIALIZED VIEW CONCURRENTLY dm.mv_empenho_ug_mes;

-- ─────────────────────────────────────────────────────────────────────
-- VERIFICAÇÃO PÓS-CARGA
-- ─────────────────────────────────────────────────────────────────────
SELECT 'dim_tempo'             AS tabela, COUNT(*) AS linhas FROM dm.dim_tempo
UNION ALL
SELECT 'dim_unidade_gestora',             COUNT(*) FROM dm.dim_unidade_gestora
UNION ALL
SELECT 'dim_credor',                      COUNT(*) FROM dm.dim_credor
UNION ALL
SELECT 'dim_natureza_despesa',            COUNT(*) FROM dm.dim_natureza_despesa
UNION ALL
SELECT 'dim_fonte_recurso',               COUNT(*) FROM dm.dim_fonte_recurso
UNION ALL
SELECT 'dim_programa_trabalho',           COUNT(*) FROM dm.dim_programa_trabalho
UNION ALL
SELECT 'dim_produto',                     COUNT(*) FROM dm.dim_produto
UNION ALL
SELECT 'fato_empenho',                    COUNT(*) FROM dm.fato_empenho
UNION ALL
SELECT 'mv_empenho_ug_mes',               COUNT(*) FROM dm.mv_empenho_ug_mes
ORDER BY tabela;