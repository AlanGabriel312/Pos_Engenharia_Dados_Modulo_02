--Contexto
--A Secretaria de Planejamento precisa de uma análise cruzada dos empenhos contabilizados
--em 2023 e 2024 mostrando, para cada combinação de Fonte de Recurso e Natureza de
--Despesa, o total empenhado em cada ano — em formato de tabela pivô (uma coluna por ano).
--Exiba apenas combinações que tiveram empenhos nos dois anos.

select
r.codigo_fonte,
r.descricao_fonte as fonte_recurso,
n.codigo_natureza, 
n.descricao_categoria as natureza_despesa,
SUM(CASE WHEN t.ano = 2023 THEN f.valor_empenhado END) as total_2023,
SUM(CASE WHEN t.ano = 2024 THEN f.valor_empenhado END) as total_2024
FROM dm.fato_empenho f
JOIN dm.dim_tempo t 
	ON t.sk_tempo = f.sk_tempo_emissao
JOIN dm.dim_natureza_despesa   n 
	ON n.sk_natureza = f.sk_natureza
JOIN dm.dim_fonte_recurso r
	ON r.sk_fonte = f.sk_fonte -- verificar essa chave pois nao sei o nome da coluna correta no banco
WHERE t.ano in (2023,2024)
	AND f.status_documento   = 'CONTABILIZADO'
GROUP BY r.codigo_fonte, r.descricao_fonte,n.codigo_natureza, n.descricao_categoria  
HAVING     SUM(CASE WHEN t.ano = 2023 THEN f.valor_empenhado END) IS NOT NULL
   AND SUM(CASE WHEN t.ano = 2024 THEN f.valor_empenhado END) IS NOT NULL
ORDER BY total_2024 desc;
