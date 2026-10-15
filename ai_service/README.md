# Service d'Extraction IA - LogiTech ERP

Ce microservice Python connecte l'application **LogiTech ERP** (Desktop Windows, Android, Web) au modèle d'intelligence artificielle développé par votre ami pour l'extraction automatique des factures, bons de commande fournisseur, bons de réception et inventaires.

---

## 🚀 Démarrage Rapide

### Option 1 : Double-clic (Windows)
Double-cliquez simplement sur le fichier :
```
ai_service/start_service.bat
```

### Option 2 : En ligne de commande
```bash
cd ai_service
pip install -r requirements.txt
python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

Le service sera disponible sur :
- **API URL** : `http://localhost:8000`
- **Documentation interactive Swagger** : `http://localhost:8000/docs`
- **Vérification d'état** : `http://localhost:8000/health`

---

## 🔑 Intégration du modèle IA de votre ami

Pour lier le modèle de votre ami :

1. Ouvrez le fichier `ai_service/.env`
2. Remplissez les paramètres fournis par votre ami :

```env
# L'adresse API où son modèle est hébergé
AI_MODEL_URL=https://api.son-serveur.com/v1/predict

# La clé ou le token d'accès secret qu'il vous a donné
AI_MODEL_API_KEY=votre_cle_secrete_ici

# Type d'autorisation (Bearer ou Api-Key)
AI_AUTH_TYPE=Bearer
```

3. Redémarrez le service (ou sauvegardez simplement le fichier, le rechargement est automatique).

> **Remarque importante** : Tant que le fichier `.env` n'a pas encore l'URL de votre ami, le service fonctionne quand même avec des données intelligentes de secours (Fallback), ce qui vous permet de tester immédiatement toute l'interface sans aucun blocage !

---

## 🧪 Tester le service

Pour vérifier que tout fonctionne :
```bash
python ai_service/test_client.py
```
