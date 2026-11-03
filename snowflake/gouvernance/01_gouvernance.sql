-- =====================================================================
-- 01_gouvernance.sql — le rôle qui écrit les règles, ses objets, et les droits du rôle des outils
-- Jour 1, étape 10. Exécuter en entier (Cmd/Ctrl+Maj+Entrée). Rejouable.
-- GOUVERNANCE possède le schéma, les tags (et plus tard les politiques), mais ne lit pas les données.
-- =====================================================================

-- ===================================================================== A. Avec ACCOUNTADMIN
USE SECONDARY ROLES NONE;
USE ROLE ACCOUNTADMIN;
SET moi = CURRENT_USER();

-- Le rôle de gouvernance, donné à l'utilisateur pour pouvoir le tester.
-- Pas rattaché à SYSADMIN : l'administrateur n'hérite pas de ses droits.
CREATE ROLE IF NOT EXISTS GOUVERNANCE
  COMMENT = 'Écrit les règles : tags et politiques. Ne lit pas les données';
GRANT ROLE GOUVERNANCE TO USER IDENTIFIER($moi);

-- Exécuter des requêtes, et trouver les tables auxquelles attacher ses politiques (USAGE, sans SELECT)
GRANT USAGE ON WAREHOUSE NYC_TAXI_WH TO ROLE GOUVERNANCE;
GRANT USAGE ON DATABASE  NYC_TAXI    TO ROLE GOUVERNANCE;
GRANT USAGE ON SCHEMA NYC_TAXI.RAW   TO ROLE GOUVERNANCE;
GRANT USAGE ON SCHEMA NYC_TAXI.MARTS TO ROLE GOUVERNANCE;

-- Le schéma de gouvernance : créé par l'administrateur, puis donné à GOUVERNANCE
CREATE SCHEMA IF NOT EXISTS NYC_TAXI.GOUVERNANCE
  COMMENT = 'Tags, politiques et tables de la gouvernance';
GRANT OWNERSHIP ON SCHEMA NYC_TAXI.GOUVERNANCE TO ROLE GOUVERNANCE COPY CURRENT GRANTS;

-- Attacher des politiques à des tables qu'il ne possède pas (jour 2)
GRANT APPLY MASKING POLICY    ON ACCOUNT TO ROLE GOUVERNANCE;
GRANT APPLY ROW ACCESS POLICY ON ACCOUNT TO ROLE GOUVERNANCE;

-- ===================================================================== B. Avec GOUVERNANCE
USE ROLE GOUVERNANCE;
USE WAREHOUSE NYC_TAXI_WH;

-- Les trois tags du contrat (section 3)
CREATE TAG IF NOT EXISTS NYC_TAXI.GOUVERNANCE.SENSIBILITE
  ALLOWED_VALUES 'public', 'interne', 'confidentiel'
  COMMENT = 'Sensibilité d''une table cataloguée';

CREATE TAG IF NOT EXISTS NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE
  ALLOWED_VALUES 'nom', 'email', 'telephone', 'date_naissance', 'identifiant_officiel', 'identifiant_interne'
  COMMENT = 'Nature de la donnée personnelle d''une colonne. Déclenche le masquage';

-- Texte libre (contrat, section 3) : pas de liste de valeurs permises
CREATE TAG IF NOT EXISTS NYC_TAXI.GOUVERNANCE.DUREE_CONSERVATION
  COMMENT = 'Durée de conservation d''une table, en texte libre';

-- Les résultats des règles de qualité (contrat, section 1)
CREATE TABLE IF NOT EXISTS NYC_TAXI.GOUVERNANCE.QUALITE_RESULTATS (
    regle         VARCHAR,
    mesure_le     TIMESTAMP_NTZ,
    nb_anomalies  NUMBER,
    seuil         NUMBER(18,2),
    statut        VARCHAR        -- OK ou ALERTE
) COMMENT = 'Une ligne par règle de qualité et par exécution des tâches';

-- ===================================================================== C. Avec GOUVERNANCE, pour le rôle des outils
-- GOUVERNANCE est propriétaire du schéma : c'est lui qui accorde les droits dessus.
GRANT USAGE ON SCHEMA NYC_TAXI.GOUVERNANCE TO ROLE TRANSFORMER;

-- Poser les tags sur ses propres tables (étape 11)
GRANT APPLY ON TAG NYC_TAXI.GOUVERNANCE.SENSIBILITE        TO ROLE TRANSFORMER;
GRANT APPLY ON TAG NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE TO ROLE TRANSFORMER;
GRANT APPLY ON TAG NYC_TAXI.GOUVERNANCE.DUREE_CONSERVATION TO ROLE TRANSFORMER;

-- Enregistrer les résultats de qualité (tâches du jour 3)
GRANT INSERT, SELECT ON TABLE NYC_TAXI.GOUVERNANCE.QUALITE_RESULTATS TO ROLE TRANSFORMER;

-- Créer la vue du catalogue V_CATALOGUE (jour 3)
GRANT CREATE VIEW ON SCHEMA NYC_TAXI.GOUVERNANCE TO ROLE TRANSFORMER;

-- ===================================================================== Vérifier
SHOW TAGS IN SCHEMA NYC_TAXI.GOUVERNANCE;   -- 3 lignes
SHOW GRANTS TO ROLE TRANSFORMER;            -- USAGE sur GOUVERNANCE, 3 APPLY, INSERT, SELECT, CREATE VIEW