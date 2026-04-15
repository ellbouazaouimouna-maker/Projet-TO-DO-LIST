# Variables
SCRIPT_PRINCIPAL = todo.sh
SCRIPT_RAPPEL = rappels.sh
CRON_JOB = "0 9 * * * /bin/bash $(PWD)/$(SCRIPT_RAPPEL)"

all: install

install:
	@echo "Installation des dépendances Zenity..."
	sudo apt-get update && sudo apt-get install -y zenity
	@echo "Attribution des droits d'exécution..."
	chmod +x $(SCRIPT_PRINCIPAL)
	chmod +x $(SCRIPT_RAPPEL)
	@echo "Installation terminée. Tapez 'make run' pour lancer l'application."

run:
	./$(SCRIPT_PRINCIPAL)

cron:
	@echo "Ajout du rappel dans crontab (exécution tous les jours à 09h00)..."
	(crontab -l 2>/dev/null; echo $(CRON_JOB)) | crontab -
	@echo "Cron job ajouté !"

clean:
	@echo "Suppression des données et historiques..."
	rm -f taches.txt historique.log
