SELECT clf->>'nomeTipoClassificador' 				as nome_tipo
      ,clf->>'nomeClassificador' 					as valor_classificador
      ,count(distinct e.id)						    as qtde_empenhos
from public.empenhos e 
cross join lateral jsonb_array_elements(e.classificadores::jsonb) as clf
where (clf->>'codigoTipoClassificador')::int in (33,28) 
group by clf->>'nomeTipoClassificador',
		 clf->>'nomeClassificador'
order by qtde_empenhos DESC
-- Resultado sem limit: 237 linhas