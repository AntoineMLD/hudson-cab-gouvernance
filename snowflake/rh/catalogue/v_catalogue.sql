-- =====================================================================
-- v_catalogue.sql — GOUVERNANCE.V_CATALOGUE : une ligne par colonne cataloguée, avec sa description et ses tags
-- Jour 3, étape 5. À exécuter en entier avec le rôle des outils : GOUVERNANCE ne voit pas les tables,
-- TRANSFORMER a reçu CREATE VIEW sur le schéma GOUVERNANCE (01_gouvernance.sql). Rejouable.
-- Porte sur MARTS seulement : INFORMATION_SCHEMA ne montre que ce que le rôle qui interroge a le droit de voir.
-- Les rôles métier ne lisent pas RAW : une vue qui l'inclurait leur reviendrait incomplète.
-- Les rôles métier la lisent grâce au SELECT sur les vues futures du schéma (02_roles_metier.sql),
-- y compris après un CREATE OR REPLACE.
-- =====================================================================
USE SECONDARY ROLES NONE;
USE ROLE TRANSFORMER;
USE WAREHOUSE NYC_TAXI_WH;

CREATE OR REPLACE VIEW NYC_TAXI.GOUVERNANCE.V_CATALOGUE
  COMMENT = 'Catalogue des tables de MARTS : une ligne par colonne, avec sa description, son type et ses tags (sensibilité, durée de conservation hérités de la table ; donnée personnelle posée sur la colonne).'
AS
WITH tags AS (
    -- Une fonction par table : elle renvoie les tags des colonnes ET ceux hérités de la table (level = 'TABLE')
    SELECT object_name, column_name, tag_name, tag_value, level
    FROM TABLE(NYC_TAXI.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS('NYC_TAXI.MARTS.DIM_DRIVER', 'table'))
    UNION ALL
    SELECT object_name, column_name, tag_name, tag_value, level
    FROM TABLE(NYC_TAXI.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS('NYC_TAXI.MARTS.MART_DRIVER_MONTHLY', 'table'))
    UNION ALL
    SELECT object_name, column_name, tag_name, tag_value, level
    FROM TABLE(NYC_TAXI.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS('NYC_TAXI.MARTS.DIM_DEPOT', 'table'))
)
SELECT
    c.table_schema                                                        AS schema_name,
    c.table_name,
    t.comment                                                             AS description_table,
    c.column_name,
    c.ordinal_position,
    c.data_type,
    c.comment                                                             AS description_colonne,
    MAX(IFF(g.tag_name = 'DONNEE_PERSONNELLE', g.tag_value, NULL))        AS donnee_personnelle,
    MAX(IFF(g.tag_name = 'SENSIBILITE',        g.tag_value, NULL))        AS sensibilite,
    MAX(IFF(g.tag_name = 'DUREE_CONSERVATION', g.tag_value, NULL))        AS duree_conservation
FROM NYC_TAXI.INFORMATION_SCHEMA.COLUMNS c
JOIN NYC_TAXI.INFORMATION_SCHEMA.TABLES t
  ON t.table_schema = c.table_schema AND t.table_name = c.table_name
LEFT JOIN tags g
  ON g.object_name = c.table_name AND g.column_name = c.column_name
WHERE c.table_schema = 'MARTS'
  AND c.table_name IN ('DIM_DRIVER', 'MART_DRIVER_MONTHLY', 'DIM_DEPOT')
GROUP BY 1, 2, 3, 4, 5, 6, 7;

-- Vérifier avec le propriétaire : 24 lignes (12 + 8 + 4 colonnes)
SELECT table_name, COUNT(*) AS nb_colonnes, COUNT(donnee_personnelle) AS nb_personnelles
FROM NYC_TAXI.GOUVERNANCE.V_CATALOGUE GROUP BY table_name ORDER BY table_name;

-- Test : un rôle métier lit la vue (critère C20)
USE SECONDARY ROLES NONE;
USE ROLE ANALYSTE;
USE WAREHOUSE NYC_TAXI_WH;
SELECT table_name, column_name, description_colonne, donnee_personnelle, sensibilite, duree_conservation
FROM NYC_TAXI.GOUVERNANCE.V_CATALOGUE
WHERE donnee_personnelle IS NOT NULL
ORDER BY table_name, ordinal_position;
