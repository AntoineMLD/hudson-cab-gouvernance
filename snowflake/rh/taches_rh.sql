-- =====================================================================
-- taches_rh.sql — le graphe de tâches quotidien : purger, contrôler, puis reconstruire MARTS
-- Jour 3, étape 6. Partie A en entier avec le rôle des outils (propriétaire des tâches). Rejouable :
-- la racine est suspendue avant d'être recréée, puis tout le graphe est réactivé.
-- Une tâche s'exécute avec les droits de son propriétaire (TRANSFORMER) : elle voit les vraies valeurs
-- (politique de masquage) et toutes les lignes (ACCES_DEPOT, ligne '*'), et écrit dans QUALITE_RESULTATS.
-- Ordre imposé par le contrat : T_PURGE → T_QUALITE → T_TABLES. On ne reconstruit MARTS que si le contrôle est passé.
-- =====================================================================

-- ===================================================================== A. Créer et activer
USE SECONDARY ROLES NONE;
USE ROLE TRANSFORMER;
USE WAREHOUSE NYC_TAXI_WH;

-- Modifier un graphe demande d'en suspendre la racine (ne fait rien la première fois)
ALTER TASK IF EXISTS NYC_TAXI.MARTS.T_PURGE SUSPEND;

-- 1. La racine : chaque jour à 6 h (heure de Paris), purge R1 de RAW (services d'abord, puis chauffeurs)
CREATE OR REPLACE TASK NYC_TAXI.MARTS.T_PURGE
  WAREHOUSE = NYC_TAXI_WH
  SCHEDULE  = 'USING CRON 0 6 * * * Europe/Paris'
  COMMENT   = 'R1 : supprime les chauffeurs partis depuis plus de 5 ans, et leurs services, dans RAW'
AS
EXECUTE IMMEDIATE $$
BEGIN
  DELETE FROM NYC_TAXI.RAW.DRIVER_SHIFTS
  WHERE driver_id IN (SELECT driver_id FROM NYC_TAXI.RAW.DRIVERS
                      WHERE end_date < DATEADD(year, -5, CURRENT_DATE()));
  DELETE FROM NYC_TAXI.RAW.DRIVERS
  WHERE end_date < DATEADD(year, -5, CURRENT_DATE());
  RETURN 'Purge R1 faite';
END;
$$;

-- 2. Après la purge : mesurer les 4 règles sur RAW, TOUT enregistrer, puis lever une erreur
--    si la règle bloquante est dépassée (T_QUALITE échoue, T_TABLES ne part pas).
CREATE OR REPLACE TASK NYC_TAXI.MARTS.T_QUALITE
  WAREHOUSE = NYC_TAXI_WH
  COMMENT   = 'Règles de qualité du contrat (section 6), enregistrées dans GOUVERNANCE.QUALITE_RESULTATS ; service_rattache est bloquante'
  AFTER NYC_TAXI.MARTS.T_PURGE
AS
EXECUTE IMMEDIATE $$
DECLARE
  maintenant      TIMESTAMP_NTZ;
  nb_licence      INTEGER;
  nb_orphelins    INTEGER;
  nb_depot        INTEGER;
  nb_depot_chauf  INTEGER;
  nb_depot_serv   INTEGER;
  nb_telephone    INTEGER;
  seuil_telephone NUMBER(18,2);
  seuil_rattache  NUMBER(18,2) DEFAULT 50;    -- SEUIL BLOQUANT (contrat : 50 services). Mettre 10 pour prouver le blocage.
  bloquee EXCEPTION (-20001, 'Règle bloquante service_rattache en dépassement : MARTS n''est pas reconstruit');
BEGIN
  maintenant := CURRENT_TIMESTAMP()::TIMESTAMP_NTZ;

  -- Les mesures (mêmes requêtes que snowflake/rh/controles/)
  SELECT COUNT(*) - COUNT(DISTINCT tlc_license_number) INTO :nb_licence
  FROM NYC_TAXI.RAW.DRIVERS;

  SELECT COUNT(*) INTO :nb_orphelins
  FROM NYC_TAXI.RAW.DRIVER_SHIFTS s
  WHERE NOT EXISTS (SELECT 1 FROM NYC_TAXI.RAW.DRIVERS d WHERE d.driver_id = s.driver_id);

  SELECT COUNT(*) INTO :nb_depot_chauf
  FROM NYC_TAXI.RAW.DRIVERS
  WHERE depot IS NULL OR depot NOT IN ('Bronx', 'Brooklyn', 'Queens');

  SELECT COUNT(*) INTO :nb_depot_serv
  FROM NYC_TAXI.RAW.DRIVER_SHIFTS
  WHERE depot IS NULL OR depot NOT IN ('Bronx', 'Brooklyn', 'Queens');

  nb_depot := nb_depot_chauf + nb_depot_serv;

  SELECT COUNT_IF(phone IS NULL OR TRIM(phone) = ''), ROUND(COUNT(*) * 0.05, 2)
  INTO :nb_telephone, :seuil_telephone
  FROM NYC_TAXI.RAW.DRIVERS
  WHERE end_date IS NULL;

  -- Enregistrer TOUTES les mesures, avant toute décision
  INSERT INTO NYC_TAXI.GOUVERNANCE.QUALITE_RESULTATS (regle, mesure_le, nb_anomalies, seuil, statut)
    SELECT 'licence_unique', :maintenant, :nb_licence, 0, IFF(:nb_licence <= 0, 'OK', 'ALERTE');
  INSERT INTO NYC_TAXI.GOUVERNANCE.QUALITE_RESULTATS (regle, mesure_le, nb_anomalies, seuil, statut)
    SELECT 'service_rattache', :maintenant, :nb_orphelins, :seuil_rattache, IFF(:nb_orphelins <= :seuil_rattache, 'OK', 'ALERTE');
  INSERT INTO NYC_TAXI.GOUVERNANCE.QUALITE_RESULTATS (regle, mesure_le, nb_anomalies, seuil, statut)
    SELECT 'depot_connu', :maintenant, :nb_depot, 0, IFF(:nb_depot <= 0, 'OK', 'ALERTE');
  INSERT INTO NYC_TAXI.GOUVERNANCE.QUALITE_RESULTATS (regle, mesure_le, nb_anomalies, seuil, statut)
    SELECT 'telephone_renseigne', :maintenant, :nb_telephone, :seuil_telephone, IFF(:nb_telephone <= :seuil_telephone, 'OK', 'ALERTE');

  -- Puis décider : seule service_rattache arrête la chaîne
  IF (nb_orphelins > seuil_rattache) THEN
    RAISE bloquee;
  END IF;
  RETURN 'Qualité mesurée : ' || nb_orphelins || ' services orphelins (seuil ' || seuil_rattache || ')';
END;
$$;

-- 3. Seulement si T_QUALITE a réussi : reconstruire MARTS (les trois INSERT OVERWRITE de rh/marts/,
--    sans USE ROLE ni USE WAREHOUSE). INSERT OVERWRITE ne recrée pas les tables : tags, descriptions
--    et politiques restent en place.
CREATE OR REPLACE TASK NYC_TAXI.MARTS.T_TABLES
  WAREHOUSE = NYC_TAXI_WH
  COMMENT   = 'Reconstruit DIM_DEPOT, DIM_DRIVER puis MART_DRIVER_MONTHLY à partir de RAW et STAGING'
  AFTER NYC_TAXI.MARTS.T_QUALITE
AS
EXECUTE IMMEDIATE $$
BEGIN
  INSERT OVERWRITE INTO NYC_TAXI.MARTS.DIM_DEPOT (depot, quartier, ouvert_en, nb_places) VALUES
      ('Bronx',    'Hunts Point',       2009, 140),
      ('Brooklyn', 'East New York',     2011, 120),
      ('Queens',   'Long Island City',  2008, 180);

  INSERT OVERWRITE INTO NYC_TAXI.MARTS.DIM_DRIVER
  SELECT
      driver_id, first_name, last_name, email, phone, birth_date, tlc_license_number, depot,
      hire_date, end_date,
      end_date IS NULL                                                                   AS is_active,
      ROUND(DATEDIFF(day, hire_date, COALESCE(end_date, CURRENT_DATE())) / 365.25, 1)    AS tenure_years
  FROM NYC_TAXI.STAGING.STG_RH__DRIVERS;

  INSERT OVERWRITE INTO NYC_TAXI.MARTS.MART_DRIVER_MONTHLY
  SELECT
      DATE_TRUNC('month', s.shift_date)::date     AS activity_month,
      s.driver_id,
      d.first_name || ' ' || d.last_name          AS driver_name,
      s.depot,
      COUNT(*)                                    AS nb_shifts,
      ROUND(SUM(s.hours_worked), 1)               AS hours_worked,
      SUM(s.trips_count)                          AS trips_count,
      ROUND(SUM(s.revenue_usd), 2)                AS revenue_usd
  FROM NYC_TAXI.STAGING.STG_RH__DRIVER_SHIFTS s
  LEFT JOIN NYC_TAXI.MARTS.DIM_DRIVER d ON d.driver_id = s.driver_id
  GROUP BY 1, 2, 3, 4;

  RETURN 'MARTS reconstruit';
END;
$$;

-- 4. Activer la racine ET les tâches qui en dépendent
SELECT SYSTEM$TASK_DEPENDENTS_ENABLE('NYC_TAXI.MARTS.T_PURGE');
SHOW TASKS IN SCHEMA NYC_TAXI.MARTS;     -- 3 tâches, state = started

-- ===================================================================== B. Lancer et vérifier (bloc par bloc)

-- B1. Lancer tout de suite, sans attendre 6 h
EXECUTE TASK NYC_TAXI.MARTS.T_PURGE;

-- B2. Une à deux minutes plus tard : les 3 tâches en SUCCEEDED
SELECT name, state, return_value, error_message, completed_time
FROM TABLE(NYC_TAXI.INFORMATION_SCHEMA.TASK_HISTORY())
WHERE name IN ('T_PURGE', 'T_QUALITE', 'T_TABLES') AND state <> 'SCHEDULED'
ORDER BY completed_time DESC
LIMIT 10;

-- B3. Une ligne par règle et par exécution
SELECT * FROM NYC_TAXI.GOUVERNANCE.QUALITE_RESULTATS ORDER BY mesure_le DESC, regle;

-- B4. Les règles sont toujours en place après une exécution des tâches (critère C19)
SELECT COUNT(*) AS chauffeurs FROM NYC_TAXI.MARTS.DIM_DRIVER;                    -- 354
SELECT table_name, COUNT(*) AS colonnes, COUNT(description_colonne) AS decrites, COUNT(donnee_personnelle) AS taguees
FROM NYC_TAXI.GOUVERNANCE.V_CATALOGUE GROUP BY table_name ORDER BY table_name;    -- descriptions et tags intacts

-- ===================================================================== C. Prouver le blocage, puis arrêter
-- C1. Dans la partie A, remplacer « DEFAULT 50 » par « DEFAULT 10 » (25 orphelins > 10), relancer la partie A,
--     puis EXECUTE TASK (B1) et TASK_HISTORY (B2) : T_QUALITE en FAILED avec le message, T_TABLES absente,
--     et une ligne service_rattache en ALERTE dans QUALITE_RESULTATS (B3).
-- C2. Remettre « DEFAULT 50 », relancer la partie A.
-- C3. À la fin du brief, une tâche activée consomme des crédits chaque jour :
--     ALTER TASK NYC_TAXI.MARTS.T_PURGE SUSPEND;
