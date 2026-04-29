# Manuel Utilisateur — Système de Gestion TO DO List
**Projet : Mini Projet Shell | AIAC — Génie Informatique**

---

## Table des matières
1. [Prérequis](#1-prérequis)
2. [Installation](#2-installation)
3. [Lancement de l'application](#3-lancement-de-lapplication)
4. [Fonctionnalités](#4-fonctionnalités)
5. [Format des données](#5-format-des-données)
6. [Rappels automatiques (cron)](#6-rappels-automatiques-cron)
7. [Fichiers du projet](#7-fichiers-du-projet)
8. [Dépannage](#8-dépannage)

---

## 1. Prérequis

| Élément | Requis |
|---|---|
| Système d'exploitation | Ubuntu 20.04+ (ou toute distro avec Zenity) |
| Shell | Bash 4.0+ |
| Interface graphique | Session X11 active |
| Paquet | `zenity`, `libnotify-bin` |

---

## 2. Installation

Ouvrez un terminal dans le dossier du projet et exécutez :

```bash
make install
```

Cette commande installe automatiquement `zenity` et attribue les droits d'exécution aux scripts.

Pour installer également le rappel automatique quotidien (09h00) :

```bash
make cron
```

---

## 3. Lancement de l'application

```bash
make run
```

Ou directement :

```bash
./todo.sh
```

L'interface graphique s'ouvre avec le menu principal.

---

## 4. Fonctionnalités

### 4.1 Afficher les tâches
Affiche toutes les tâches ou filtrées selon :
- **Statut** : En attente, En cours, Terminé
- **Priorité** : Haute, Moyenne, Basse

### 4.2 Ajouter une tâche
Remplissez le formulaire avec :
- **Titre** *(obligatoire)*
- **Description**
- **Statut** : En attente | En cours | Terminé
- **Priorité** : Haute | Moyenne | Basse
- **Échéance** : format `YYYY-MM-DD` (ex: `2025-05-15`)
- **ID Parent** : laisser vide pour une tâche principale, sinon indiquer l'ID d'une tâche existante pour créer une sous-tâche

### 4.3 Modifier une tâche
Entrez l'ID de la tâche à modifier. Les champs laissés vides conservent leur valeur actuelle. Toute modification est enregistrée dans l'historique.

### 4.4 Supprimer une tâche
Entrez l'ID de la tâche. Une confirmation est demandée. La suppression est en cascade : toutes les sous-tâches liées sont également supprimées.

### 4.5 Voir les sous-tâches
Entrez l'ID d'une tâche parente pour afficher toutes ses sous-tâches.

### 4.6 Exporter en CSV
Génère un fichier `export_taches_YYYYMMDD_HHMMSS.csv` dans le dossier courant.

### 4.7 Importer depuis CSV
Ouvre un explorateur de fichiers. Sélectionnez un fichier CSV au format compatible (voir section 5). Les tâches importées reçoivent de nouveaux IDs automatiquement.

### 4.8 Historique
Affiche les 50 dernières actions (ajouts, modifications, suppressions, exports) avec horodatage et utilisateur.

---

## 5. Format des données

### Fichier `taches.txt` (séparateur `|`)

```
ID|Titre|Description|Statut|Priorité|Echéance|ID_Parent
1|Préparer rapport|Rapport mensuel|En cours|Haute|2025-05-01|
2|Collecter données|Section statistiques|En attente|Moyenne|2025-04-30|1
```

| Champ | Description |
|---|---|
| ID | Entier auto-incrémenté |
| Titre | Nom court de la tâche |
| Description | Détail de la tâche |
| Statut | `En attente` / `En cours` / `Terminé` |
| Priorité | `Haute` / `Moyenne` / `Basse` |
| Echéance | Format `YYYY-MM-DD` |
| ID_Parent | ID d'une tâche parente (vide si tâche principale) |

### Fichier `historique.log`

```
[2025-04-29 09:15:32] brik - AJOUT tâche ID=1 Titre='Préparer rapport' ...
[2025-04-29 09:20:11] brik - MODIFICATION tâche ID=1 | Statut: 'En attente'→'En cours'
```

---

## 6. Rappels automatiques (cron)

Le script `rappels.sh` envoie une notification système (`notify-send`) pour chaque tâche non terminée dont l'échéance est aujourd'hui.

**Installation du cron :**
```bash
make cron
```

**Vérifier le cron installé :**
```bash
crontab -l
```

**Résultat attendu :**
```
0 9 * * * /bin/bash /chemin/vers/rappels.sh
```

> ⚠️ Le rappel nécessite une session graphique active. Il fonctionne uniquement si vous êtes connecté au bureau Ubuntu à 09h00.

---

## 7. Fichiers du projet

```
projet-todo/
├── todo.sh          # Script principal (interface graphique Zenity)
├── rappels.sh       # Script de rappels (notifications cron)
├── Makefile         # Installation, lancement, nettoyage
├── taches.txt       # Base de données des tâches (auto-créé)
├── historique.log   # Journal des actions (auto-créé)
├── sub-tasks/       # Liens sous-tâches par parent (auto-créé)
├── README.md        # Architecture et choix techniques
└── MANUAL.md        # Ce manuel
```

---

## 8. Dépannage

| Problème | Solution |
|---|---|
| `zenity: command not found` | Exécuter `make install` |
| Fenêtre ne s'ouvre pas | Vérifier que vous êtes en session graphique X11 |
| Notification cron absente | Vérifier `DISPLAY=:0` et que la session est active |
| Date invalide | Utiliser le format `YYYY-MM-DD` (ex: `2025-12-31`) |
| ID parent introuvable | Vérifier l'ID avec "Afficher les tâches" avant d'ajouter |
