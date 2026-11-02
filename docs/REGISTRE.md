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

Le registre des activités de traitement décrit ce qu'une organisation fait des données personnelles qu'elle détient. Cette fiche en est une version réduite, limitée à ce qu'un Data Engineer peut renseigner et prouver. La trame complète est celle de la CNIL (lien dans les ressources).

Chaque réponse de la colonne de droite doit pouvoir être vérifiée dans l'entrepôt : indiquez la requête ou le fichier qui le prouve.

### Le traitement

| Rubrique | Réponse |
|---|---|
| Nom du traitement | |
| Finalité : à quoi servent ces données | |
| Personnes concernées | |
| Service responsable des données | |

### Les données

| Catégorie de données | Colonnes concernées | Tables où elles se trouvent |
|---|---|---|
| Identité | | |
| Coordonnées | | |
| Vie professionnelle | | |

### Qui y accède

| Rôle | Ce qu'il voit | Pourquoi il en a besoin | Preuve (requête ou test) |
|---|---|---|---|
| | | | |

### Combien de temps

| Règle | Comment elle est appliquée | Preuve |
|---|---|---|
| R1 : suppression 5 ans après la fin du contrat | | |
| R2 : pas de restauration au-delà de 1 jour | | |
| R3 : pas de fichier sur le stage | | |

Délai réel entre l'exécution de la purge et la disparition définitive d'une donnée dans Snowflake, en tenant compte de Time Travel et de Fail-safe : ______ jours.

### Comment on le contrôle

| Question | Réponse | Preuve |
|---|---|---|
| Peut-on dire qui a lu ces données la semaine dernière ? | | |
| Sait-on quand une donnée est fausse ? | | |
| Que se passe-t-il si le rôle des outils est compromis ? | | |

### Limites connues

Ce que votre mise en œuvre ne couvre pas : deux ou trois lignes, sans détour.
