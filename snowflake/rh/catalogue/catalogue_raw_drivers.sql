-- =====================================================================
-- catalogue_raw_drivers.sql — fiche de catalogue complète de RAW.DRIVERS
-- Jour 1, étape 11. À exécuter en entier avec le rôle des outils (propriétaire de la table). Rejouable.
-- Les vues de STAGING ne se cataloguent pas : elles lisent RAW, et ce qui protège RAW s'applique à elles.
-- =====================================================================
USE SECONDARY ROLES NONE;
USE ROLE TRANSFORMER;
USE WAREHOUSE NYC_TAXI_WH;

-- 1. La table
COMMENT ON TABLE NYC_TAXI.RAW.DRIVERS IS
  'Fichier du personnel, copie fidèle de drivers.csv : 1 ligne = 1 chauffeur (400 lignes avant purge), erreurs de saisie comprises. Source : fichier transmis par le service RH, déposé sur RH_STAGE puis chargé par COPY INTO (chargement_rh_2_copier.sql). Mise à jour à chaque nouveau fichier transmis par le RH ; purgée chaque jour par la tâche T_PURGE (règle R1). Lue uniquement par le rôle des outils. Responsable des données : service RH.';

-- 2. Les colonnes
COMMENT ON COLUMN NYC_TAXI.RAW.DRIVERS.driver_id          IS 'Identifiant interne du chauffeur (format D0001), attribué par le service RH. Pseudonyme : renvoie à une personne sans la nommer.';
COMMENT ON COLUMN NYC_TAXI.RAW.DRIVERS.first_name         IS 'Prénom du chauffeur, tel que saisi dans le fichier RH. Identifiant direct.';
COMMENT ON COLUMN NYC_TAXI.RAW.DRIVERS.last_name          IS 'Nom de famille du chauffeur, tel que saisi dans le fichier RH. Identifiant direct.';
COMMENT ON COLUMN NYC_TAXI.RAW.DRIVERS.email              IS 'Adresse e-mail du chauffeur, telle que saisie (casse et espaces non corrigés). Identifiant direct. Contrôlée par la règle de qualité email_valide.';
COMMENT ON COLUMN NYC_TAXI.RAW.DRIVERS.phone              IS 'Numéro de téléphone du chauffeur, tel que saisi ; peut être vide. Identifiant direct. Contrôlé par la règle telephone_renseigne.';
COMMENT ON COLUMN NYC_TAXI.RAW.DRIVERS.birth_date         IS 'Date de naissance du chauffeur. Identifiant indirect.';
COMMENT ON COLUMN NYC_TAXI.RAW.DRIVERS.tlc_license_number IS 'Numéro de licence délivré par la TLC de New York. Public à New York, mais identifie une personne de façon unique. Contrôlé par la règle licence_unique.';
COMMENT ON COLUMN NYC_TAXI.RAW.DRIVERS.depot              IS 'Dépôt de rattachement, tel que saisi (orthographe non corrigée). Contrôlé par la règle depot_connu ; normalisé dans STAGING.';
COMMENT ON COLUMN NYC_TAXI.RAW.DRIVERS.hire_date          IS 'Date d''embauche du chauffeur. Contrôlée par la règle dates_coherentes.';
COMMENT ON COLUMN NYC_TAXI.RAW.DRIVERS.end_date           IS 'Date de fin de contrat ; vide si le chauffeur est en poste. Point de départ du délai de 5 ans de la règle R1.';
COMMENT ON COLUMN NYC_TAXI.RAW.DRIVERS._source_file       IS 'Colonne technique : nom du fichier dont vient la ligne (METADATA$FILENAME au chargement).';
COMMENT ON COLUMN NYC_TAXI.RAW.DRIVERS._loaded_at         IS 'Colonne technique : date et heure du chargement de la ligne (METADATA$START_SCAN_TIME).';

-- 3. Les tags de la table
ALTER TABLE NYC_TAXI.RAW.DRIVERS SET TAG
  NYC_TAXI.GOUVERNANCE.SENSIBILITE        = 'confidentiel',
  NYC_TAXI.GOUVERNANCE.DUREE_CONSERVATION = '5 ans après la fin du contrat (end_date), règle R1';

-- 4. Les colonnes personnelles (mêmes choix que DIM_DRIVER)
ALTER TABLE NYC_TAXI.RAW.DRIVERS MODIFY COLUMN driver_id          SET TAG NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE = 'identifiant_interne';
ALTER TABLE NYC_TAXI.RAW.DRIVERS MODIFY COLUMN first_name         SET TAG NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE = 'nom';
ALTER TABLE NYC_TAXI.RAW.DRIVERS MODIFY COLUMN last_name          SET TAG NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE = 'nom';
ALTER TABLE NYC_TAXI.RAW.DRIVERS MODIFY COLUMN email              SET TAG NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE = 'email';
ALTER TABLE NYC_TAXI.RAW.DRIVERS MODIFY COLUMN phone              SET TAG NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE = 'telephone';
ALTER TABLE NYC_TAXI.RAW.DRIVERS MODIFY COLUMN birth_date         SET TAG NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE = 'date_naissance';
ALTER TABLE NYC_TAXI.RAW.DRIVERS MODIFY COLUMN tlc_license_number SET TAG NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE = 'identifiant_officiel';

-- 5. Vérifier : 12 colonnes décrites, 7 colonnes taguées
SELECT column_name, comment FROM NYC_TAXI.INFORMATION_SCHEMA.COLUMNS
WHERE table_schema = 'RAW' AND table_name = 'DRIVERS' ORDER BY ordinal_position;

SELECT level, column_name, tag_name, tag_value
FROM TABLE(NYC_TAXI.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS('NYC_TAXI.RAW.DRIVERS', 'table'))
ORDER BY level, column_name;
