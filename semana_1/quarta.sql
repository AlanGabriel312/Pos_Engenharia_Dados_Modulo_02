-- O setor de compras quer saber quais categorias de produto 
-- geram maior lucro bruto total 
-- (soma de valor_venda_real − valor_unitario × quantidade por item vendido). 
-- Liste a categoria, o total de unidades vendidas e o lucro bruto total. 
-- Exiba apenas categorias com lucro acima de R$ 500,00, ordenado do maior lucro para o menor.

SELECT ctg.descricao AS categoria,
       SUM(inotaf.quantidade) AS quantidade_vendida,
       SUM(inotaf.valor_venda_real - (pdt.valor_custo * inotaf.quantidade)) AS lucro_bruto
FROM vendas.item_nota_fiscal AS inotaf
INNER JOIN vendas.produto AS pdt ON inotaf.id_produto = pdt.id
INNER JOIN vendas.categoria AS ctg ON pdt.id_categoria = ctg.id
GROUP BY ctg.descricao
HAVING SUM(inotaf.valor_venda_real - (pdt.valor_custo * inotaf.quantidade)) > 500.00
ORDER BY lucro_bruto DESC;

