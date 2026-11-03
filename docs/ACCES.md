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

Pour chaque rôle qui peut poser ou retirer un tag, ou détacher une politique : que pourrait-il démasquer ? Est-ce acceptable, et qui le surveille ?

---

## Partie 2 — Cahier de tests

Décidez d'abord à quoi ressemble une valeur masquée pour chaque type de colonne (texte, date) et notez-le ici : ______. Puis remplissez en deux temps : la colonne « attendu » **avant** d'écrire les politiques, à partir de la matrice du contrat ; la colonne « obtenu » après, en exécutant la requête avec le rôle indiqué (`USE ROLE ...`).

Un test est vert quand « obtenu » est identique à « attendu ». Un accès refusé (`Object does not exist or not authorized`) est un résultat comme un autre : écrivez-le.

### Lignes visibles

| N° | Rôle | Requête | Attendu | Obtenu | Vert ? |
|---|---|---|---|---|---|
| 1 | `RH_PAIE` | `SELECT COUNT(*) FROM NYC_TAXI.MARTS.DIM_DRIVER` | | | |
| 2 | `RESP_DEPOT_QUEENS` | la même | | | |
| 3 | `RESP_DEPOT_QUEENS` | `SELECT DISTINCT depot FROM NYC_TAXI.MARTS.DIM_DRIVER` | | | |
| 4 | `RESP_DEPOT_BRONX` | `SELECT COUNT(*) FROM NYC_TAXI.MARTS.MART_DRIVER_MONTHLY` | | | |
| 5 | `ANALYSTE` | `SELECT COUNT(*) FROM NYC_TAXI.MARTS.DIM_DRIVER` | | | |
| 6 | `GOUVERNANCE` | la même | | | |
| 7 | `ACCOUNTADMIN` | la même | | | |
| 8 | `RH_PAIE` | `SELECT COUNT(*) FROM NYC_TAXI.RAW.DRIVER_SHIFTS` | | | |
| 9 | `ANALYSTE` | `SELECT COUNT(*) FROM NYC_TAXI.RAW.DRIVERS` | | | |
| 9 bis | `ACCOUNTADMIN` | `SELECT first_name, email FROM NYC_TAXI.RAW.DRIVERS LIMIT 3` | | | |

### Valeurs visibles

Pour le chauffeur `D0003`, la valeur que chaque rôle doit lire dans chaque colonne (ou « colonne absente », ou « ligne invisible »).

| Colonne | `RH_PAIE` | `RESP_DEPOT_QUEENS` | `RESP_DEPOT_BRONX` | `ANALYSTE` |
|---|---|---|---|---|
| nom et prénom | | | | |
| e-mail | | | | |
| téléphone | | | | |
| date de naissance | | | | |
| numéro de licence | | | | |
| `driver_name` dans `MART_DRIVER_MONTHLY` | | | | |

### Le pipeline fonctionne toujours

| N° | Vérification | Attendu | Obtenu | Vert ? |
|---|---|---|---|---|
| 10 | Avec le rôle des outils, après avoir relancé les fichiers SQL : nombre de lignes de `DIM_DRIVER` | | | |
| 11 | Avec `RH_PAIE` : l'e-mail de `D0003` est toujours une vraie adresse | | | |
| 12 | Les politiques sont toujours attachées après la relance (requête de la section 7 du contrat) | | | |

Ajoutez vos propres tests : un cahier qui ne contient que des tests verts dès le premier essai n'a probablement pas cherché les cas limites.
