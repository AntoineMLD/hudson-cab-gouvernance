# Les accès — carte des droits et cahier de tests

Copier ce fichier sous le nom `docs/ACCES.md`.

- **Partie 1, jours 1 et 2** : la carte des droits, complétée au fur et à mesure que vous créez rôles et objets ;
- **Partie 2, jour 2** : le cahier de tests, « attendu » écrit avant les politiques, « obtenu » après.

---

## Partie 1 — Carte des droits

Dans Snowflake, faire une action demande d'être propriétaire de l'objet ou d'avoir reçu un privilège précis. Les droits ci-dessous sont créés par `snowflake/gouvernance/01_gouvernance.sql` (jour 1) et vérifiés avec `SHOW GRANTS TO ROLE GOUVERNANCE;` (11 droits, aucun `SELECT` sur une table RH) et `SHOW GRANTS TO ROLE TRANSFORMER;`. Les droits des rôles métier sont créés par `snowflake/gouvernance/02_roles_metier.sql` (jour 2) et vérifiés avec `SHOW GRANTS TO ROLE RESP_DEPOT_QUEENS;` et `SHOW FUTURE GRANTS IN SCHEMA NYC_TAXI.MARTS;`. Les objets marqués « jour 2 » ou « jour 3 » ne sont pas encore créés.

### Qui possède quoi

Le propriétaire d'un objet est le rôle qui l'a créé, ou celui à qui la propriété a été donnée.

| Objet | Propriétaire | Comment |
|---|---|---|
| Tables de `RAW` et de `MARTS`, vues de `STAGING`, stage `RH_STAGE` | `TRANSFORMER` | créées par les scripts de chargement et les SQL fournis |
| Schéma `GOUVERNANCE` | `GOUVERNANCE` | créé par `ACCOUNTADMIN`, puis `GRANT OWNERSHIP ... COPY CURRENT GRANTS` |
| Tags `SENSIBILITE`, `DONNEE_PERSONNELLE`, `DUREE_CONSERVATION` | `GOUVERNANCE` | créés par lui dans son schéma |
| Politiques de masquage | `GOUVERNANCE` | jour 2 |
| Politique d'accès par ligne | `GOUVERNANCE` | jour 2 |
| Table `ACCES_DEPOT` | `GOUVERNANCE` | jour 2 |
| Table `QUALITE_RESULTATS` | `GOUVERNANCE` | créée par lui dans son schéma |
| Vue `V_CATALOGUE` | `TRANSFORMER` | jour 3, grâce à `CREATE VIEW` sur le schéma `GOUVERNANCE` |

### Qui fait quoi, avec quel droit

| Action | Rôle qui la fait | Privilège nécessaire | Accordé par |
|---|---|---|---|
| Créer un tag | `GOUVERNANCE` | être propriétaire du schéma `GOUVERNANCE` (ou `CREATE TAG` sur le schéma) | `ACCOUNTADMIN` (transfert de propriété du schéma) |
| Poser un tag sur une colonne de `DIM_DRIVER` | `TRANSFORMER` | `APPLY` sur le tag, `USAGE` sur le schéma `GOUVERNANCE`, et être propriétaire de la table | `GOUVERNANCE` (propriétaire du tag et du schéma) |
| Créer une politique de masquage | `GOUVERNANCE` | être propriétaire du schéma `GOUVERNANCE` (ou `CREATE MASKING POLICY` sur le schéma) | `ACCOUNTADMIN` (transfert de propriété du schéma) |
| Attacher une politique de masquage à un tag | `GOUVERNANCE` | être propriétaire du tag et de la politique, et `APPLY MASKING POLICY` sur le compte | `ACCOUNTADMIN` (seul à pouvoir accorder un droit sur le compte) |
| Ajouter une politique d'accès par ligne à une table | `GOUVERNANCE` | être propriétaire de la politique, et `APPLY ROW ACCESS POLICY` sur le compte (la table appartient à `TRANSFORMER`) | `ACCOUNTADMIN` |
| Écrire une ligne dans `QUALITE_RESULTATS` | `TRANSFORMER` (tâche `T_QUALITE`) | `INSERT` sur la table, `USAGE` sur le schéma `GOUVERNANCE` | `GOUVERNANCE` (propriétaire de la table) |
| Créer la vue `V_CATALOGUE` | `TRANSFORMER` | `CREATE VIEW` et `USAGE` sur le schéma `GOUVERNANCE` | `GOUVERNANCE` |
| Lire `DIM_DRIVER` | `TRANSFORMER` (propriétaire) ; `RH_PAIE`, `RESP_DEPOT_QUEENS`, `RESP_DEPOT_BRONX`, `ANALYSTE` | `USAGE` sur `NYC_TAXI` et sur `MARTS`, `SELECT` sur la table | `ACCOUNTADMIN` (`02_roles_metier.sql`) |
| Lire toutes les tables de `MARTS`, même recréées | `ANALYSTE` | `SELECT` sur toutes les tables et sur les tables futures de `MARTS` | `ACCOUNTADMIN` (seul à pouvoir accorder un droit sur les objets futurs ici) |
| Lire la vue `V_CATALOGUE` (jour 3), même recréée | les 4 rôles métier | `USAGE` sur le schéma `GOUVERNANCE`, `SELECT` sur les vues futures du schéma | `ACCOUNTADMIN` (`02_roles_metier.sql`) |
| Lire `RAW` ou `STAGING` | `TRANSFORMER` seulement | propriétaire des tables et des vues ; aucun rôle métier n'a `USAGE` sur ces schémas | — |
| Exécuter une requête | chaque rôle | `USAGE` sur le warehouse `NYC_TAXI_WH` | `ACCOUNTADMIN` |
| Faire tourner les tâches planifiées | `TRANSFORMER` | `EXECUTE TASK` sur le compte, `CREATE TASK` sur `MARTS` | `ACCOUNTADMIN` (`00_installation.sql`) |
| Trouver les tables pour y attacher des politiques, sans les lire | `GOUVERNANCE` | `USAGE` sur `NYC_TAXI`, `RAW` et `MARTS`, sans `SELECT` | `ACCOUNTADMIN` |

### Les rôles métier

| Rôle | Rattaché à | Droits de lecture | Ce qui le limite |
|---|---|---|---|
| `RH_PAIE` | l'utilisateur, pas à `SYSADMIN` | `DIM_DRIVER`, `MART_DRIVER_MONTHLY`, `DIM_DEPOT` | rien (voit tout, matrice du contrat) |
| `RESP_DEPOT_QUEENS` | l'utilisateur, pas à `SYSADMIN` | `DIM_DRIVER`, `MART_DRIVER_MONTHLY`, `DIM_DEPOT` | filtre par dépôt et masquage (jour 2, étapes 5 et 6) |
| `RESP_DEPOT_BRONX` | l'utilisateur, pas à `SYSADMIN` | `DIM_DRIVER`, `MART_DRIVER_MONTHLY`, `DIM_DEPOT` | filtre par dépôt et masquage (jour 2, étapes 5 et 6) |
| `ANALYSTE` | l'utilisateur, pas à `SYSADMIN` | toutes les tables de `MARTS`, présentes et futures | masquage des identifiants directs (jour 2, étape 5) |

Avant les politiques, un droit `SELECT` ne protège rien : avec `RESP_DEPOT_QUEENS`, `SELECT COUNT(*) FROM NYC_TAXI.MARTS.DIM_DRIVER` renvoie 400 chauffeurs, tous dépôts confondus, e-mails compris ; `SELECT COUNT(*) FROM NYC_TAXI.RAW.DRIVERS` est refusé (« does not exist or not authorized »).

### Ce que cette carte permet à un rôle de défaire

- `TRANSFORMER` a `APPLY` sur les trois tags et possède les tables : il peut retirer le tag `DONNEE_PERSONNELLE` d'une colonne (`UNSET TAG`), ce qui la démasque pour tous. Il voit déjà tout en clair, mais il pourrait exposer une colonne aux autres rôles.
- `GOUVERNANCE` possède les politiques et `ACCES_DEPOT` : il peut ajouter une ligne `('ANALYSTE', '*')` à un responsable, ou changer le corps d'une politique. Il ne lit pas les données lui-même, mais il décide qui les lit.
- `ACCOUNTADMIN` peut tout réattribuer (rôles, propriétés, droits).
- Qui surveille : ces actions sont des requêtes, visibles dans `SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY` et `ACCESS_HISTORY`. La requête d'audit du jour 3 et la relecture des scripts versionnés dans Git en sont le contrôle. Le test 12 (politiques toujours attachées) se relance après chaque exécution des tâches.

---

## Partie 2 — Cahier de tests

**Format d'une valeur masquée** (décidé avant d'écrire les politiques) :

| Type de colonne | Colonnes | Valeur masquée | Pourquoi |
|---|---|---|---|
| Texte | `first_name`, `last_name`, `email`, `phone`, `tlc_license_number`, `driver_name` | `'*****'` | Un masque visible distingue « masqué » de « vide dans le fichier » (un `phone` vide reste `NULL`). Pas de masque partiel de l'e-mail (domaine visible) : le contrat interdit à l'analyste toute donnée qui identifie directement un chauffeur. |
| Date | `birth_date` | `NULL` pour les rôles qui ne la voient pas | Une politique de masquage renvoie le type qu'elle reçoit : une date ne peut pas valoir `'*****'`. |
| Date, cas de l'analyste | `birth_date` | le 1er janvier de l'année de naissance (ex. `1985-06-14` → `1985-01-01`) | « L'année de naissance seulement » (contrat, section 4), en gardant le type date. Le jour et le mois disparaissent. |
| Identifiant interne | `driver_id` | jamais masqué | Visible de tous les rôles métier (contrat, section 4), malgré son tag `identifiant_interne`. |
| Ligne filtrée | toutes | la ligne n'apparaît pas | Le filtre par dépôt retire la ligne entière : on ne voit pas une ligne masquée, on ne la voit pas du tout. |

Puis remplissez en deux temps : la colonne « attendu » **avant** d'écrire les politiques, à partir de la matrice du contrat ; la colonne « obtenu » après, en exécutant la requête avec le rôle indiqué (`USE ROLE ...`).

Un test est vert quand « obtenu » est identique à « attendu ». Un accès refusé (`Object does not exist or not authorized`) est un résultat comme un autre : écrivez-le.

### Valeurs de référence

Relevées avec `TRANSFORMER`, avant toute politique (`SELECT depot, COUNT(*) ... GROUP BY depot`) :

| Table | Bronx | Brooklyn | Queens | Total |
|---|---|---|---|---|
| `MARTS.DIM_DRIVER` | 122 | 117 | 161 | 400 |
| `MARTS.MART_DRIVER_MONTHLY` | 290 | 259 | 365 | 914 |

Chauffeur témoin `D0003` : Anthony Suarez, dépôt **Queens**, e-mail `anthony.suarez3@mail.example`, téléphone `+1 (917) 555-2473`, naissance `1981-12-07`, licence TLC `5213863`.

### Lignes visibles

| N° | Rôle | Requête | Attendu | Obtenu | Vert ? |
|---|---|---|---|---|---|
| 1 | `RH_PAIE` | `SELECT COUNT(*) FROM NYC_TAXI.MARTS.DIM_DRIVER` | 400 (tous les dépôts) | | |
| 2 | `RESP_DEPOT_QUEENS` | la même | 161 (Queens seulement) | | |
| 3 | `RESP_DEPOT_QUEENS` | `SELECT DISTINCT depot FROM NYC_TAXI.MARTS.DIM_DRIVER` | 1 ligne : `Queens` | | |
| 4 | `RESP_DEPOT_BRONX` | `SELECT COUNT(*) FROM NYC_TAXI.MARTS.MART_DRIVER_MONTHLY` | 290 (Bronx seulement) | | |
| 5 | `ANALYSTE` | `SELECT COUNT(*) FROM NYC_TAXI.MARTS.DIM_DRIVER` | 400 (tous les dépôts) | | |
| 6 | `GOUVERNANCE` | la même | refusé : « does not exist or not authorized » (aucun `SELECT` sur les tables) | | |
| 7 | `ACCOUNTADMIN` | la même | 0 : il a le droit de lire (hérité de `TRANSFORMER` par `SYSADMIN`), mais il est absent de `ACCES_DEPOT`, donc le filtre ne lui laisse aucune ligne | | |
| 8 | `RH_PAIE` | `SELECT COUNT(*) FROM NYC_TAXI.RAW.DRIVER_SHIFTS` | refusé (aucun rôle métier ne lit `RAW`) | | |
| 9 | `ANALYSTE` | `SELECT COUNT(*) FROM NYC_TAXI.RAW.DRIVERS` | refusé | | |
| 9 bis | `ACCOUNTADMIN` | `SELECT first_name, email FROM NYC_TAXI.RAW.DRIVERS LIMIT 3` | 3 lignes (pas de filtre sur `RAW`), `first_name` = `*****`, `email` = `*****` (masquage par tag : seul `TRANSFORMER` voit en clair) | 3 lignes, `*****` / `*****` sur les 3 | oui |
| 13 | `RESP_DEPOT_BRONX` | `SELECT COUNT(*) FROM NYC_TAXI.MARTS.DIM_DRIVER` | 122 | | |
| 14 | `RESP_DEPOT_QUEENS` | `SELECT COUNT(*) FROM NYC_TAXI.MARTS.MART_DRIVER_MONTHLY` | 365 | | |
| 15 | `RESP_DEPOT_QUEENS` | `SELECT COUNT(*) FROM NYC_TAXI.MARTS.DIM_DRIVER WHERE depot = 'Brooklyn'` | 0 (Brooklyn n'a pas de responsable dans la matrice) | | |
| 16 | `ACCOUNTADMIN` | `SELECT COUNT(*) FROM NYC_TAXI.MARTS.MART_DRIVER_MONTHLY` | 0 | | |
| 17 | `ANALYSTE` | `SELECT COUNT(*) FROM NYC_TAXI.MARTS.DIM_DEPOT` | 3 (référentiel sans filtre ni masque) | | |

### Valeurs visibles

Pour le chauffeur `D0003` (dépôt Queens), la valeur que chaque rôle doit lire dans chaque colonne (ou « colonne absente », ou « ligne invisible »).

| Colonne | `RH_PAIE` | `RESP_DEPOT_QUEENS` | `RESP_DEPOT_BRONX` | `ANALYSTE` |
|---|---|---|---|---|
| nom et prénom | Anthony / Suarez | Anthony / Suarez | ligne invisible | `*****` / `*****` |
| e-mail | `anthony.suarez3@mail.example` | `*****` | ligne invisible | `*****` |
| téléphone | `+1 (917) 555-2473` | `+1 (917) 555-2473` | ligne invisible | `*****` |
| date de naissance | `1981-12-07` | `NULL` | ligne invisible | `1981-01-01` (année seulement) |
| numéro de licence | `5213863` | `*****` | ligne invisible | `*****` |
| `driver_name` dans `MART_DRIVER_MONTHLY` | Anthony Suarez | Anthony Suarez | ligne invisible | `*****` |
| `driver_id` | `D0003` | `D0003` | ligne invisible | `D0003` |

**Obtenu** (`SELECT * FROM NYC_TAXI.MARTS.DIM_DRIVER WHERE driver_id = 'D0003'`, rôle par rôle) :

| Rôle | Obtenu | Vert ? |
|---|---|---|
| `RH_PAIE` | `D0003`, Anthony, Suarez, `anthony.suarez3@mail.example`, `+1 (917) 555-2473`, `1981-12-07`, `5213863`, Queens : tout en clair | oui |
| `RESP_DEPOT_QUEENS` | `D0003`, Anthony, Suarez, `*****`, `+1 (917) 555-2473`, `NULL`, `*****`, Queens : nom, prénom et téléphone en clair, le reste masqué | oui |
| `RESP_DEPOT_BRONX` | à tester après l'étape 6 (avant le filtre par dépôt, la ligne est encore visible, masquée) | |
| `ANALYSTE` | `D0003`, `*****`, `*****`, `*****`, `*****`, `1981-01-01`, `*****`, Queens ; `driver_name` du mart = `*****` : identifiant interne visible, année de naissance seulement, tout le reste masqué | oui |

### Cas limites

| N° | Rôle | Requête | Attendu | Obtenu | Vert ? |
|---|---|---|---|---|---|
| 18 | `ANALYSTE` | `SELECT COUNT(*) FROM NYC_TAXI.MARTS.DIM_DRIVER WHERE email LIKE '%@%'` | 0 : le masque s'applique avant le filtre, l'analyste ne peut pas retrouver un chauffeur par son e-mail | 0 | oui |
| 21 | `TRANSFORMER` | `SELECT first_name, email, birth_date FROM NYC_TAXI.RAW.DRIVERS WHERE driver_id = 'D0003'` | tout en clair (le pipeline lit les vraies valeurs) | Anthony, `anthony.suarez3@mail.example`, `1981-12-07` | oui |
| 19 | `ANALYSTE` | `SELECT driver_id FROM NYC_TAXI.MARTS.DIM_DRIVER WHERE driver_id = 'D0003'` | `D0003` (identifiant interne visible, contrat section 4) | | |
| 20 | `GOUVERNANCE` puis `RESP_DEPOT_QUEENS` | ajouter `('RESP_DEPOT_QUEENS', 'Brooklyn')` dans `GOUVERNANCE.ACCES_DEPOT`, sans toucher à la politique, puis `SELECT COUNT(*) FROM NYC_TAXI.MARTS.DIM_DRIVER` | 278 (161 + 117) ; après suppression de la ligne : de nouveau 161 | | |

**Faux rouge rencontré** : la ligne `SELECT * ... WHERE driver_id = 'D0003'` lancée seule, sans ses `USE ROLE`, a renvoyé toutes les valeurs en clair. La requête était partie avec le dernier rôle utilisé dans la feuille (`TRANSFORMER`), pas avec `ANALYSTE`. Relancée avec son bloc (`USE SECONDARY ROLES NONE; USE ROLE ANALYSTE; USE WAREHOUSE ...;`), elle donne bien les valeurs masquées. Règle retenue : chaque test se lance avec ses `USE`, et on vérifie le rôle affiché avant de lire le résultat.

### Le pipeline fonctionne toujours

| N° | Vérification | Attendu | Obtenu | Vert ? |
|---|---|---|---|---|
| 10 | Avec le rôle des outils, après avoir relancé les fichiers SQL : nombre de lignes de `DIM_DRIVER` | | | |
| 11 | Avec `RH_PAIE` : l'e-mail de `D0003` est toujours une vraie adresse | | | |
| 12 | Les politiques sont toujours attachées après la relance (requête de la section 7 du contrat) | | | |

Ajoutez vos propres tests : un cahier qui ne contient que des tests verts dès le premier essai n'a probablement pas cherché les cas limites.
