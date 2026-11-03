-- =====================================================================
-- catalogue_dim_driver.sql — fiche de catalogue complète de MARTS.DIM_DRIVER
-- Jour 1, étape 11. À exécuter en entier avec le rôle des outils (propriétaire de la table). Rejouable :
-- COMMENT et SET TAG remplacent la valeur précédente.
-- =====================================================================
USE SECONDARY ROLES NONE;
USE ROLE TRANSFORMER;
USE WAREHOUSE NYC_TAXI_WH;

-- 1. La table
COMMENT ON TABLE NYC_TAXI.MARTS.DIM_DRIVER IS
  'Dimension chauffeur : 1 ligne = 1 chauffeur de Hudson Cab Partners, en poste ou parti (400 lignes avant purge). Source : RAW.DRIVERS (fichier du personnel transmis par le service RH), nettoyé par STAGING.STG_RH__DRIVERS. Reconstruite chaque jour par la tâche T_TABLES (INSERT OVERWRITE, la table n''est jamais recréée). Responsable des données : service RH ; responsable technique : équipe data de Hudson Cab Europe.';

-- 2. Les colonnes
COMMENT ON COLUMN NYC_TAXI.MARTS.DIM_DRIVER.driver_id          IS 'Identifiant interne du chauffeur (format D0001), attribué par le service RH. Clé de la table, sert à joindre les services. Pseudonyme : ne nomme personne seul, mais renvoie à une personne. Visible de tous les rôles métier (contrat, section 4).';
COMMENT ON COLUMN NYC_TAXI.MARTS.DIM_DRIVER.first_name         IS 'Prénom du chauffeur, tel que saisi par le service RH. Identifiant direct.';
COMMENT ON COLUMN NYC_TAXI.MARTS.DIM_DRIVER.last_name          IS 'Nom de famille du chauffeur, tel que saisi par le service RH. Identifiant direct.';
COMMENT ON COLUMN NYC_TAXI.MARTS.DIM_DRIVER.email              IS 'Adresse e-mail personnelle du chauffeur, mise en minuscules et sans espaces par le staging. Sert au service paie pour le contacter. Identifiant direct.';
COMMENT ON COLUMN NYC_TAXI.MARTS.DIM_DRIVER.phone              IS 'Numéro de téléphone du chauffeur ; vide si non renseigné dans le fichier RH. Sert aux responsables de dépôt pour joindre leurs chauffeurs. Identifiant direct.';
COMMENT ON COLUMN NYC_TAXI.MARTS.DIM_DRIVER.birth_date         IS 'Date de naissance du chauffeur. Identifiant indirect (combinée au dépôt, elle peut désigner une personne). L''analyste n''en voit que l''année.';
COMMENT ON COLUMN NYC_TAXI.MARTS.DIM_DRIVER.tlc_license_number IS 'Numéro de licence de chauffeur délivré par la TLC (Taxi and Limousine Commission) de New York. Public à New York, mais identifie une personne de façon unique : traité comme un identifiant officiel.';
COMMENT ON COLUMN NYC_TAXI.MARTS.DIM_DRIVER.depot              IS 'Dépôt de rattachement du chauffeur (Bronx, Brooklyn ou Queens), normalisé par le staging. Sert au filtre par ligne des responsables de dépôt.';
COMMENT ON COLUMN NYC_TAXI.MARTS.DIM_DRIVER.hire_date          IS 'Date d''embauche du chauffeur.';
COMMENT ON COLUMN NYC_TAXI.MARTS.DIM_DRIVER.end_date           IS 'Date de fin de contrat ; vide si le chauffeur est en poste. Point de départ du délai de conservation de 5 ans (règle R1).';
COMMENT ON COLUMN NYC_TAXI.MARTS.DIM_DRIVER.is_active          IS 'Colonne calculée : vrai si le chauffeur est en poste (end_date vide).';
COMMENT ON COLUMN NYC_TAXI.MARTS.DIM_DRIVER.tenure_years       IS 'Colonne calculée : ancienneté en années, à une décimale, de hire_date jusqu''à end_date ou, pour un chauffeur en poste, jusqu''à la date du calcul.';

-- 3. Les tags de la table
-- confidentiel : la table contient des noms, des coordonnées et des dates de naissance.
ALTER TABLE NYC_TAXI.MARTS.DIM_DRIVER SET TAG
  NYC_TAXI.GOUVERNANCE.SENSIBILITE        = 'confidentiel',
  NYC_TAXI.GOUVERNANCE.DUREE_CONSERVATION = '5 ans après la fin du contrat (end_date), règle R1';

-- 4. Les colonnes personnelles (contrat, section 3 : six valeurs possibles)
-- driver_id porte le tag lui aussi : il renvoie à une personne. La politique de masquage du jour 2
-- prévoira une exception pour la valeur identifiant_interne (visible de tous, contrat section 4).
ALTER TABLE NYC_TAXI.MARTS.DIM_DRIVER MODIFY COLUMN driver_id          SET TAG NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE = 'identifiant_interne';
ALTER TABLE NYC_TAXI.MARTS.DIM_DRIVER MODIFY COLUMN first_name         SET TAG NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE = 'nom';
ALTER TABLE NYC_TAXI.MARTS.DIM_DRIVER MODIFY COLUMN last_name          SET TAG NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE = 'nom';
ALTER TABLE NYC_TAXI.MARTS.DIM_DRIVER MODIFY COLUMN email              SET TAG NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE = 'email';
ALTER TABLE NYC_TAXI.MARTS.DIM_DRIVER MODIFY COLUMN phone              SET TAG NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE = 'telephone';
ALTER TABLE NYC_TAXI.MARTS.DIM_DRIVER MODIFY COLUMN birth_date         SET TAG NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE = 'date_naissance';
ALTER TABLE NYC_TAXI.MARTS.DIM_DRIVER MODIFY COLUMN tlc_license_number SET TAG NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE = 'identifiant_officiel';
-- Non tagués : depot, hire_date, end_date, is_active, tenure_years. Ils ne désignent personne seuls,
-- aucune des six valeurs du contrat ne leur correspond, et le contrat ne demande pas de les masquer.
-- Ils restent des identifiants indirects (voir docs/REGISTRE.md et la limite « réidentification » du README).

-- 5. Vérifier : 12 colonnes décrites, 7 colonnes taguées, 2 tags sur la table
SELECT column_name, comment FROM NYC_TAXI.INFORMATION_SCHEMA.COLUMNS
WHERE table_schema = 'MARTS' AND table_name = 'DIM_DRIVER' ORDER BY ordinal_position;

SELECT level, column_name, tag_name, tag_value
FROM TABLE(NYC_TAXI.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS('NYC_TAXI.MARTS.DIM_DRIVER', 'table'))
ORDER BY level, column_name;
