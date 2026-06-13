-- O gerente de vendas precisa de uma lista completa do catálogo de produtos com o 
-- nome da categoria de cada um. Liste o nome do produto, seu preço de venda, custo e 
-- o nome da categoria, ordenado pelo nome da categoria e depois pelo nome do produto.

SELECT pd.nome AS Nome_Produto,
       ctg.descricao AS Categoria_Produto,
       pd.valor_custo AS Custo_Produto,
       pd.valor_venda AS Venda_Produto
FROM vendas.produto AS pd
LEFT JOIN vendas.categoria AS ctg ON pd.id_categoria = ctg.id
ORDER BY ctg.descricao ASC, pd.nome ASC
