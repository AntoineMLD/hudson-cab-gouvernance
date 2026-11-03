# hudson-cab-gouvernance

Gouvernance de l'entrepôt Snowflake du domaine RH de Hudson Cab Partners, flotte de taxis new-yorkaise dont les données du personnel sont gérées depuis Paris par sa filiale Hudson Cab Europe. Ce dépôt contient les scripts SQL rejouables (chargement, catalogue, rôles, masquage, filtre par dépôt, purge, qualité, tâches planifiées, audit) et la documentation associée (veille réglementaire, registre du traitement, carte des droits et cahier de tests).

Les fichiers RH (`data/*.csv`) ne sont pas publiés : même fictif, un fichier du personnel contient des noms, des e-mails, des téléphones et des dates de naissance, et un fichier poussé une fois sur un dépôt public reste dans son historique. Ils sont exclus par le `.gitignore` et se récupèrent à part, depuis le kit de démarrage.

## Gouvernance

### Écart principal : les chauffeurs partis restent cinq ans dans la base active

C'est l'écart qui touche le plus les chauffeurs eux-mêmes. Pendant 5 ans après son départ, un chauffeur reste dans `MARTS.DIM_DRIVER` à côté des actifs : le responsable de son ancien dépôt voit encore son nom et son téléphone, et l'analyste ses données pseudonymisées. Le Fail-safe (R2) prolonge la vie d'une donnée de 7 jours, n'est accessible qu'au support Snowflake et ne l'expose à personne. Les chauffeurs partis, eux, restent visibles de personnes qui n'en ont plus besoin, pendant des années.

- **Ce que dit le texte** : après la fin du contrat, les données passent en archive intermédiaire séparée de la base active, d'accès restreint, et seulement si une obligation ou un contentieux le justifie (CNIL, référentiel GRH 2019, section 7 ; RGPD, art. 5.1.c et 5.1.e).
- **Ce que dit le contrat** : R1 fixe seulement une suppression à 5 ans, et la matrice des accès ne distingue pas actifs et partis.
- **Notre proposition** : dès que `end_date` est renseignée, réserver les lignes du chauffeur à `RH_PAIE` jusqu'à la purge, et supprimer ses coordonnées (`email`, `phone`) dès son départ.

Le détail de la confrontation, règle par règle, est dans [`docs/VEILLE.md`](docs/VEILLE.md), section 4.

### Ce que nous avons mis en œuvre : le contrat tel qu'il est

<!-- Cocher au fur et à mesure des jours 2 et 3 -->
- [ ] Matrice des accès appliquée telle qu'écrite : masquage par tag, filtre par ligne via `ACCES_DEPOT`, actifs et partis traités de la même façon.
- [ ] R1 : `T_PURGE` supprime les chauffeurs 5 ans après `end_date`, ainsi que leurs services, puis `T_TABLES` reconstruit les marts.
- [ ] R2 : Time Travel réglé à 1 jour sur les tables RH. Les tables restent permanentes.
- [ ] R3 : `PURGE = TRUE` au chargement, et `data/` exclu du dépôt Git.
- [ ] Règles de qualité : `licence_unique`, `service_rattache` (bloquante), plus ______, enregistrées dans `QUALITE_RESULTATS`.

### Ce que nous proposons à la direction (non mis en œuvre)

| Écart | Règle | Proposition | Contrepartie |
|---|---|---|---|
| Chauffeurs partis en base active (écart principal) | R1, matrice | Réserver leurs lignes à `RH_PAIE` ; supprimer les coordonnées au départ | Le filtre par ligne se complique ; les responsables de dépôt perdent l'historique de leurs anciens chauffeurs |
| Fail-safe de 7 jours non couvert | R2 | Marts en tables transientes ; `RAW` reste permanente, et les 8 jours sont écrits dans le registre | Recréer les tables par `CLONE` pour garder les tags et les politiques, avec `COPY GRANTS` pour les droits ; aucune récupération possible après 1 jour sur les marts ; tant que `RAW` reste permanente, la donnée purgée y survit 8 jours : on réduit le nombre de copies, pas la durée |
| Même durée pour toutes les données | R1 | Une durée par catégorie (identité, coordonnées, services) ; durée légale validée par le DPO | Plusieurs valeurs de `DUREE_CONSERVATION`, et une purge plus complexe |
| Aucun rôle pour répondre à une demande d'accès | Matrice | Procédure tracée : extraction par `TRANSFORMER` à la demande de `RH_PAIE` | Un rôle technique touche des données à des fins métier, d'où la nécessité de tracer |
| Réidentification possible par `ANALYSTE` | Matrice | Avis du DPO ; agréger ou retirer l'ancienneté | Moins de finesse pour les analyses |
| Détection sans correction ; règle bloquante qui empêche la purge | Qualité | Responsable et délai de correction ; correction dans `RAW` ; purge des marts par `T_PURGE` | `T_PURGE` touche aussi les marts : une règle de plus à tester |
| Copies du fichier RH hors Snowflake | R3 (hors contrat) | Bonne pratique : `data/` dans le `.gitignore` (fait) ; copies locales supprimées après validation du chargement (à faire) | Aucune |

### Choix techniques

<!-- Jour 2 : une ligne par colonne personnelle, masquer ou supprimer, et pourquoi -->

| Colonne | Décision (masquer, supprimer, laisser) | Pour quel rôle | Raison |
|---|---|---|---|
| `driver_id` (4 tables) | taguer `identifiant_interne`, laisser visible | tous les rôles métier | Le contrat le veut visible de tous pour compter et joindre sans nommer ; il porte quand même le tag car il renvoie à une personne (pseudonyme). La politique de masquage prévoit une exception pour cette valeur. |
| `driver_name` (`MART_DRIVER_MONTHLY`) | taguer `nom` | — | Colonne calculée à partir du prénom et du nom : c'est une donnée personnelle, masquée comme le nom. |
| `depot`, `hire_date`, `end_date`, `is_active`, `tenure_years` | ne pas taguer `DONNEE_PERSONNELLE` | — | Ils ne désignent personne seuls, aucune des six valeurs du contrat ne leur correspond, et le contrat ne demande pas de les masquer. Ce sont pourtant des identifiants indirects : combinés à l'année de naissance, ils peuvent permettre de réidentifier un chauffeur (voir « Ce que nous proposons à la direction »). |

### Ordre d'exécution des scripts

Chaque script s'exécute en entier dans une feuille Snowsight, avec le rôle indiqué.

| Ordre | Script | Rôle | Vérification |
|---|---|---|---|
| 1 | `snowflake/00_installation.sql` | `ACCOUNTADMIN` | 3 schémas : `RAW`, `STAGING`, `MARTS` |
| 2 | `snowflake/rh/chargement_rh_1_preparer.sql` | `TRANSFORMER` | le stage `RH_STAGE` existe |
| 3 | Dépôt des 2 CSV sur le stage depuis Snowsight | `TRANSFORMER` | `LIST @NYC_TAXI.RAW.RH_STAGE;` : 2 fichiers |
| 4 | `snowflake/rh/chargement_rh_2_copier.sql` | `TRANSFORMER` | 400 et 25 951 lignes, stage vide |
| 5 | `snowflake/rh/00_tables_rh.sql` | `TRANSFORMER` | 3 tables dans `MARTS` |
| 6 | `snowflake/rh/staging/stg_rh__drivers.sql`, `stg_rh__driver_shifts.sql` | `TRANSFORMER` | 2 vues ; 25 933 services |
| 7 | `snowflake/rh/marts/dim_depot.sql`, `dim_driver.sql`, `mart_driver_monthly.sql` | `TRANSFORMER` | 3, 400 et 914 lignes |
| 8 | `snowflake/gouvernance/01_gouvernance.sql` | `ACCOUNTADMIN` puis `GOUVERNANCE` (dans le script) | `SHOW TAGS IN SCHEMA NYC_TAXI.GOUVERNANCE;` : 3 tags ; relancé sans erreur |
| 9 | `snowflake/gouvernance/modele_catalogue_dim_depot.sql` | `TRANSFORMER` | 4 colonnes décrites, 2 tags sur `DIM_DEPOT` |
| 10 | `snowflake/rh/catalogue/catalogue_*.sql` (4 fichiers) | `TRANSFORMER` | aucune colonne sans description dans `DIM_DRIVER` et `RAW.DRIVERS` ; 4 tables taguées |
| 11 | `snowflake/gouvernance/02_roles_metier.sql` | `ACCOUNTADMIN` | `SHOW GRANTS TO ROLE RESP_DEPOT_QUEENS;` : USAGE + 3 SELECT ; relancé sans erreur |
| 12 | ______ | | |

### Le chargement, étape par étape

Les deux fichiers RH sont chargés dans `RAW` avec le rôle des outils `TRANSFORMER`, en trois temps : préparer (`chargement_rh_1_preparer.sql`), déposer les fichiers sur le stage depuis Snowsight, copier (`chargement_rh_2_copier.sql`). Quatre notions à comprendre :

1. **Le format de fichier** (`NYC_TAXI.RAW.CSV_RH`) dit à Snowflake comment lire un CSV : virgule comme séparateur (`TYPE = CSV`), première ligne ignorée car elle contient les noms de colonnes (`SKIP_HEADER = 1`), valeurs éventuellement entourées de guillemets (`FIELD_OPTIONALLY_ENCLOSED_BY = '"'`). `TRIM_SPACE = FALSE` garde les espaces, parce que `RAW` est une copie fidèle du fichier : le nettoyage se fait plus loin, dans les vues de `STAGING`, et les erreurs de saisie restent mesurables par les règles de qualité.
2. **Le stage** (`NYC_TAXI.RAW.RH_STAGE`) est un espace de dépôt interne à Snowflake, chiffré côté serveur, où l'on pose les fichiers avant de les copier dans une table. Les deux CSV y sont déposés depuis Snowsight (bouton + Files), puis vérifiés avec `LIST`.
3. **`COPY INTO`** copie chaque fichier du stage dans sa table (`RAW.DRIVERS`, `RAW.DRIVER_SHIFTS`). Il ajoute deux colonnes techniques : `_source_file`, qui vient de `METADATA$FILENAME` (le nom du fichier chargé), et `_loaded_at`, qui vient de `METADATA$START_SCAN_TIME` (l'heure du chargement). Elles permettent de savoir d'où vient chaque ligne. `ON_ERROR = ABORT_STATEMENT` arrête tout à la première ligne illisible, plutôt que de l'ignorer en silence (`CONTINUE`) et de charger une copie incomplète.
4. **`PURGE = TRUE`** retire chaque fichier du stage une fois copié : c'est la règle R3 du contrat.

**Rejouer le chargement** : relancé, `chargement_rh_2_copier.sql` échoue avec « Remote file '@rh_stage/drivers.csv' was not found ». Les fichiers sont nommés explicitement (`FILES = (...)`) et ont été purgés : le commentaire du script fourni (« ne charge rien de plus ») est donc inexact, et les comptages restent à 400 et 25 951. Si l'on redépose le même fichier, `COPY INTO` ne le recharge pas, parce qu'il garde pendant 64 jours l'historique des fichiers déjà chargés dans la table (nom et empreinte du fichier). Aucun doublon n'est donc possible, sauf avec `FORCE = TRUE` ou un fichier modifié.

Résultat : 400 chauffeurs, 25 951 services, stage vide (captures `docs/capture_stage_vide.png` et `docs/capture_relance_copy.png`).

### Limites connues

<!-- À compléter au fil des jours, sans détour -->