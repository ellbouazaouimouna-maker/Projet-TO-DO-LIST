# ==============================================================================
# PROJET : TO DO LIST - AIAC
# Makefile — Installation, lancement, cron, nettoyage
# ==============================================================================

SCRIPT_DIR  := $(shell pwd)
TODO        := $(SCRIPT_DIR)/todo.sh
RAPPELS     := $(SCRIPT_DIR)/rappels.sh
LOG         := $(SCRIPT_DIR)/cron.log

.PHONY: all install run cron uncron clean uninstall help

all: help

# ── Aide ──────────────────────────────────────────────────────────────────────
help:
	@echo ""
	@echo "  TO DO LIST — Commandes disponibles"
	@echo "  ─────────────────────────────────────────────"
	@echo "  make install   →  installe zenity, libnotify"
	@echo "  make run       →  lance l'application"
	@echo "  make cron      →  active les rappels (toutes les minutes)"
	@echo "  make uncron    →  désactive les rappels cron"
	@echo "  make clean     →  supprime les données (taches, log, config)"
	@echo "  make uninstall →  clean + désactive le cron"
	@echo ""

# ── Installation des dépendances ──────────────────────────────────────────────
install:
	@echo "==> Installation des dépendances..."
	@sudo apt-get update -qq
	@sudo apt-get install -y zenity libnotify-bin 2>/dev/null || \
		echo "  Certains paquets n'ont pas pu être installés (mode offline ?)"
	@chmod +x "$(TODO)" "$(RAPPELS)"
	@echo " Installation terminée."
	@echo "   Lancez l'application avec : make run"

# ── Lancement ─────────────────────────────────────────────────────────────────
run:
	@echo "==> Lancement de TO DO LIST..."
	@bash "$(TODO)"

# ── Activation cron (toutes les minutes) ──────────────────────────────────────
cron:
	@echo "==> Activation des rappels automatiques (toutes les minutes)..."
	@(crontab -l 2>/dev/null | grep -v "rappels.sh"; \
	  echo "* * * * * /bin/bash $(RAPPELS) >> $(LOG) 2>&1") | crontab -
	@echo " Cron activé : rappels.sh tourne toutes les minutes."
	@echo "   Logs visibles dans : $(LOG)"
	@echo "   Vérifiez avec     : crontab -l"

# ── Désactivation cron ────────────────────────────────────────────────────────
uncron:
	@echo "==> Désactivation des rappels automatiques..."
	@crontab -l 2>/dev/null | grep -v "rappels.sh" | crontab -
	@echo " Cron désactivé."

# ── Nettoyage des données ─────────────────────────────────────────────────────
clean:
	@echo "==> Suppression des données..."
	@rm -f "$(SCRIPT_DIR)/taches.txt"
	@rm -f "$(SCRIPT_DIR)/historique.log"
	@rm -f "$(SCRIPT_DIR)/cron.log"
	@rm -f "$(SCRIPT_DIR)"/export_taches_*.csv
	@rm -rf "$(SCRIPT_DIR)/sub-tasks"
	@echo " Données supprimées."

# ── Désinstallation complète ──────────────────────────────────────────────────
uninstall: clean uncron
	@echo " Désinstallation terminée."
