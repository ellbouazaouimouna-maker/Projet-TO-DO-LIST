#  Système de Gestion TODO List

## Architecture
- **Stockage** : Fichier `tasks.txt` (format CSV: ID|Status|Priority|Task|Date)
- **Historique** : `history.log` pour traçabilité
- **Sous-tâches** : Dossier `sub-tasks/` avec un fichier par tâche

## Choix d'implémentation
- **Shell pur** : Portable, léger, pas de dépendances
- **Format pipe-separated** : Simple parsing avec `read`
- **IDs auto-incrémentés** : Gestion simple des identifiants
- **Couleurs ANSI** : Interface utilisateur améliorée

## Installation
\`\`\`bash
make install
\`\`\`

## Utilisation
\`\`\`bash
todo help
todo add "Acheter du lait" HIGH "2024-12-25"
todo list
\`\`\`
