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
- [x] Matrice des accès appliquée telle qu'écrite : masquage par tag (`03_masquage.sql`), filtre par ligne via `ACCES_DEPOT` (`04_acces_depot.sql`), actifs et partis traités de la même façon. Preuve : cahier de tests de `docs/ACCES.md`, entièrement vert.
- [x] R1 : `purge_rh.sql` supprime les services puis les chauffeurs partis depuis plus de 5 ans (46 au 03/11/2026), puis les marts sont reconstruits. Automatisé par `T_PURGE` (à venir).
- [x] R2 : Time Travel réglé à 1 jour sur les 4 tables RH (`conservation_rh.sql`). Les tables restent permanentes (Fail-safe de 7 jours, voir l'écart).
- [x] R3 : `PURGE = TRUE` au chargement, et `data/` exclu du dépôt Git. Preuve : stage vide après chargement (`docs/capture_stage_vide.png`), `git log --all -- data/` vide.
- [x] Règles de qualité : `licence_unique`, `service_rattache` (bloquante), `depot_connu`, `telephone_renseigne`, mesurées chaque jour par `T_QUALITE` et enregistrées dans `QUALITE_RESULTATS`. Graphe quotidien `T_PURGE` → `T_QUALITE` → `T_TABLES` (6 h, heure de Paris), exécuté par le rôle des outils.

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
| `first_name`, `last_name`, `email`, `phone`, `birth_date`, `tlc_license_number`, `driver_name` | masquer, pas supprimer | `ANALYSTE`, responsables de dépôt, administrateurs | Une même table sert la paie (tout en clair) et l'analyste (rien d'identifiant) : seul le masquage dynamique permet les deux sans dupliquer les tables. Deux politiques attachées au tag `DONNEE_PERSONNELLE` (une pour le texte, une pour les dates, car une politique renvoie le type qu'elle reçoit) : toute colonne taguée, dans `RAW` comme dans `MARTS`, est protégée sans autre geste. Le test de rôle utilise `CURRENT_ROLE()` et non `IS_ROLE_IN_SESSION()`, pour que `ACCOUNTADMIN`, qui hérite de `TRANSFORMER`, ne voie pas les données en clair. Les responsables de dépôt sont reconnus par le préfixe `RESP_DEPOT_`, pour qu'un nouveau dépôt ne demande aucune modification de politique. |
| Lignes de `DIM_DRIVER` et `MART_DRIVER_MONTHLY` | filtrer par dépôt avec une politique d'accès par ligne pilotée par `GOUVERNANCE.ACCES_DEPOT` | responsables de dépôt ; administrateurs et rôles absents de la matrice | Qui voit quel dépôt est écrit dans des lignes, pas dans la politique : ouvrir un dépôt ou un accès = une ligne `INSERT`, sans modifier la politique (test 20). `*` = tous les dépôts (`TRANSFORMER`, `RH_PAIE`, `ANALYSTE`). `TRANSFORMER` doit y figurer, sinon le pipeline ne verrait aucune ligne et reconstruirait les marts vides, sans erreur. Les lignes de référence sont insérées par `MERGE` : le script est rejouable sans effacer un accès ajouté plus tard. Le filtre ne porte que sur `MARTS` (guide) ; `RAW` n'est lisible que par `TRANSFORMER` et, par héritage, par les administrateurs, pour qui les colonnes personnelles restent masquées (test 9 bis). |
| `RAW.DRIVER_SHIFTS` (purge R1) | purger les services des chauffeurs purgés, avant les chauffeurs | `T_PURGE` (rôle des outils) | R1 s'applique partout où la donnée du chauffeur a été copiée. Avec le fichier actuel, 46 chauffeurs sont purgés et 0 service (services de janvier à mars 2025, chauffeurs partis avant novembre 2021) ; avec un fichier historique complet, la purge des services évite de garder l'activité de chauffeurs supprimés et des services orphelins, qui bloqueraient la règle `service_rattache`. Les services d'abord : une fois le chauffeur supprimé, on ne saurait plus lesquels lui appartenaient. |
| Durée de rétention | `DATA_RETENTION_TIME_IN_DAYS = 1` posé explicitement sur les 4 tables RH | rôle des outils (propriétaire) | Règle R2. Posée table par table pour ne pas dépendre du réglage du compte ou de la base. `DIM_DEPOT` n'est pas concernée (aucune donnée personnelle). |
| Tâches planifiées | 3 tâches en graphe, propriété du rôle des outils, corps en `EXECUTE IMMEDIATE $$ … $$` | `TRANSFORMER` | Une tâche s'exécute avec les droits de son propriétaire : `TRANSFORMER` voit les vraies valeurs (sinon les mesures de qualité seraient fausses et les marts recevraient des masques) et toutes les lignes. `T_QUALITE` enregistre toutes les mesures avant de lever l'erreur : on garde la trace du dépassement qui a bloqué la chaîne. `T_TABLES` reprend les `INSERT OVERWRITE` des fichiers de `rh/marts/` : les tables ne sont jamais recréées, et les tags, descriptions et politiques survivent. |

### Les règles de qualité

Mesurées chaque jour sur `RAW` par la tâche `T_QUALITE`, avec le rôle des outils (qui voit les vraies valeurs : une règle mesurée sur des valeurs masquées ne mesurerait rien). Chaque exécution ajoute une ligne par règle dans `GOUVERNANCE.QUALITE_RESULTATS` (`OK` si `nb_anomalies <= seuil`, sinon `ALERTE`).

| Règle | Énoncé | Fichier | Seuil | Gravité | Mesure au 03/11/2026 |
|---|---|---|---|---|---|
| `licence_unique` | un numéro de licence n'appartient qu'à un chauffeur | `controles/licence_unique.sql` (fourni) | 0 | avertissement | 4 → ALERTE (4 licences partagées entre plusieurs chauffeurs) |
| `service_rattache` | chaque service appartient à un chauffeur connu | `controles/service_rattache.sql` | 50 services | **bloquante** : `T_TABLES` ne reconstruit pas `MARTS` | 25 → OK (25 services orphelins dans le fichier d'origine, sous le seuil de 50) |
| `depot_connu` | le dépôt est écrit exactement `Bronx`, `Brooklyn` ou `Queens` (chauffeurs et services) | `controles/depot_connu.sql` | 0 | avertissement | 9 → ALERTE (dépôts mal écrits dans le fichier ; corrigés dans STAGING, mais la source reste fausse) |
| `telephone_renseigne` | chaque chauffeur en poste a un téléphone | `controles/telephone_renseigne.sql` | 5 % des chauffeurs en poste, converti en nombre à la mesure | avertissement | 12 → OK (seuil : 14,50 = 5 % de 290 chauffeurs en poste) |

**Pourquoi le rôle des outils** : lancée avec `ACCOUNTADMIN`, la règle `licence_unique` a renvoyé 353 au lieu de 4. Pour l'administrateur, toutes les licences sont masquées (`*****`) : `COUNT(DISTINCT tlc_license_number)` ne voit qu'une valeur, et 354 − 1 = 353. Une règle de qualité mesurée sur des valeurs masquées ne mesure rien : les règles tournent avec `TRANSFORMER`, dans la tâche `T_QUALITE`. `service_rattache` et `depot_connu` donnaient le bon résultat, car `driver_id` n'est jamais masqué et `depot` n'est pas tagué.

**Qui corrige** : une `ALERTE` signale une erreur du fichier source. Elle se corrige dans le système RH, puis par un nouveau chargement ; l'équipe data ne réécrit pas `RAW` à la main (voir l'écart « détection sans correction »).

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
| 12 | `snowflake/gouvernance/03_masquage.sql` (partie A) | `GOUVERNANCE` | `SHOW MASKING POLICIES` : 2 politiques ; `POLICY_REFERENCES` sur `DIM_DRIVER` : attachées par le tag ; relancé sans erreur |
| 13 | `snowflake/gouvernance/04_acces_depot.sql` (partie A) | `GOUVERNANCE` | `ACCES_DEPOT` : 5 lignes ; `RESP_DEPOT_QUEENS` voit 161 chauffeurs ; relancé sans erreur |
| 14 | `snowflake/rh/purge_rh.sql` | `TRANSFORMER` | 46 chauffeurs purgés (au 03/11/2026), 0 service ; `RAW.DRIVERS` : 354 |
| 15 | `snowflake/rh/marts/dim_driver.sql`, puis `mart_driver_monthly.sql` | `TRANSFORMER` | `DIM_DRIVER` : 354 ; `MART_DRIVER_MONTHLY` : 914 |
| 16 | `snowflake/rh/conservation_rh.sql` | `TRANSFORMER` | `retention_time` = 1 sur les 4 tables RH |
| 17 | `snowflake/rh/controles/*.sql` (4 règles) | `TRANSFORMER` | licence_unique 4, service_rattache 25, depot_connu 9, telephone_renseigne 12 / 14,50 |
| 18 | `snowflake/rh/catalogue/v_catalogue.sql` | `TRANSFORMER` | 24 lignes ; `ANALYSTE` lit la vue et y trouve les 3 tables |
| 19 | `snowflake/rh/taches_rh.sql` (partie A) | `TRANSFORMER` | 3 tâches `started` ; après `EXECUTE TASK` : `T_PURGE`, `T_QUALITE`, `T_TABLES` en `SUCCEEDED`, 4 lignes dans `QUALITE_RESULTATS` |
| 20 | `snowflake/gouvernance/06_audit.sql` | `ACCOUNTADMIN` | les rôles qui ont lu `DIM_DRIVER` ces 7 derniers jours, avec les colonnes (jusqu'à 3 h de latence) |
| 21 | fin du brief : `ALTER TASK NYC_TAXI.MARTS.T_PURGE SUSPEND;` | `TRANSFORMER` | `SHOW TASKS` : `suspended` (les tâches activées consomment des crédits) |

### Le chargement, étape par étape

Les deux fichiers RH sont chargés dans `RAW` avec le rôle des outils `TRANSFORMER`, en trois temps : préparer (`chargement_rh_1_preparer.sql`), déposer les fichiers sur le stage depuis Snowsight, copier (`chargement_rh_2_copier.sql`). Quatre notions à comprendre :

1. **Le format de fichier** (`NYC_TAXI.RAW.CSV_RH`) dit à Snowflake comment lire un CSV : virgule comme séparateur (`TYPE = CSV`), première ligne ignorée car elle contient les noms de colonnes (`SKIP_HEADER = 1`), valeurs éventuellement entourées de guillemets (`FIELD_OPTIONALLY_ENCLOSED_BY = '"'`). `TRIM_SPACE = FALSE` garde les espaces, parce que `RAW` est une copie fidèle du fichier : le nettoyage se fait plus loin, dans les vues de `STAGING`, et les erreurs de saisie restent mesurables par les règles de qualité.
2. **Le stage** (`NYC_TAXI.RAW.RH_STAGE`) est un espace de dépôt interne à Snowflake, chiffré côté serveur, où l'on pose les fichiers avant de les copier dans une table. Les deux CSV y sont déposés depuis Snowsight (bouton + Files), puis vérifiés avec `LIST`.
3. **`COPY INTO`** copie chaque fichier du stage dans sa table (`RAW.DRIVERS`, `RAW.DRIVER_SHIFTS`). Il ajoute deux colonnes techniques : `_source_file`, qui vient de `METADATA$FILENAME` (le nom du fichier chargé), et `_loaded_at`, qui vient de `METADATA$START_SCAN_TIME` (l'heure du chargement). Elles permettent de savoir d'où vient chaque ligne. `ON_ERROR = ABORT_STATEMENT` arrête tout à la première ligne illisible, plutôt que de l'ignorer en silence (`CONTINUE`) et de charger une copie incomplète.
4. **`PURGE = TRUE`** retire chaque fichier du stage une fois copié : c'est la règle R3 du contrat.

**Rejouer le chargement** : relancé, `chargement_rh_2_copier.sql` échoue avec « Remote file '@rh_stage/drivers.csv' was not found ». Les fichiers sont nommés explicitement (`FILES = (...)`) et ont été purgés : le commentaire du script fourni (« ne charge rien de plus ») est donc inexact, et les comptages restent à 400 et 25 951. Si l'on redépose le même fichier, `COPY INTO` ne le recharge pas, parce qu'il garde pendant 64 jours l'historique des fichiers déjà chargés dans la table (nom et empreinte du fichier). Aucun doublon n'est donc possible, sauf avec `FORCE = TRUE` ou un fichier modifié.

Résultat : 400 chauffeurs, 25 951 services, stage vide (captures `docs/capture_stage_vide.png` et `docs/capture_relance_copy.png`).

### Limites connues

- `ALTER TABLE ... DROP ALL ROW ACCESS POLICIES` dans `04_acces_depot.sql` retirerait aussi une autre politique d'accès par ligne posée plus tard sur ces tables.
- Le filtre par dépôt ne distingue pas chauffeurs en poste et chauffeurs partis : un responsable voit pendant 5 ans le nom et le téléphone de ses anciens chauffeurs (écart principal, voir plus haut).
- `GOUVERNANCE` peut modifier `ACCES_DEPOT` et les politiques : il ne lit pas les données, mais il peut en ouvrir l'accès à un autre rôle. Ses modifications sont tracées dans `ACCESS_HISTORY` et `QUERY_HISTORY` (requête d'audit du jour 3).
- Une donnée purgée survit 8 jours dans Snowflake : 1 jour de Time Travel (R2), puis 7 jours de Fail-safe, que l'on ne peut pas raccourcir sur une table permanente (voir `docs/REGISTRE.md` et `docs/VEILLE.md`).
- Les règles de qualité détectent sans corriger : une `ALERTE` se corrige dans le système RH, puis par un nouveau chargement. `licence_unique` (4) et `depot_connu` (9) sont en alerte au 03/11/2026.
- `driver_id`, combiné au dépôt, à l'année de naissance et à l'ancienneté, peut permettre à l'analyste de réidentifier certains chauffeurs.
- Le rôle des outils `TRANSFORMER` voit tout en clair et peut retirer un tag de masquage : sa compromission exposerait toutes les données. Le risque est limité par la traçabilité (`ACCESS_HISTORY`, `QUERY_HISTORY`) et par `06_audit.sql`, pas supprimé.
- L'audit de `ACCESS_HISTORY` a jusqu'à 3 h de latence : les lectures de la dernière heure peuvent manquer.
- Le droit du travail applicable aux durées de conservation (français ou new-yorkais) reste à trancher par le DPO et le conseil juridique (`docs/VEILLE.md`).
- Le graphe de tâches reste activé tant que `T_PURGE` n'est pas suspendu (`ALTER TASK NYC_TAXI.MARTS.T_PURGE SUSPEND;`) : il consomme des crédits chaque jour.
