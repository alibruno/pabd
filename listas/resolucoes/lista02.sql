-- Questão 01 - View de Performance da Equipe

DROP VIEW IF EXISTS v_staff_performance;
CREATE VIEW v_staff_performance 
AS
    SELECT
        st.staff_id,
        COALESCE(st.first_name, '') || ' ' || COALESCE(st.last_name, '') AS full_name,
        COALESCE(ci.city, 'Undefined city') AS city,
        COALESCE(co.country, 'Undefined country') AS country,
        COALESCE(SUM(pa.amount), 0.0) AS total_amount
    FROM
        staff AS st
        LEFT JOIN address AS ad ON st.address_id = ad.address_id
        LEFT JOIN city AS ci ON ad.city_id = ci.city_id
        LEFT JOIN country AS co ON ci.country_id = co.country_id
        LEFT JOIN rental AS re ON st.staff_id = re.staff_id
        LEFT JOIN payment AS pa ON re.rental_id = pa.rental_id
    GROUP BY
        st.staff_id,
        st.first_name,
        st.last_name,
        ci.city,
        co.country;

SELECT * FROM v_staff_performance;



-- Questão 02 - View Materializada de Receita por Categoria
-- Materialized View com suporte à concorrência (uso de índice)

DROP MATERIALIZED VIEW mv_category_total_sales;
DROP INDEX IF EXISTS idx_mv_category_name;

CREATE MATERIALIZED VIEW mv_category_total_sales 
AS
    SELECT
        ca.name AS category_name,
        COALESCE(SUM(pa.amount), 0.0) AS total_sales
    FROM
        category AS ca
        JOIN film_category AS fc ON ca.category_id = fc.category_id
        JOIN film AS fm ON fc.film_id = fm.film_id
        JOIN inventory AS inv ON fm.film_id = inv.film_id
        JOIN rental AS re ON inv.inventory_id = re.inventory_id
        JOIN payment AS pa ON re.rental_id = pa.rental_id
    GROUP BY
        ca.name
    WITH DATA;

-- Indice para que a mv consiga recarregar seus dados de forma concorrente
CREATE UNIQUE INDEX idx_mv_category_name
ON mv_category_total_sales (category_name);

REFRESH MATERIALIZED VIEW CONCURRENTLY mv_category_total_sales;

SELECT * FROM mv_category_total_sales;



-- Questão 03 - Otimizando Filmes Atrasados

DROP INDEX IF EXISTS idx_rental_return_date_is_null;

CREATE INDEX idx_rental_return_date_is_null
ON rental (return_date)
WHERE return_date IS NULL;

EXPLAIN ANALYZE
SELECT * FROM rental WHERE return_date IS NULL;

-- Sem índice
/*
                                              QUERY PLAN
-------------------------------------------------------------------------------------------------------
 Seq Scan on rental  (cost=0.00..310.44 rows=183 width=36) (actual time=0.976..1.240 rows=183 loops=1)
   Filter: (return_date IS NULL)
   Rows Removed by Filter: 15861
 Planning Time: 0.076 ms
 Execution Time: 1.261 ms
(5 rows)
*/

-- Com índice parcial
/*
                                                                 QUERY PLAN
---------------------------------------------------------------------------------------------------------------------------------------------
 Index Scan using idx_rental_return_date_is_null on rental  (cost=0.14..37.45 rows=183 width=36) (actual time=0.022..0.049 rows=183 loops=1)
 Planning Time: 0.156 ms
 Execution Time: 0.065 ms
(3 rows)
*/



-- Questão 04 - Busca Inteligente de Sinopses

-- BTree não funciona para buscas com LIKE '%palavra%', apenas para 'palavra%'.
-- GIN, por padrão, não funciona para o tipo TEXT, presente no campo description.
-- Alterar o campo description de TEXT para tsvector e depois aplicar índice GIN continuará com buscas lentas, pois o tsvector não funciona para buscas com LIKE '%palavra%'

-- pg_trgm é uma extensão nativa do PostgreSQL que permite criar índices para buscas com LIKE '%palavra%'
-- GIN, com a extensão pg_trgm, funciona para buscas com LIKE '%palavra%'

DROP INDEX IF EXISTS idx_film_description_search;
DROP EXTENSION IF EXISTS pg_trgm;

CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX idx_film_description_search 
ON film USING gin (description gin_trgm_ops);

EXPLAIN ANALYZE
SELECT * FROM film
WHERE description
LIKE '%documentary%';

EXPLAIN ANALYZE
SELECT * FROM film
WHERE description
LIKE '%drama%';

EXPLAIN ANALYZE
SELECT * FROM film
WHERE description
LIKE '%act%';

/*
                                                              QUERY PLAN
---------------------------------------------------------------------------------------------------------------------------------------
 Bitmap Heap Scan on film  (cost=82.22..86.24 rows=1 width=662) (actual time=0.290..0.291 rows=0 loops=1)
   Recheck Cond: (description ~~ '%documentary%'::text)
   Rows Removed by Index Recheck: 101
   Heap Blocks: exact=44
   ->  Bitmap Index Scan on idx_film_description_search  (cost=0.00..82.22 rows=1 width=0) (actual time=0.111..0.111 rows=101 loops=1)
         Index Cond: (description ~~ '%documentary%'::text)
 Planning Time: 0.553 ms
 Execution Time: 0.328 ms
(8 rows)
*/

/*
                                                               QUERY PLAN                                                               
----------------------------------------------------------------------------------------------------------------------------------------
 Bitmap Heap Scan on film  (cost=13.01..84.89 rows=40 width=662) (actual time=0.060..0.224 rows=126 loops=1)
   Recheck Cond: (description ~~ '%act%'::text)
   Rows Removed by Index Recheck: 38
   Heap Blocks: exact=52
   ->  Bitmap Index Scan on idx_film_description_search  (cost=0.00..13.00 rows=40 width=0) (actual time=0.037..0.037 rows=164 loops=1)
         Index Cond: (description ~~ '%act%'::text)
 Planning Time: 0.152 ms
 Execution Time: 0.257 ms
(8 rows)
*/

-- Questão 05 - Histórico do Cliente

-- A primeira coluna do índice é customer_id pois a consulta é mais comum em relação a payment_date. 
-- Caso este não seja requisitado numa consulta, o index agirá sobre o customer_id.

DROP INDEX IF EXISTS idx_customer_payment_date;
CREATE INDEX idx_customer_payment_date
ON payment (customer_id, payment_date);

EXPLAIN ANALYZE
SELECT * 
FROM payment 
WHERE customer_id = 599
ORDER BY payment_date DESC;

EXPLAIN ANALYZE
SELECT * 
FROM payment 
WHERE customer_id = 599;

/*
                                                                QUERY PLAN                                                                
------------------------------------------------------------------------------------------------------------------------------------------
 Sort  (cost=121.91..122.09 rows=73 width=32) (actual time=0.052..0.055 rows=18 loops=1)
   Sort Key: payment_date DESC
   Sort Method: quicksort  Memory: 25kB
   ->  Bitmap Heap Scan on payment  (cost=4.85..119.65 rows=73 width=32) (actual time=0.032..0.040 rows=18 loops=1)
         Recheck Cond: (customer_id = 599)
         Heap Blocks: exact=3
         ->  Bitmap Index Scan on idx_customer_payment_date  (cost=0.00..4.83 rows=73 width=0) (actual time=0.023..0.023 rows=18 loops=1)
               Index Cond: (customer_id = 599)
 Planning Time: 0.320 ms
 Execution Time: 0.081 ms
(10 rows)
*/

/*
                                                             QUERY PLAN
------------------------------------------------------------------------------------------------------------------------------------
 Bitmap Heap Scan on payment  (cost=4.85..119.65 rows=73 width=32) (actual time=0.036..0.045 rows=18 loops=1)
   Recheck Cond: (customer_id = 599)
   Heap Blocks: exact=3
   ->  Bitmap Index Scan on idx_customer_payment_date  (cost=0.00..4.83 rows=73 width=0) (actual time=0.025..0.026 rows=18 loops=1)
         Index Cond: (customer_id = 599)
 Planning Time: 0.121 ms
 Execution Time: 0.070 ms
(7 rows)
*/



-- Questão 06 - Login Case-Insensitive

-- O EXPLAIN ANALYZE não aplica o índice pois há poucos registros (2) de staff.
-- Porém, quando há mais dados na tabela, o índice será utilizado e será mais performático que um Seq Scan.

DROP INDEX IF EXISTS idx_customer_email;
CREATE INDEX idx_customer_email
ON customer(LOWER(email));

EXPLAIN ANALYZE
SELECT * 
FROM customer 
WHERE LOWER(email) LIKE 'mary%';



-- Questão 07 - Validação de Datas

DROP TRIGGER IF EXISTS trg_insert_update_rental_return_date ON rental;
DROP FUNCTION IF EXISTS fn_insert_update_rental_return_date;

CREATE FUNCTION fn_insert_update_rental_return_date()
    RETURNS TRIGGER
    LANGUAGE PLPGSQL
AS $$
BEGIN
    IF NEW.rental_date IS NULL THEN
        RAISE EXCEPTION 'rental_date cannot be NULL';
    
    ELSIF NEW.return_date < NEW.rental_date THEN
        RAISE EXCEPTION 'rental_date cannot be ahead of return_date';
    
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_insert_update_rental_return_date
    BEFORE INSERT OR UPDATE
    ON rental
    FOR EACH ROW
    EXECUTE FUNCTION fn_insert_update_rental_return_date();

-- TESTES

SELECT * FROM rental WHERE rental_id = 16050;

-- INSERT OK
INSERT INTO rental (rental_date, inventory_id, customer_id, return_date, staff_id)
VALUES (now(), 1, 1, now() + interval '1 day', 1);

-- !(INSERT OK) - Chama o trigger
INSERT INTO rental (rental_date, inventory_id, customer_id, return_date, staff_id)
VALUES (now() + interval '1 day', 1, 1, now(), 1);

-- UPDATE OK
UPDATE rental
SET return_date = now() + interval '1 hour'
WHERE rental_id = 16050;

--!(UPDATE OK) - Chama o trigger
UPDATE rental
SET rental_date = now() + interval '7 hour'
WHERE rental_id = 16050;

-- INSERT NULL
INSERT INTO rental (rental_date, inventory_id, customer_id, staff_id)
VALUES (NULL, 1, 1, 1);



-- Questão 08 - Auditoria de Preços

-- Tipos da tabela film: \d+ film

DROP TRIGGER IF EXISTS trg_audit_film_cost ON film;
DROP FUNCTION IF EXISTS fn_audit_film_cost;
DROP TABLE IF EXISTS film_cost_audit;

CREATE TABLE film_cost_audit (
    film_cost_audit_id SERIAL PRIMARY KEY,
    film_id INT, 
    old_cost NUMERIC(5, 2), 
    new_cost NUMERIC(5, 2), 
    changed_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now()
);

CREATE FUNCTION fn_audit_film_cost()
    RETURNS TRIGGER
    LANGUAGE PLPGSQL
AS $$
BEGIN
    INSERT INTO film_cost_audit (film_id, old_cost, new_cost)
    VALUES (OLD.film_id, OLD.replacement_cost, NEW.replacement_cost);

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_audit_film_cost
    AFTER UPDATE
    ON film
    FOR EACH ROW
    WHEN (NEW.replacement_cost != OLD.replacement_cost)
    EXECUTE FUNCTION fn_audit_film_cost();

-- TESTES

SELECT * FROM film WHERE film_id = 1; 
--replacement_cost = 20.99

SELECT * FROM film_cost_audit WHERE film_id = 1;

-- UPDATE 1
UPDATE film
SET replacement_cost = 25.99
WHERE film_id = 1;

-- UPDATE 2 (Não atualiza o film_cost_audit)
UPDATE film
SET replacement_cost = 25.99
WHERE film_id = 1;



-- Questão 09 - Proteção de Catálogo

DROP TRIGGER IF EXISTS trg_prevent_delete_in_use_language ON language;
DROP FUNCTION IF EXISTS fn_prevent_delete_in_use_language;

CREATE FUNCTION fn_prevent_delete_in_use_language()
    RETURNS TRIGGER
    LANGUAGE PLPGSQL
AS $$
BEGIN
    IF EXISTS (
        SELECT language_id 
        FROM film AS f 
        WHERE f.language_id = OLD.language_id
    ) THEN
        RAISE EXCEPTION 'language cannot be deleted. There are films using it.';
    END IF;

    -- Obrigatório se passou pelo IF: autoriza o DELETE a prosseguir
    RETURN OLD;
END;
$$;

CREATE TRIGGER trg_prevent_delete_in_use_language
    BEFORE DELETE
    ON language
    FOR EACH ROW
    EXECUTE FUNCTION fn_prevent_delete_in_use_language();

-- DELETE chamando o trigger

DELETE FROM language WHERE language_id = 1;

-- Teste sem chamar o trigger

INSERT INTO language (name) VALUES ('Portuguese');
DELETE FROM language WHERE language_id = 7;



--- Questão 10 - Sincronização de Estatísticas

DROP TRIGGER IF EXISTS trg_update_increment_from_custumer_rental ON rental;
DROP FUNCTION IF EXISTS fn_update_increment_from_custumer_rental;
DROP TABLE IF EXISTS customer_rental_stats;

CREATE TABLE customer_rental_stats (
    customer_rental_stats_id SERIAL PRIMARY KEY,
    customer_id INT NOT NULL,
    total_rentals INT DEFAULT 0,

    CONSTRAINT fk_customer
        FOREIGN KEY (customer_id) 
        REFERENCES customer (customer_id)
        ON DELETE CASCADE
);

INSERT INTO customer_rental_stats (customer_id, total_rentals)
SELECT customer_id, COUNT(rental_id) FROM rental GROUP BY customer_id;

CREATE FUNCTION fn_update_increment_from_custumer_rental()
    RETURNS TRIGGER
    LANGUAGE PLPGSQL
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM customer_rental_stats AS c WHERE c.customer_id = NEW.customer_id
    ) THEN  
        INSERT INTO customer_rental_stats (customer_id, total_rentals) VALUES (NEW.customer_id, 1);
        RETURN NEW;
    END IF;

    UPDATE customer_rental_stats
    SET total_rentals = total_rentals + 1
    WHERE customer_id = NEW.customer_id;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_update_increment_from_custumer_rental
    AFTER INSERT
    ON rental
    FOR EACH ROW
    EXECUTE FUNCTION fn_update_increment_from_custumer_rental();

SELECT * FROM customer_rental_stats WHERE customer_id = 1;

INSERT INTO rental (rental_date, inventory_id, customer_id, staff_id)
VALUES (now(), 1, 1, 1);

-- Atual = 34
-- Após INSERT INTO = 35
