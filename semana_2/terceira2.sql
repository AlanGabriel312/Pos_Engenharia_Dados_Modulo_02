SELECT e.id
    ,e.codigo
    ,e.nomecredor
    ,(item->>'valor')::numeric as valor_item
    ,(clf->>'codigoTipoClassificador')::int as cod_tipo
    ,clf->>'nomeTipoClassificador' as nome_tipo
    ,clf->>'nomeClassificador' as valor_classificador
from public.empenhos e
cross join lateral jsonb_array_elements(e.itens::jsonb) as item
cross join lateral jsonb_array_elements(item->'classificadores') as clf
limit 100
