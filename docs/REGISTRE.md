# Registre du traitement — données du personnel

Copier ce fichier sous le nom `docs/REGISTRE.md`. Il se remplit en deux temps :

- **Partie 1, jour 1** : l'inventaire des données personnelles des deux fichiers, avant tout chargement ;
- **Partie 2, jour 3** : la fiche de registre, qui s'appuie sur l'inventaire et sur ce que vous avez construit.

---

## Partie 1 — Inventaire des données personnelles (jour 1)

Une donnée personnelle est une information qui se rapporte à une personne identifiée ou identifiable. Trois cas à distinguer :

- **identifiant direct** : la colonne suffit à désigner la personne (un nom, un e-mail) ;
- **identifiant indirect** : la colonne ne suffit pas seule, mais permet d'identifier quelqu'un une fois combinée à d'autres (une date de naissance et un dépôt) ;
- **pas une donnée personnelle** : la colonne ne dit rien d'une personne.

### `drivers.csv` : les colonnes

| Colonne | Exemple de valeur | Donnée personnelle ? (direct, indirect, non) | Valeur du tag `DONNEE_PERSONNELLE` | Qui en a besoin, et pour quoi faire |
|---|---|---|---|---|
| `driver_id` | D0001 | indirect : pseudonyme, il ne désigne personne seul mais renvoie à la ligne du chauffeur dans `drivers.csv` | `identifiant_interne` | Tous les rôles métier : compter et joindre sans nommer (contrat section 4) |
| `first_name` | Thomas | direct | `nom` | Paie (contrats) ; responsables de dépôt (contacter leur équipe). Pas l'analyste |
| `last_name` | Pierre | direct | `nom` | Idem `first_name` |
| `email` | thomas.pierre1@post.example | direct | `email` | Paie (communication RH). Personne d'autre |
| `phone` | +1 (917) 555-0161 | direct | `telephone` | Paie ; responsables de dépôt (joindre un chauffeur) |
| `birth_date` | 1957-07-24 | indirect : seule elle ne désigne personne, mais avec le dépôt et la date d'embauche elle isole presque quelqu'un | `date_naissance` | Paie (obligations légales). Analyste : l'année seulement, pour les âges |
| `tlc_license_number` | 5841963 | direct : numéro officiel propre à une personne. Qu'il soit public à New York ne change rien : une donnée publique reste personnelle, et sa présence ici la relie à un nom, un e-mail et un téléphone | `identifiant_officiel` | Paie / conformité (vérifier la licence). Personne d'autre |
| `depot` | Bronx | indirect : avec `birth_date` et `hire_date` elle réduit un groupe à une personne | aucun (hors des six valeurs) | Responsables de dépôt (filtrage des lignes), analyste (comparer les dépôts), paie |
| `hire_date` | 2010-11-12 | indirect : combinée au dépôt, elle désigne vite un chauffeur | aucun (hors des six valeurs) | Paie (ancienneté) ; analyste (ancienneté, via `tenure_years`) |
| `end_date` | 2025-03-06 | indirect : idem, et elle déclenche la purge R1 (5 ans après) | aucun (hors des six valeurs) | Paie (départs, purge) ; analyste (`is_active`) |

### `driver_shifts.csv` : les colonnes

Ce fichier est un fichier de données personnelles dans son ensemble : chaque service est rattaché à un `driver_id`, donc des heures et une recette décrivent l'activité d'une personne identifiable (fiche 5). Pris sans `driver_id`, ils ne diraient rien d'une personne.

| Colonne | Exemple de valeur | Donnée personnelle ? (direct, indirect, non) | Valeur du tag `DONNEE_PERSONNELLE` | Qui en a besoin, et pour quoi faire |
|---|---|---|---|---|
| `shift_id` | S017747 | non : identifie un service, pas une personne | aucun | Pipeline (dédoublonnage) |
| `driver_id` | D0317 | indirect : pseudonyme qui relie le service au chauffeur | `identifiant_interne` | Tous les rôles métier : joindre les services aux chauffeurs |
| `shift_date` | 2025-03-03 | indirect : avec `driver_id`, dit quand une personne a travaillé | aucun (hors des six valeurs) | Paie, responsables de dépôt, analyste (activité mensuelle) |
| `depot` | Brooklyn | indirect : avec `driver_id`, dit où travaille la personne | aucun | Responsables de dépôt (filtrage), analyste |
| `start_hour` | 19 | indirect : avec `driver_id`, révèle les horaires d'une personne | aucun | Paie (primes de nuit éventuelles). Analyste : peu utile, à confirmer |
| `hours_worked` | 7.6 | indirect : durée de travail d'une personne | aucun | Paie (rémunération) ; analyste (agrégats) |
| `trips_count` | 20 | indirect : performance d'une personne | aucun | Analyste (agrégats), paie |
| `revenue_usd` | 525.58 | indirect : recette générée par une personne | aucun | Analyste (agrégats), paie |

### Où cette donnée est-elle copiée ?

Pour chaque colonne personnelle : la liste des tables et des vues de l'entrepôt où elle se retrouve, y compris sous une autre forme (colonne renommée, colonne calculée). À compléter au fil des trois jours.

| Colonne d'origine | Table ou vue | Colonne | Sous quelle forme |
|---|---|---|---|
| toutes les colonnes de `drivers.csv` | `NYC_TAXI.RAW.DRIVERS` | mêmes noms + `_source_file`, `_loaded_at` | copie brute |
| `first_name`, `last_name` | `STAGING.STG_RH__DRIVERS` | `first_name`, `last_name` | identique |
| `email` | `STAGING.STG_RH__DRIVERS` | `email` | minuscules, espaces retirés |
| `phone` | `STAGING.STG_RH__DRIVERS` | `phone` | espaces retirés, vide devient NULL |
| `birth_date`, `hire_date`, `end_date` | `STAGING.STG_RH__DRIVERS` | mêmes noms | typées en date |
| `tlc_license_number`, `driver_id` | `STAGING.STG_RH__DRIVERS` | mêmes noms | identique |
| `depot` | `STAGING.STG_RH__DRIVERS` | `depot` | mise en forme (`INITCAP`) |
| toutes les colonnes personnelles | `MARTS.DIM_DRIVER` | mêmes noms | identique ; plus `is_active` (calculée depuis `end_date`) et `tenure_years` (calculée depuis `hire_date` et `end_date`) |
| `first_name`, `last_name` | `MARTS.MART_DRIVER_MONTHLY` | `driver_name` | **concaténés** : nom complet recopié dans une table que l'analyste lit |
| `driver_id`, `depot` | `MARTS.MART_DRIVER_MONTHLY` | `driver_id`, `depot` | identique (le `depot` vient du service, pas de `DIM_DRIVER`) |
| `driver_id`, `depot` et colonnes de service | `NYC_TAXI.RAW.DRIVER_SHIFTS` | mêmes noms | copie brute |
| `driver_id`, `shift_date`, `depot`, `start_hour`, `hours_worked`, `trips_count`, `revenue_usd` | `STAGING.STG_RH__DRIVER_SHIFTS` | mêmes noms | typées ; dédoublonnées |
| `shift_date`, `hours_worked`, `trips_count`, `revenue_usd` | `MARTS.MART_DRIVER_MONTHLY` | `activity_month`, `hours_worked`, `trips_count`, `revenue_usd` | agrégées par mois et par chauffeur (`nb_shifts` en plus) |
| fichiers sources | stage de chargement (nom à confirmer dans `chargement_rh_1_preparer.sql`) | fichiers CSV | **hypothèse non vérifiée** : copie des fichiers eux-mêmes (règle R3) |

### Ce qui a surpris

- `driver_name` dans `MART_DRIVER_MONTHLY` : le nom complet est recopié dans une table que l'analyste lit. Un masquage posé seulement sur `DIM_DRIVER` ne la protège pas ; il faut la retirer ou la masquer aussi.
- `tlc_license_number` : numéro public à New York, mais le garder à côté du nom, de l'e-mail et du téléphone en fait la colonne la plus sensible du fichier. Personne en dehors de la paie n'en a besoin.
- `depot`, `hire_date`, `end_date` et les colonnes de `driver_shifts.csv` ne rentrent dans aucune des six valeurs du tag : je les ai inventoriées comme indirectes sans tag. Le masquage par tag ne les couvrira pas, il faudra les traiter autrement (accès par ligne, agrégation).

---

## Partie 2 — Fiche de registre (jour 3)

Version réduite du registre des activités de traitement (RGPD, art. 30), limitée à ce qu'un Data Engineer peut renseigner et prouver. Chaque réponse renvoie à un fichier du dépôt, une requête ou une capture de `docs/`. Trame complète : CNIL, « Le registre des activités de traitement ».

### Le traitement

| Rubrique | Réponse |
|---|---|
| Nom du traitement | Entrepôt du personnel roulant de Hudson Cab Partners : chauffeurs et services |
| Finalité : à quoi servent ces données | Gestion du personnel : paie des chauffeurs (service paie), organisation des dépôts (responsables de dépôt), pilotage de l'activité par dépôt et par mois sans identifier les chauffeurs (analyste) |
| Personnes concernées | Chauffeurs de taxi de Hudson Cab Partners, en poste ou partis depuis moins de 5 ans, rattachés aux dépôts du Bronx, de Brooklyn et de Queens (354 au 03/11/2026, après la purge de 46 chauffeurs) |
| Responsable du traitement | Hudson Cab Europe (Paris), qui décide des finalités et des moyens depuis le transfert de la gestion des données du personnel (`docs/VEILLE.md`, section 1) |
| Service responsable des données | Service RH (fichier source) ; équipe data de Hudson Cab Europe (entrepôt, règles techniques) |
| Sous-traitant | Snowflake (hébergement et calcul), région : ______ |
| Autorité de contrôle | CNIL |

### Les données

| Catégorie de données | Colonnes concernées | Tables où elles se trouvent |
|---|---|---|
| Identité | `first_name`, `last_name`, `birth_date` ; `driver_name` (colonne calculée : prénom + nom) | `RAW.DRIVERS`, `MARTS.DIM_DRIVER` ; `driver_name` dans `MARTS.MART_DRIVER_MONTHLY` ; vue `STAGING.STG_RH__DRIVERS` (sans stockage propre) |
| Identifiants | `driver_id` (interne, pseudonyme), `tlc_license_number` (officiel, délivré par la TLC) | `driver_id` : les 4 tables ; `tlc_license_number` : `RAW.DRIVERS`, `MARTS.DIM_DRIVER` |
| Coordonnées | `email`, `phone` | `RAW.DRIVERS`, `MARTS.DIM_DRIVER` |
| Vie professionnelle | `depot`, `hire_date`, `end_date`, `is_active`, `tenure_years` ; services : `shift_date`, `start_hour`, `hours_worked`, `trips_count`, `revenue_usd` | `RAW.DRIVERS`, `MARTS.DIM_DRIVER` ; `RAW.DRIVER_SHIFTS`, `MARTS.MART_DRIVER_MONTHLY` (agrégé par mois) |

Toutes les colonnes d'identité, d'identifiant et de coordonnées portent le tag `DONNEE_PERSONNELLE`, y compris la colonne calculée `driver_name` ; les 4 tables portent `SENSIBILITE = confidentiel` et leur `DUREE_CONSERVATION`. Preuve : `GOUVERNANCE.V_CATALOGUE` lue par `ANALYSTE` (`docs/capture_catalogue.png`), fichiers `snowflake/rh/catalogue/`.

### Qui y accède

| Rôle | Ce qu'il voit | Pourquoi il en a besoin | Preuve (requête ou test) |
|---|---|---|---|
| `RH_PAIE` | les 354 chauffeurs, tous les dépôts, tout en clair, dans `MARTS` | payer les chauffeurs et les contacter | `docs/ACCES.md`, tests 1, 11, 11 bis ; `docs/capture_deux_roles.png` |
| `RESP_DEPOT_QUEENS`, `RESP_DEPOT_BRONX` | les chauffeurs de leur seul dépôt ; nom, prénom et téléphone en clair, le reste masqué | organiser les services et joindre leurs chauffeurs | tests 2, 3, 4, 13, 14, 15 ; tableau « Valeurs visibles » |
| `ANALYSTE` | tous les dépôts, tout `MARTS` ; `driver_id` et l'année de naissance seulement, aucune donnée qui identifie directement | analyser l'activité sans nommer personne | tests 5, 17, 18, 19 ; `docs/capture_deux_roles.png` |
| `TRANSFORMER` (rôle des outils) | tout, en clair, dans `RAW`, `STAGING` et `MARTS` | charger, purger, mesurer la qualité, reconstruire les marts (tâches planifiées) | test 21 ; `docs/capture_taches.png` |
| `GOUVERNANCE` | aucune donnée | écrire les tags et les politiques | test 6 (refusé) ; `SHOW GRANTS TO ROLE GOUVERNANCE` : aucun `SELECT` |
| `ACCOUNTADMIN` | aucune ligne des marts RH ; dans `RAW`, des lignes aux colonnes personnelles masquées | administrer le compte, pas lire les données | tests 7, 9 bis, 16 |

Ajouter un dépôt ou un accès se fait par une ligne dans `GOUVERNANCE.ACCES_DEPOT`, sans modifier la politique (test 20, `docs/capture_ajout_depot.png`).

### Combien de temps

| Règle | Comment elle est appliquée | Preuve |
|---|---|---|
| R1 : suppression 5 ans après la fin du contrat | Tâche quotidienne `T_PURGE` (6 h, heure de Paris) : supprime dans `RAW` les services puis les chauffeurs dont `end_date` date de plus de 5 ans ; `T_TABLES` reconstruit ensuite les marts à partir de `RAW`. 46 chauffeurs purgés le 03/11/2026 (0 service : leurs services avaient déjà disparu du fichier). | `snowflake/rh/purge_rh.sql`, `snowflake/rh/taches_rh.sql` ; `RAW.DRIVERS` et `DIM_DRIVER` passent de 400 à 354 |
| R2 : pas de restauration au-delà de 1 jour | `DATA_RETENTION_TIME_IN_DAYS = 1` posé sur les 4 tables RH | `snowflake/rh/conservation_rh.sql` ; `SHOW TABLES` (`retention_time` = 1) ; `docs/capture_time_travel.png` (lecture de la table avant la purge : 400, contre 354 après) |
| R3 : pas de fichier sur le stage | `COPY INTO … PURGE = TRUE` retire chaque fichier du stage après chargement ; les CSV sont exclus du dépôt Git (`.gitignore`) | `LIST @NYC_TAXI.RAW.RH_STAGE` vide (`docs/capture_stage_vide.png`) ; `git log --all -- data/` vide |

Délai réel entre l'exécution de la purge et la disparition définitive d'une donnée dans Snowflake, en tenant compte de Time Travel et de Fail-safe : **8 jours** (1 jour de Time Travel, lisible par le propriétaire de la table, puis 7 jours de Fail-safe, restaurables seulement par le support Snowflake ; Fail-safe ne se raccourcit pas sur une table permanente). La purge étant quotidienne, une donnée atteint la limite des 5 ans et disparaît des tables au plus tard le lendemain, puis définitivement 8 jours après. Écart signalé sur R2 : `docs/VEILLE.md`, section 4.

### Comment on le contrôle

| Question | Réponse | Preuve |
|---|---|---|
| Peut-on dire qui a lu ces données la semaine dernière ? | Oui : `ACCESS_HISTORY` donne les tables et les colonnes lues par chaque requête, `QUERY_HISTORY` le rôle, jointes sur `query_id`. L'audit dit qui a demandé une colonne ; la politique décide de ce qu'il a vu (l'analyste a lu `EMAIL`, mais seulement `*****`). Latence : jusqu'à 3 h. | `snowflake/gouvernance/06_audit.sql` ; `docs/capture_audit.png`, `docs/capture_audit_colonnes_personnelles.png` |
| Sait-on quand une donnée est fausse ? | Oui : 4 règles mesurées chaque jour sur `RAW` par `T_QUALITE` et enregistrées dans `GOUVERNANCE.QUALITE_RESULTATS`. Au 03/11/2026 : `licence_unique` 4 (ALERTE), `depot_connu` 9 (ALERTE), `service_rattache` 25 / 50 (OK), `telephone_renseigne` 12 / 14,50 (OK). La règle bloquante arrête la chaîne : `T_TABLES` ne reconstruit pas les marts. Les mesures tournent avec le rôle des outils : lancées avec `ACCOUNTADMIN`, elles portent sur des valeurs masquées et sont fausses (353 au lieu de 4). | `snowflake/rh/controles/`, `snowflake/rh/taches_rh.sql` ; `docs/capture_qualite.png`, `docs/capture_blocage.png`, `docs/capture_faux_resultat_licence.png` |
| Que se passe-t-il si le rôle des outils est compromis ? | `TRANSFORMER` voit tout en clair, possède les tables et a `APPLY` sur les tags : il pourrait lire et extraire toutes les données, en supprimer, ou retirer le tag `DONNEE_PERSONNELLE` d'une colonne, ce qui la démasquerait pour tous les rôles. Il ne peut ni modifier les politiques ni `ACCES_DEPOT` (propriété de `GOUVERNANCE`). Ce qui limite le risque : aucun utilisateur nommé ne porte les règles, ses actions sont tracées dans `QUERY_HISTORY` et `ACCESS_HISTORY`, le test 12 (politiques attachées) se relance après chaque exécution, et Time Travel permet de restaurer une suppression pendant 1 jour. Une violation serait à documenter et, en cas de risque, à notifier à la CNIL sous 72 h (RGPD, art. 33). | `docs/ACCES.md`, « Ce que cette carte permet à un rôle de défaire » ; `docs/VEILLE.md`, fiche 7 |

### Limites connues

- Les chauffeurs partis restent jusqu'à 5 ans dans la base active, visibles des responsables de leur ancien dépôt et de l'analyste : le contrat ne prévoit pas d'archivage intermédiaire séparé (écart principal, voir le README).
- Une donnée purgée survit 8 jours dans Snowflake (Time Travel puis Fail-safe), au-delà du jour fixé par R2.
- Les règles de qualité détectent sans corriger, et `driver_id`, combiné au dépôt, à l'année de naissance et à l'ancienneté, peut permettre à l'analyste de réidentifier certains chauffeurs. Le droit du travail applicable aux durées de conservation (français ou new-yorkais) reste à trancher par le DPO et le conseil juridique (`docs/VEILLE.md`, section 5).
