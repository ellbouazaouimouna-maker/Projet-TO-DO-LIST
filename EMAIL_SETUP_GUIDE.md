# 📧 Guide Complet — Configuration des Emails et Notifications

## Projet TO DO LIST — Version 5.0

---

## 🔔 NOUVEAUTÉS DE LA VERSION 5.0

### 1. Notifications Configurables
L'utilisateur peut maintenant choisir **quels rappels activer** :
- ⏰ 1 heure avant l'échéance
- ⚠️ 30 minutes avant l'échéance
- 🔔 10 minutes avant l'échéance
- 🚨 À l'heure exacte de l'échéance

**Menu :** `🔔 Configurer Notifications` dans l'application.

### 2. Popup à l'Échéance (NOUVEAU !)
Quand une tâche dépasse son échéance, un **popup s'affiche** au démarrage de l'application demandant :
- **✅ Terminée** → Statut passe à "Terminé"
- **❌ En retard** → Statut passe à "En retard"

Vous pouvez désactiver ce popup dans `🔔 Configurer Notifications`.

---

## 📧 ÉTAPE PAR ÉTAPE : CONFIGURATION DES EMAILS

### ÉTAPE 1 — INSTALLER MAILUTILS

Ouvrez un terminal et exécutez :

```bash
sudo apt update
sudo apt install mailutils
```

Cela installe la commande `mail` utilisée par le script de rappels.

> 💡 **Alternative légère** : Vous pouvez aussi utiliser `bsd-mailx` :
> ```bash
> sudo apt install bsd-mailx
> ```

---

### ÉTAPE 2 — CHOISIR UN AGENT DE TRANSFERT (MTA)

Pendant l'installation de `mailutils`, une fenêtre s'affiche vous demandant de choisir la configuration de **Postfix**. Options :

| Option | Quand l'utiliser |
|---|---|
| **Internet Site** | Vous avez un nom de domaine fixe |
| **Internet with smarthost** | Vous utilisez un serveur SMTP externe (recommandé) |
| **Satellite system** | Vous envoyez via un autre serveur |
| **Local only** | Emails internes uniquement |

**Recommandation pour Gmail / Outlook :** Choisissez **"Internet with smarthost"** ou configurez `ssmtp` (voir Étape 3).

---

### ÉTAPE 3 — CONFIGURER SSMTP (RECOMMANDÉ POUR GMAIL / OUTLOOK)

SSMTP est plus simple que Postfix pour l'envoi via un compte email existant.

#### 3.1 Installer ssmtp

```bash
sudo apt install ssmtp
```

#### 3.2 Configurer ssmtp

Éditez le fichier de configuration :

```bash
sudo nano /etc/ssmtp/ssmtp.conf
```

**Exemple pour Gmail :**

```ini
root=votre_email@gmail.com
mailhub=smtp.gmail.com:587
AuthUser=votre_email@gmail.com
AuthPass=VOTRE_MOT_DE_PASSE_APPLICATION
UseSTARTTLS=YES
UseTLS=YES
hostname=localhost
FromLineOverride=YES
```

**Exemple pour Outlook / Hotmail :**

```ini
root=votre_email@outlook.com
mailhub=smtp-mail.outlook.com:587
AuthUser=votre_email@outlook.com
AuthPass=VOTRE_MOT_DE_PASSE
UseSTARTTLS=YES
UseTLS=YES
hostname=localhost
FromLineOverride=YES
```

---

### ⚠️ IMPORTANT : MOT DE PASSE D'APPLICATION (GMAIL)

Pour Gmail, vous **NE POUVEZ PAS** utiliser votre mot de passe principal. Vous devez créer un **"Mot de passe d'application"** (App Password) :

1. Allez sur : https://myaccount.google.com/apppasswords
2. Connectez-vous avec votre compte Google
3. Dans "Sélectionner l'application", choisissez **"Mail"**
4. Dans "Sélectionner l'appareil", choisissez **"Ordinateur Linux"**
5. Cliquez sur **Générer**
6. Copiez le mot de passe à 16 caractères (ex: `abcd efgh ijkl mnop`)
7. Collez-le dans `ssmtp.conf` (sans espaces : `abcdefghijklmnop`)

> 🔒 **Pourquoi ?** Gmail bloque les connexions "moins sécurisées". Le mot de passe d'application contourne cette restriction.

---

### ÉTAPE 4 — TESTER L'ENVOI D'EMAIL

Dans un terminal, testez avec :

```bash
echo "Ceci est un test de l'application TO DO LIST" | mail -s "Test Email" votre_email@gmail.com
```

Vérifiez votre boîte de réception (et le dossier **Spam/Pourriels**).

**Si ça ne marche pas, vérifiez les logs :**

```bash
# Voir les logs de mail
cat /var/log/mail.log

# Ou tester avec verbose
mail -v -s "Test" votre_email@gmail.com <<< "Test"
```

---

### ÉTAPE 5 — CONFIGURER L'APPLICATION TO DO LIST

1. Lancez l'application : `./todo.sh` ou `make run`
2. Dans le menu principal, sélectionnez : **"📧 Configurer Email Rappels"**
3. Entrez votre adresse email
4. Sélectionnez **"oui"** pour activer les rappels
5. Cliquez **OK**

La configuration est sauvegardée dans `config.cfg`.

---

### ÉTAPE 6 — INSTALLER LE CRON (RAPPELS AUTOMATIQUES)

Le script `rappels.sh` doit s'exécuter **toutes les minutes** pour vérifier les échéances.

#### Option A : Via le Makefile (recommandé)

```bash
make cron
```

#### Option B : Manuellement

```bash
crontab -e
```

Ajoutez cette ligne (adaptez le chemin) :

```cron
* * * * * /bin/bash /chemin/complet/vers/rappels.sh >> /chemin/complet/vers/cron.log 2>&1
```

**Exemple concret :**

```cron
* * * * * /bin/bash /home/hamza/Projet-TO-DO-LIST/rappels.sh >> /home/hamza/Projet-TO-DO-LIST/cron.log 2>&1
```

#### Vérifier que le cron est installé :

```bash
crontab -l
```

Vous devriez voir la ligne ci-dessus.

---

## 🔧 DÉPANNAGE DES EMAILS

| Problème | Cause probable | Solution |
|---|---|---|
| `commande 'mail' introuvable` | `mailutils` non installé | `sudo apt install mailutils` |
| Email non reçu | Dans les spams | Vérifiez le dossier Spam |
| `Authorization failed` | Mauvais login/mot de passe | Vérifiez `ssmtp.conf` |
| `Connection refused` | Mauvais serveur SMTP | Vérifiez `mailhub` dans `ssmtp.conf` |
| Gmail bloque la connexion | Mot de passe principal utilisé | Utilisez un **App Password** |
| `send-mail: Cannot open mailhub:25` | Port SMTP bloqué | Utilisez le port 587 avec TLS |
| Erreur `DISPLAY` | Cron n'a pas accès à l'affichage | `export DISPLAY=:0` dans `rappels.sh` (déjà fait) |

---

## 📁 FICHIERS DE CONFIGURATION

### `config.cfg` — Configuration Email

```ini
EMAIL_ACTIF=true
EMAIL_DESTINATAIRE=votre_email@gmail.com
```

### `notifications.cfg` — Configuration des Rappels (NOUVEAU)

```ini
NOTIF_1H=true
NOTIF_30MIN=true
NOTIF_10MIN=true
NOTIF_EXACT=true
POPUP_DEADLINE=true
```

- `true` = activé
- `false` = désactivé

---

## 🔄 RÉCAPITULATIF DU FLUX COMPLET

```
┌─────────────────┐
│  Ajouter tâche  │  ← Vous définissez l'échéance (date + heure)
│  dans todo.sh   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  rappels.sh     │  ← Exécuté toutes les minutes par cron
│  (cron job)     │
└────────┬────────┘
         │
    ┌────┴────┬────────┬────────┬────────┐
    ▼         ▼        ▼        ▼        ▼
  1h avant  30min    10min   Heure    Expiré
  (notif)   (notif)  (notif) exacte   (popup)
    │         │        │        │        │
    ▼         ▼        ▼        ▼        ▼
 notify-  notify-  notify-  notify-  zenity
  send     send     send     send    popup
    │         │        │        │    (dans todo.sh)
    ▼         ▼        ▼        ▼        ▼
  email    email    email    email   email
    │         │        │        │        │
    └─────────┴────────┴────────┴────────┘
              │
              ▼
    ┌─────────────────┐
    │  Votre boîte    │  ← Vous recevez les rappels !
    │  mail + bureau  │
    └─────────────────┘
```

---

## 📝 NOTES IMPORTANTES

1. **Session graphique requise** : Les notifications `notify-send` ne fonctionnent que si vous êtes connecté à un bureau Ubuntu (GNOME/X11). Elles ne fonctionnent pas en SSH sans X11 forwarding.

2. **Cron et environnement** : Le script `rappels.sh` contient déjà `export DISPLAY=:0` et `export DBUS_SESSION_BUS_ADDRESS` pour que les notifications fonctionnent depuis cron.

3. **Fréquence du cron** : `* * * * *` = toutes les minutes. C'est nécessaire pour détecter précisément les fenêtres de 10min/30min/1h. Si vous voulez moins de charge CPU, vous pouvez mettre `*/5 * * * *` (toutes les 5 minutes) mais vous risquez de manquer certains rappels.

4. **Sécurité** : Le fichier `ssmtp.conf` contient votre mot de passe en clair. Protégez-le :
   ```bash
   sudo chmod 640 /etc/ssmtp/ssmtp.conf
   sudo chown root:mail /etc/ssmtp/ssmtp.conf
   ```

---

**Version 5.0 — Projet TO DO LIST AIAC**
