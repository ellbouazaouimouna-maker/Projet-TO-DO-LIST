#!/bin/bash

# Définition de l'environnement graphique pour que cron puisse afficher des notifications
export DISPLAY=:0
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
FICHIER_DONNEES="$(dirname "$0")/taches.txt"
DATE_AUJOURDHUI=$(date "+%Y-%m-%d")

# Vérifie si le fichier existe
if [ ! -f "$FICHIER_DONNEES" ]; then
    exit 1
fi

# Parcourt le fichier et cherche les tâches de la date du jour qui ne sont pas "Terminé"
tail -n +2 "$FICHIER_DONNEES" | while IFS='|' read -r id titre desc statut priorite echeance parent; do
    if [[ "$echeance" == "$DATE_AUJOURDHUI" && "$statut" != "Terminé" ]]; then
        # Envoie une notification système
        notify-send "RAPPEL TO DO LIST" "La tâche '$titre' (Priorité $priorite) arrive à échéance aujourd'hui !" -u critical
    fi
done
