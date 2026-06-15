#!/bin/bash

# ==============================================================================
# PROJET : TO DO LIST - AIAC
# Script  : rappels.sh — Notifications automatiques via cron
# Version : 6.2 — Sans email
#
# INSTALLATION CRON (toutes les minutes) :
#   crontab -e
#   Ajouter : * * * * * /bin/bash /chemin/vers/rappels.sh >> /chemin/vers/cron.log 2>&1
#
# FORMAT taches.txt :
#   ID|Titre|Description|Statut|Priorité|YYYY-MM-DD HH:MM|ID_Parent|Notif_Dates
#   Notif_Dates : "2026-06-18 14:30,2026-06-19 09:00" | "none" | (vide=global)
# ==============================================================================

# --- Environnement graphique requis pour notify-send depuis cron ---
export DISPLAY=:0
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${UID}/bus"

# --- Chemins ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FICHIER_DONNEES="$SCRIPT_DIR/taches.txt"
FICHIER_HISTORIQUE="$SCRIPT_DIR/historique.log"
FICHIER_NOTIFICATIONS="$SCRIPT_DIR/notifications.cfg"


# --- Lire la configuration globale ---
NOTIF_1H="true"
NOTIF_30MIN="true"
NOTIF_10MIN="true"
NOTIF_EXACT="true"
POPUP_DEADLINE="true"

if [ -f "$FICHIER_NOTIFICATIONS" ]; then
    NOTIF_1H=$(grep "^NOTIF_1H=" "$FICHIER_NOTIFICATIONS" | cut -d'=' -f2)
    NOTIF_30MIN=$(grep "^NOTIF_30MIN=" "$FICHIER_NOTIFICATIONS" | cut -d'=' -f2)
    NOTIF_10MIN=$(grep "^NOTIF_10MIN=" "$FICHIER_NOTIFICATIONS" | cut -d'=' -f2)
    NOTIF_EXACT=$(grep "^NOTIF_EXACT=" "$FICHIER_NOTIFICATIONS" | cut -d'=' -f2)
    POPUP_DEADLINE=$(grep "^POPUP_DEADLINE=" "$FICHIER_NOTIFICATIONS" | cut -d'=' -f2)
fi

[ -z "$NOTIF_1H" ] && NOTIF_1H="true"
[ -z "$NOTIF_30MIN" ] && NOTIF_30MIN="true"
[ -z "$NOTIF_10MIN" ] && NOTIF_10MIN="true"
[ -z "$NOTIF_EXACT" ] && NOTIF_EXACT="true"
[ -z "$POPUP_DEADLINE" ] && POPUP_DEADLINE="true"

# --- Vérification fichier de données ---
if [ ! -f "$FICHIER_DONNEES" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M')] ERREUR : '$FICHIER_DONNEES' introuvable." >&2
    exit 1
fi

# ==============================================================================
# FONCTIONS UTILITAIRES
# ==============================================================================

log_rappel() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] RAPPEL - $1" >> "$FICHIER_HISTORIQUE"
}

envoyer_notification() {
    local titre="$1"
    local message="$2"
    local urgence="$3"
    local expire="${4:-8000}"

    if command -v notify-send &>/dev/null; then
        notify-send "$titre" "$message" \
            -u "$urgence" \
            -t "$expire" \
            -i appointment-soon
    fi
}

envoyer_terminal() {
    echo "============================================"
    echo "  RAPPEL TO DO LIST — $(date '+%Y-%m-%d %H:%M')"
    echo "  $1"
    echo "============================================"
}


# ==============================================================================
# VÉRIFICATION DES ÉCHÉANCES ET NOTIFICATIONS
# ==============================================================================

MAINTENANT_TS=$(date '+%s')
MAINTENANT_STR=$(date '+%Y-%m-%d %H:%M')

tail -n +2 "$FICHIER_DONNEES" | while IFS='|' read -r id titre desc statut priorite echeance parent notif_dates; do

    [ "$statut" = "Terminé" ]   && continue
    [ "$statut" = "En retard" ] && continue
    [ -z "$echeance" ]           && continue

    ECHEANCE_TS=$(date -d "$echeance" '+%s' 2>/dev/null)
    [ -z "$ECHEANCE_TS" ] && continue

    # ==================================================================
    # NOTIFICATIONS PERSONNALISÉES (dates+heures complètes type alarme)
    # ==================================================================
    if [ -n "$notif_dates" ] && [ "$notif_dates" != "none" ]; then
        # Parcourir les dates séparées par des virgules
        local IFS_OLD="$IFS"
        IFS=','
        for date_notif in $notif_dates; do
            IFS="$IFS_OLD"

            # Vérifier le format YYYY-MM-DD HH:MM
            if ! [[ "$date_notif" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}\ ([01][0-9]|2[0-3]):[0-5][0-9]$ ]]; then
                continue
            fi

            # Convertir en timestamp
            local NOTIF_TS
            NOTIF_TS=$(date -d "$date_notif" '+%s' 2>/dev/null)
            [ -z "$NOTIF_TS" ] && continue

            # Fenêtre de +/- 1 minute (60 secondes)
            local DIFF_NOTIF=$(( NOTIF_TS - MAINTENANT_TS ))

            if [ "$DIFF_NOTIF" -ge -60 ] && [ "$DIFF_NOTIF" -le 60 ]; then
                envoyer_terminal "⏰ ALARME : '$titre' à $date_notif | Échéance : $echeance"

                envoyer_notification \
                    "⏰ Rappel TO DO LIST — $date_notif" \
                    "La tâche '$titre' a une alarme programmée.\n Alarme : $date_notif\n Échéance : $echeance\n Priorité : $priorite" \
                    "critical" "15000"

                log_rappel "ALARME PERSONNALISÉE — ID=$id | '$titre' | alarme=$date_notif | échéance=$echeance"
            fi
        done
        IFS="$IFS_OLD"

        # Si dates perso définies, on ne fait PAS les globales
        continue
    fi

    # ==================================================================
    # NOTIFICATIONS GLOBALES (comportement par défaut)
    # ==================================================================
    if [ "$notif_dates" = "none" ]; then
        continue
    fi

    DIFF=$(( ECHEANCE_TS - MAINTENANT_TS ))

    # CAS 1 : RAPPEL 1 HEURE AVANT
    if [ "$NOTIF_1H" = "true" ] && [ "$DIFF" -ge 3540 ] && [ "$DIFF" -le 3660 ]; then
        envoyer_terminal "⏰ Dans 1 heure : '$titre' (Priorité : $priorite) | Échéance : $echeance"
        envoyer_notification \
            "⏰ Rappel dans 1 heure — TO DO LIST" \
            "La tâche '$titre' arrive à échéance dans 1 heure.\n Échéance : $echeance\n Priorité : $priorite" \
            "normal" "10000"
        log_rappel "1h avant — ID=$id | '$titre' | échéance=$echeance"
    fi

    # CAS 2 : RAPPEL 30 MINUTES AVANT
    if [ "$NOTIF_30MIN" = "true" ] && [ "$DIFF" -ge 1740 ] && [ "$DIFF" -le 1860 ]; then
        envoyer_terminal "  Dans 30 min : '$titre' (Priorité : $priorite) | Échéance : $echeance"
        envoyer_notification \
            " Rappel dans 30 minutes — TO DO LIST" \
            "La tâche '$titre' arrive à échéance dans 30 minutes.\n Échéance : $echeance\n Priorité : $priorite" \
            "normal" "12000"
        log_rappel "30min avant — ID=$id | '$titre' | échéance=$echeance"
    fi

    # CAS 3 : RAPPEL 10 MINUTES AVANT
    if [ "$NOTIF_10MIN" = "true" ] && [ "$DIFF" -ge 540 ] && [ "$DIFF" -le 660 ]; then
        envoyer_terminal " Dans 10 min : '$titre' (Priorité : $priorite) | Échéance : $echeance"
        envoyer_notification \
            " RAPPEL URGENT — dans 10 minutes !" \
            " La tâche '$titre' expire dans 10 minutes !\n Échéance : $echeance\n Priorité : $priorite\n\nAgissez maintenant !" \
            "critical" "15000"
        log_rappel "10min avant — ID=$id | '$titre' | échéance=$echeance"
    fi

    # CAS 4 : RAPPEL À L'HEURE EXACTE
    if [ "$NOTIF_EXACT" = "true" ] && [ "$DIFF" -ge -60 ] && [ "$DIFF" -le 60 ]; then
        envoyer_terminal " MAINTENANT : '$titre' (Priorité : $priorite) | Échéance : $echeance"
        envoyer_notification \
            " ÉCHÉANCE MAINTENANT — TO DO LIST" \
            " La tâche '$titre' arrive à échéance MAINTENANT !\n Échéance : $echeance\n Priorité : $priorite" \
            "critical" "-1"
        log_rappel "HEURE EXACTE — ID=$id | '$titre' | échéance=$echeance"
    fi

done

# ==============================================================================
# MISE À JOUR AUTOMATIQUE : tâches expirées
# ==============================================================================

while IFS='|' read -r id titre desc statut priorite echeance parent notif_dates; do
    [ "$statut" = "Terminé" ]   && continue
    [ "$statut" = "En retard" ] && continue
    [ -z "$echeance" ]           && continue

    if [[ "$echeance" < "$MAINTENANT_STR" ]]; then

        if [ "$POPUP_DEADLINE" = "true" ]; then
            envoyer_notification \
                " Tâche expirée — TO DO LIST" \
                "La tâche '$titre' a dépassé son échéance ($echeance).\nOuvrez l'application TO DO LIST pour mettre à jour le statut." \
                "critical" "-1"
            envoyer_terminal " EXPIRÉE : '$titre' | échéance dépassée ($echeance) → Ouvrez l'app pour mettre à jour"
            log_rappel "AUTO-EXPIRATION POPUP — ID=$id | '$titre' | échéance=$echeance | En attente de décision utilisateur"
        else
            local nouvelle_ligne="$id|$titre|$desc|En retard|$priorite|$echeance|$parent|$notif_dates"
            grep -v "^$id|" "$FICHIER_DONNEES" > /tmp/todo_tmp.txt
            head -1 /tmp/todo_tmp.txt > /tmp/todo_sorted.txt
            { echo "$nouvelle_ligne"; tail -n +2 /tmp/todo_tmp.txt; } \
                | sort -t'|' -k1 -n >> /tmp/todo_sorted.txt
            mv /tmp/todo_sorted.txt "$FICHIER_DONNEES"
            rm -f /tmp/todo_tmp.txt

            envoyer_notification \
                " Tâche expirée — TO DO LIST" \
                "La tâche '$titre' est passée en 'En retard'.\n Échéance dépassée : $echeance" \
                "critical" "-1"
            envoyer_terminal " EXPIRÉE : '$titre' | échéance dépassée ($echeance) → En retard"
            log_rappel "AUTO-EXPIRATION — ID=$id | '$titre' → En retard | échéance=$echeance"
        fi
    fi

done < <(tail -n +2 "$FICHIER_DONNEES")

exit 0
