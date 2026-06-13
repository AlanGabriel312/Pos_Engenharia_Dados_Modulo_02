--Contexto
--O controle interno quer identificar, dentro de cada Unidade Gestora, os 5 credores que
--receberam os maiores valores em empenhos contabilizados durante o ano de 2025. O
--resultado deve mostrar a posição do credor dentro de cada UG e o percentual que ele
--representa sobre o total da UG.

WITH ranking_credores AS (
    select ug.nome_ug,
           c.nome_credor,
           SUM(f.valor_empenhado) AS total_credor,
           RANK() OVER (PARTITION BY f.sk_ug ORDER BY SUM(f.valor_empenhado) DESC) AS ranking,
           ROUND((SUM(f.valor_empenhado) * 100.0) /SUM(SUM(f.valor_empenhado)) OVER (PARTITION BY f.sk_ug),2) AS pct_ug
    FROM dm.fato_empenho f
    JOIN dm.dim_tempo t
        ON t.sk_tempo = f.sk_tempo_emissao
    JOIN dm.dim_unidade_gestora ug
        ON ug.sk_ug = f.sk_ug
    JOIN dm.dim_credor c
        ON c.sk_credor = f.sk_credor
    WHERE t.ano = 2025 AND f.status_documento = 'CONTABILIZADO'
    GROUP BY f.sk_ug, ug.nome_ug, c.nome_credor
)
SELECT *
FROM ranking_credores
WHERE ranking <= 5
ORDER by nome_ug,ranking;
