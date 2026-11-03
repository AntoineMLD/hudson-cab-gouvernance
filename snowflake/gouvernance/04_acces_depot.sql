-- =====================================================================
-- 04_acces_depot.sql — filtrer les lignes par dépôt avec une table de correspondance
-- Jour 2, étape 6. Partie A en entier avec GOUVERNANCE (Cmd/Ctrl+Maj+Entrée). Rejouable.
-- Partie B : les tests, un bloc à la fois. Partie C : prouver qu'un dépôt s'ajoute sans toucher à la politique.
-- Qui voit quel dépôt est écrit dans des LIGNES de ACCES_DEPOT, jamais dans la politique.
-- =====================================================================

-- ===================================================================== A. Écrire et attacher
USE SECONDARY ROLES NONE;
USE ROLE GOUVERNANCE;
USE WAREHOUSE NYC_TAXI_WH;

-- 1. La table de correspondance (contrat, section 1) : une ligne par rôle et par dépôt visible, * = tous
CREATE TABLE IF NOT EXISTS NYC_TAXI.GOUVERNANCE.ACCES_DEPOT (
    role_name VARCHAR NOT NULL,
    depot     VARCHAR NOT NULL     -- un dépôt (Bronx, Brooklyn, Queens), ou * pour tous
) COMMENT = 'Quel rôle voit quel dépôt dans les tables RH de MARTS. * = tous les dépôts. Un rôle absent ne voit aucune ligne.';

-- 2. Les lignes de la matrice. MERGE plutôt que DELETE + INSERT : le script reste rejouable
--    sans effacer une ligne ajoutée plus tard (un nouveau dépôt, un nouveau responsable).
MERGE INTO NYC_TAXI.GOUVERNANCE.ACCES_DEPOT t
USING (
    SELECT column1 AS role_name, column2 AS depot FROM VALUES
        ('TRANSFORMER',       '*'),       -- sans cette ligne, le pipeline ne verrait plus rien, sans erreur
        ('RH_PAIE',           '*'),
        ('ANALYSTE',          '*'),
        ('RESP_DEPOT_QUEENS', 'Queens'),
        ('RESP_DEPOT_BRONX',  'Bronx')
) s
ON t.role_name = s.role_name AND t.depot = s.depot
WHEN NOT MATCHED THEN INSERT (role_name, depot) VALUES (s.role_name, s.depot);
-- Absents volontairement : GOUVERNANCE, ACCOUNTADMIN, SYSADMIN (contrat : aucune ligne).

-- 3. La politique : appelée pour chaque ligne, avec la valeur de la colonne depot.
--    TRUE = la ligne s'affiche, FALSE = elle disparaît. La sous-requête lit ACCES_DEPOT avec les droits
--    du propriétaire de la politique (GOUVERNANCE) : les rôles métier n'ont pas besoin de lire cette table.
CREATE ROW ACCESS POLICY IF NOT EXISTS NYC_TAXI.GOUVERNANCE.RAP_DEPOT
  AS (depot_ligne VARCHAR) RETURNS BOOLEAN -> FALSE                 -- corps provisoire (rejouable)
  COMMENT = 'Filtre les lignes des tables RH de MARTS par dépôt, selon GOUVERNANCE.ACCES_DEPOT';

ALTER ROW ACCESS POLICY NYC_TAXI.GOUVERNANCE.RAP_DEPOT SET BODY ->
  EXISTS (
    SELECT 1
    FROM NYC_TAXI.GOUVERNANCE.ACCES_DEPOT a
    WHERE a.role_name = CURRENT_ROLE()          -- le rôle principal, pas les rôles hérités ni secondaires
      AND a.depot IN (depot_ligne, '*')
  );

-- 4. L'attacher aux deux tables RH de MARTS, sur la colonne depot.
--    DROP ALL ne fait rien s'il n'y a rien ; ADD échouerait si la politique était déjà attachée.
ALTER TABLE NYC_TAXI.MARTS.DIM_DRIVER          DROP ALL ROW ACCESS POLICIES;
ALTER TABLE NYC_TAXI.MARTS.DIM_DRIVER          ADD ROW ACCESS POLICY NYC_TAXI.GOUVERNANCE.RAP_DEPOT ON (depot);
ALTER TABLE NYC_TAXI.MARTS.MART_DRIVER_MONTHLY DROP ALL ROW ACCESS POLICIES;
ALTER TABLE NYC_TAXI.MARTS.MART_DRIVER_MONTHLY ADD ROW ACCESS POLICY NYC_TAXI.GOUVERNANCE.RAP_DEPOT ON (depot);

-- 5. Vérifier
SELECT * FROM NYC_TAXI.GOUVERNANCE.ACCES_DEPOT ORDER BY role_name;   -- 5 lignes
SHOW ROW ACCESS POLICIES IN SCHEMA NYC_TAXI.GOUVERNANCE;

-- ===================================================================== B. Tester (un bloc à la fois)

-- Test 1 : RH_PAIE → 400
USE SECONDARY ROLES NONE;
USE ROLE RH_PAIE;
USE WAREHOUSE NYC_TAXI_WH;
SELECT COUNT(*) FROM NYC_TAXI.MARTS.DIM_DRIVER;

-- Tests 2, 3, 14 : RESP_DEPOT_QUEENS → 161, Queens seulement, 365 lignes de mart, D0003 visible
USE SECONDARY ROLES NONE;
USE ROLE RESP_DEPOT_QUEENS;
USE WAREHOUSE NYC_TAXI_WH;
SELECT COUNT(*) FROM NYC_TAXI.MARTS.DIM_DRIVER;
SELECT DISTINCT depot FROM NYC_TAXI.MARTS.DIM_DRIVER;
SELECT COUNT(*) FROM NYC_TAXI.MARTS.MART_DRIVER_MONTHLY;
SELECT * FROM NYC_TAXI.MARTS.DIM_DRIVER WHERE driver_id = 'D0003';

-- Tests 4, 13 : RESP_DEPOT_BRONX → 290 lignes de mart, 122 chauffeurs, D0003 invisible
USE SECONDARY ROLES NONE;
USE ROLE RESP_DEPOT_BRONX;
USE WAREHOUSE NYC_TAXI_WH;
SELECT COUNT(*) FROM NYC_TAXI.MARTS.MART_DRIVER_MONTHLY;
SELECT COUNT(*) FROM NYC_TAXI.MARTS.DIM_DRIVER;
SELECT * FROM NYC_TAXI.MARTS.DIM_DRIVER WHERE driver_id = 'D0003';    -- 0 ligne

-- Test 5 : ANALYSTE → 400
USE SECONDARY ROLES NONE;
USE ROLE ANALYSTE;
USE WAREHOUSE NYC_TAXI_WH;
SELECT COUNT(*) FROM NYC_TAXI.MARTS.DIM_DRIVER;

-- Test 6 : GOUVERNANCE → refusé
USE SECONDARY ROLES NONE;
USE ROLE GOUVERNANCE;
USE WAREHOUSE NYC_TAXI_WH;
SELECT COUNT(*) FROM NYC_TAXI.MARTS.DIM_DRIVER;

-- Tests 7, 16 : ACCOUNTADMIN → 0 et 0 (il a le droit de lire, mais il est absent de ACCES_DEPOT)
USE SECONDARY ROLES NONE;
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE NYC_TAXI_WH;
SELECT COUNT(*) FROM NYC_TAXI.MARTS.DIM_DRIVER;
SELECT COUNT(*) FROM NYC_TAXI.MARTS.MART_DRIVER_MONTHLY;

-- ===================================================================== C. Ajouter un dépôt sans toucher à la politique (test 20)
-- Donner Brooklyn à la responsable de Queens : une ligne dans la table, rien d'autre.
USE SECONDARY ROLES NONE;
USE ROLE GOUVERNANCE;
USE WAREHOUSE NYC_TAXI_WH;
INSERT INTO NYC_TAXI.GOUVERNANCE.ACCES_DEPOT VALUES ('RESP_DEPOT_QUEENS', 'Brooklyn');

USE ROLE RESP_DEPOT_QUEENS;
SELECT depot, COUNT(*) FROM NYC_TAXI.MARTS.DIM_DRIVER GROUP BY depot;   -- Queens 161, Brooklyn 117 : 278

-- Revenir à la matrice du contrat
USE ROLE GOUVERNANCE;
DELETE FROM NYC_TAXI.GOUVERNANCE.ACCES_DEPOT WHERE role_name = 'RESP_DEPOT_QUEENS' AND depot = 'Brooklyn';
USE ROLE RESP_DEPOT_QUEENS;
SELECT COUNT(*) FROM NYC_TAXI.MARTS.DIM_DRIVER;                          -- de nouveau 161
