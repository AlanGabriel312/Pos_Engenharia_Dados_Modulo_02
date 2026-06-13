-- O setor financeiro precisa de um extrato das notas fiscais emitidas. 
-- Liste o número da nota fiscal, a data da venda, o nome do cliente, 
-- o nome do vendedor e a forma de pagamento utilizada. Ordene da 
-- venda mais recente para a mais antiga.

select nf.numero_nf as Numero_Nota_Fiscal
	  ,nf.data_venda as Data_Venda
	  ,pfc.nome as Nome_Cliente
	  ,pfv.nome as Nome_Vendedor
	  ,nf.id_forma_pagto as Forma_Pagamento
from vendas.nota_fiscal as nf
inner join geral.pessoa_fisica as pfv on nf.id_vendedor = pfv.id
inner join geral.pessoa_fisica as pfc on nf.id_cliente = pfc.id
order by Data_Venda DESC
