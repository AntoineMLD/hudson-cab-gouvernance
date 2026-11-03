-- Règle d'avertissement (contrat, section 6) : chaque chauffeur en poste a un téléphone.
-- Seuil : 5 % des chauffeurs en poste. La colonne seuil du contrat est un nombre : le pourcentage est converti
-- en nombre de chauffeurs au moment de la mesure (5 % de l'effectif en poste ce jour-là).
SELECT
    COUNT_IF(phone IS NULL OR TRIM(phone) = '')        AS nb_anomalies,
    ROUND(COUNT(*) * 0.05, 2)                          AS seuil
FROM NYC_TAXI.RAW.DRIVERS
WHERE end_date IS NULL;
