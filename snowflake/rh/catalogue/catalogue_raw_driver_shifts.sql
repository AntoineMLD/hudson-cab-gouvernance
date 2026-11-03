-- =====================================================================
-- catalogue_raw_driver_shifts.sql — fiche de catalogue courte de RAW.DRIVER_SHIFTS
-- Jour 1, étape 11. À exécuter en entier avec le rôle des outils. Rejouable.
-- =====================================================================
USE SECONDARY ROLES NONE;
USE ROLE TRANSFORMER;
USE WAREHOUSE NYC_TAXI_WH;

COMMENT ON TABLE NYC_TAXI.RAW.DRIVER_SHIFTS IS
  'Relevé des services, copie fidèle de driver_shifts.csv : 1 ligne = 1 prise de poste d''un chauffeur (25 951 lignes, janvier à mars 2025), doublons et erreurs compris. Source : fichier transmis par le service RH, chargé par COPY INTO. Mise à jour à chaque nouveau fichier ; les services des chauffeurs purgés sont supprimés par T_PURGE (règle R1). Donnée personnelle indirecte : chaque service se rattache à un chauffeur par driver_id et décrit son activité (heures, courses, recette). Lue uniquement par le rôle des outils. Responsable des données : service RH.';

-- confidentiel : temps de travail et recette rattachés à une personne (données de paie).
ALTER TABLE NYC_TAXI.RAW.DRIVER_SHIFTS SET TAG
  NYC_TAXI.GOUVERNANCE.SENSIBILITE        = 'confidentiel',
  NYC_TAXI.GOUVERNANCE.DUREE_CONSERVATION = '5 ans après la fin du contrat du chauffeur, règle R1 (durée propre aux heures de travail à valider par le DPO, voir docs/VEILLE.md)';

ALTER TABLE NYC_TAXI.RAW.DRIVER_SHIFTS MODIFY COLUMN driver_id SET TAG NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE = 'identifiant_interne';

SELECT level, column_name, tag_name, tag_value
FROM TABLE(NYC_TAXI.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS('NYC_TAXI.RAW.DRIVER_SHIFTS', 'table'))
ORDER BY level, column_name;
