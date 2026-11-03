-- =====================================================================
-- conservation_rh.sql — règle R2 : une donnée personnelle supprimée ne doit plus pouvoir être restaurée
-- par Time Travel au-delà de 1 jour. Jour 3, étape 2. À exécuter en entier avec le rôle des outils :
-- seul le propriétaire d'une table peut changer sa durée de rétention (GOUVERNANCE serait refusé). Rejouable.
-- La valeur est posée explicitement sur chaque table : elle ne dépend plus du réglage par défaut du compte
-- ou de la base, qui peut aller jusqu'à 90 jours en édition Enterprise.
-- Limite : après ce jour de Time Travel, une table permanente passe encore 7 jours en Fail-safe
-- (restaurable par le support Snowflake seulement). Voir docs/REGISTRE.md et docs/VEILLE.md (écart sur R2).
-- =====================================================================
USE SECONDARY ROLES NONE;
USE ROLE TRANSFORMER;
USE WAREHOUSE NYC_TAXI_WH;

-- Les quatre tables qui contiennent des données de chauffeurs
ALTER TABLE NYC_TAXI.RAW.DRIVERS                SET DATA_RETENTION_TIME_IN_DAYS = 1;
ALTER TABLE NYC_TAXI.RAW.DRIVER_SHIFTS          SET DATA_RETENTION_TIME_IN_DAYS = 1;
ALTER TABLE NYC_TAXI.MARTS.DIM_DRIVER           SET DATA_RETENTION_TIME_IN_DAYS = 1;
ALTER TABLE NYC_TAXI.MARTS.MART_DRIVER_MONTHLY  SET DATA_RETENTION_TIME_IN_DAYS = 1;
-- DIM_DEPOT n'en contient pas : pas concernée.

-- Vérifier : colonne retention_time = 1 pour les quatre tables
SHOW TABLES IN SCHEMA NYC_TAXI.RAW;
SHOW TABLES IN SCHEMA NYC_TAXI.MARTS;
