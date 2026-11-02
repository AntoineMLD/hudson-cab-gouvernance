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
| | | | |

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
| 8 | ______ | | |

### Le chargement, étape par étape

<!-- Jour 1, étape 8 : à quoi servent le format de fichier, le stage, COPY INTO et PURGE = TRUE -->

### Limites connues

<!-- À compléter au fil des jours, sans détour -->