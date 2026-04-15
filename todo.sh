#!/bin/bash

# ============================================
#        TODO LIST - Gestionnaire de tâches
# ============================================

TASKS_FILE="tasks.txt"
HISTORY_FILE="history.log"
SUB_TASKS_DIR="sub-tasks"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# Initialisation des fichiers nécessaires
init() {
    [ ! -f "$TASKS_FILE" ] && touch "$TASKS_FILE"
    [ ! -f "$HISTORY_FILE" ] && touch "$HISTORY_FILE"
    [ ! -d "$SUB_TASKS_DIR" ] && mkdir -p "$SUB_TASKS_DIR"
}

# Journaliser une action
log_action() {
    local action="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $action" >> "$HISTORY_FILE"
}

# Afficher le menu principal
show_menu() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════╗"
    echo "║        ✅  TODO LIST MANAGER         ║"
    echo "╚══════════════════════════════════════╝"
    echo -e "${RESET}"
    echo -e "${BOLD}  1.${RESET} 📋 Afficher toutes les tâches"
    echo -e "${BOLD}  2.${RESET} ➕ Ajouter une tâche"
    echo -e "${BOLD}  3.${RESET} ✔️  Marquer une tâche comme terminée"
    echo -e "${BOLD}  4.${RESET} ❌ Supprimer une tâche"
    echo -e "${BOLD}  5.${RESET} 🔍 Rechercher une tâche"
    echo -e "${BOLD}  6.${RESET} 📁 Gérer les sous-tâches"
    echo -e "${BOLD}  7.${RESET} 📜 Voir l'historique"
    echo -e "${BOLD}  8.${RESET} 🗑️  Vider les tâches terminées"
    echo -e "${BOLD}  9.${RESET} 📊 Statistiques"
    echo -e "${BOLD}  0.${RESET} 🚪 Quitter"
    echo ""
    echo -ne "${YELLOW}Votre choix : ${RESET}"
}

# Afficher toutes les tâches
list_tasks() {
    echo -e "\n${CYAN}${BOLD}═══════════════ LISTE DES TÂCHES ═══════════════${RESET}"
    if [ ! -s "$TASKS_FILE" ]; then
        echo -e "${YELLOW}  Aucune tâche enregistrée.${RESET}"
    else
        local i=1
        while IFS='|' read -r status task priority date; do
            if [ "$status" = "DONE" ]; then
                echo -e "  ${GREEN}[$i] ✔ $task${RESET} ${BLUE}(Priorité: $priority)${RESET} ${CYAN}[$date]${RESET}"
            else
                echo -e "  ${RED}[$i] ☐ $task${RESET} ${BLUE}(Priorité: $priority)${RESET} ${CYAN}[$date]${RESET}"
            fi
            ((i++))
        done < "$TASKS_FILE"
    fi
    echo -e "${CYAN}${BOLD}════════════════════════════════════════════════${RESET}\n"
}

# Ajouter une tâche
add_task() {
    echo -ne "\n${YELLOW}Nom de la tâche : ${RESET}"
    read -r task
    if [ -z "$task" ]; then
        echo -e "${RED}  Erreur : le nom ne peut pas être vide.${RESET}"
        return
    fi
    echo -ne "${YELLOW}Priorité (haute/moyenne/basse) [moyenne] : ${RESET}"
    read -r priority
    priority=${priority:-moyenne}
    local date
    date=$(date '+%Y-%m-%d')
    echo "TODO|$task|$priority|$date" >> "$TASKS_FILE"
    log_action "AJOUT : $task (Priorité: $priority)"
    echo -e "${GREEN}  ✅ Tâche '$task' ajoutée avec succès !${RESET}"
}

# Marquer une tâche comme terminée
complete_task() {
    list_tasks
    echo -ne "${YELLOW}Numéro de la tâche à terminer : ${RESET}"
    read -r num
    if ! [[ "$num" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}  Numéro invalide.${RESET}"
        return
    fi
    local total
    total=$(wc -l < "$TASKS_FILE")
    if [ "$num" -lt 1 ] || [ "$num" -gt "$total" ]; then
        echo -e "${RED}  Tâche introuvable.${RESET}"
        return
    fi
    local task_name
    task_name=$(sed -n "${num}p" "$TASKS_FILE" | cut -d'|' -f2)
    sed -i "${num}s/^TODO/DONE/" "$TASKS_FILE"
    log_action "TERMINÉ : $task_name"
    echo -e "${GREEN}  ✔️  Tâche '$task_name' marquée comme terminée !${RESET}"
}

# Supprimer une tâche
delete_task() {
    list_tasks
    echo -ne "${YELLOW}Numéro de la tâche à supprimer : ${RESET}"
    read -r num
    if ! [[ "$num" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}  Numéro invalide.${RESET}"
        return
    fi
    local total
    total=$(wc -l < "$TASKS_FILE")
    if [ "$num" -lt 1 ] || [ "$num" -gt "$total" ]; then
        echo -e "${RED}  Tâche introuvable.${RESET}"
        return
    fi
    local task_name
    task_name=$(sed -n "${num}p" "$TASKS_FILE" | cut -d'|' -f2)
    echo -ne "${RED}  Confirmer la suppression de '$task_name' ? (o/n) : ${RESET}"
    read -r confirm
    if [ "$confirm" = "o" ] || [ "$confirm" = "O" ]; then
        sed -i "${num}d" "$TASKS_FILE"
        log_action "SUPPRESSION : $task_name"
        echo -e "${GREEN}  🗑️  Tâche '$task_name' supprimée.${RESET}"
    else
        echo -e "${YELLOW}  Suppression annulée.${RESET}"
    fi
}

# Rechercher une tâche
search_task() {
    echo -ne "\n${YELLOW}Rechercher : ${RESET}"
    read -r keyword
    echo -e "\n${CYAN}${BOLD}Résultats pour '${keyword}' :${RESET}"
    local found=0
    local i=1
    while IFS='|' read -r status task priority date; do
        if echo "$task" | grep -qi "$keyword"; then
            local icon="☐"
            local color=$RED
            [ "$status" = "DONE" ] && icon="✔" && color=$GREEN
            echo -e "  ${color}[$i] $icon $task${RESET} ${BLUE}(Priorité: $priority | Date: $date)${RESET}"
            found=1
        fi
        ((i++))
    done < "$TASKS_FILE"
    [ $found -eq 0 ] && echo -e "${YELLOW}  Aucune tâche trouvée.${RESET}"
}

# Gérer les sous-tâches
manage_subtasks() {
    echo -e "\n${CYAN}${BOLD}═══════ GESTION DES SOUS-TÂCHES ═══════${RESET}"
    list_tasks
    echo -ne "${YELLOW}Numéro de la tâche principale : ${RESET}"
    read -r num
    if ! [[ "$num" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}  Numéro invalide.${RESET}"
        return
    fi
    local task_name
    task_name=$(sed -n "${num}p" "$TASKS_FILE" | cut -d'|' -f2)
    local sub_file="$SUB_TASKS_DIR/task_${num}.txt"

    echo -e "\n${BOLD}Sous-tâches de : $task_name${RESET}"
    if [ -f "$sub_file" ] && [ -s "$sub_file" ]; then
        cat -n "$sub_file"
    else
        echo -e "${YELLOW}  Aucune sous-tâche.${RESET}"
    fi

    echo -e "\n  ${BOLD}1.${RESET} Ajouter une sous-tâche"
    echo -e "  ${BOLD}2.${RESET} Supprimer une sous-tâche"
    echo -e "  ${BOLD}3.${RESET} Retour"
    echo -ne "${YELLOW}Choix : ${RESET}"
    read -r sub_choice

    case $sub_choice in
        1)
            echo -ne "${YELLOW}Nom de la sous-tâche : ${RESET}"
            read -r sub_task
            echo "[ ] $sub_task" >> "$sub_file"
            log_action "SOUS-TÂCHE AJOUTÉE : $sub_task (-> $task_name)"
            echo -e "${GREEN}  Sous-tâche ajoutée !${RESET}"
            ;;
        2)
            echo -ne "${YELLOW}Numéro à supprimer : ${RESET}"
            read -r sub_num
            sed -i "${sub_num}d" "$sub_file"
            echo -e "${GREEN}  Sous-tâche supprimée.${RESET}"
            ;;
        3) return ;;
    esac
}

# Voir l'historique
view_history() {
    echo -e "\n${CYAN}${BOLD}═══════════════ HISTORIQUE ═══════════════${RESET}"
    if [ ! -s "$HISTORY_FILE" ]; then
        echo -e "${YELLOW}  Historique vide.${RESET}"
    else
        tail -20 "$HISTORY_FILE" | while read -r line; do
            echo -e "  ${BLUE}$line${RESET}"
        done
    fi
    echo -e "${CYAN}${BOLD}══════════════════════════════════════════${RESET}\n"
}

# Vider les tâches terminées
clear_done() {
    local count
    count=$(grep -c "^DONE" "$TASKS_FILE" 2>/dev/null || echo 0)
    if [ "$count" -eq 0 ]; then
        echo -e "${YELLOW}  Aucune tâche terminée à supprimer.${RESET}"
        return
    fi
    echo -ne "${RED}  Supprimer $count tâche(s) terminée(s) ? (o/n) : ${RESET}"
    read -r confirm
    if [ "$confirm" = "o" ] || [ "$confirm" = "O" ]; then
        sed -i '/^DONE/d' "$TASKS_FILE"
        log_action "NETTOYAGE : $count tâche(s) terminée(s) supprimée(s)"
        echo -e "${GREEN}  🗑️  $count tâche(s) supprimée(s).${RESET}"
    fi
}

# Statistiques
show_stats() {
    local total done todo
    total=$(wc -l < "$TASKS_FILE" 2>/dev/null || echo 0)
    done=$(grep -c "^DONE" "$TASKS_FILE" 2>/dev/null || echo 0)
    todo=$((total - done))
    local pct=0
    [ "$total" -gt 0 ] && pct=$((done * 100 / total))

    echo -e "\n${CYAN}${BOLD}═══════════════ STATISTIQUES ═══════════════${RESET}"
    echo -e "  ${BOLD}Total des tâches   :${RESET} $total"
    echo -e "  ${GREEN}${BOLD}Tâches terminées   :${RESET} $done"
    echo -e "  ${RED}${BOLD}Tâches en cours    :${RESET} $todo"
    echo -e "  ${YELLOW}${BOLD}Progression        :${RESET} $pct%"

    # Barre de progression
    local bar=""
    local filled=$((pct / 5))
    for ((i=0; i<20; i++)); do
        [ $i -lt $filled ] && bar+="█" || bar+="░"
    done
    echo -e "  ${GREEN}[$bar]${RESET} $pct%"

    # Priorités
    echo -e "\n  ${BOLD}Par priorité :${RESET}"
    echo -e "    Haute   : $(grep -c "|haute|" "$TASKS_FILE" 2>/dev/null || echo 0)"
    echo -e "    Moyenne : $(grep -c "|moyenne|" "$TASKS_FILE" 2>/dev/null || echo 0)"
    echo -e "    Basse   : $(grep -c "|basse|" "$TASKS_FILE" 2>/dev/null || echo 0)"
    echo -e "${CYAN}${BOLD}═════════════════════════════════════════════${RESET}\n"
}

# Boucle principale
main() {
    init
    while true; do
        show_menu
        read -r choice
        case $choice in
            1) list_tasks ;;
            2) add_task ;;
            3) complete_task ;;
            4) delete_task ;;
            5) search_task ;;
            6) manage_subtasks ;;
            7) view_history ;;
            8) clear_done ;;
            9) show_stats ;;
            0)
                echo -e "\n${GREEN}  Au revoir ! 👋${RESET}\n"
                log_action "FIN DE SESSION"
                exit 0
                ;;
            *)
                echo -e "${RED}  Option invalide. Veuillez réessayer.${RESET}"
                ;;
        esac
        echo -ne "\n${YELLOW}Appuyez sur [Entrée] pour continuer...${RESET}"
        read -r
    done
}

main
