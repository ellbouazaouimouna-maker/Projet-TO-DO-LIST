# ==============================================================================
# Makefile — Système de Gestion TO DO List
# Projet : Mini Projet Shell | AIAC — Génie Informatique
# ==============================================================================

SCRIPT_PRINCIPAL = todo.sh
SCRIPT_RAPPEL    = rappels.sh
CRON_JOB         = "0 9 * * * /bin/bash $(PWD)/$(SCRIPT_RAPPEL)"

.PHONY: all install run cron uninstall clean help

# Cible par défaut
all: install

# --- INSTALLATION ---
install:
	@echo "==> Installation des dépendances..."
	sudo apt-get update -qq && sudo apt-get install -y zenity libnotify-bin
	@echo "==> Attribution des droits d'exécution..."
	chmod +x $(SCRIPT_PRINCIPAL)
	chmod +x $(SCRIPT_RAPPEL)
	@echo "==> Initialisation des dossiers..."
	mkdir -p sub-tasks
	touch historique.log
	@if [ ! -f taches.txt ]; then \
		echo "ID|Titre|Description|Statut|Priorité|Echéance|ID_Parent" > taches.txt; \
	fi
	@echo ""
	@echo "✅ Installation terminée."
	@echo "   Lancez l'application avec : make run"
	@echo "   Activez les rappels avec  : make cron"

# --- LANCEMENT ---
run:
	@echo "==> Lancement de TO DO LIST..."
	./$(SCRIPT_PRINCIPAL)

# --- RAPPELS CRON ---
cron:
	@echo "==> Ajout du rappel quotidien dans crontab (09h00)..."
	(crontab -l 2>/dev/null | grep -v "$(SCRIPT_RAPPEL)"; echo $(CRON_JOB)) | crontab -
	@echo "✅ Cron job installé : exécution tous les jours à 09h00."
	@echo "   Vérifiez avec : crontab -l"

# --- SUPPRESSION DU CRON ---
uncron:
	@echo "==> Suppression du rappel cron..."
	crontab -l 2>/dev/null | grep -v "$(SCRIPT_RAPPEL)" | crontab -
	@echo "✅ Cron job supprimé."

# --- DÉSINSTALLATION ---
uninstall: uncron clean
	@echo "==> Désinstallation complète effectuée."

# --- NETTOYAGE DES DONNÉES ---
clean:
	@echo "==> Nettoyage des données..."
	rm -f taches.txt historique.log export_taches_*.csv /tmp/todo_tmp.txt /tmp/todo_sorted.txt
	rm -rf sub-tasks/
	@echo "✅ Données supprimées."

# --- AIDE ---
help:
	@echo ""
	@echo "========================================="
	@echo "  TO DO LIST — Makefile Help"
	@echo "========================================="
	@echo ""
	@echo "  make install    Installe les dépendances et initialise le projet"
	@echo "  make run        Lance l'application"
	@echo "  make cron       Active les rappels quotidiens à 09h00"
	@echo "  make uncron     Désactive les rappels cron"
	@echo "  make clean      Supprime les données (taches.txt, historique.log)"
	@echo "  make uninstall  Nettoyage complet + suppression cron"
	@echo "  make help       Affiche cette aide"
	@echo ""
