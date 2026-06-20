#!/bin/bash

# ==============================================================================
# PROJET : TO DO LIST - AIAC
# Version : 7.2 
# ==============================================================================

FICHIER_DONNEES="taches.txt"
FICHIER_HISTORIQUE="historique.log"
DOSSIER_SOUS_TACHES="sub-tasks"
FICHIER_NOTIFICATIONS="notifications.cfg"
FICHIER_SUPPRIMEES="taches_supprime.txt"   # Corbeille : tâches supprimées récupérables

# --- INITIALISATION ---
if [ ! -f "$FICHIER_DONNEES" ]; then
    echo "ID|Titre|Description|Statut|Priorité|Echéance|ID_Parent|Notif_Dates" > "$FICHIER_DONNEES"
fi
# Corbeille : même format que taches.txt
if [ ! -f "$FICHIER_SUPPRIMEES" ]; then
    echo "ID|Titre|Description|Statut|Priorité|Echéance|ID_Parent|Notif_Dates" > "$FICHIER_SUPPRIMEES"
fi
touch "$FICHIER_HISTORIQUE"
mkdir -p "$DOSSIER_SOUS_TACHES"


if [ ! -f "$FICHIER_NOTIFICATIONS" ]; then
    echo "NOTIF_1H=true" > "$FICHIER_NOTIFICATIONS"
    echo "NOTIF_30MIN=true" >> "$FICHIER_NOTIFICATIONS"
    echo "NOTIF_10MIN=true" >> "$FICHIER_NOTIFICATIONS"
    echo "NOTIF_EXACT=true" >> "$FICHIER_NOTIFICATIONS"
    echo "POPUP_DEADLINE=true" >> "$FICHIER_NOTIFICATIONS"
fi

# --- Agrandissement de la police Zenity via GTK CSS ---
_GTK_CSS_DIR="$HOME/.config/gtk-3.0"
_GTK_CSS_FILE="$_GTK_CSS_DIR/gtk.css"
_GTK_CSS_BACKUP="/tmp/gtk_todo_backup_$$.css"
_GTK_CSS_INJECTED=false

mkdir -p "$_GTK_CSS_DIR"
if [ -f "$_GTK_CSS_FILE" ]; then
    cp "$_GTK_CSS_FILE" "$_GTK_CSS_BACKUP"
fi
cat >> "$_GTK_CSS_FILE" << 'CSSEOF'
/* TODO-LIST-AIAC */
* { font-size: 14pt; }
CSSEOF
_GTK_CSS_INJECTED=true

_restore_css() {
    if [ "$_GTK_CSS_INJECTED" = true ]; then
        if [ -f "$_GTK_CSS_BACKUP" ]; then
            cp "$_GTK_CSS_BACKUP" "$_GTK_CSS_FILE"
            rm -f "$_GTK_CSS_BACKUP"
        else
            # Supprimer seulement les lignes injectées
            sed -i '/\/\* TODO-LIST-AIAC \*\//,/^\* { font-size: 14pt; }$/d' "$_GTK_CSS_FILE" 2>/dev/null
        fi
    fi
}
trap '_restore_css' EXIT

zenity_safe() {
    zenity "$@" 2>/dev/null
}

# --- UTILITAIRES ---

log_action() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $(whoami) - $1" >> "$FICHIER_HISTORIQUE"
}

generer_id() {
    local dernier_id
    dernier_id=$(tail -n +2 "$FICHIER_DONNEES" | awk -F'|' '{print $1}' | sort -n | tail -1)
    if [ -z "$dernier_id" ]; then echo "1"; else echo "$((dernier_id + 1))"; fi
}

tache_existe() {
    [[ "$1" =~ ^[0-9]+$ ]] || return 1
    grep -q "^$1|" "$FICHIER_DONNEES"
}

notif_globale() {
    local cle="$1"
    local val
    val=$(grep "^${cle}=" "$FICHIER_NOTIFICATIONS" | cut -d'=' -f2)
    [ -z "$val" ] && val="true"
    echo "$val"
}

# ==============================================================================
# VÉRIFICATION AUTOMATIQUE DES TÂCHES EXPIRÉES
# ==============================================================================
verifier_taches_expirees() {
    local maintenant
    maintenant=$(date '+%Y-%m-%d %H:%M')
    local compteur=0

    while IFS='|' read -r id titre desc statut priorite echeance parent notif_dates; do
        [ "$statut" = "Terminé" ]   && continue
        [ "$statut" = "En retard" ] && continue
        [ -z "$echeance" ] && continue

        if [[ "$echeance" < "$maintenant" ]]; then
            local popup_active
            popup_active=$(grep "^POPUP_DEADLINE=" "$FICHIER_NOTIFICATIONS" | cut -d'=' -f2)

            if [ "$popup_active" = "true" ]; then
                local reponse
                reponse=$(zenity_safe --question \
                    --title="⏰ Échéance dépassée — '$titre'" \
                    --text="La tâche '<b>$titre</b>' a dépassé son échéance ($echeance).\n\n<b>La tâche est-elle terminée ?</b>\n\n• Cliquez <b>OK</b> si la tâche est TERMINÉE\n• Cliquez <b>Annuler</b> si la tâche est EN RETARD" \
                    --ok-label=" Terminée" \
                    --cancel-label=" En retard" \
                    --width=400)

                local nouveau_statut
                if [ $? -eq 0 ]; then
                    nouveau_statut="Terminé"
                else
                    nouveau_statut="En retard"
                fi

                local nouvelle_ligne="$id|$titre|$desc|$nouveau_statut|$priorite|$echeance|$parent|$notif_dates"
                grep -v "^$id|" "$FICHIER_DONNEES" > /tmp/todo_tmp.txt
                head -1 /tmp/todo_tmp.txt > /tmp/todo_sorted.txt
                { echo "$nouvelle_ligne"; tail -n +2 /tmp/todo_tmp.txt; } \
                    | sort -t'|' -k1 -n >> /tmp/todo_sorted.txt
                mv /tmp/todo_sorted.txt "$FICHIER_DONNEES"
                rm -f /tmp/todo_tmp.txt

                log_action "AUTO-POPUP - Tâche ID=$id '$titre' passée en '$nouveau_statut' (échéance: $echeance)"
                compteur=$((compteur + 1))
            else
                local nouvelle_ligne="$id|$titre|$desc|En retard|$priorite|$echeance|$parent|$notif_dates"
                grep -v "^$id|" "$FICHIER_DONNEES" > /tmp/todo_tmp.txt
                head -1 /tmp/todo_tmp.txt > /tmp/todo_sorted.txt
                { echo "$nouvelle_ligne"; tail -n +2 /tmp/todo_tmp.txt; } \
                    | sort -t'|' -k1 -n >> /tmp/todo_sorted.txt
                mv /tmp/todo_sorted.txt "$FICHIER_DONNEES"
                rm -f /tmp/todo_tmp.txt
                log_action "AUTO - Tâche ID=$id '$titre' passée en 'En retard' (échéance: $echeance)"
                compteur=$((compteur + 1))
            fi
        fi
    done < <(tail -n +2 "$FICHIER_DONNEES")

    if [ "$compteur" -gt 0 ]; then
        zenity_safe --warning \
            --title=" Tâches expirées" \
            --text=" $compteur tâche(s) ont dépassé leur échéance et ont été mises à jour.\n\nConsultez la liste avec le filtre 'En retard' ou 'Terminé'."
    fi
}

verifier_taches_expirees

# ==============================================================================
# CONFIGURER LES DATES DE NOTIFICATION (date + heure complètes)
# ==============================================================================
configurer_notif_dates() {
    local titre_tache="$1"
    local dates_actuelles="$2"
    local echeance="$3"
    local maintenant
    maintenant=$(date '+%Y-%m-%d %H:%M')

    local dates_liste=""

    while true; do
        local message
        if [ -n "$dates_liste" ]; then
            message="Dates de notification configurées :\n<b>$dates_liste</b>\n\nAjoutez une notification (format YYYY-MM-DD HH:MM)\nou laissez vide pour terminer.\n\n Doit être après <b>$maintenant</b> et avant <b>$echeance</b>."
        else
            message="Configurez les notifications pour '<b>$titre_tache</b>'\n\nÉchéance : <b>$echeance</b>\nMaintenant : <b>$maintenant</b>\n\nEntrez une date et heure (YYYY-MM-DD HH:MM)\nExemples : 2026-06-18 14:30, 2026-06-19 09:00\n\nLaissez vide et cliquez OK pour terminer."
        fi

        local nouvelle_date
        nouvelle_date=$(zenity_safe --entry \
            --title=" Date de notification — '$titre_tache'" \
            --text="$message" \
            --entry-text="")

        # Si annulé → retourner les dates actuelles
        if [ $? -ne 0 ]; then
            echo "$dates_actuelles"
            return
        fi

        # Si vide → terminer
        if [ -z "$nouvelle_date" ]; then
            break
        fi

        # Validation format YYYY-MM-DD HH:MM
        if ! [[ "$nouvelle_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}\ ([01][0-9]|2[0-3]):[0-5][0-9]$ ]]; then
            zenity_safe --error --text=" Format invalide '$nouvelle_date'.\nUtilisez YYYY-MM-DD HH:MM (ex: 2026-06-18 14:30)."
            continue
        fi

        # Vérifier que la date est dans le futur (après maintenant)
        if [[ "$nouvelle_date" < "$maintenant" ]] || [[ "$nouvelle_date" == "$maintenant" ]]; then
            zenity_safe --error --text=" La date '$nouvelle_date' doit être APRÈS maintenant ($maintenant)."
            continue
        fi

        # Vérifier que la date est avant l'échéance
        if [[ "$nouvelle_date" > "$echeance" ]] || [[ "$nouvelle_date" == "$echeance" ]]; then
            zenity_safe --error --text=" La date '$nouvelle_date' doit être AVANT l'échéance ($echeance)."
            continue
        fi

        # Vérifier doublon
        if echo "$dates_liste" | grep -qw "$nouvelle_date"; then
            zenity_safe --error --text=" La date '$nouvelle_date' est déjà ajoutée."
            continue
        fi

        # Ajouter à la liste
        if [ -n "$dates_liste" ]; then
            dates_liste="$dates_liste,$nouvelle_date"
        else
            dates_liste="$nouvelle_date"
        fi
    done

    echo "$dates_liste"
}

# ==============================================================================
# 1. AJOUTER UNE TÂCHE
# ==============================================================================
ajouter_tache() {
    local inputs
    inputs=$(zenity_safe --forms --title=" Ajouter une tâche" \
        --text="Remplissez les informations ci-dessous" \
        --add-entry="Titre" \
        --add-entry="Description" \
        --add-combo="Statut" --combo-values="En attente|En cours|Terminé|En retard" \
        --add-combo="Priorité" --combo-values="Haute|Moyenne|Basse" \
        --add-entry="ID Parent (vide = tâche principale)")

    [ -z "$inputs" ] && return

    local id
    id=$(generer_id)

    local titre desc statut priorite parent
    IFS='|' read -r titre desc statut priorite parent <<< "$inputs"

    # --- Sélection de l'échéance ---
    local echeance=""
    local date_choisie
    date_choisie=$(zenity_safe --calendar \
        --title=" Choisir une échéance" \
        --text="Sélectionnez une date d'échéance (doit être après maintenant)" \
        --date-format="%Y-%m-%d")

    if [ -n "$date_choisie" ]; then
        local heure_choisie
        heure_choisie=$(zenity_safe --entry \
            --title=" Choisir une heure" \
            --text="Entrez l'heure d'échéance (format HH:MM, ex: 18:00) :" \
            --entry-text="09:00")

        [ -z "$heure_choisie" ] && heure_choisie="09:00"

        if ! [[ "$heure_choisie" =~ ^([01][0-9]|2[0-3]):[0-5][0-9]$ ]]; then
            zenity_safe --error --text=" Format d'heure invalide '$heure_choisie'.\nUtilisez HH:MM (ex: 18:00)."
            return
        fi

        local maintenant echeance_complete
        maintenant=$(date '+%Y-%m-%d %H:%M')
        echeance_complete="$date_choisie $heure_choisie"

        if [[ "$echeance_complete" > "$maintenant" ]]; then
            echeance="$echeance_complete"
        else
            zenity_safe --error --text=" L'échéance '$echeance_complete' est invalide.\nElle doit être strictement après maintenant ($maintenant)."
            return
        fi
    fi

    # --- Configurer les dates de notification ---
    local notif_dates=""
    if [ -n "$echeance" ]; then
        local choix_notif
        choix_notif=$(zenity_safe --list \
            --title=" Notifications pour '$titre'" \
            --text="Choisissez le type de notifications pour cette tâche :\n\n• <b>Dates personnalisées</b> : Vous définissez date+heure exactes (type alarme)\n• <b>Paramètres globaux</b> : Utilise les rappels par défaut (1h, 30min, 10min, exact)\n• <b>Aucune</b> : Pas de notification" \
            --column="Type" \
            --width=500 --height=300 \
            " Dates personnalisées" \
            " Paramètres globaux" \
            " Aucune notification")

        case "$choix_notif" in
            " Dates personnalisées")
                notif_dates=$(configurer_notif_dates "$titre" "" "$echeance")
                ;;
            " Aucune notification")
                notif_dates="none"
                ;;
            *)
                notif_dates=""
                ;;
        esac
    fi

    # Validation ID parent
    if [ -n "$parent" ] && ! tache_existe "$parent"; then
        zenity_safe --error --text="ID Parent '$parent' introuvable."
        return
    fi

    echo "$id|$titre|$desc|$statut|$priorite|$echeance|$parent|$notif_dates" >> "$FICHIER_DONNEES"

    if [ -n "$parent" ]; then
        echo "$id" >> "$DOSSIER_SOUS_TACHES/parent_$parent.txt"
    fi

    log_action "AJOUT tâche ID=$id Titre='$titre' Statut='$statut' Priorité='$priorite' Échéance='$echeance' Parent='$parent' Notif_Dates='$notif_dates'"

    local notif_affichage
    if [ -z "$notif_dates" ]; then
        notif_affichage=" Paramètres globaux"
    elif [ "$notif_dates" = "none" ]; then
        notif_affichage=" Aucune notification"
    else
        notif_affichage=" $notif_dates"
    fi

    zenity_safe --info --text=" Tâche '$titre' ajoutée avec succès (ID: $id) !\n\n Échéance : $echeance\n Notifications : $notif_affichage"
}

# ==============================================================================
# 2. AFFICHER LES TÂCHES
# ==============================================================================

afficher_taches() {
    local filtre
    filtre=$(zenity_safe --list --title=" Filtrer les tâches" \
        --text="Choisissez un filtre d'affichage :" \
        --column="Filtre" \
        "Toutes les tâches" \
        "En attente" \
        "En cours" \
        "Terminé" \
        "En retard" \
        "Haute priorité" \
        "Moyenne priorité" \
        "Basse priorité")

    [ -z "$filtre" ] && return

    local donnees
    case "$filtre" in
        "Toutes les tâches")
            donnees=$(tail -n +2 "$FICHIER_DONNEES") ;;
        "En attente"|"En cours"|"Terminé"|"En retard")
            donnees=$(tail -n +2 "$FICHIER_DONNEES" | awk -F'|' -v f="$filtre" '$4 == f') ;;
        "Haute priorité")
            donnees=$(tail -n +2 "$FICHIER_DONNEES" | awk -F'|' '$5 == "Haute"') ;;
        "Moyenne priorité")
            donnees=$(tail -n +2 "$FICHIER_DONNEES" | awk -F'|' '$5 == "Moyenne"') ;;
        "Basse priorité")
            donnees=$(tail -n +2 "$FICHIER_DONNEES" | awk -F'|' '$5 == "Basse"') ;;
    esac

    if [ -z "$donnees" ]; then
        zenity_safe --info --text="Aucune tâche trouvée pour ce filtre."
        return
    fi

    # Tri initial par ID (l'utilisateur pourra re-trier en cliquant les en-têtes)
    donnees=$(echo "$donnees" | sort -t'|' -k1 -n)

    # Largeur de remplissage de l'ID : Zenity trie les colonnes comme du TEXTE.
    # En complétant l'ID avec des zéros à gauche (ex: 02, 10), le tri par clic
    # sur l'en-tête "ID" respecte l'ordre NUMÉRIQUE (2 avant 10 et non l'inverse).
    # Remarque : si tous les ID ont 1 chiffre, aucun zéro n'est ajouté.
    local largeur_id
    largeur_id=$(echo "$donnees" | awk -F'|' 'length($1)>m{m=length($1)} END{print m+0}')
    [ -z "$largeur_id" ] && largeur_id=1
    [ "$largeur_id" -lt 1 ] && largeur_id=1

    # Construire les lignes du tableau
    local args=()
    while IFS='|' read -r id titre desc statut priorite echeance parent notif_dates; do
        [ -z "$id" ] && continue
        local id_aff
        id_aff=$(printf "%0${largeur_id}d" "$id" 2>/dev/null) || id_aff="$id"

        local notifs_affichage
        if [ -z "$notif_dates" ]; then
            notifs_affichage=" Global"
        elif [ "$notif_dates" = "none" ]; then
            notifs_affichage=" Aucune"
        else
            notifs_affichage=" $notif_dates"
        fi
        args+=("$id_aff" "$titre" "$statut" "$priorite" "$echeance" "$notifs_affichage")
    done <<< "$donnees"

    # AFFICHAGE — Dans Zenity, les en-têtes de colonnes sont CLIQUABLES :
    #   • 1er clic sur un en-tête  → tri croissant sur cette colonne
    #   • 2e clic sur le même en-tête → tri décroissant
    # Le tri se fait en temps réel, sans rouvrir la fenêtre, exactement comme
    # dans l'explorateur de fichiers Windows.
    zenity_safe --list \
        --title=" Liste des Tâches — $filtre" \
        --text="Cliquez sur un en-tête de colonne (ID, Titre, Statut, Priorité, Échéance) pour trier. Re-cliquez pour inverser l'ordre." \
        --width=1000 --height=520 \
        --column="ID" --column="Titre" --column="Statut" --column="Priorité" --column="Échéance" --column="Notifications" \
        "${args[@]}"
}

# ==============================================================================
# 3. MODIFIER UNE TÂCHE
# ==============================================================================
modifier_tache() {
    local id
    id=$(zenity_safe --entry --title=" Modifier une tâche" --text="Entrez l'ID de la tâche à modifier :")
    [ -z "$id" ] && return

    if ! tache_existe "$id"; then
        zenity_safe --error --text="ID '$id' introuvable."
        return
    fi

    local ligne
    ligne=$(grep "^$id|" "$FICHIER_DONNEES")
    local ancien_titre ancien_desc ancien_statut ancien_priorite ancien_echeance ancien_parent ancien_notif_dates
    IFS='|' read -r _ ancien_titre ancien_desc ancien_statut ancien_priorite ancien_echeance ancien_parent ancien_notif_dates <<< "$ligne"

    local statuts priorites
    case "$ancien_statut" in
        "En cours")   statuts="En cours|En attente|Terminé|En retard" ;;
        "Terminé")    statuts="Terminé|En attente|En cours|En retard" ;;
        "En retard")  statuts="En retard|En attente|En cours|Terminé" ;;
        *)            statuts="En attente|En cours|Terminé|En retard" ;;
    esac
    case "$ancien_priorite" in
        "Moyenne")  priorites="Moyenne|Haute|Basse" ;;
        "Basse")    priorites="Basse|Haute|Moyenne" ;;
        *)          priorites="Haute|Moyenne|Basse" ;;
    esac

    local inputs
    inputs=$(zenity_safe --forms --title=" Modifier tâche ID $id" \
        --text="Modifiez les champs (laisser vide = garder valeur actuelle)" \
        --add-entry="Titre (actuel: $ancien_titre)" \
        --add-entry="Description (actuel: $ancien_desc)" \
        --add-combo="Statut" --combo-values="$statuts" \
        --add-combo="Priorité" --combo-values="$priorites" \
        --add-entry="Échéance YYYY-MM-DD HH:MM (actuel: $ancien_echeance)")

    [ -z "$inputs" ] && return

    local nouveau_titre nouveau_desc nouveau_statut nouveau_priorite nouveau_echeance
    IFS='|' read -r nouveau_titre nouveau_desc nouveau_statut nouveau_priorite nouveau_echeance <<< "$inputs"

    [ -z "$nouveau_titre" ]    && nouveau_titre="$ancien_titre"
    [ -z "$nouveau_desc" ]     && nouveau_desc="$ancien_desc"
    [ -z "$nouveau_echeance" ] && nouveau_echeance="$ancien_echeance"

    if [ -n "$nouveau_echeance" ]; then
        if ! date -d "$nouveau_echeance" &>/dev/null; then
            zenity_safe --error --text="Format invalide. Utilisez YYYY-MM-DD HH:MM (ex: 2026-06-15 18:00)."
            return
        fi
    fi

    # --- Modifier les notifications ---
    local nouveau_notif_dates
    nouveau_notif_dates="$ancien_notif_dates"
    if [ -n "$nouveau_echeance" ]; then
        local reponse_notif
        reponse_notif=$(zenity_safe --question \
            --title=" Modifier les notifications ?" \
            --text="Voulez-vous modifier les dates de notification ?\n\nActuelles : $( [ -z "$ancien_notif_dates" ] && echo "Paramètres globaux" || echo "$ancien_notif_dates" )" \
            --ok-label=" Modifier" \
            --cancel-label=" Garder")

        if [ $? -eq 0 ]; then
            local choix_notif
            choix_notif=$(zenity_safe --list \
                --title=" Notifications pour '$nouveau_titre'" \
                --text="Choisissez le type de notifications :" \
                --column="Type" \
                --width=500 --height=300 \
                " Dates personnalisées" \
                " Paramètres globaux" \
                " Aucune notification")

            case "$choix_notif" in
                " Dates personnalisées")
                    nouveau_notif_dates=$(configurer_notif_dates "$nouveau_titre" "$ancien_notif_dates" "$nouveau_echeance")
                    ;;
                " Aucune notification")
                    nouveau_notif_dates="none"
                    ;;
                *)
                    nouveau_notif_dates=""
                    ;;
            esac
        fi
    fi

    local nouvelle_ligne="$id|$nouveau_titre|$nouveau_desc|$nouveau_statut|$nouveau_priorite|$nouveau_echeance|$ancien_parent|$nouveau_notif_dates"
    grep -v "^$id|" "$FICHIER_DONNEES" > /tmp/todo_tmp.txt
    head -1 /tmp/todo_tmp.txt > /tmp/todo_sorted.txt
    { echo "$nouvelle_ligne"; tail -n +2 /tmp/todo_tmp.txt; } | sort -t'|' -k1 -n >> /tmp/todo_sorted.txt
    mv /tmp/todo_sorted.txt "$FICHIER_DONNEES"
    rm -f /tmp/todo_tmp.txt

    log_action "MODIFICATION tâche ID=$id | Titre: '$ancien_titre'→'$nouveau_titre' | Statut: '$ancien_statut'→'$nouveau_statut' | Priorité: '$ancien_priorite'→'$nouveau_priorite' | Échéance: '$ancien_echeance'→'$nouveau_echeance' | Notif: '$ancien_notif_dates'→'$nouveau_notif_dates'"

    local notif_affichage
    if [ -z "$nouveau_notif_dates" ]; then
        notif_affichage=" Paramètres globaux"
    elif [ "$nouveau_notif_dates" = "none" ]; then
        notif_affichage=" Aucune notification"
    else
        notif_affichage=" $nouveau_notif_dates"
    fi

    zenity_safe --info --text=" Tâche $id modifiée avec succès !\n\n Notifications : $notif_affichage"
}

# ==============================================================================
# 4. SUPPRIMER UNE TÂCHE
# ==============================================================================
# --- Helper : copie la ligne d'une tâche depuis taches.txt vers la corbeille ---
deplacer_vers_corbeille() {
    local id_supp="$1"
    local ligne_supp
    ligne_supp=$(grep "^$id_supp|" "$FICHIER_DONNEES")
    [ -z "$ligne_supp" ] && return
    # S'assurer que la corbeille a bien un entête
    if [ ! -f "$FICHIER_SUPPRIMEES" ]; then
        head -1 "$FICHIER_DONNEES" > "$FICHIER_SUPPRIMEES"
    fi
    echo "$ligne_supp" >> "$FICHIER_SUPPRIMEES"
}

supprimer_tache() {
    local id
    id=$(zenity_safe --entry --title=" Supprimer" --text="Entrez l'ID de la tâche à supprimer :")
    [ -z "$id" ] && return

    if ! tache_existe "$id"; then
        zenity_safe --error --text="ID '$id' introuvable."
        return
    fi

    local titre
    titre=$(grep "^$id|" "$FICHIER_DONNEES" | cut -d'|' -f2)

    zenity_safe --question --text="Déplacer la tâche '$titre' (ID: $id) et ses sous-tâches vers la corbeille ?\n\nVous pourrez la restaurer plus tard depuis le menu.\n( Restaurer une tâche)" || return

    # Sous-tâches : on les déplace d'abord vers la corbeille, puis on les retire
    if [ -f "$DOSSIER_SOUS_TACHES/parent_$id.txt" ]; then
        while IFS= read -r sous_id; do
            deplacer_vers_corbeille "$sous_id"
            grep -v "^$sous_id|" "$FICHIER_DONNEES" > /tmp/todo_tmp.txt && mv /tmp/todo_tmp.txt "$FICHIER_DONNEES"
            log_action "CORBEILLE sous-tâche ID=$sous_id (parent=$id)"
        done < "$DOSSIER_SOUS_TACHES/parent_$id.txt"
        rm -f "$DOSSIER_SOUS_TACHES/parent_$id.txt"
    fi

    # Tâche principale : déplacement vers la corbeille puis retrait de la liste active
    deplacer_vers_corbeille "$id"
    grep -v "^$id|" "$FICHIER_DONNEES" > /tmp/todo_tmp.txt && mv /tmp/todo_tmp.txt "$FICHIER_DONNEES"
    log_action "CORBEILLE tâche ID=$id Titre='$titre'"
    zenity_safe --info --text=" Tâche '$titre' (ID: $id) déplacée vers la corbeille.\n\nPour la récupérer : menu →  Restaurer une tâche."
}

# ==============================================================================
# 4 bis. RESTAURER UNE TÂCHE (depuis la corbeille)
# ==============================================================================
restaurer_tache() {
    # Vérifier que la corbeille contient au moins une tâche
    if [ ! -f "$FICHIER_SUPPRIMEES" ] || [ -z "$(tail -n +2 "$FICHIER_SUPPRIMEES" 2>/dev/null)" ]; then
        zenity_safe --info --text="La corbeille est vide. Aucune tâche à restaurer."
        return
    fi

    # Construire la liste des tâches supprimées
    local args=()
    while IFS='|' read -r rid rtitre rdesc rstatut rpriorite recheance rparent rnotif; do
        [ -z "$rid" ] && continue
        args+=("$rid" "$rtitre" "$rstatut" "$rpriorite" "$recheance")
    done < <(tail -n +2 "$FICHIER_SUPPRIMEES")

    # Laisser l'utilisateur choisir la tâche à restaurer
    local id
    id=$(zenity_safe --list \
        --title=" Corbeille — Restaurer une tâche" \
        --text="Sélectionnez la tâche à restaurer, puis cliquez sur OK :" \
        --width=900 --height=450 \
        --column="ID" --column="Titre" --column="Statut" --column="Priorité" --column="Échéance" \
        "${args[@]}")

    [ -z "$id" ] && return

    # Récupérer la ligne complète dans la corbeille
    local ligne
    ligne=$(grep "^$id|" "$FICHIER_SUPPRIMEES")
    if [ -z "$ligne" ]; then
        zenity_safe --error --text="Tâche ID '$id' introuvable dans la corbeille."
        return
    fi

    # Empêcher un conflit si un ID identique existe déjà dans la liste active
    if grep -q "^$id|" "$FICHIER_DONNEES"; then
        zenity_safe --error --text="Impossible de restaurer : une tâche avec l'ID $id existe déjà dans la liste active."
        return
    fi

    # 1) Réinsérer la ligne dans taches.txt, puis re-trier par ID
    grep -v "^$id|" "$FICHIER_DONNEES" > /tmp/todo_restore.txt
    head -1 /tmp/todo_restore.txt > /tmp/todo_restore_sorted.txt
    { echo "$ligne"; tail -n +2 /tmp/todo_restore.txt; } | sort -t'|' -k1 -n >> /tmp/todo_restore_sorted.txt
    mv /tmp/todo_restore_sorted.txt "$FICHIER_DONNEES"
    rm -f /tmp/todo_restore.txt

    # 2) Retirer la ligne de la corbeille
    grep -v "^$id|" "$FICHIER_SUPPRIMEES" > /tmp/corbeille_tmp.txt && mv /tmp/corbeille_tmp.txt "$FICHIER_SUPPRIMEES"

    # 3) Reconstituer le lien parent → sous-tâche si la tâche restaurée a un parent
    local parent_restaure
    parent_restaure=$(echo "$ligne" | cut -d'|' -f7)
    if [ -n "$parent_restaure" ]; then
        echo "$id" >> "$DOSSIER_SOUS_TACHES/parent_$parent_restaure.txt"
    fi

    local titre_restaure
    titre_restaure=$(echo "$ligne" | cut -d'|' -f2)
    log_action "RESTAURATION tâche ID=$id Titre='$titre_restaure' (depuis la corbeille)"
    zenity_safe --info --text=" Tâche '$titre_restaure' (ID: $id) restaurée avec succès dans la liste active."
}

# ==============================================================================
# 5. AFFICHER LES SOUS-TÂCHES
# ==============================================================================
afficher_sous_taches() {
    local id
    id=$(zenity_safe --entry --title=" Sous-tâches" --text="Entrez l'ID de la tâche parente :")
    [ -z "$id" ] && return

    if ! tache_existe "$id"; then
        zenity_safe --error --text="ID '$id' introuvable."
        return
    fi

    local titre_parent
    titre_parent=$(grep "^$id|" "$FICHIER_DONNEES" | cut -d'|' -f2)

    local args=()
    while IFS='|' read -r sid stitre sdesc sstatut spriorite secheance sparent snotif_dates; do
        [ "$sparent" = "$id" ] && args+=("$sid" "$stitre" "$sstatut" "$spriorite" "$secheance")
    done < <(tail -n +2 "$FICHIER_DONNEES")

    if [ ${#args[@]} -eq 0 ]; then
        zenity_safe --info --text="Aucune sous-tâche pour '$titre_parent'."
        return
    fi

    zenity_safe --list --title=" Sous-tâches de '$titre_parent' (ID: $id)" --width=800 --height=400 \
        --column="ID" --column="Titre" --column="Statut" --column="Priorité" --column="Échéance" \
        "${args[@]}"
}

# ==============================================================================
# 6. EXPORTER EN CSV
# ==============================================================================
exporter_csv() {
    local fichier_export="export_taches_$(date '+%Y%m%d_%H%M%S').csv"
    cp "$FICHIER_DONNEES" "$fichier_export"
    log_action "EXPORT CSV → $fichier_export"
    zenity_safe --info --text=" Exporté sous '$fichier_export'"
}

# ==============================================================================
# 7. IMPORTER DEPUIS CSV
# ==============================================================================
importer_csv() {
    local fichier
    fichier=$(zenity_safe --file-selection --title=" Importer un fichier CSV" --file-filter="*.csv *.txt")
    [ -z "$fichier" ] && return

    if [ ! -f "$fichier" ]; then
        zenity_safe --error --text="Fichier introuvable."
        return
    fi

    local tmp_import="/tmp/todo_import_$$.txt"
    tail -n +2 "$fichier" > "$tmp_import"
    local compteur=0

    while IFS='|' read -r _ titre desc statut priorite echeance parent notif_dates; do
        [ -z "$titre" ] && continue
        local id
        id=$(generer_id)
        echo "$id|$titre|$desc|$statut|$priorite|$echeance|$parent|$notif_dates" >> "$FICHIER_DONNEES"
        compteur=$((compteur + 1))
    done < "$tmp_import"
    rm -f "$tmp_import"

    log_action "IMPORT CSV depuis '$fichier' ($compteur tâche(s) importée(s))"
    zenity_safe --info --text=" Importation terminée : $compteur tâche(s) importée(s) depuis '$fichier'."
}

# ==============================================================================
# 8. AFFICHER L'HISTORIQUE
# ==============================================================================
afficher_historique() {
    if [ ! -s "$FICHIER_HISTORIQUE" ]; then
        zenity_safe --info --text="L'historique est vide."
        return
    fi

    local contenu
    contenu=$(tail -50 "$FICHIER_HISTORIQUE")
    zenity_safe --text-info --title=" Historique des modifications (50 dernières)" \
        --width=900 --height=500 <<< "$contenu"
}


# ==============================================================================
# 9. CONFIGURER LES NOTIFICATIONS GLOBALES
# ==============================================================================
configurer_notifications() {
    local notif_1h notif_30min notif_10min notif_exact popup_deadline
    notif_1h=$(grep "^NOTIF_1H=" "$FICHIER_NOTIFICATIONS" | cut -d'=' -f2)
    notif_30min=$(grep "^NOTIF_30MIN=" "$FICHIER_NOTIFICATIONS" | cut -d'=' -f2)
    notif_10min=$(grep "^NOTIF_10MIN=" "$FICHIER_NOTIFICATIONS" | cut -d'=' -f2)
    notif_exact=$(grep "^NOTIF_EXACT=" "$FICHIER_NOTIFICATIONS" | cut -d'=' -f2)
    popup_deadline=$(grep "^POPUP_DEADLINE=" "$FICHIER_NOTIFICATIONS" | cut -d'=' -f2)

    [ -z "$notif_1h" ] && notif_1h="true"
    [ -z "$notif_30min" ] && notif_30min="true"
    [ -z "$notif_10min" ] && notif_10min="true"
    [ -z "$notif_exact" ] && notif_exact="true"
    [ -z "$popup_deadline" ] && popup_deadline="true"

    local val_1h val_30min val_10min val_exact val_popup
    [ "$notif_1h" = "true" ] && val_1h="Activé|Désactivé" || val_1h="Désactivé|Activé"
    [ "$notif_30min" = "true" ] && val_30min="Activé|Désactivé" || val_30min="Désactivé|Activé"
    [ "$notif_10min" = "true" ] && val_10min="Activé|Désactivé" || val_10min="Désactivé|Activé"
    [ "$notif_exact" = "true" ] && val_exact="Activé|Désactivé" || val_exact="Désactivé|Activé"
    [ "$popup_deadline" = "true" ] && val_popup="Activé|Désactivé" || val_popup="Désactivé|Activé"

    local inputs
    inputs=$(zenity_safe --forms \
        --title=" Configuration des Notifications Globales" \
        --text="Paramètres par défaut pour les tâches SANS dates personnalisées :" \
        --add-combo=" Rappel 1 heure avant" --combo-values="$val_1h" \
        --add-combo=" Rappel 30 minutes avant" --combo-values="$val_30min" \
        --add-combo=" Rappel 10 minutes avant" --combo-values="$val_10min" \
        --add-combo=" Rappel à l'heure exacte" --combo-values="$val_exact" \
        --add-combo=" Popup à l'échéance (Terminé/En retard)" --combo-values="$val_popup")

    [ -z "$inputs" ] && return

    local new_1h new_30min new_10min new_exact new_popup
    IFS='|' read -r new_1h new_30min new_10min new_exact new_popup <<< "$inputs"

    local bool_1h bool_30min bool_10min bool_exact bool_popup
    [ "$new_1h" = "Activé" ] && bool_1h="true" || bool_1h="false"
    [ "$new_30min" = "Activé" ] && bool_30min="true" || bool_30min="false"
    [ "$new_10min" = "Activé" ] && bool_10min="true" || bool_10min="false"
    [ "$new_exact" = "Activé" ] && bool_exact="true" || bool_exact="false"
    [ "$new_popup" = "Activé" ] && bool_popup="true" || bool_popup="false"

    echo "NOTIF_1H=$bool_1h" > "$FICHIER_NOTIFICATIONS"
    echo "NOTIF_30MIN=$bool_30min" >> "$FICHIER_NOTIFICATIONS"
    echo "NOTIF_10MIN=$bool_10min" >> "$FICHIER_NOTIFICATIONS"
    echo "NOTIF_EXACT=$bool_exact" >> "$FICHIER_NOTIFICATIONS"
    echo "POPUP_DEADLINE=$bool_popup" >> "$FICHIER_NOTIFICATIONS"

    log_action "CONFIG NOTIFICATIONS GLOBALES modifiée — 1h=$bool_1h 30min=$bool_30min 10min=$bool_10min exact=$bool_exact popup=$bool_popup"

    zenity_safe --info --text=" Configuration globale sauvegardée !\n\nCes paramètres s'appliquent aux tâches sans dates personnalisées.\n\n• 1 heure avant : $new_1h\n• 30 minutes avant : $new_30min\n• 10 minutes avant : $new_10min\n• Heure exacte : $new_exact\n• Popup échéance : $new_popup"
}

# ==============================================================================
# 10. AIDE
# ==============================================================================
afficher_aide() {
    zenity_safe --text-info --title=" Aide - TO DO LIST" --width=850 --height=700 <<'EOF'
=== SYSTÈME DE GESTION TO DO LIST - AIAC v6.1 ===

FONCTIONNALITÉS DISPONIBLES :

1. Afficher les tâches
   → Liste avec filtrage par statut ou priorité.
   → Affiche les dates de notification personnalisées.

2. Ajouter une tâche
   → Crée une nouvelle tâche avec échéance.
   →  NOUVEAU : Configure des dates+heures de notification
     exactes (type alarme) avec validation.

3. Modifier une tâche
   → Modifie les champs et les dates de notification.

4. Supprimer une tâche
   → Supprime une tâche et ses sous-tâches.

5. Voir les sous-tâches
   → Affiche les sous-tâches d'une tâche parente.

6. Exporter / Importer CSV

7. Historique
   → Journal des 50 dernières actions.

8. Configurer Notifications Globales
   → Paramètres par défaut (1h, 30min, 10min, exact).

═══════════════════════════════════════════════════════════════════
 DATES DE NOTIFICATION PERSONNALISÉES (NOUVEAUTÉ v6.1)
═══════════════════════════════════════════════════════════════════

Après avoir défini l'échéance d'une tâche, vous pouvez choisir :

1.  DATES PERSONNALISÉES
   → Vous saisissez des dates ET heures exactes (YYYY-MM-DD HH:MM)
   → Exemples : 2026-06-18 14:30, 2026-06-19 09:00, 2026-06-20 08:00
   → Vous pouvez ajouter AUTANT de dates que vous voulez
   → Chaque date = une notification (type alarme)

   VALIDATIONS :
   • La date doit être APRÈS maintenant
   • La date doit être AVANT l'échéance de la tâche
   • Pas de doublons

2.  PARAMÈTRES GLOBAUX
   → Utilise les rappels par défaut (1h, 30min, 10min, exact)
   → Configurable via " Configurer Notifications Globales"

3.  AUCUNE NOTIFICATION
   → Pas de rappel pour cette tâche

EXEMPLE :
Tâche "Rendre rapport" — Échéance : 2026-06-20 18:00
Dates de notification : 2026-06-18 14:30, 2026-06-19 09:00, 2026-06-20 08:00
→ Vous serez notifié le 18 à 14h30, le 19 à 9h00 et le 20 à 8h00.

═══════════════════════════════════════════════════════════════════
 POPUP À L'ÉCHÉANCE
═══════════════════════════════════════════════════════════════════

Quand une tâche expire et que vous ouvrez l'application, un popup
demande si la tâche est TERMINÉE ou EN RETARD.

Désactivez dans " Configurer Notifications Globales".

EOF
}

# ==============================================================================
# MENU PRINCIPAL
# ==============================================================================
while true; do
    choix=$(zenity_safe --list --title=" TO DO LIST — MENU PRINCIPAL" \
        --width=450 --height=550 \
        --column="Actions" \
        "  Afficher les tâches" \
        "  Ajouter une tâche" \
        "   Modifier une tâche" \
        "   Supprimer une tâche" \
        "  Restaurer une tâche" \
        "  Voir les sous-tâches" \
        "  Exporter en CSV" \
        "  Importer depuis CSV" \
        "  Historique" \
        "  Configurer Notifications Globales" \
        "  Aide" \
        "  Quitter")

    case "$choix" in
        "  Afficher les tâches")        afficher_taches ;;
        "  Ajouter une tâche")          ajouter_tache ;;
        "   Modifier une tâche")         modifier_tache ;;
        "   Supprimer une tâche")        supprimer_tache ;;
        "  Restaurer une tâche")        restaurer_tache ;;
        "  Voir les sous-tâches")       afficher_sous_taches ;;
        "  Exporter en CSV")            exporter_csv ;;
        "  Importer depuis CSV")        importer_csv ;;
        "  Historique")                 afficher_historique ;;
        "  Configurer Notifications Globales") configurer_notifications ;;
        "  Aide")                       afficher_aide ;;
        "  Quitter"|"")                 exit 0 ;;
    esac
done
