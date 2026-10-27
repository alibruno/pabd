-- Questão 1 - Resumo por piloto/temporada (incompleto)
DROP INDEX IF EXISTS idx_mv_driver_season_summary;
DROP MATERIALIZED VIEW IF EXISTS  mv_driver_season_summary;

CREATE MATERIALIZED VIEW mv_driver_season_summary
AS
    SELECT
        r.year,
        d.id,
        d.name,
        d.total_race_starts,
        COUNT(CASE WHEN rd.position_number = 1 THEN 1 END) AS total_wins,
        COUNT(CASE WHEN rd.position_number <= 3 THEN 1 END) total_podiums,
        COUNT(CASE WHEN rd.race_reason_retired IS NOT NULL THEN 1 END) AS dnf,
        rd.race_points
    FROM race_data AS rd
    JOIN race AS r ON rd.race_id = r.id
    JOIN driver AS d ON rd.driver_id = d.id
    WHERE rd.type = 'RACE_RESULT'
    GROUP BY r.year, d.id, rd.race_points
    WITH DATA;

CREATE UNIQUE INDEX idx_mv_driver_season_summary
ON mv_driver_season_summary (id, name);

REFRESH MATERIALIZED VIEW CONCURRENTLY mv_driver_season_summary;

SELECT * FROM mv_driver_season_summary WHERE id = 'ayrton-senna'



-- Questão 2 - Auditoria de pontos do campeonato

DROP TRIGGER IF EXISTS trg_audit_points_adjustment ON season_driver_standing;
DROP FUNCTION IF EXISTS fn_audit_points_adjustment;
DROP TABLE IF EXISTS points_adjustment_audit;

CREATE TABLE points_adjustment_audit(
    id         SERIAL PRIMARY KEY,
    year       INT NOT NULL,
    driver_id  VARCHAR(100) NOT NULL,
    old_points DECIMAL(8,2),
    new_points DECIMAL(8,2),
    changed_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE FUNCTION fn_audit_points_adjustment()
    RETURNS TRIGGER
    LANGUAGE PLPGSQL
AS $$
BEGIN
    IF OLD.points = NEW.points THEN
        RETURN NEW;
    END IF;

    INSERT INTO points_adjustment_audit (year, driver_id, old_points, new_points, changed_at)
    VALUES (OLD.year, OLD.driver_id, OLD.points, NEW.points, now());

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_audit_points_adjustment
    BEFORE UPDATE
    ON season_driver_standing
    FOR EACH ROW
    --WHEN
    EXECUTE FUNCTION fn_audit_points_adjustment();

-- SELECTS 
SELECT * FROM season_driver_standing WHERE driver_id = 'ayrton-senna' AND YEAR = 1988;
SELECT * FROM points_adjustment_audit WHERE driver_id = 'ayrton-senna' AND YEAR = 1988;

UPDATE season_driver_standing
SET points = 100
WHERE driver_id = 'ayrton-senna' AND YEAR = 1988;



-- Questão 3 - Impedir exclusão de piloto com histórico
DROP TRIGGER IF EXISTS trg_dont_delete_driver_used ON driver;
DROP FUNCTION IF EXISTS fn_dont_delete_driver_used;

CREATE FUNCTION fn_dont_delete_driver_used()
    RETURNS TRIGGER
    LANGUAGE PLPGSQL
AS $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM race_data AS rd WHERE rd.driver_id = OLD.id
    ) THEN
        RAISE EXCEPTION 'Cannot remove used driver';
    END IF;

    RETURN OLD;
END;
$$;

CREATE TRIGGER trg_dont_delete_driver_used
    BEFORE DELETE
    ON driver
    FOR EACH ROW
    --WHEN
    EXECUTE FUNCTION fn_dont_delete_driver_used();

-- SELECTS 
SELECT * FROM driver WHERE id = 'ayrton-senna';

DELETE FROM driver
WHERE id = 'ayrton-senna';