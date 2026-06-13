--Contexto
--A auditoria solicita um resumo anual de todos os empenhos com status CONTABILIZADO,
--mostrando quantos empenhos foram realizados e qual o valor total empenhado em cada ano.
--O resultado deve estar ordenado do ano mais recente para o mais antigo.

SELECT
    ano,
    COUNT(*) AS qtd_empenhos,
    SUM(valor) AS total_empenhado
FROM empenhos
WHERE statusdocumento = 'CONTABILIZADO'
GROUP BY ano
ORDER BY ano DESC;
