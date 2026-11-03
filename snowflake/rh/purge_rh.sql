-- =====================================================================
-- purge_rh.sql — règle R1 : les données d'un chauffeur sont supprimées 5 ans après la fin de son contrat
-- Jour 3, étape 1. À exécuter en entier avec le rôle des outils (propriétaire des tables). Rejouable.
-- On purge la source (RAW) ; les tables de MARTS sont ensuite reconstruites à partir d'elle (T_TABLES).
-- Un chauffeur en poste (end_date vide) n'est jamais purgé : NULL < date n'est pas vrai.
-- =====================================================================
USE SECONDARY ROLES NONE;
USE ROLE TRANSFORMER;
USE WAREHOUSE NYC_TAXI_WH;

-- 0. Compter avant de supprimer
SELECT COUNT(*) AS chauffeurs_a_purger
FROM NYC_TAXI.RAW.DRIVERS
WHERE end_date < DATEADD(year, -5, CURRENT_DATE());

-- 1. Les services d'abord : une fois le chauffeur supprimé, on ne saurait plus lesquels lui appartenaient.
--    R1 s'applique partout où la donnée du chauffeur a été copiée. Avec le fichier actuel (services de
--    janvier à mars 2025), cette instruction ne supprime rien ; avec un historique plus long, elle évite
--    des services orphelins, qui feraient aussi échouer la règle bloquante service_rattache.
DELETE FROM NYC_TAXI.RAW.DRIVER_SHIFTS
WHERE driver_id IN (
    SELECT driver_id FROM NYC_TAXI.RAW.DRIVERS
    WHERE end_date < DATEADD(year, -5, CURRENT_DATE())
);

-- 2. Puis les chauffeurs
DELETE FROM NYC_TAXI.RAW.DRIVERS
WHERE end_date < DATEADD(year, -5, CURRENT_DATE());

-- 3. Vérifier : plus aucun chauffeur hors délai
SELECT COUNT(*) AS restant_hors_delai
FROM NYC_TAXI.RAW.DRIVERS
WHERE end_date < DATEADD(year, -5, CURRENT_DATE());     -- 0
