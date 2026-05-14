#!/bin/bash

# ==============================================================================
# PROJET : TO DO LIST - AIAC
# Script  : rappels.sh — Notifications automatiques via cron
# Usage   : Planifié par cron, exécuté quotidiennement à 09h00
#           Commande cron : 0 9 * * * /bin/bash /chemin/vers/rappels.sh
# ==============================================================================

# --- Environnement graphique (requis pour cron) ---
export DISPLAY=:0
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${UID}/bus"

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FICHIER_DONNEES="$SCRIPT_DIR/taches.txt"
DATE_AUJOURDHUI=$(date "+%Y-%m-%d")
DATE_DEMAIN=$(date -d "tomorrow" "+%Y-%m-%d")

# --- Vérifications préalables ---
if [ ! -f "$FICHIER_DONNEES" ]; then
    exit 1
fi

if ! command -v notify-send &>/dev/null; then
    exit 1
fi

# --- Parcours des tâches ---
tail -n +2 "$FICHIER_DONNEES" | while IFS='|' read -r id titre desc statut priorite echeance parent; do

    # Ignorer les tâches terminées
    [ "$statut" = "Terminé" ] && continue

    # Rappel : tâche échéant AUJOURD'HUI
    if [ "$echeance" = "$DATE_AUJOURDHUI" ]; then
        notify-send "⚠️ RAPPEL TO DO LIST" \
            "La tâche '$titre' (Priorité : $priorite) arrive à échéance AUJOURD'HUI !" \
            -u critical -i appointment-soon
    fi

    # Rappel : tâche échéant DEMAIN
    if [ "$echeance" = "$DATE_DEMAIN" ]; then
        notify-send "📅 RAPPEL TO DO LIST" \
            "La tâche '$titre' (Priorité : $priorite) arrive à échéance DEMAIN." \
            -u normal -i appointment-soon
    fi

done
