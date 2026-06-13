select e.id
	  ,e.codigo
	  ,clf->>'nomeTipoClassificador'		as nome_tipo_classificador
	  ,clf->>'nomeClassificador'			as valor_classificador
	  ,parcela								as parcela_valor
from public.empenhos e 
cross join lateral jsonb_array_elements(e.classificadores::jsonb)		as clf
cross join lateral jsonb_array_elements_text(clf->'valoresClassificador')	as parcela
where(clf->>'codigoTipoClassificador')::int = 33
-- Resultado sem limit: 5505516 de linhas
