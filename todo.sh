#!/bin/bash

# ==============================================================================
# PROJET : TO DO LIST - AIAC
# Description : Gestionnaire de tâches avec Zenity (Interface Graphique)
# ==============================================================================

FICHIER_DONNEES="taches.txt"
FICHIER_HISTORIQUE="historique.log"

# Initialisation des fichiers
if [ ! -f "$FICHIER_DONNEES" ]; then
    echo "ID|Titre|Description|Statut|Priorité|Echéance|ID_Parent" > "$FICHIER_DONNEES"
fi
touch "$FICHIER_HISTORIQUE"

# Fonction pour masquer les erreurs de driver graphique (Mesa/EGL)
# On redirige les erreurs standards de zenity pour plus de clarté
zenity_safe() {
    zenity "$@" 2>/dev/null
}

log_action() {
    local action="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $(whoami) - $action" >> "$FICHIER_HISTORIQUE"
}

generer_id() {
    local dernier_id=$(tail -n +2 "$FICHIER_DONNEES" | awk -F'|' '{print $1}' | sort -n | tail -1)
    if [ -z "$dernier_id" ]; then echo "1"; else echo "$((dernier_id + 1))"; fi
}

# --- FONCTIONS ---

ajouter_tache() {
    # Correction : On sépare les champs pour éviter le bug de format de date
    local inputs=$(zenity_safe --forms --title="Ajouter une tâche" \
        --text="Remplissez les informations ci-dessous" \
        --add-entry="Titre" \
        --add-entry="Description" \
        --add-combo="Statut" --combo-values="En attente|En cours|Terminé" \
        --add-combo="Priorité" --combo-values="Haute|Moyenne|Basse" \
        --add-calendar="Échéance (Sélectionnez une date)" \
        --add-entry="ID Parent (laisser vide si tâche principale)")

    if [ -n "$inputs" ]; then
        local id=$(generer_id)
        echo "$id|$inputs" >> "$FICHIER_DONNEES"
        log_action "Ajout tâche ID $id"
        zenity_safe --info --text="Tâche $id ajoutée avec succès !"
    fi
}

afficher_taches() {
    local data=$(tail -n +2 "$FICHIER_DONNEES" | awk -F'|' '{print $1 "\n" $2 "\n" $4 "\n" $5 "\n" $6 "\n" $7}')
    if [ -z "$data" ]; then
        zenity_safe --info --text="La liste est vide."
    else
        zenity_safe --list --title="Liste des Tâches" --width=800 --height=400 \
            --column="ID" --column="Titre" --column="Statut" --column="Priorité" --column="Échéance" --column="ID Parent" \
            $data
    fi
}

supprimer_tache() {
    local id=$(zenity_safe --entry --title="Supprimer" --text="Entrez l'ID de la tâche à supprimer :")
    if [ -n "$id" ]; then
        if grep -q "^$id|" "$FICHIER_DONNEES"; then
            grep -v "^$id|" "$FICHIER_DONNEES" > tmp.txt && mv tmp.txt "$FICHIER_DONNEES"
            log_action "Suppression tâche ID $id"
            zenity_safe --info --text="Tâche $id supprimée."
        else
            zenity_safe --error --text="ID $id introuvable."
        fi
    fi
}

# --- MENU PRINCIPAL ---

while true; do
    choix=$(zenity_safe --list --title="TO DO LIST - MENU" --width=400 --height=350 \
        --column="Actions" \
        "Afficher les tâches" \
        "Ajouter une tâche" \
        "Supprimer une tâche" \
        "Exporter en CSV" \
        "Aide (--help)" \
        "Quitter")

    case $choix in
        "Afficher les tâches") afficher_taches ;;
        "Ajouter une tâche") ajouter_tache ;;
        "Supprimer une tâche") supprimer_tache ;;
        "Exporter en CSV") cp "$FICHIER_DONNEES" "export_taches.csv" && zenity_safe --info --text="Exporté sous export_taches.csv" ;;
        "Aide (--help)") zenity_safe --info --title="Aide" --text="Utilisez le menu pour gérer vos tâches.\nLes rappels sont gérés par le script rappels.sh via cron." ;;
        "Quitter"|*) exit 0 ;;
    esac
done
