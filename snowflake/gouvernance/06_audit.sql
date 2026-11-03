-- =====================================================================
-- 06_audit.sql — qui a lu les données personnelles des chauffeurs, avec quel rôle, ces 7 derniers jours
-- Jour 3, étape 8. À exécuter avec ACCOUNTADMIN : SNOWFLAKE.ACCOUNT_USAGE n'est lisible que par lui ici.
-- ACCESS_HISTORY dit QUELS objets et QUELLES colonnes ont été lus, et par quel utilisateur ;
-- le RÔLE est dans QUERY_HISTORY : on joint les deux sur query_id.
-- Latence : jusqu'à 3 h pour ACCESS_HISTORY, 45 min pour QUERY_HISTORY. Les lectures de la dernière heure
-- peuvent manquer : ce n'est pas une erreur.
-- =====================================================================
USE SECONDARY ROLES NONE;
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE NYC_TAXI_WH;

-- 1. Qui a lu les tables RH, avec quel rôle, quelles colonnes (une ligne par rôle, utilisateur et table)
WITH acces AS (
    SELECT
        ah.query_id,
        ah.query_start_time,
        ah.user_name,
        obj.value:"objectName"::STRING   AS objet,
        col.value:"columnName"::STRING   AS colonne
    FROM SNOWFLAKE.ACCOUNT_USAGE.ACCESS_HISTORY ah,
         LATERAL FLATTEN(input => ah.base_objects_accessed) obj,                  -- une ligne par objet lu
         LATERAL FLATTEN(input => obj.value:"columns", OUTER => TRUE) col         -- une ligne par colonne lue
    WHERE ah.query_start_time >= DATEADD(day, -7, CURRENT_TIMESTAMP())
      AND obj.value:"objectName"::STRING IN (
            'NYC_TAXI.MARTS.DIM_DRIVER', 'NYC_TAXI.MARTS.MART_DRIVER_MONTHLY',
            'NYC_TAXI.RAW.DRIVERS', 'NYC_TAXI.RAW.DRIVER_SHIFTS')
)
SELECT
    q.role_name                                                        AS role,
    a.user_name                                                        AS utilisateur,
    a.objet                                                            AS table_lue,
    COUNT(DISTINCT a.query_id)                                         AS nb_requetes,
    LISTAGG(DISTINCT a.colonne, ', ') WITHIN GROUP (ORDER BY a.colonne) AS colonnes_lues,
    MIN(a.query_start_time)                                            AS premiere_lecture,
    MAX(a.query_start_time)                                            AS derniere_lecture
FROM acces a
JOIN SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY q ON q.query_id = a.query_id
GROUP BY 1, 2, 3
ORDER BY table_lue, role;

-- 2. Seulement les colonnes personnelles (celles qui portent le tag DONNEE_PERSONNELLE dans le catalogue)
WITH acces AS (
    SELECT ah.query_id, ah.query_start_time, ah.user_name,
           obj.value:"objectName"::STRING AS objet,
           col.value:"columnName"::STRING AS colonne
    FROM SNOWFLAKE.ACCOUNT_USAGE.ACCESS_HISTORY ah,
         LATERAL FLATTEN(input => ah.base_objects_accessed) obj,
         LATERAL FLATTEN(input => obj.value:"columns") col
    WHERE ah.query_start_time >= DATEADD(day, -7, CURRENT_TIMESTAMP())
      AND obj.value:"objectName"::STRING = 'NYC_TAXI.MARTS.DIM_DRIVER'
      AND col.value:"columnName"::STRING IN
          ('FIRST_NAME', 'LAST_NAME', 'EMAIL', 'PHONE', 'BIRTH_DATE', 'TLC_LICENSE_NUMBER')
)
SELECT q.role_name AS role, a.user_name AS utilisateur, a.colonne,
       COUNT(DISTINCT a.query_id) AS nb_requetes, MAX(a.query_start_time) AS derniere_lecture
FROM acces a
JOIN SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY q ON q.query_id = a.query_id
GROUP BY 1, 2, 3
ORDER BY role, colonne;
-- À lire avec la matrice : lire une colonne ne veut pas dire la voir en clair. ANALYSTE apparaît comme
-- lecteur de EMAIL, mais il n'a lu que '*****' (masquage). L'audit dit qui a demandé, la politique dit ce qu'il a vu.
