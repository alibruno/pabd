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
