# Système de Gestion TO DO List
**Projet : Mini Projet Shell | AIAC — Génie Informatique (GI1)**

---

## Table des matières
1. [Architecture du projet](#1-architecture-du-projet)
2. [Choix d'implémentation](#2-choix-dimplémentation)
3. [Description des composants](#3-description-des-composants)
4. [Commandes supportées](#4-commandes-supportées)
5. [Flux de données](#5-flux-de-données)

---

## 1. Architecture du projet

```
projet-todo/
├── todo.sh              # Script principal — interface graphique Zenity
├── rappels.sh           # Script de rappels automatiques via cron
├── Makefile             # Automatisation : install, run, cron, clean
├── taches.txt           # Base de données principale (format CSV pipe-separated)
├── historique.log       # Journal horodaté de toutes les actions
├── sub-tasks/           # Dossier de liens entre tâches et sous-tâches
│   └── parent_N.txt     # Liste des IDs de sous-tâches du parent N
├── README.md            # Architecture et choix techniques (ce fichier)
└── MANUAL.md            # Manuel utilisateur
```

---

## 2. Choix d'implémentation

### Shell Bash pur
Le projet est entièrement développé en **Bash** sans aucun langage externe (Python, Perl, etc.). Ce choix garantit la portabilité sur tout système Linux/Unix disposant de Bash 4+, sans installation de runtime supplémentaire.

### Interface graphique Zenity
**Zenity** est une bibliothèque GTK permettant de créer des boîtes de dialogue graphiques depuis un script shell. Elle est choisie car :
- Nativement disponible sur Ubuntu/GNOME
- Supporte les formulaires, listes, sélecteurs de fichiers, calendriers
- Légère et simple à intégrer dans Bash

### Format de stockage pipe-separated (`|`)
Le fichier `taches.txt` utilise `|` comme séparateur au lieu de la virgule (CSV standard) pour éviter les conflits avec les virgules présentes dans les titres et descriptions. Le parsing se fait nativement avec `IFS='|' read` ou `awk -F'|'`.

### IDs auto-incrémentés
Les identifiants sont générés automatiquement en lisant le dernier ID du fichier et en ajoutant 1. Cette approche est simple, sans risque de collision dans un usage mono-utilisateur.

### Sous-tâches par fichiers de liaison
Chaque tâche parente dispose d'un fichier `sub-tasks/parent_N.txt` listant les IDs de ses sous-tâches. Cette structure permet une suppression en cascade efficace sans parcourir tout le fichier principal.

### Historique textuel horodaté
Chaque action (ajout, modification, suppression, export, import) est enregistrée dans `historique.log` avec le format :
```
[YYYY-MM-DD HH:MM:SS] utilisateur - ACTION détails
```
Cela permet une traçabilité complète sans base de données.

### Rappels via cron + notify-send
Les notifications d'échéance sont gérées par `rappels.sh`, planifié via **cron** (exécution quotidienne à 09h00). `notify-send` affiche une notification système native (bulle de notification Ubuntu), compatible avec l'environnement GNOME/X11.

---

## 3. Description des composants

### `todo.sh` — Script principal

| Fonction | Rôle |
|---|---|
| `zenity_safe()` | Encapsule zenity en masquant les erreurs Mesa/EGL |
| `log_action()` | Écrit une entrée horodatée dans `historique.log` |
| `generer_id()` | Calcule le prochain ID disponible |
| `tache_existe()` | Vérifie si un ID existe dans `taches.txt` |
| `ajouter_tache()` | Formulaire d'ajout avec validation date et ID parent |
| `afficher_taches()` | Affichage avec filtres statut/priorité |
| `modifier_tache()` | Édition d'une tâche existante avec traçage des changements |
| `supprimer_tache()` | Suppression avec cascade sur les sous-tâches |
| `afficher_sous_taches()` | Affichage hiérarchique des sous-tâches d'un parent |
| `exporter_csv()` | Copie horodatée de `taches.txt` |
| `importer_csv()` | Import depuis fichier CSV externe |
| `afficher_historique()` | Affiche les 50 dernières entrées du journal |
| `afficher_aide()` | Documentation intégrée complète |

### `rappels.sh` — Notifications cron

Parcourt `taches.txt` ligne par ligne. Pour chaque tâche dont l'échéance correspond à la date du jour et dont le statut n'est pas "Terminé", envoie une notification critique via `notify-send`.

### `Makefile` — Automatisation

| Cible | Action |
|---|---|
| `make install` | Installe zenity + libnotify-bin, initialise les fichiers |
| `make run` | Lance `todo.sh` |
| `make cron` | Installe le rappel quotidien dans crontab |
| `make uncron` | Supprime le rappel cron |
| `make clean` | Supprime les données (taches.txt, historique.log, exports) |
| `make uninstall` | Nettoyage complet + suppression cron |
| `make help` | Affiche l'aide Makefile |

---

## 4. Commandes supportées

Toutes les commandes sont accessibles via le **menu graphique** de `todo.sh` :

| Action | Description |
|---|---|
| Afficher les tâches | Liste avec filtre statut ou priorité |
| Ajouter une tâche | Formulaire complet avec validation |
| Modifier une tâche | Édition par ID, conservation des champs non modifiés |
| Supprimer une tâche | Suppression avec confirmation et cascade sous-tâches |
| Voir les sous-tâches | Affichage hiérarchique par tâche parente |
| Exporter en CSV | Export horodaté dans le dossier courant |
| Importer depuis CSV | Import via explorateur de fichiers |
| Historique | Journal des 50 dernières actions |
| Aide | Documentation intégrée |
| Quitter | Ferme l'application |

---

## 5. Flux de données

```
Utilisateur
    │
    ▼
[todo.sh] ──────────────────────────────────────────┐
    │                                               │
    ├── Lecture/Écriture ──► taches.txt             │
    │                        (base de données)      │
    │                                               │
    ├── Écriture ──────────► historique.log         │
    │                        (traçabilité)          │
    │                                               │
    ├── Lecture/Écriture ──► sub-tasks/parent_N.txt │
    │                        (liens sous-tâches)    │
    │                                               │
    └── Export ────────────► export_taches_*.csv    │
                                                    │
[rappels.sh] ◄── cron (09h00) ──────────────────────┘
    │
    ├── Lecture ───────────► taches.txt
    │
    └── notify-send ───────► Notification système Ubuntu
```
