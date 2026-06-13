SELECT e.id
      ,e.codigo
      ,e.nomecredor
      ,e.valor as valor_total_empenho
      ,(item->>'valor')::numeric as valor_item
      ,item->>'classificadoresStr' as classificadores_resumo
from public.empenhos e 
cross join lateral jsonb_array_elements(e.itens::jsonb) as item
limit 100