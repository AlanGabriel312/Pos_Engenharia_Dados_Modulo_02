EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT *
FROM empenhos e
JOIN ordem_bancaria_orcamentaria obo
ON e.codigo = obo.codigone AND e.codigoug = obo.codigoug
JOIN unidade_gestora ug
ON ug.codigo = e.codigoug AND ug.ano = e.ano;