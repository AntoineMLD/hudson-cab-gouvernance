-- Règle BLOQUANTE (contrat, section 6) : chaque service appartient à un chauffeur connu.
-- Seuil : 50 services. Au-delà, T_QUALITE enregistre ALERTE puis lève une erreur : T_TABLES ne reconstruit pas MARTS.
-- Une anomalie = un service dont le driver_id n'existe pas dans RAW.DRIVERS (service orphelin).
SELECT COUNT(*) AS nb_anomalies
FROM NYC_TAXI.RAW.DRIVER_SHIFTS s
WHERE NOT EXISTS (
    SELECT 1 FROM NYC_TAXI.RAW.DRIVERS d WHERE d.driver_id = s.driver_id
);
