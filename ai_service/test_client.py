"""
Script de test pour vérifier :
1. La vérification du type de fichier image
2. La réponse avec statut "OK"
3. Le texte prêt pour l'OCR et le petit LLM
Usage: python test_client.py
"""
import sys
import httpx

SERVER_URL = "http://127.0.0.1:8000"

def test_service():
    print(f"--> [1/3] Test de connexion vers {SERVER_URL}...")
    try:
        r = httpx.get(f"{SERVER_URL}/health", timeout=5.0)
        print(f"Statut Health: {r.status_code}")
        print(f"Reponse: {r.json()}\n")
    except Exception as e:
        print(f"[ERREUR] Impossible de joindre le serveur. Lancez 'start_service.bat' d'abord.")
        print(f"Detail: {e}")
        return

    print("--> [2/3] Test d'envoi d'une image valide (PNG) avec verification du type...")
    # Signature PNG binaire reelle
    png_bytes = b'\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15c4'
    files = [
        ("files", ("facture_scan.png", png_bytes, "image/png"))
    ]
    data = {"document_type": "facture d'achat"}
    try:
        r = httpx.post(f"{SERVER_URL}/api/scan", files=files, data=data, timeout=10.0)
        print(f"Statut HTTP : {r.status_code}")
        resp = r.json()
        print(f"Statut IA   : {resp.get('status')} (Doit etre OK)")
        print(f"Message     : {resp.get('message')}")
        print(f"Texte pour l'app :\n{'-'*40}\n{resp.get('text_response')}\n{'-'*40}")
        print(f"Total TTC   : {resp.get('extracted_data', {}).get('total_ttc')} TND")
        print(f"Articles    : {len(resp.get('extracted_data', {}).get('items', []))}")
    except Exception as e:
        print(f"[ERREUR] Lors du scan image valide: {e}")

    print("\n--> [3/3] Test de rejet d'un fichier NON-IMAGE (securite type)...")
    fake_file = [
        ("files", ("document_dangereux.exe", b"MZ\x90\x00\x03\x00\x00\x00", "application/octet-stream"))
    ]
    try:
        r = httpx.post(f"{SERVER_URL}/api/scan", files=fake_file, data=data, timeout=10.0)
        print(f"Statut HTTP (Attendu 400): {r.status_code}")
        print(f"Message de rejet: {r.json().get('detail')}")
        if r.status_code == 400:
            print("[OK] Le controle de type d'image fonctionne parfaitement !")
    except Exception as e:
        print(f"[ERREUR] Lors du test de rejet: {e}")

if __name__ == "__main__":
    test_service()
