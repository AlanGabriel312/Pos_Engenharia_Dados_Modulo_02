SELECT e.id
      ,e.codigo
      ,e.nomecredor
      ,prod->>'nomeProdutoGenerico' as produto
      ,prod->>'descricaoProdutoGenerico' as descricao
      ,prod->>'unidadeFornecimentoGenerico' as unidade
      ,(prod->>'quantidade')::numeric as quantidade
      ,(prod->>'precoUnitario')::numeric as preco_unitario
      ,(prod->>'precoTotal')::numeric as preco_total
from public.empenhos e 
cross join lateral jsonb_array_elements(e.produto::jsonb) as prod
limit 100
