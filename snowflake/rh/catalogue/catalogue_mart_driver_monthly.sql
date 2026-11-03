-- =====================================================================
-- catalogue_mart_driver_monthly.sql — fiche de catalogue courte de MARTS.MART_DRIVER_MONTHLY
-- Jour 1, étape 11. À exécuter en entier avec le rôle des outils. Rejouable.
-- =====================================================================
USE SECONDARY ROLES NONE;
USE ROLE TRANSFORMER;
USE WAREHOUSE NYC_TAXI_WH;

COMMENT ON TABLE NYC_TAXI.MARTS.MART_DRIVER_MONTHLY IS
  'Activité mensuelle de chaque chauffeur : 1 ligne = 1 chauffeur, 1 mois et 1 dépôt (914 lignes avant purge), avec le nombre de services, les heures, les courses et la recette. Source : STAGING.STG_RH__DRIVER_SHIFTS (services dédoublonnés) joint à MARTS.DIM_DRIVER pour le nom. Reconstruite chaque jour par la tâche T_TABLES (INSERT OVERWRITE). Responsable des données : service RH ; responsable technique : équipe data.';

COMMENT ON COLUMN NYC_TAXI.MARTS.MART_DRIVER_MONTHLY.activity_month IS 'Mois d''activité (premier jour du mois), calculé depuis la date du service.';
COMMENT ON COLUMN NYC_TAXI.MARTS.MART_DRIVER_MONTHLY.driver_id      IS 'Identifiant interne du chauffeur (format D0001). Visible de tous les rôles métier, pour compter et joindre sans nommer.';
COMMENT ON COLUMN NYC_TAXI.MARTS.MART_DRIVER_MONTHLY.driver_name    IS 'Colonne calculée : prénom et nom du chauffeur, recopiés de DIM_DRIVER. Donnée personnelle, masquée comme le nom.';
COMMENT ON COLUMN NYC_TAXI.MARTS.MART_DRIVER_MONTHLY.depot          IS 'Dépôt du service (Bronx, Brooklyn ou Queens). Sert au filtre par ligne des responsables de dépôt.';
COMMENT ON COLUMN NYC_TAXI.MARTS.MART_DRIVER_MONTHLY.nb_shifts      IS 'Nombre de services du chauffeur dans le mois, pour ce dépôt.';
COMMENT ON COLUMN NYC_TAXI.MARTS.MART_DRIVER_MONTHLY.hours_worked   IS 'Heures travaillées dans le mois, arrondies à une décimale.';
COMMENT ON COLUMN NYC_TAXI.MARTS.MART_DRIVER_MONTHLY.trips_count    IS 'Nombre de courses dans le mois.';
COMMENT ON COLUMN NYC_TAXI.MARTS.MART_DRIVER_MONTHLY.revenue_usd    IS 'Recette du mois en dollars, arrondie au cent.';

ALTER TABLE NYC_TAXI.MARTS.MART_DRIVER_MONTHLY SET TAG
  NYC_TAXI.GOUVERNANCE.SENSIBILITE        = 'confidentiel',
  NYC_TAXI.GOUVERNANCE.DUREE_CONSERVATION = '5 ans après la fin du contrat du chauffeur, règle R1 (reconstruite depuis RAW après la purge)';

ALTER TABLE NYC_TAXI.MARTS.MART_DRIVER_MONTHLY MODIFY COLUMN driver_id   SET TAG NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE = 'identifiant_interne';
-- driver_name est calculée (first_name || ' ' || last_name) : une colonne calculée à partir d'un nom est un nom.
ALTER TABLE NYC_TAXI.MARTS.MART_DRIVER_MONTHLY MODIFY COLUMN driver_name SET TAG NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE = 'nom';

SELECT level, column_name, tag_name, tag_value
FROM TABLE(NYC_TAXI.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS('NYC_TAXI.MARTS.MART_DRIVER_MONTHLY', 'table'))
ORDER BY level, column_name;
