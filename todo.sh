#!/bin/bash

# ==============================================================================
# MINI PROJET : TO DO LIST
# VERSION COMPLETE FINALE CORRIGEE
# ==============================================================================

# ------------------------------------------------------------------------------
# FICHIERS
# ------------------------------------------------------------------------------

FICHIER_DONNEES="taches.txt"
FICHIER_HISTORIQUE="historique.log"
FICHIER_EXPORT="export_taches.csv"

# ------------------------------------------------------------------------------
# INITIALISATION
# ------------------------------------------------------------------------------

if [ ! -f "$FICHIER_DONNEES" ]; then
    echo "ID|Titre|Description|Statut|Priorite|Echeance|ID_Parent" > "$FICHIER_DONNEES"
fi

touch "$FICHIER_HISTORIQUE"

# ------------------------------------------------------------------------------
# FONCTIONS UTILITAIRES
# ------------------------------------------------------------------------------

zenity_safe() {
    zenity "$@" 2>/dev/null
}

log_action() {

    echo "[$(date '+%d/%m/%Y %H:%M:%S')] $(whoami) : $1" >> "$FICHIER_HISTORIQUE"
}

generer_id() {

    dernier_id=$(tail -n +2 "$FICHIER_DONNEES" | \
        awk -F'|' '{print $1}' | \
        sort -n | \
        tail -1)

    if [ -z "$dernier_id" ]; then
        echo "1"
    else
        echo $((dernier_id + 1))
    fi
}

# ------------------------------------------------------------------------------
# AJOUTER TACHE
# ------------------------------------------------------------------------------

ajouter_tache() {

    titre=$(zenity_safe --entry \
        --title="Titre" \
        --text="Entrez le titre de la tâche")

    [ -z "$titre" ] && return

    description=$(zenity_safe --entry \
        --title="Description" \
        --text="Entrez la description")

    statut=$(zenity_safe --list \
        --title="Statut" \
        --column="Choix" \
        "En attente" \
        "En cours" \
        "Terminé")

    [ -z "$statut" ] && return

    priorite=$(zenity_safe --list \
        --title="Priorité" \
        --column="Choix" \
        "Haute" \
        "Moyenne" \
        "Basse")

    [ -z "$priorite" ] && return

    # ==========================================================================
    # CALENDRIER : TOUTES LES DATES
    # ==========================================================================

    echeance=$(zenity_safe --calendar \
        --title="Date d'échéance" \
        --date-format="%Y-%m-%d")

    [ -z "$echeance" ] && return

    parent=$(zenity_safe --entry \
        --title="Sous-tâche" \
        --text="ID Parent (laisser vide si aucune sous-tâche)")

    id=$(generer_id)

    echo "$id|$titre|$description|$statut|$priorite|$echeance|$parent" >> "$FICHIER_DONNEES"

    log_action "Ajout tâche ID $id"

    date_affiche=$(date -d "$echeance" +"%d/%m/%Y")

    zenity_safe --info \
        --title="Succès" \
        --text="Tâche ajoutée avec succès.

Date : $date_affiche"
}

# ------------------------------------------------------------------------------
# AFFICHER TACHES
# ------------------------------------------------------------------------------

afficher_taches() {

    if [ $(wc -l < "$FICHIER_DONNEES") -le 1 ]; then

        zenity_safe --info \
            --text="Aucune tâche disponible."

        return
    fi

    declare -a LISTE

    while IFS='|' read -r id titre description statut priorite echeance parent
    do

        date_affiche=$(date -d "$echeance" +"%d/%m/%Y" 2>/dev/null)

        LISTE+=("$id")
        LISTE+=("$titre")
        LISTE+=("$description")
        LISTE+=("$statut")
        LISTE+=("$priorite")
        LISTE+=("$date_affiche")
        LISTE+=("$parent")

    done < <(tail -n +2 "$FICHIER_DONNEES")

    zenity_safe --list \
        --title="Liste des tâches" \
        --width=1300 \
        --height=600 \
        --column="ID" \
        --column="Titre" \
        --column="Description" \
        --column="Statut" \
        --column="Priorité" \
        --column="Échéance" \
        --column="ID Parent" \
        "${LISTE[@]}"
}

# ------------------------------------------------------------------------------
# MODIFIER TACHE
# ------------------------------------------------------------------------------

modifier_tache() {

    id=$(zenity_safe --entry \
        --title="Modifier tâche" \
        --text="Entrez l'ID de la tâche")

    [ -z "$id" ] && return

    ligne=$(grep "^$id|" "$FICHIER_DONNEES")

    if [ -z "$ligne" ]; then

        zenity_safe --error \
            --text="Tâche introuvable."

        return
    fi

    IFS='|' read -r old_id titre description statut priorite echeance parent <<< "$ligne"

    champ=$(zenity_safe --list \
        --title="Choisir la colonne à modifier" \
        --width=400 \
        --height=350 \
        --column="Colonnes" \
        "Titre" \
        "Description" \
        "Statut" \
        "Priorité" \
        "Échéance" \
        "ID Parent")

    [ -z "$champ" ] && return

    case "$champ" in

        "Titre")

            nouveau=$(zenity_safe --entry \
                --title="Modifier Titre" \
                --entry-text="$titre")

            [ -z "$nouveau" ] && return

            titre="$nouveau"
            ;;

        "Description")

            nouveau=$(zenity_safe --entry \
                --title="Modifier Description" \
                --entry-text="$description")

            [ -z "$nouveau" ] && return

            description="$nouveau"
            ;;

        "Statut")

            nouveau=$(zenity_safe --list \
                --title="Modifier Statut" \
                --column="Statut" \
                "En attente" \
                "En cours" \
                "Terminé")

            [ -z "$nouveau" ] && return

            statut="$nouveau"
            ;;

        "Priorité")

            nouveau=$(zenity_safe --list \
                --title="Modifier Priorité" \
                --column="Priorité" \
                "Haute" \
                "Moyenne" \
                "Basse")

            [ -z "$nouveau" ] && return

            priorite="$nouveau"
            ;;

        "Échéance")

            nouveau=$(zenity_safe --calendar \
                --title="Modifier Date" \
                --date-format="%Y-%m-%d")

            [ -z "$nouveau" ] && return

            echeance="$nouveau"
            ;;

        "ID Parent")

            nouveau=$(zenity_safe --entry \
                --title="Modifier ID Parent" \
                --entry-text="$parent")

            parent="$nouveau"
            ;;

    esac

    grep -v "^$id|" "$FICHIER_DONNEES" > temp.txt

    echo "$id|$titre|$description|$statut|$priorite|$echeance|$parent" >> temp.txt

    mv temp.txt "$FICHIER_DONNEES"

    log_action "Modification tâche ID $id"

    zenity_safe --info \
        --text="Modification effectuée."
}

# ------------------------------------------------------------------------------
# SUPPRIMER TACHE
# ------------------------------------------------------------------------------

supprimer_tache() {

    id=$(zenity_safe --entry \
        --title="Supprimer tâche" \
        --text="Entrez l'ID")

    [ -z "$id" ] && return

    if grep -q "^$id|" "$FICHIER_DONNEES"; then

        grep -v "^$id|" "$FICHIER_DONNEES" > temp.txt

        mv temp.txt "$FICHIER_DONNEES"

        log_action "Suppression tâche ID $id"

        zenity_safe --info \
            --text="Tâche supprimée."

    else

        zenity_safe --error \
            --text="ID introuvable."
    fi
}

# ------------------------------------------------------------------------------
# FILTRER
# ------------------------------------------------------------------------------

filtrer_taches() {

    statut=$(zenity_safe --list \
        --title="Filtrer" \
        --column="Statut" \
        "En attente" \
        "En cours" \
        "Terminé")

    [ -z "$statut" ] && return

    declare -a LISTE

    while IFS='|' read -r id titre description st priorite echeance parent
    do

        if [ "$st" = "$statut" ]; then

            date_affiche=$(date -d "$echeance" +"%d/%m/%Y")

            LISTE+=("$id")
            LISTE+=("$titre")
            LISTE+=("$description")
            LISTE+=("$st")
            LISTE+=("$priorite")
            LISTE+=("$date_affiche")
            LISTE+=("$parent")

        fi

    done < <(tail -n +2 "$FICHIER_DONNEES")

    zenity_safe --list \
        --title="Résultat du filtre" \
        --width=1300 \
        --height=600 \
        --column="ID" \
        --column="Titre" \
        --column="Description" \
        --column="Statut" \
        --column="Priorité" \
        --column="Échéance" \
        --column="ID Parent" \
        "${LISTE[@]}"
}

# ------------------------------------------------------------------------------
# EXPORT CSV
# ------------------------------------------------------------------------------

exporter_csv() {

    cp "$FICHIER_DONNEES" "$FICHIER_EXPORT"

    zenity_safe --info \
        --title="Export CSV" \
        --text="Export terminé :
$FICHIER_EXPORT"

    log_action "Export CSV"
}

# ------------------------------------------------------------------------------
# IMPORT CSV
# ------------------------------------------------------------------------------

importer_csv() {

    fichier=$(zenity_safe --file-selection \
        --title="Importer un fichier")

    [ -z "$fichier" ] && return

    tail -n +2 "$fichier" >> "$FICHIER_DONNEES"

    zenity_safe --info \
        --text="Importation terminée."

    log_action "Import CSV"
}

# ------------------------------------------------------------------------------
# HISTORIQUE
# ------------------------------------------------------------------------------

afficher_historique() {

    zenity_safe --text-info \
        --title="Historique" \
        --width=900 \
        --height=500 \
        --filename="$FICHIER_HISTORIQUE"
}

# ------------------------------------------------------------------------------
# RAPPELS
# ------------------------------------------------------------------------------

verifier_rappels() {

    aujourdhui=$(date +"%Y-%m-%d")

    rappels=""

    while IFS='|' read -r id titre description statut priorite echeance parent
    do

        if [ "$echeance" = "$aujourdhui" ]; then

            date_affiche=$(date -d "$echeance" +"%d/%m/%Y")

            rappels="$rappels

ID : $id
Titre : $titre
Date : $date_affiche

"
        fi

    done < <(tail -n +2 "$FICHIER_DONNEES")

    if [ -n "$rappels" ]; then

        zenity_safe --warning \
            --title="Rappels du jour" \
            --width=500 \
            --height=300 \
            --text="$rappels"
    fi
}

# ------------------------------------------------------------------------------
# AIDE
# ------------------------------------------------------------------------------

afficher_aide() {

    zenity_safe --info \
        --width=700 \
        --height=500 \
        --title="Aide" \
        --text="
================ TO DO LIST =================

✔ Ajouter une tâche
✔ Modifier une tâche
✔ Supprimer une tâche
✔ Afficher les tâches
✔ Filtrer par statut
✔ Gestion des priorités
✔ Sous-tâches
✔ Historique
✔ Export CSV
✔ Import CSV
✔ Rappels

Format date :
JJ/MM/AAAA

=============================================
"
}

# ------------------------------------------------------------------------------
# RAPPELS AU DEMARRAGE
# ------------------------------------------------------------------------------

verifier_rappels

# ------------------------------------------------------------------------------
# MENU PRINCIPAL
# ------------------------------------------------------------------------------

while true
do

    choix=$(zenity_safe --list \
        --title="TO DO LIST - MENU PRINCIPAL" \
        --width=550 \
        --height=650 \
        --column="Actions" \
        "Afficher les tâches" \
        "Ajouter une tâche" \
        "Modifier une tâche" \
        "Supprimer une tâche" \
        "Filtrer par statut" \
        "Afficher historique" \
        "Exporter CSV" \
        "Importer CSV" \
        "Aide (--help)" \
        "Quitter")

    case "$choix" in

        "Afficher les tâches")
            afficher_taches
            ;;

        "Ajouter une tâche")
            ajouter_tache
            ;;

        "Modifier une tâche")
            modifier_tache
            ;;

        "Supprimer une tâche")
            supprimer_tache
            ;;

        "Filtrer par statut")
            filtrer_taches
            ;;

        "Afficher historique")
            afficher_historique
            ;;

        "Exporter CSV")
            exporter_csv
            ;;

        "Importer CSV")
            importer_csv
            ;;

        "Aide (--help)")
            afficher_aide
            ;;

        "Quitter"|*)
            exit 0
            ;;
    esac

done
