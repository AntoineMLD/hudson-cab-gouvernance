-- =====================================================================
-- 03_masquage.sql — masquage dynamique des colonnes personnelles, attaché au tag DONNEE_PERSONNELLE
-- Jour 2, étape 5. Partie A en entier avec GOUVERNANCE (Cmd/Ctrl+Maj+Entrée). Rejouable.
-- Partie B : les tests, un bloc à la fois (sélectionner le bloc, puis Ctrl+Entrée).
-- Une politique renvoie le type qu'elle reçoit : une politique pour le texte, une pour les dates.
-- Attachées au tag, elles protègent toute colonne qui le porte, aujourd'hui ou demain,
-- dans RAW comme dans MARTS (et dans les vues de STAGING, qui lisent RAW).
-- =====================================================================

-- ===================================================================== A. Écrire et attacher
USE SECONDARY ROLES NONE;
USE ROLE GOUVERNANCE;
USE WAREHOUSE NYC_TAXI_WH;

-- 1. Politique texte : nom, prénom, e-mail, téléphone, licence, driver_name, driver_id
--    Rejouable : créer avec un corps provisoire, puis écrire le vrai corps avec SET BODY
--    (CREATE OR REPLACE échouerait sur une politique déjà attachée).
CREATE MASKING POLICY IF NOT EXISTS NYC_TAXI.GOUVERNANCE.MASK_TEXTE
  AS (val STRING) RETURNS STRING -> val
  COMMENT = 'Masque les colonnes texte taguées DONNEE_PERSONNELLE selon le rôle actif (contrat, section 4)';

ALTER MASKING POLICY NYC_TAXI.GOUVERNANCE.MASK_TEXTE SET BODY ->
  CASE
    -- 1. L'identifiant interne reste visible de tous : il permet de compter et de joindre sans nommer.
    WHEN SYSTEM$GET_TAG_ON_CURRENT_COLUMN('NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE') = 'identifiant_interne'
      THEN val
    -- 2. Le rôle des outils voit tout : s'il lisait un masque, il le recopierait dans les marts.
    --    3. Le service paie voit tout (matrice).
    --    CURRENT_ROLE() regarde le rôle principal seulement : ACCOUNTADMIN, qui hérite de TRANSFORMER
    --    par SYSADMIN, ne passe pas par ce cas (IS_ROLE_IN_SESSION l'aurait laissé passer).
    WHEN CURRENT_ROLE() IN ('TRANSFORMER', 'RH_PAIE')
      THEN val
    -- 4. Les responsables de dépôt voient nom, prénom et téléphone (matrice).
    --    Le préfixe couvre un futur dépôt (RESP_DEPOT_STATEN_ISLAND) sans modifier la politique ;
    --    les lignes visibles, elles, dépendent de la table ACCES_DEPOT.
    WHEN STARTSWITH(CURRENT_ROLE(), 'RESP_DEPOT_')
         AND SYSTEM$GET_TAG_ON_CURRENT_COLUMN('NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE') IN ('nom', 'telephone')
      THEN val
    -- 5. Une valeur vide reste vide : on distingue « masqué » de « absent du fichier ».
    WHEN val IS NULL
      THEN NULL
    -- 6. Tout le reste est masqué : analyste, administrateurs, tout rôle absent de la matrice.
    ELSE '*****'
  END;

-- 2. Politique date : birth_date
CREATE MASKING POLICY IF NOT EXISTS NYC_TAXI.GOUVERNANCE.MASK_DATE
  AS (val DATE) RETURNS DATE -> val
  COMMENT = 'Masque les colonnes date taguées DONNEE_PERSONNELLE selon le rôle actif (contrat, section 4)';

ALTER MASKING POLICY NYC_TAXI.GOUVERNANCE.MASK_DATE SET BODY ->
  CASE
    WHEN CURRENT_ROLE() IN ('TRANSFORMER', 'RH_PAIE') THEN val
    -- L'analyste ne voit que l'année : le 1er janvier de l'année de naissance (le type date est conservé).
    WHEN CURRENT_ROLE() = 'ANALYSTE'                  THEN DATE_TRUNC('YEAR', val)
    ELSE NULL
  END;

-- 3. Attacher les deux politiques au tag. La commande échoue si c'est déjà fait :
--    le bloc attrape l'erreur et affiche son message, pour que la partie A reste rejouable.
EXECUTE IMMEDIATE $$
BEGIN
  ALTER TAG NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE SET
    MASKING POLICY NYC_TAXI.GOUVERNANCE.MASK_TEXTE,
    MASKING POLICY NYC_TAXI.GOUVERNANCE.MASK_DATE;
  RETURN 'Politiques attachées au tag DONNEE_PERSONNELLE.';
EXCEPTION
  WHEN STATEMENT_ERROR THEN
    RETURN 'Non attachées, lire le message (déjà attachées ?) : ' || SQLERRM;
END;
$$;

-- 4. Vérifier : où les politiques sont-elles attachées ? (contrat, section 7)
SHOW MASKING POLICIES IN SCHEMA NYC_TAXI.GOUVERNANCE;
SELECT policy_name, policy_kind, ref_entity_name, ref_column_name, tag_name
FROM TABLE(NYC_TAXI.INFORMATION_SCHEMA.POLICY_REFERENCES(
  REF_ENTITY_NAME => 'NYC_TAXI.MARTS.DIM_DRIVER', REF_ENTITY_DOMAIN => 'TABLE'));

-- ===================================================================== B. Tester (un bloc à la fois)
-- Avant l'étape 6, le filtre par dépôt n'existe pas encore : RESP_DEPOT_BRONX voit encore D0003 (masqué).

-- Test : RH_PAIE → tout en clair
USE SECONDARY ROLES NONE;
USE ROLE RH_PAIE;
USE WAREHOUSE NYC_TAXI_WH;
SELECT * FROM NYC_TAXI.MARTS.DIM_DRIVER WHERE driver_id = 'D0003';

-- Test : RESP_DEPOT_QUEENS → nom, prénom, téléphone en clair ; e-mail et licence *****, naissance NULL
USE SECONDARY ROLES NONE;
USE ROLE RESP_DEPOT_QUEENS;
USE WAREHOUSE NYC_TAXI_WH;
SELECT * FROM NYC_TAXI.MARTS.DIM_DRIVER WHERE driver_id = 'D0003';

-- Test : ANALYSTE → D0003 visible, tout le reste *****, naissance 1981-01-01
USE SECONDARY ROLES NONE;
USE ROLE ANALYSTE;
USE WAREHOUSE NYC_TAXI_WH;
SELECT * FROM NYC_TAXI.MARTS.DIM_DRIVER WHERE driver_id = 'D0003';
SELECT DISTINCT driver_name FROM NYC_TAXI.MARTS.MART_DRIVER_MONTHLY WHERE driver_id = 'D0003';   -- *****
SELECT COUNT(*) FROM NYC_TAXI.MARTS.DIM_DRIVER WHERE email LIKE '%@%';                           -- test 18 : 0

-- Test 9 bis : ACCOUNTADMIN sur RAW → lignes visibles, valeurs masquées
USE SECONDARY ROLES NONE;
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE NYC_TAXI_WH;
SELECT CURRENT_ROLE(), IS_ROLE_IN_SESSION('TRANSFORMER');    -- ACCOUNTADMIN, TRUE : pourquoi CURRENT_ROLE()
SELECT first_name, email FROM NYC_TAXI.RAW.DRIVERS LIMIT 3;  -- ***** partout

-- Test : TRANSFORMER → tout en clair (le pipeline lit les vraies valeurs)
USE SECONDARY ROLES NONE;
USE ROLE TRANSFORMER;
USE WAREHOUSE NYC_TAXI_WH;
SELECT first_name, email, birth_date FROM NYC_TAXI.RAW.DRIVERS WHERE driver_id = 'D0003';
