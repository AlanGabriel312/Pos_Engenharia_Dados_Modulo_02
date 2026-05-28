-- O diretor comercial quer identificar os melhores vendedores. 
-- Liste o nome de cada vendedor, a quantidade de notas fiscais emitidas, 
-- o valor total vendido e o ticket médio por venda. Ordenando do maior total para o menor.

select pf.nome as Nome_Vendedor 
	  ,count(nf.numero_nf) as Qtde_Notas_Fiscais
	  ,sum(nf.valor) as Valor_Total_vendido
	  ,avg(nf.valor) as ticket_medio
from vendas.nota_fiscal as nf
inner join geral.pessoa_fisica as pf on nf.id_vendedor = pf.id
group by pf.nome 
order by sum(nf.valor) DESC
