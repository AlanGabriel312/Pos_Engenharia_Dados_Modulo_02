--Contexto
--O gestor financeiro precisa de uma lista rápida de todas as Unidades Gestoras cadastradas no
--Data Mart, com a cidade onde estão localizadas e o tipo de poder (Executivo, Judiciário etc.),
--ordenada alfabeticamente pelo nome.

SELECT
    codigo_ug,
    nome_ug,
    poder,
    municipio
FROM dm.dim_unidade_gestora
WHERE municipio IS NOT NULL
ORDER BY nome_ug ASC;
