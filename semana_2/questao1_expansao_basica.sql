SELECT e.id
      ,e.codigo
      ,e.nomecredor
      ,(clf->>'codigoTipoClassificador')::int 		as cod_tipo
      ,clf->>'nomeTipoClassificador' 				as nome_tipo
      ,clf->>'nomeClassificador' 					as valor_classificador
from public.empenhos e 
cross join lateral jsonb_array_elements(e.classificadores::jsonb) as clf
-- Resultado sem limit: 26704036 linhas 
