# Système de Gestion TO DO List

## Mini Projet Shell – AIAC | Génie Informatique (GI22)

### Présentation

TO DO List est une application de gestion de tâches développée entièrement en Bash avec une interface graphique basée sur Zenity. Elle permet aux utilisateurs de créer, organiser par ordre numerique(ID) ou alphabetique (Titre) ou par priorite (Haute,moyenne,basse) leurs taches et suivre leurs tâches quotidiennes grâce à une interface simple, intuitive et portable sur les systèmes Linux.

Le projet a été conçu dans le respect des contraintes du module Shell Programming, sans recours à des langages externes tels que Python ou Java.

---

# Architecture du Projet

```
projet-todo/
├── todo.sh                
├── rappels.sh             
├── Makefile               
├── taches.txt             
├── taches_supprime.txt   
├── historique.log        
├── notifications.cfg      
├── sub-tasks/
│   └── parent_N.txt      
├── README.md              
└── MANUAL.md              
```

---

# Choix d'Implémentation

## Bash Pur

L'application est entièrement développée en Shell Bash afin de garantir :

* Une grande portabilité.
* Une faible consommation de ressources.
* Aucune dépendance à un langage externe.

## Interface Graphique Zenity

Zenity permet de créer des interfaces graphiques GTK directement depuis Bash.

Elle est utilisée pour :

* Les formulaires de saisie.
* Les listes de tâches.
* Les calendriers.
* Les boîtes de dialogue.
* Les messages d'information et d'erreur.

## Stockage des Données

Les tâches sont stockées dans un fichier texte utilisant le séparateur :

```
|
```

Exemple :

```
1|Rapport IA|Finaliser le rapport|En cours|Haute|2026-06-20 18:00||
```

Ce format facilite la lecture et le traitement avec Bash et AWK.

## Gestion des Identifiants

Chaque tâche reçoit automatiquement un identifiant unique généré à partir du plus grand ID existant.

## Gestion des Sous-Tâches

Les relations entre tâches parentes et sous-tâches sont enregistrées dans des fichiers dédiés :

```
sub-tasks/parent_3.txt
```

Cette approche permet une suppression et une restauration efficaces.

---

# Fonctionnalités Principales

## Gestion des tâches

* Ajout d'une tâche.
* Modification d'une tâche.
* Suppression d'une tâche.
* Restauration d'une tâche supprimée.
* Affichage des tâches tries par ordre choisi par l'utilisateur.
* Gestion des sous-tâches.

## Gestion des priorités

Chaque tâche peut être définie avec :

* Haute priorité
* Moyenne priorité
* Basse priorité

## Gestion des statuts

Les statuts disponibles sont :

* En attente
* En cours
* Terminé
* En retard

---

# Nouvelles Fonctionnalités Ajoutées

## Corbeille et Restauration

Les tâches supprimées ne sont plus perdues définitivement.

Elles sont déplacées vers :

```
taches_supprime.txt
```

L'utilisateur peut :

* Consulter les tâches supprimées.
* Restaurer une tâche supprimée.
* Restaurer automatiquement les liens parent/enfant.

Cette fonctionnalité réduit fortement le risque de perte accidentelle de données.

---

## Notifications Personnalisées

Lors de la création ou de la modification d'une tâche, l'utilisateur peut définir :

* Une ou plusieurs dates de rappel.
* Une heure précise pour chaque rappel.

Exemple :

```
2026-06-18 14:30
2026-06-19 09:00
2026-06-20 08:00
```

Des vérifications garantissent que :

* La date est valide.
* Elle est dans le futur.
* Elle est antérieure à l'échéance.
* Aucun doublon n'existe.

---

## Notifications Globales

Un fichier :

```
notifications.cfg
```

permet de configurer les rappels automatiques :

* 1 heure avant l'échéance.
* 30 minutes avant l'échéance.
* 10 minutes avant l'échéance.
* À l'heure exacte.
* Popup à l'expiration.

L'utilisateur peut activer ou désactiver chaque option via l'interface graphique.

---

## Détection Automatique des Tâches Expirées

À chaque démarrage de l'application :

* Les tâches dont l'échéance est dépassée sont détectées.
* Un popup demande si la tâche est terminée.
* Sinon elle est automatiquement marquée "En retard".

Cela permet un suivi plus réaliste de l'avancement du travail.

---

## Historique et Traçabilité

Chaque opération est enregistrée dans :

```
historique.log
```

Format :

```
[2026-06-20 14:30:12] mouna - AJOUT tâche ID=12
```

Les opérations journalisées :

* Ajout
* Modification
* Suppression
* Restauration
* Import
* Export
* Changement de configuration

---

# Description des Composants

## todo.sh

Script principal contenant :

| Fonction                   | Description                      |
| -------------------------- | -------------------------------- |
| zenity_safe()              | Gestion sécurisée de Zenity      |
| log_action()               | Journalisation                   |
| generer_id()               | Génération d'identifiants        |
| ajouter_tache()            | Création de tâches               |
| modifier_tache()           | Modification                     |
| supprimer_tache()          | Mise en corbeille                |
| restaurer_tache()          | Récupération depuis la corbeille |
| afficher_taches()          | Affichage et filtrage            |
| afficher_sous_taches()     | Vue hiérarchique                 |
| configurer_notifications() | Paramétrage des rappels          |
| afficher_historique()      | Consultation du journal          |

---

## rappels.sh

Responsable des notifications système.

Fonctionnement :

1. Lecture de taches.txt
2. Vérification des échéances
3. Déclenchement des notifications
4. Affichage via notify-send

---

## Makefile

| Commande       | Action                                |
| -------------- | ------------------------------------- |
| make install   | Installation et initialisation        |
| make run       | Lancement de l'application            |
| make cron      | Installation des rappels automatiques |
| make uncron    | Suppression du cron                   |
| make clean     | Nettoyage des données                 |
| make uninstall | Désinstallation complète              |
| make help      | Affichage de l'aide                   |

---

# Flux de Données

```
Utilisateur =>todo.sh =>taches.txt =>hisstorique.log =>taches_supprime.txt 
    
```

---

# Conclusion

Ce projet démontre qu'il est possible de réaliser une application complète de gestion de tâches en Shell Bash tout en proposant une interface graphique moderne, une gestion avancée des notifications, une corbeille avec restauration, un historique détaillé et une organisation hiérarchique des tâches.

L'ensemble respecte les contraintes pédagogiques du module tout en apportant des fonctionnalités généralement présentes dans des applications professionnelles de gestion de tâches.
