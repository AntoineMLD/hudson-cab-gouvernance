hudson-cab-gouvernance
<!-- Gardez ce fichier court (< 100 lignes) : il est chargé à CHAQUE session. -->
Projet

Pipeline data pour les données de taxis Hudson Cab (shifts chauffeurs, courses…). Stack : Python, SQL, dbt, Snowflake. <!-- adaptez -->

Structure
data/ : CSV bruts. Ne JAMAIS les lire en entier. Utiliser head -n 20 fichier.csv et wc -l.
models/ : modèles dbt (staging → intermediate → marts)
scripts/ : scripts Python d'ingestion
Commandes
Compiler : dbt compile --select <modele>
Lancer un modèle : dbt run --select <modele>
Tester : dbt test --select <modele>
Conventions
SQL : mots-clés en minuscules, CTE plutôt que sous-requêtes, un modèle = un fichier
Nommage : stg_<source>__<table>, int_<sujet>, fct_ / dim_
Python : type hints, pas de print en prod (logging)
Façon de travailler
Réponses concises. Pas de récap de ce que tu viens de faire.
Avant une modif touchant plus de 2 fichiers : propose un plan court et attends ma validation.
Je suis en apprentissage : explique le "pourquoi" en 2-3 phrases quand c'est un concept nouveau.
Ne lance pas --full-refresh sans demander.
Compact instructions

Quand tu compactes, garde : les décisions prises, les fichiers modifiés, les erreurs en cours. Jette : les sorties de commandes longues et les explorations abandonnées.