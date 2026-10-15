"""
=============================================================================
LogiTech ERP - Pipeline OCR & Small LLM (Pour votre ami développeur)
=============================================================================
Ce script Python montre exactement comment :
1. Recevoir une image depuis l'application.
2. Vérifier que c'est bien une image (JPEG, PNG, WebP, etc.).
3. Renvoyer "OK" à l'application.
4. Intégrer votre modèle OCR pour extraire tout le texte brut.
5. Passer le texte à un petit LLM (Ollama, HuggingFace, etc.) pour extraire
   chaque partie (fournisseur, articles, prix, TVA, totaux).
6. Renvoyer le résultat dans un champ de texte de l'application.
=============================================================================
"""

import os
import io
from typing import Dict, Any

# ===========================================================================
# ÉTAPE 1 : Vérification que le fichier est bien une image
# ===========================================================================
def verify_image(filename: str, file_bytes: bytes) -> tuple[bool, str]:
    """
    Vérifie l'extension et les magic bytes pour s'assurer que c'est une image valide.
    """
    if not file_bytes or len(file_bytes) < 4:
        return False, "Fichier vide"

    # Vérification des signatures binaires
    is_jpeg = file_bytes.startswith(b'\xff\xd8\xff')
    is_png = file_bytes.startswith(b'\x89PNG\r\n\x1a\n')
    is_webp = file_bytes.startswith(b'RIFF') and b'WEBP' in file_bytes[:16]
    is_bmp = file_bytes.startswith(b'BM')
    is_pdf = file_bytes.startswith(b'%PDF')

    if is_jpeg or is_png or is_webp or is_bmp or is_pdf:
        return True, "OK"
    
    return False, "Type de fichier invalide (pas une image reconnue)"


# ===========================================================================
# ÉTAPE 2 : Modèle OCR (Insérez votre modèle OCR ici)
# ===========================================================================
def extract_text_with_ocr(image_bytes: bytes) -> str:
    """
    TODO (Votre Ami) : Branchez ici votre modèle OCR.
    Exemples de modèles OCR populaires en Python :
    - PaddleOCR (rapide et précis pour les factures) :
        from paddleocr import PaddleOCR
        ocr = PaddleOCR(use_angle_cls=True, lang='fr')
        result = ocr.ocr(image_bytes)
    - EasyOCR :
        import easyocr
        reader = easyocr.Reader(['fr', 'en'])
        result = reader.readtext(image_bytes)
    - Tesseract :
        import pytesseract
        from PIL import Image
        text = pytesseract.image_to_string(Image.open(io.BytesIO(image_bytes)))
    """
    # Exemple de texte simulé en attendant votre modèle :
    ocr_raw_text = (
        "FACTURE N° FAC-2026-0042\n"
        "Date : 28/09/2026\n"
        "Fournisseur : STE PRO DISTRIBUTION TUNISIE\n"
        "Matricule Fiscal : 0987654/C/A/M/000\n"
        "Articles :\n"
        "- 10x Souris Optique USB Sans Fil @ 25.000 TND (TVA 19%)\n"
        "- 4x Clavier Ergonomique @ 65.000 TND (TVA 19%)\n"
        "Total HT : 510.000 TND\n"
        "TVA : 96.900 TND\n"
        "Timbre fiscal : 1.000 TND\n"
        "Net à Payer TTC : 607.900 TND"
    )
    return ocr_raw_text


# ===========================================================================
# ÉTAPE 3 : Petit LLM (Insérez votre LLM ici)
# ===========================================================================
def parse_with_small_llm(ocr_text: str) -> Dict[str, Any]:
    """
    TODO (Votre Ami) : Branchez ici votre petit LLM.
    Exemples de petits modèles locaux idéaux :
    - Ollama (Qwen2.5:3b, Llama-3.2:3b, Phi-3.5:mini) :
        import requests
        res = requests.post("http://localhost:11434/api/generate", json={
            "model": "qwen2.5:3b",
            "prompt": f"Extraire les informations en JSON : {ocr_text}",
            "stream": False
        })
    - Transformers / vLLM / HuggingFace :
        tokenizer & model.generate(...)
    """
    # Structure de données renvoyée à l'application ERP :
    return {
        "status": "OK",
        "document_number": "FAC-2026-0042",
        "supplier_name": "STE PRO DISTRIBUTION TUNISIE",
        "total_ht": 510.000,
        "total_tva": 96.900,
        "total_ttc": 607.900,
        "items": [
            {"name": "Souris Optique USB Sans Fil", "qty": 10, "price": 25.000},
            {"name": "Clavier Ergonomique", "qty": 4, "price": 65.000}
        ]
    }


# ===========================================================================
# Point d'entrée pour tester directement
# ===========================================================================
if __name__ == "__main__":
    print("\n--- Test du Pipeline Image -> OCR -> LLM -> ERP ---")
    
    # Simulation d'un fichier image PNG reçu de l'app
    sample_image = b'\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR...'
    filename = "facture_client.png"

    # 1. Vérification du type
    is_valid, status = verify_image(filename, sample_image)
    print(f"1. Verification du type d'image : {status} (Valide={is_valid})")

    if is_valid:
        # 2. Extraction OCR
        print("2. Extraction OCR en cours...")
        raw_text = extract_text_with_ocr(sample_image)
        print(f"   Texte extrait :\n{raw_text}\n")

        # 3. Traitement par le petit LLM
        print("3. Analyse par le petit LLM...")
        structured_data = parse_with_small_llm(raw_text)
        print(f"   Resultat structure : {structured_data}\n")

        # 4. Message de reponse renvoye a l'application
        app_text_field = f"OK\n{raw_text}"
        print(f"4. Texte final envoye dans le champ de l'application :\n{app_text_field}")
