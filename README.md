### 🦊 Firefox Remote GUI over Web (Docker + noVNC + Caddy)

Ce projet permet de **lancer un navigateur Firefox dans un environnement graphique complet sur un VPS**, et d’y accéder **depuis un navigateur web** à l’adresse :

```
http://<IP-VPS>:6667/
```

---

### 📦 Contenu du projet

- **Docker Compose** : orchestration automatique des services
- **Container XFCE + Firefox + VNC + noVNC** :
  - XFCE = environnement de bureau léger
  - Firefox = navigateur utilisable
  - VNC = serveur de bureau distant
  - noVNC = client HTML5 dans le navigateur
- **Caddy** : reverse proxy HTTP sur le port 6667

---

### 🌐 Accès

Une fois démarré :

```
http://<ton-ip-vps>:6667/
```

Cela ouvre une **interface graphique distante avec Firefox**.

---

### 🧠 Définitions

#### 🖥️ VNC (Virtual Network Computing)

Protocole qui permet de **voir et contrôler à distance un environnement graphique** (bureau Linux). Il fonctionne généralement via un port TCP comme 5901.

#### 🌍 noVNC

Un **client VNC en HTML5**. Il permet de **se connecter au serveur VNC via un navigateur web**, sans logiciel natif.

Il utilise un **WebSocket (`ws://` ou `wss://`)** pour convertir le flux VNC en flux web interactif via un proxy nommé `websockify`.

#### 🧰 Caddy

Un serveur web et reverse proxy qui :

- Sert l’interface web à l’URL `http://<IP>:6667`
- Redirige le trafic vers le conteneur Firefox/noVNC
- Peut gérer automatiquement le HTTPS (non activé ici, mais prévu facilement)

---

### ▶️ Démarrer le projet

```
docker-compose up -d
```

Puis ouvre :

```
http://<IP-VPS>:6667/
```

---

### 🔐 Sécurité

Pour renforcer la sécurité réseau, active le pare-feu pour n’ouvrir que les ports nécessaires :

```
sudo apt install ufw -y
sudo ufw allow 22       # SSH
sudo ufw allow 6667     # Accès Web distant
sudo ufw enable
```

Cela bloque tous les autres ports (ex : 5901, 6080) qui sont utilisés en interne uniquement via Docker, ce qui réduit drastiquement la surface d’attaque.

---

### ✅ Prochaines étapes possibles

- Ajouter un nom de domaine + HTTPS automatique avec Caddy
- Ajouter une authentification par mot de passe et des check regulier de token
- Démarrer Firefox sur une URL spécifique
- Crypter le flux par dessus le TLS
