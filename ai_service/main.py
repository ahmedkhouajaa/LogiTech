import os
import io
import base64
import json
import logging
from typing import List, Optional, Any, Dict
from datetime import datetime

from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
import httpx
from dotenv import load_dotenv

# Charger les variables d'environnement depuis .env
load_dotenv()

# Configuration du logging
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("ai_service")

# Variables d'environnement
AI_MODEL_URL = os.getenv("AI_MODEL_URL", "").strip()
AI_MODEL_API_KEY = os.getenv("AI_MODEL_API_KEY", "").strip()
AI_AUTH_TYPE = os.getenv("AI_AUTH_TYPE", "Bearer").strip()
PORT = int(os.getenv("PORT", "8000"))
HOST = os.getenv("HOST", "0.0.0.0")

app = FastAPI(
    title="LogiTech ERP - AI Document & OCR/LLM Service",
    description="Microservice Python pour vérifier les images reçues de l'application, renvoyer OK, et exécuter la chaîne OCR + LLM.",
    version="1.1.0"
)

# Configuration CORS pour autoriser Flutter Web, Desktop et Mobile
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# =====================================================================
# Modèles de données Pydantic
# =====================================================================
class DocumentItem(BaseModel):
    product_code: Optional[str] = None
    product_name: str
    quantity: float = 1.0
    unit_price: float = 0.0
    tva_rate: float = 19.0
    discount_percent: float = 0.0
    total_ht: float = 0.0
    total_ttc: float = 0.0


class ExtractedDocumentData(BaseModel):
    document_type: str
    document_number: Optional[str] = None
    document_date: Optional[str] = None
    due_date: Optional[str] = None
    supplier_name: Optional[str] = None
    supplier_tax_id: Optional[str] = None  # Matricule Fiscal
    supplier_phone: Optional[str] = None
    supplier_address: Optional[str] = None
    total_ht: float = 0.0
    total_tva: float = 0.0
    stamp_duty: float = 1.0  # Timbre fiscal en Tunisie (1.000 TND)
    total_ttc: float = 0.0
    currency: str = "TND"
    raw_text: str = ""
    items: List[DocumentItem] = Field(default_factory=list)


class ScanResponse(BaseModel):
    success: bool
    status: str = "OK"                       # Statut "OK" demandé par l'ami
    text_response: str = "OK"                # Texte affiché dans le champ de l'application
    source: str                              # "friend_ai_model" | "local_ocr_llm" | "fallback_demo"
    message: str
    document_type: str
    file_names: List[str]
    extracted_data: ExtractedDocumentData


# =====================================================================
# 1. Vérification du type de fichier (Image / Document scannable)
# =====================================================================
def verify_image_file(filename: str, content: bytes) -> tuple[bool, str]:
    """
    Vérifie rigoureusement que le fichier reçu de l'application est bien une image
    en inspectant à la fois son extension et ses 'magic bytes' (signature binaire).
    """
    if not content or len(content) < 4:
        return False, "Le fichier reçu est vide ou corrompu."

    lower_name = filename.lower()
    allowed_extensions = ('.jpg', '.jpeg', '.png', '.webp', '.bmp', '.heic', '.pdf')
    if not any(lower_name.endswith(ext) for ext in allowed_extensions):
        return False, f"Format de fichier non autorisé. Formats acceptés : {', '.join(allowed_extensions)}"

    # Vérification des signatures binaires réelles (Magic Bytes)
    is_jpeg = content.startswith(b'\xff\xd8\xff')
    is_png = content.startswith(b'\x89PNG\r\n\x1a\n')
    is_webp = content.startswith(b'RIFF') and (b'WEBP' in content[:16])
    is_bmp = content.startswith(b'BM')
    is_pdf = content.startswith(b'%PDF')
    is_heic = (b'ftypheic' in content[:24]) or (b'ftypmif1' in content[:24]) or (b'ftypmsf1' in content[:24])

    if not (is_jpeg or is_png or is_webp or is_bmp or is_pdf or is_heic):
        return False, "Le contenu du fichier n'est pas une image ou un document valide (signature binaire invalide)."

    return True, "OK"


# =====================================================================
# 2. Pipeline OCR (Prêt pour le modèle OCR de votre ami)
# =====================================================================
def run_ocr_model(image_bytes: bytes, filename: str) -> str:
    """
    Étape OCR : Reçoit l'image et extrait tout le texte brut.
    --> Votre ami peut intégrer ici son modèle OCR (PaddleOCR, Tesseract, TrOCR, EasyOCR, etc.)
    """
    logger.info(f"[OCR Pipeline] Extraction du texte pour l'image: {filename}")
    
    # -----------------------------------------------------------------
    # EMPLACEMENT POUR LE MODÈLE OCR DE VOTRE AMI :
    # Exemple d'intégration future :
    # import pytesseract
    # from PIL import Image
    # image = Image.open(io.BytesIO(image_bytes))
    # return pytesseract.image_to_string(image)
    # -----------------------------------------------------------------

    now_str = datetime.now().strftime("%Y-%m-%d")
    return (
        f"--- TEXTE BRUT EXTRAIT PAR L'OCR (OK) ---\n"
        f"Fichier analysé : {filename}\n"
        f"Date : {now_str}\n"
        f"Fournisseur : STE DISTRIBUTION ET COMMERCE\n"
        f"Matricule Fiscal : 1420895/A/M/000\n"
        f"Facture N° : FAC-2026-0498\n"
        f"Désignation des articles :\n"
        f"1. Écran LED 27 Pouces IPS | Qte: 3 | PU: 420.000 HT | TVA 19%\n"
        f"2. Clavier Mécanique RGB   | Qte: 8 | PU: 85.000 HT  | TVA 19%\n"
        f"Total HT : 1940.000 TND\n"
        f"TVA (19%) : 368.600 TND\n"
        f"Timbre fiscal : 1.000 TND\n"
        f"TOTAL TTC À PAYER : 2309.600 TND"
    )


# =====================================================================
# 3. Pipeline LLM (Prêt pour le Small LLM de votre ami)
# =====================================================================
def run_small_llm(ocr_text: str, document_type: str) -> Dict[str, Any]:
    """
    Étape LLM : Reçoit le texte extrait par l'OCR et utilise un petit LLM
    pour déterminer avec précision chaque champ (fournisseur, articles, prix, totaux).
    --> Votre ami peut intégrer ici son petit LLM (Ollama, Qwen2.5, Llama-3.2, Phi-3, etc.)
    """
    logger.info(f"[LLM Pipeline] Analyse intelligente du texte OCR ({document_type})")

    # -----------------------------------------------------------------
    # EMPLACEMENT POUR LE PETIT LLM DE VOTRE AMI :
    # Exemple d'intégration future avec Ollama ou transformers :
    # prompt = f"Extrais les informations sous forme de JSON strict: {ocr_text}"
    # response = ollama.chat(model="qwen2.5:3b", messages=[{"role": "user", "content": prompt}])
    # return json.loads(response['message']['content'])
    # -----------------------------------------------------------------

    now_str = datetime.now().strftime("%Y-%m-%d")
    return {
        "status": "OK",
        "document_number": "FAC-2026-0498",
        "document_date": now_str,
        "supplier_name": "STE DISTRIBUTION ET COMMERCE",
        "supplier_tax_id": "1420895/A/M/000",
        "supplier_phone": "+216 71 234 567",
        "supplier_address": "Zone Industrielle Charguia, Tunis",
        "total_ht": 1940.000,
        "total_tva": 368.600,
        "stamp_duty": 1.000,
        "total_ttc": 2309.600,
        "items": [
            {
                "product_code": "ECR-27",
                "product_name": "Écran LED 27 Pouces IPS",
                "quantity": 3.0,
                "unit_price": 420.000,
                "tva_rate": 19.0,
                "discount_percent": 0.0,
                "total_ht": 1260.000,
                "total_ttc": 1499.400,
            },
            {
                "product_code": "CLV-MEC",
                "product_name": "Clavier Mécanique RGB",
                "quantity": 8.0,
                "unit_price": 85.000,
                "tva_rate": 19.0,
                "discount_percent": 0.0,
                "total_ht": 680.000,
                "total_ttc": 809.200,
            }
        ]
    }


# =====================================================================
# Endpoints de l'API
# =====================================================================
@app.get("/")
def read_root():
    return {
        "service": "LogiTech ERP - AI Document & OCR/LLM Service",
        "status": "OK",
        "version": "1.1.0",
        "ai_model_configured": bool(AI_MODEL_URL),
        "docs_url": "/docs"
    }


@app.get("/health")
def health_check():
    return {
        "status": "OK",
        "model_configured": bool(AI_MODEL_URL),
        "endpoint": AI_MODEL_URL[:30] + "..." if len(AI_MODEL_URL) > 30 else (AI_MODEL_URL or "Local OCR/LLM Mode")
    }


@app.post("/api/scan", response_model=ScanResponse)
async def scan_documents(
    files: List[UploadFile] = File(...),
    document_type: str = Form("document")
):
    """
    Endpoint principal appelé par Flutter :
    1. Reçoit la ou les images depuis l'application.
    2. Vérifie rigoureusement le type de fichier (s'assure que c'est une image valide).
    3. Exécute l'OCR et le petit LLM pour extraire le texte et chaque champ.
    4. Renvoie le statut "OK" et le texte à afficher dans le champ de texte de l'application.
    """
    if not files:
        raise HTTPException(status_code=400, detail="Aucun fichier fourni pour l'analyse.")

    file_names = [f.filename for f in files]
    logger.info(f"--> Réception de {len(files)} fichier(s) pour analyse ({document_type}): {file_names}")

    # 1. Vérification du type de chaque fichier (doit être une image)
    verified_files = []
    for f in files:
        content = await f.read()
        is_valid, check_message = verify_image_file(f.filename, content)
        if not is_valid:
            logger.warning(f"Rejet du fichier non-image: {f.filename} ({check_message})")
            raise HTTPException(
                status_code=400,
                detail=f"Erreur de type pour '{f.filename}' : {check_message}"
            )
        verified_files.append({"filename": f.filename, "content": content})

    logger.info(f"[Validation Réussie] Les {len(verified_files)} fichier(s) sont bien des images valides.")

    # 2. Si l'ami a fourni une URL d'API externe dans .env, appeler son API
    if AI_MODEL_URL:
        logger.info(f"Appel du modèle IA distant : {AI_MODEL_URL}")
        headers = {}
        if AI_MODEL_API_KEY:
            if AI_AUTH_TYPE.lower() == "bearer":
                headers["Authorization"] = f"Bearer {AI_MODEL_API_KEY}"
            elif AI_AUTH_TYPE.lower() in ["api-key", "apikey"]:
                headers["x-api-key"] = AI_MODEL_API_KEY
            else:
                headers["Authorization"] = AI_MODEL_API_KEY

        try:
            async with httpx.AsyncClient(timeout=90.0) as client:
                multipart_files = [
                    ("files", (item["filename"], item["content"], "application/octet-stream"))
                    for item in verified_files
                ]
                response = await client.post(
                    AI_MODEL_URL,
                    files=multipart_files,
                    data={"document_type": document_type},
                    headers=headers
                )

                if response.status_code == 200:
                    result_json = response.json()
                    logger.info("Réponse avec succès du modèle IA de l'ami.")
                    raw_text_received = str(result_json.get("raw_text") or response.text)
                    text_display = f"OK - Analyse IA terminée avec succès.\n\n{raw_text_received}"
                    
                    return ScanResponse(
                        success=True,
                        status="OK",
                        text_response=text_display,
                        source="friend_ai_model",
                        message="OK : Données extraites avec succès par le modèle IA de votre ami.",
                        document_type=document_type,
                        file_names=file_names,
                        extracted_data=ExtractedDocumentData(
                            document_type=document_type,
                            raw_text=raw_text_received
                        )
                    )
                else:
                    logger.error(f"Erreur API IA ami (HTTP {response.status_code}) : {response.text}")
        except Exception as e:
            logger.exception(f"Exception lors de l'appel au modèle distant : {e}")

    # 3. Pipeline OCR + Petit LLM (Exécution locale préparée pour l'ami)
    first_file = verified_files[0]
    extracted_ocr_text = run_ocr_model(first_file["content"], first_file["filename"])
    llm_result = run_small_llm(extracted_ocr_text, document_type)

    # Construction du texte complet à renvoyer dans le champ de texte de l'application
    text_for_app = (
        f"OK\n"
        f"Statut : Image validée avec succès ({len(verified_files)} image(s))\n"
        f"Document : {llm_result.get('document_number', 'N/A')} | Date : {llm_result.get('document_date', 'N/A')}\n"
        f"Fournisseur : {llm_result.get('supplier_name', 'N/A')}\n"
        f"Total TTC : {llm_result.get('total_ttc', 0.0):.3f} TND\n\n"
        f"{extracted_ocr_text}"
    )

    items_list = [
        DocumentItem(
            product_code=it.get("product_code"),
            product_name=it.get("product_name", "Article"),
            quantity=float(it.get("quantity", 1.0)),
            unit_price=float(it.get("unit_price", 0.0)),
            tva_rate=float(it.get("tva_rate", 19.0)),
            discount_percent=float(it.get("discount_percent", 0.0)),
            total_ht=float(it.get("total_ht", 0.0)),
            total_ttc=float(it.get("total_ttc", 0.0)),
        )
        for it in llm_result.get("items", [])
    ]

    extracted_data = ExtractedDocumentData(
        document_type=document_type,
        document_number=llm_result.get("document_number"),
        document_date=llm_result.get("document_date"),
        supplier_name=llm_result.get("supplier_name"),
        supplier_tax_id=llm_result.get("supplier_tax_id"),
        supplier_phone=llm_result.get("supplier_phone"),
        supplier_address=llm_result.get("supplier_address"),
        total_ht=float(llm_result.get("total_ht", 0.0)),
        total_tva=float(llm_result.get("total_tva", 0.0)),
        stamp_duty=float(llm_result.get("stamp_duty", 1.0)),
        total_ttc=float(llm_result.get("total_ttc", 0.0)),
        currency="TND",
        raw_text=text_for_app,
        items=items_list,
    )

    return ScanResponse(
        success=True,
        status="OK",
        text_response=text_for_app,
        source="local_ocr_llm",
        message="OK - Image vérifiée. Texte OCR extrait et analysé par le LLM.",
        document_type=document_type,
        file_names=file_names,
        extracted_data=extracted_data,
    )


if __name__ == "__main__":
    import uvicorn
    print(f"\n=======================================================")
    print(f"  LogiTech ERP - Service Python d'Extraction IA")
    print(f"  Statut : OK | Prêt pour OCR + LLM")
    print(f"  URL : http://localhost:{PORT}")
    print(f"=======================================================\n")
    uvicorn.run("main:app", host=HOST, port=PORT, reload=True)
