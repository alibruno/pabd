-- =============================================
-- Questão 1: Cadastro de Cliente e Perfil
-- =============================================

BEGIN;

INSERT INTO customer(first_name, last_name)
VALUES ('Vinícius', 'Souza');

ROLLBACK;

-- Resposta:
-- Não existe e seus dados serão desconsiderados, pois fere a integridade dos dados definidos na tabela.


-- =============================================
-- Questão 2: Gestão de Estoque e Suprimentos
-- =============================================

-- Transsação

BEGIN;

SAVEPOINT estoque_atualizado;

INSERT INTO inventory(film_id, store_id)
VALUES (32767, 1);

ROLLBACK TO estoque_atualizado;

INSERT INTO inventory(film_id, store_id)
VALUES (1, 1);

COMMIT;

-- Consulta

SELECT * FROM inventory ORDER BY inventory_id DESC LIMIT 5;

-- Resposta:
-- Após o COMMIT, a tabela armazenou somente o valor válido. Com o SAVEPOINT, foi possível restaurar o estoque original e 
-- manter a transação ativa, possibilitando a continuar fazendo as operações necessárias. Sem esse marcador, uma grande 
-- quantidade de dados seria perdida caso houvesse pelo menos um erro.