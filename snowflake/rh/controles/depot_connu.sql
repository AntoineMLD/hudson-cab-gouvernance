-- Règle d'avertissement (contrat, section 6) : le dépôt est écrit exactement Bronx, Brooklyn ou Queens.
-- Seuil : 0. Mesurée sur RAW, copie fidèle du fichier : une faute de saisie (« bronx », « Queens ») y reste visible,
-- même si le staging la corrige ensuite (INITCAP(TRIM(...))).
SELECT
    (SELECT COUNT(*) FROM NYC_TAXI.RAW.DRIVERS
      WHERE depot IS NULL OR depot NOT IN ('Bronx', 'Brooklyn', 'Queens'))
  + (SELECT COUNT(*) FROM NYC_TAXI.RAW.DRIVER_SHIFTS
      WHERE depot IS NULL OR depot NOT IN ('Bronx', 'Brooklyn', 'Queens'))
    AS nb_anomalies;
