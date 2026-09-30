"""
Servidor LAYA (FastAPI) para los componentes Delphi.

Un solo servidor para cualquier modelo. Se configura con variables de entorno,
que fijan los .bat de arranque:

  LAYA_MODELO_RUTA    carpeta local de un modelo afinado (p. ej. C:\\LAYA\\modelos\\laya_codiesp_v2).
                      Si está vacía se usa LAYA_MODELO_HUB.
  LAYA_MODELO_HUB     modelo de Hugging Face (por defecto convaiinnovations/laya-multilingual).
  LAYA_MODELO_NOMBRE  nombre que devuelve /salud; TLayaDBAnalyzer lo guarda en FieldModel.
  LAYA_OFFLINE        1 = no consultar Hugging Face (el modelo ya está en la caché local).
                      La primera vez que se usa un modelo del Hub hay que ponerlo a 0.

Endpoints:
  GET  /salud           estado y nombre del modelo
  POST /predict         respuesta completa de LAYA (la usan los componentes)
  POST /predict_tabla   una fila por pregunta, para clientes sencillos
"""
import os

os.environ["USE_TF"] = "0"
if os.environ.get("LAYA_OFFLINE", "1") == "1":
    os.environ["HF_HUB_OFFLINE"] = "1"
    os.environ["TRANSFORMERS_OFFLINE"] = "1"

import json
import logging
import time

from fastapi import FastAPI
from pydantic import BaseModel
import laya

HUB = os.environ.get("LAYA_MODELO_HUB", "convaiinnovations/laya-multilingual").strip()
RUTA = os.environ.get("LAYA_MODELO_RUTA", "").strip()
NOMBRE = os.environ.get("LAYA_MODELO_NOMBRE", "").strip() or (
    os.path.basename(RUTA.rstrip("\\/")) if RUTA else HUB)

log = logging.getLogger("uvicorn.error")

if RUTA:
    log.info("Cargando modelo local %s", RUTA)
    agent = laya.Agent(RUTA, device="cpu")
else:
    log.info("Cargando modelo %s", HUB)
    agent = laya.load(HUB)

app = FastAPI(title="Servidor LAYA")


class Peticion(BaseModel):
    state: dict
    questions: dict


def a_json(obj):
    """Convierte los números de NumPy en tipos que FastAPI sabe serializar."""
    return json.loads(json.dumps(obj, default=float))


@app.get("/salud")
def salud():
    return {"estado": "ok", "modelo": NOMBRE}


@app.post("/predict")
def predict(p: Peticion):
    t0 = time.perf_counter()
    r = a_json(agent.predict(p.state, p.questions))
    log.info("predict: %d preguntas en %.0f ms", len(p.questions),
             (time.perf_counter() - t0) * 1000)
    return r


@app.post("/predict_tabla")
def predict_tabla(p: Peticion):
    r = predict(p)
    filas = []
    for nombre, a in r["answers"].items():
        t = a["type"]
        if t == "choice":
            resp = a["choice"]
            prob = a["probabilities"][resp]
        elif t == "score":
            nivel = str(round(a["score"]))
            resp = a["legend"][nivel]
            prob = a["probabilities"][nivel]
        else:  # noul
            resp = "Sí" if a["noul"] >= 0.5 else "No"
            prob = a["noul"] if a["noul"] >= 0.5 else 1 - a["noul"]
        filas.append({"pregunta": nombre, "tipo": t,
                      "respuesta": resp, "probabilidad": round(prob * 100, 1)})
    return filas
