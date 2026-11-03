-- =====================================================================
-- catalogue_mart_driver_monthly.sql — fiche de catalogue courte de MARTS.MART_DRIVER_MONTHLY
-- Jour 1, étape 11. À exécuter en entier avec le rôle des outils. Rejouable.
-- =====================================================================
USE SECONDARY ROLES NONE;
USE ROLE TRANSFORMER;
USE WAREHOUSE NYC_TAXI_WH;

COMMENT ON TABLE NYC_TAXI.MARTS.MART_DRIVER_MONTHLY IS
  'Activité mensuelle de chaque chauffeur : 1 ligne = 1 chauffeur, 1 mois et 1 dépôt (914 lignes avant purge), avec le nombre de services, les heures, les courses et la recette. Source : STAGING.STG_RH__DRIVER_SHIFTS (services dédoublonnés) joint à MARTS.DIM_DRIVER pour le nom. Reconstruite chaque jour par la tâche T_TABLES (INSERT OVERWRITE). Responsable des données : service RH ; responsable technique : équipe data.';

ALTER TABLE NYC_TAXI.MARTS.MART_DRIVER_MONTHLY SET TAG
  NYC_TAXI.GOUVERNANCE.SENSIBILITE        = 'confidentiel',
  NYC_TAXI.GOUVERNANCE.DUREE_CONSERVATION = '5 ans après la fin du contrat du chauffeur, règle R1 (reconstruite depuis RAW après la purge)';

ALTER TABLE NYC_TAXI.MARTS.MART_DRIVER_MONTHLY MODIFY COLUMN driver_id   SET TAG NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE = 'identifiant_interne';
-- driver_name est calculée (first_name || ' ' || last_name) : une colonne calculée à partir d'un nom est un nom.
ALTER TABLE NYC_TAXI.MARTS.MART_DRIVER_MONTHLY MODIFY COLUMN driver_name SET TAG NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE = 'nom';

SELECT level, column_name, tag_name, tag_value
FROM TABLE(NYC_TAXI.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS('NYC_TAXI.MARTS.MART_DRIVER_MONTHLY', 'table'))
ORDER BY level, column_name;
