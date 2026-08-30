-- 1.	Liste os produtos com preço superior a R$ 1000.
SELECT * FROM products 
WHERE price > 1000;

-- 2.	Liste os produtos ordenados pelo preço, do maior para o menor.
SELECT * FROM products
ORDER BY price DESC;

-- 3.	Aumente o preço de todos os produtos da `Dell` em 10%.
UPDATE products
SET price = price * 1.1
WHERE name LIKE '%Dell%';

-- 4.	Exclua todos os produtos que sejam do tipo `Macbook`.
DELETE FROM products
WHERE name LIKE '%Macbook%';

-- 5.	Exclua um produto que não possua pedidos associados.
DELETE FROM products
WHERE NOT EXISTS (
    SELECT *
    FROM orders_products op 
    WHERE op.product_id = products.id
);

-- 6.	Liste todos os pedidos realizados nos últimos 30 dias.
SELECT * FROM orders
WHERE order_date >= NOW() - INTERVAL '30 days';

-- 7.	Liste os pedidos e os respectivos nomes de usuário.
SELECT
    u.name user_name,
    o.id order_id,
    o.order_date,
    o.status order_status,
    o.total
FROM orders o
JOIN users u ON o.user_id = u.id;

-- 8.	Liste todos os usuários e seus pedidos, inclusive usuários sem pedidos.
SELECT
    u.name user_name,
    o.id order_id,
    o.order_date,
    o.status order_status,
    o.total
FROM orders o
RIGHT JOIN users u ON o.user_id = u.id
ORDER BY u.name, o.id NULLS LAST;

-- 9.	Liste todos os usuários (id, nome e email) que realizaram pelo menos um pedido.
SELECT 
    u.id,
    u.name,
    u.email
FROM users u
WHERE EXISTS (
    SELECT *
    FROM orders o 
    WHERE o.user_id = u.id
);

-- 10.	Liste produtos que nunca foram vendidos.

    /*
    Caso 1: Existe pedido associado? 
    Caso 2: Se tiver pedido associado, todos foram cancelados 
            e portanto não foram vendidos?
    
    Exemplo:

    order.id = {1, 2, 3, 4}
    product.id = {1, 2, 3, 4}
    orders_products = { 
        o.id = 1 | p.id = 1 | o.status = paid, 
        o.id = 2 | p.id = 2 | o.status = canceled,
        o.id = 3 | p.id = 2 | o.status = paid,
        o.id = 4 | p.id = 3 | o.status = canceled,
    }
    
    4 - 1º filtro - não tem pedido associado
    3 - 2º filtro - tem pedido associado mas todos foram cancelados
    */

SELECT * FROM products p
WHERE EXISTS (
    SELECT *
    FROM orders_products op
    JOIN orders o ON op.order_id = o.id
    WHERE 
        op.product_id <> p.id
        OR (op.product_id = p.id AND o.status = 'canceled')
);

-- 11.	Liste usuários que nunca realizaram pedidos.
-- 12.	Liste os produtos com preço acima da média em ordem decrescente.
-- 13.	Liste a quantidade de pedidos realizados por cada usuário.
-- 14.	Listar os três produtos mais vendidos.
-- 15.	Gerar um relatório com: usuários, quantidade de pedidos e valor total comprado.