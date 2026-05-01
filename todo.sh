#!/bin/bash

# ==============================================================================
# PROJET : TO DO LIST - AIAC
# Auteur  : Groupe GI - AIAC
# Version : 2.0 - Complète
# ==============================================================================

FICHIER_DONNEES="taches.txt"
FICHIER_HISTORIQUE="historique.log"
DOSSIER_SOUS_TACHES="sub-tasks"

# --- INITIALISATION ---
if [ ! -f "$FICHIER_DONNEES" ]; then
    echo "ID|Titre|Description|Statut|Priorité|Echéance|ID_Parent" > "$FICHIER_DONNEES"
fi
touch "$FICHIER_HISTORIQUE"
mkdir -p "$DOSSIER_SOUS_TACHES"

# Masquer les erreurs graphiques Mesa/EGL de zenity
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
    grep -q "^$1|" "$FICHIER_DONNEES"
}

# ==============================================================================
# 1. AJOUTER UNE TÂCHE
# ==============================================================================
ajouter_tache() {
    local inputs
    inputs=$(zenity_safe --forms --title="➕ Ajouter une tâche" \
        --text="Remplissez les informations ci-dessous" \
        --add-entry="Titre" \
        --add-entry="Description" \
        --add-combo="Statut" --combo-values="En attente|En cours|Terminé" \
        --add-combo="Priorité" --combo-values="Haute|Moyenne|Basse" \
        --add-entry="Échéance (YYYY-MM-DD)" \
        --add-entry="ID Parent (vide = tâche principale)")

    [ -z "$inputs" ] && return

    local id
    id=$(generer_id)

    # Parsing des champs retournés par --forms (séparateur |)
    local titre desc statut priorite echeance parent
    IFS='|' read -r titre desc statut priorite echeance parent <<< "$inputs"

    # Validation date
    if [ -n "$echeance" ] && ! date -d "$echeance" &>/dev/null; then
        zenity_safe --error --text="Format de date invalide. Utilisez YYYY-MM-DD."
        return
    fi

    # Validation ID parent
    if [ -n "$parent" ] && ! tache_existe "$parent"; then
        zenity_safe --error --text="ID Parent '$parent' introuvable."
        return
    fi

    echo "$id|$titre|$desc|$statut|$priorite|$echeance|$parent" >> "$FICHIER_DONNEES"

    # Créer le fichier de sous-tâche si c'est une sous-tâche
    if [ -n "$parent" ]; then
        echo "$id" >> "$DOSSIER_SOUS_TACHES/parent_$parent.txt"
    fi

    log_action "AJOUT tâche ID=$id Titre='$titre' Statut='$statut' Priorité='$priorite' Échéance='$echeance' Parent='$parent'"
    zenity_safe --info --text="✅ Tâche '$titre' ajoutée avec succès (ID: $id) !"
}

# ==============================================================================
# 2. AFFICHER LES TÂCHES
# ==============================================================================
afficher_taches() {
    local filtre
    filtre=$(zenity_safe --list --title="🔍 Filtrer les tâches" \
        --text="Choisissez un filtre d'affichage :" \
        --column="Filtre" \
        "Toutes les tâches" \
        "En attente" \
        "En cours" \
        "Terminé" \
        "Haute priorité" \
        "Moyenne priorité" \
        "Basse priorité")

    [ -z "$filtre" ] && return

    local donnees
    case "$filtre" in
        "Toutes les tâches")
            donnees=$(tail -n +2 "$FICHIER_DONNEES") ;;
        "En attente"|"En cours"|"Terminé")
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

    local args=()
    while IFS='|' read -r id titre desc statut priorite echeance parent; do
        args+=("$id" "$titre" "$statut" "$priorite" "$echeance" "$parent")
    done <<< "$donnees"

    zenity_safe --list --title="📋 Liste des Tâches — $filtre" --width=900 --height=500 \
        --column="ID" --column="Titre" --column="Statut" --column="Priorité" --column="Échéance" --column="ID Parent" \
        "${args[@]}"
}

# ==============================================================================
# 3. MODIFIER UNE TÂCHE
# ==============================================================================
modifier_tache() {
    local id
    id=$(zenity_safe --entry --title="✏️ Modifier une tâche" --text="Entrez l'ID de la tâche à modifier :")
    [ -z "$id" ] && return

    if ! tache_existe "$id"; then
        zenity_safe --error --text="ID '$id' introuvable."
        return
    fi

    # Lire les valeurs actuelles
    local ligne
    ligne=$(grep "^$id|" "$FICHIER_DONNEES")
    local ancien_titre ancien_desc ancien_statut ancien_priorite ancien_echeance ancien_parent
    IFS='|' read -r _ ancien_titre ancien_desc ancien_statut ancien_priorite ancien_echeance ancien_parent <<< "$ligne"

    local inputs
    inputs=$(zenity_safe --forms --title="✏️ Modifier tâche ID $id" \
        --text="Modifiez les champs souhaités (actuels affichés)" \
        --add-entry="Titre (actuel: $ancien_titre)" \
        --add-entry="Description (actuel: $ancien_desc)" \
        --add-combo="Statut" --combo-values="En attente|En cours|Terminé" \
        --add-combo="Priorité" --combo-values="Haute|Moyenne|Basse" \
        --add-entry="Échéance YYYY-MM-DD (actuel: $ancien_echeance)")

    [ -z "$inputs" ] && return

    local nouveau_titre nouveau_desc nouveau_statut nouveau_priorite nouveau_echeance
    IFS='|' read -r nouveau_titre nouveau_desc nouveau_statut nouveau_priorite nouveau_echeance <<< "$inputs"

    # Garder ancienne valeur si champ vide
    [ -z "$nouveau_titre" ]     && nouveau_titre="$ancien_titre"
    [ -z "$nouveau_desc" ]      && nouveau_desc="$ancien_desc"
    [ -z "$nouveau_statut" ]    && nouveau_statut="$ancien_statut"
    [ -z "$nouveau_priorite" ]  && nouveau_priorite="$ancien_priorite"
    [ -z "$nouveau_echeance" ]  && nouveau_echeance="$ancien_echeance"

    # Validation date
    if [ -n "$nouveau_echeance" ] && ! date -d "$nouveau_echeance" &>/dev/null; then
        zenity_safe --error --text="Format de date invalide. Utilisez YYYY-MM-DD."
        return
    fi

    # Remplacement dans le fichier
    local nouvelle_ligne="$id|$nouveau_titre|$nouveau_desc|$nouveau_statut|$nouveau_priorite|$nouveau_echeance|$ancien_parent"
    sed -i "s|^$id|.*|$nouvelle_ligne|" "$FICHIER_DONNEES"
    # Utiliser une approche plus robuste
    grep -v "^$id|" "$FICHIER_DONNEES" > /tmp/todo_tmp.txt
    # Insérer la nouvelle ligne après l'en-tête en respectant l'ordre des ID
    head -1 /tmp/todo_tmp.txt > /tmp/todo_sorted.txt
    { echo "$nouvelle_ligne"; tail -n +2 /tmp/todo_tmp.txt; } | sort -t'|' -k1 -n >> /tmp/todo_sorted.txt
    mv /tmp/todo_sorted.txt "$FICHIER_DONNEES"
    rm -f /tmp/todo_tmp.txt

    log_action "MODIFICATION tâche ID=$id | Titre: '$ancien_titre'→'$nouveau_titre' | Statut: '$ancien_statut'→'$nouveau_statut' | Priorité: '$ancien_priorite'→'$nouveau_priorite' | Échéance: '$ancien_echeance'→'$nouveau_echeance'"
    zenity_safe --info --text="✅ Tâche $id modifiée avec succès !"
}

# ==============================================================================
# 4. SUPPRIMER UNE TÂCHE
# ==============================================================================
supprimer_tache() {
    local id
    id=$(zenity_safe --entry --title="🗑️ Supprimer" --text="Entrez l'ID de la tâche à supprimer :")
    [ -z "$id" ] && return

    if ! tache_existe "$id"; then
        zenity_safe --error --text="ID '$id' introuvable."
        return
    fi

    local titre
    titre=$(grep "^$id|" "$FICHIER_DONNEES" | cut -d'|' -f2)

    zenity_safe --question --text="Supprimer la tâche '$titre' (ID: $id) et ses sous-tâches ?" || return

    # Supprimer les sous-tâches liées
    if [ -f "$DOSSIER_SOUS_TACHES/parent_$id.txt" ]; then
        while IFS= read -r sous_id; do
            grep -v "^$sous_id|" "$FICHIER_DONNEES" > /tmp/todo_tmp.txt && mv /tmp/todo_tmp.txt "$FICHIER_DONNEES"
            log_action "SUPPRESSION sous-tâche ID=$sous_id (parent=$id)"
        done < "$DOSSIER_SOUS_TACHES/parent_$id.txt"
        rm -f "$DOSSIER_SOUS_TACHES/parent_$id.txt"
    fi

    grep -v "^$id|" "$FICHIER_DONNEES" > /tmp/todo_tmp.txt && mv /tmp/todo_tmp.txt "$FICHIER_DONNEES"
    log_action "SUPPRESSION tâche ID=$id Titre='$titre'"
    zenity_safe --info --text="🗑️ Tâche '$titre' (ID: $id) supprimée."
}

# ==============================================================================
# 5. AFFICHER LES SOUS-TÂCHES D'UNE TÂCHE
# ==============================================================================
afficher_sous_taches() {
    local id
    id=$(zenity_safe --entry --title="🔗 Sous-tâches" --text="Entrez l'ID de la tâche parente :")
    [ -z "$id" ] && return

    if ! tache_existe "$id"; then
        zenity_safe --error --text="ID '$id' introuvable."
        return
    fi

    local titre_parent
    titre_parent=$(grep "^$id|" "$FICHIER_DONNEES" | cut -d'|' -f2)

    local args=()
    while IFS='|' read -r sid stitre sdesc sstatut spriorite secheance sparent; do
        [ "$sparent" = "$id" ] && args+=("$sid" "$stitre" "$sstatut" "$spriorite" "$secheance")
    done < <(tail -n +2 "$FICHIER_DONNEES")

    if [ ${#args[@]} -eq 0 ]; then
        zenity_safe --info --text="Aucune sous-tâche pour '$titre_parent'."
        return
    fi

    zenity_safe --list --title="🔗 Sous-tâches de '$titre_parent' (ID: $id)" --width=800 --height=400 \
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
    zenity_safe --info --text="✅ Exporté sous '$fichier_export'"
}

# ==============================================================================
# 7. IMPORTER DEPUIS CSV
# ==============================================================================
importer_csv() {
    local fichier
    fichier=$(zenity_safe --file-selection --title="📂 Importer un fichier CSV" --file-filter="*.csv *.txt")
    [ -z "$fichier" ] && return

    if [ ! -f "$fichier" ]; then
        zenity_safe --error --text="Fichier introuvable."
        return
    fi

    local compteur=0
    # Ignorer la première ligne (en-tête)
    tail -n +2 "$fichier" | while IFS='|' read -r _ titre desc statut priorite echeance parent; do
        local id
        id=$(generer_id)
        echo "$id|$titre|$desc|$statut|$priorite|$echeance|$parent" >> "$FICHIER_DONNEES"
        compteur=$((compteur + 1))
    done

    log_action "IMPORT CSV depuis '$fichier'"
    zenity_safe --info --text="✅ Importation terminée depuis '$fichier'."
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
    zenity_safe --text-info --title="📜 Historique des modifications (50 dernières)" \
        --width=900 --height=500 <<< "$contenu"
}

# ==============================================================================
# 9. AIDE
# ==============================================================================
afficher_aide() {
    zenity_safe --text-info --title="❓ Aide - TO DO LIST" --width=700 --height=500 <<'EOF'
=== SYSTÈME DE GESTION TO DO LIST - AIAC ===

FONCTIONNALITÉS DISPONIBLES :

1. Afficher les tâches
   → Affiche toutes les tâches avec filtrage par statut ou priorité.

2. Ajouter une tâche
   → Crée une nouvelle tâche avec titre, description, statut,
     priorité, échéance, et éventuel ID parent (sous-tâche).

3. Modifier une tâche
   → Modifie les champs d'une tâche existante par son ID.
     Tous les changements sont tracés dans l'historique.

4. Supprimer une tâche
   → Supprime une tâche et toutes ses sous-tâches associées.

5. Voir les sous-tâches
   → Affiche toutes les sous-tâches d'une tâche parente.

6. Exporter en CSV
   → Exporte les tâches dans un fichier CSV horodaté.

7. Importer depuis CSV
   → Importe des tâches depuis un fichier CSV compatible.

8. Historique
   → Affiche les 50 dernières actions effectuées.

FORMAT DES DONNÉES (taches.txt) :
ID | Titre | Description | Statut | Priorité | Échéance | ID_Parent

RAPPELS AUTOMATIQUES :
Les rappels sont gérés par rappels.sh via cron.
Installation : make cron (exécution quotidienne à 09h00)

FILTRES DISPONIBLES :
Statut   : En attente | En cours | Terminé
Priorité : Haute | Moyenne | Basse
EOF
}

# ==============================================================================
# MENU PRINCIPAL
# ==============================================================================
while true; do
    choix=$(zenity_safe --list --title="📝 TO DO LIST — MENU PRINCIPAL" \
        --width=450 --height=450 \
        --column="Actions" \
        "📋  Afficher les tâches" \
        "➕  Ajouter une tâche" \
        "✏️   Modifier une tâche" \
        "🗑️   Supprimer une tâche" \
        "🔗  Voir les sous-tâches" \
        "💾  Exporter en CSV" \
        "📂  Importer depuis CSV" \
        "📜  Historique" \
        "❓  Aide" \
        "🚪  Quitter")

    case "$choix" in
        "📋  Afficher les tâches")   afficher_taches ;;
        "➕  Ajouter une tâche")     ajouter_tache ;;
        "✏️   Modifier une tâche")    modifier_tache ;;
        "🗑️   Supprimer une tâche")   supprimer_tache ;;
        "🔗  Voir les sous-tâches")  afficher_sous_taches ;;
        "💾  Exporter en CSV")       exporter_csv ;;
        "📂  Importer depuis CSV")   importer_csv ;;
        "📜  Historique")            afficher_historique ;;
        "❓  Aide")                  afficher_aide ;;
        "🚪  Quitter"|"")            exit 0 ;;
    esac
done
