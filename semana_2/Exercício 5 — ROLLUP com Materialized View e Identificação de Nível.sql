--Contexto
--O painel executivo precisa de um relatório de três níveis em uma única query, usando a
--Materialized View mv_empenho_ug_mes para melhor performance. O relatório deve apresentar
--para o ano de 2024:

SELECT
    CASE
        WHEN GROUPING(nome_ug) = 0 AND GROUPING(trimestre) = 0 THEN 'Detalhe'
        WHEN GROUPING(nome_ug) = 0 AND GROUPING(trimestre) = 1 THEN 'Sub UG'
        WHEN GROUPING(nome_ug) = 1 AND GROUPING(trimestre) = 1 THEN 'Total Geral'
    END AS nivel,
    COALESCE(nome_ug, '-- todas --') AS nome_ug,
    COALESCE('Q' || trimestre::text, '-- todas --') AS trimestre,
    COUNT(*) AS qtd,
    SUM(total_empenhado) AS total
FROM dm.mv_empenho_ug_mes
WHERE ano = 2024
GROUP BY ROLLUP(nome_ug, trimestre)
ORDER BY nome_ug NULLS LAST, trimestre NULLS LAST;

