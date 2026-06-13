-- O setor de marketing quer mapear a concentração de clientes por estado. 
-- Liste a sigla do estado, o nome da cidade, a quantidade de clientes únicos 
-- com endereço cadastrado naquela cidade. Exiba apenas cidades com 
-- pelo menos 50 clientes, ordenando por estado e depois pelo total de clientes 
-- de forma decrescente.

select est.sigla as estado
	  ,cid.descricao as cidade
      ,count(distinct pf.id) as Qtde_clientes
from geral.pessoa_fisica pf 
inner join endereco as ende on pf.id = ende.id_pessoa 
inner join bairro as bairro on ende.id_bairro = bairro.id 
inner join cidade as cid on bairro.id_cidade = cid.id 
inner join estado as est on cid.id_estado = est.id 
group by estado,cidade
having count(distinct pf.id) >= 50
order by Qtde_clientes desc



