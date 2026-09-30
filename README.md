# LAYA para Delphi

Componentes Delphi para usar **[LAYA](https://huggingface.co/convaiinnovations/laya)**, un modelo
open source de decisiones tipadas, **en local**, sin enviar datos a ningún servicio externo.

LAYA no genera texto: recibe un texto y unas preguntas tipadas y devuelve respuestas con
probabilidades, en una sola pasada. Sirve para clasificar, puntuar o detectar cosas en textos
libres: el departamento que debe atender un correo, si un informe clínico menciona diabetes, la
urgencia de una incidencia...

Este repositorio incluye:

* un **servidor Python** (FastAPI) que carga el modelo y lo expone por HTTP en el propio equipo;
* **siete componentes Delphi** que hablan con el servidor, procesan tablas de base de datos,
  miden la calidad del modelo y generan datos de entrenamiento;
* dos **aplicaciones de demostración**;
* un **notebook de Kaggle** para afinar el modelo con datos propios en una GPU gratuita;
* un caso completo con casos clínicos reales publicados (**CodiEsp**): evaluación del modelo
  base, entrenamiento y evaluación del modelo afinado.

Desarrollado con **Delphi 12 Community Edition** y **Python 3.11** en Windows.

---

## Arquitectura

```text
 Aplicación Delphi                         Servidor local (Python)
┌──────────────────────────────┐   HTTP    ┌────────────────────────────┐
│ TLayaServer ─────────────────┼──────────►│ servidor.py (FastAPI)      │
│   │  TLayaQuestions          │  JSON     │   /salud                   │
│   │  TLayaResults            │◄──────────┤   /predict  ──► modelo     │
│   │                          │           │                  LAYA      │
│ TLayaDBAnalyzer ── TDataSet  │           └────────────────────────────┘
│ TLayaEvaluator               │
│ TLayaTrainingExporter ──► .jsonl ──► Kaggle (GPU) ──► modelo afinado
└──────────────────────────────┘
```

## Estructura

| Carpeta | Contenido |
|---|---|
| `Componentes/` | Paquetes `LayaRT` (ejecución) y `LayaDT` (diseño) con las unidades `Laya.*` |
| `Demo_Predict/` | Consultas sueltas y análisis de la tabla de clientes |
| `Demo_Revisor/` | Evaluación y exportación con la base de datos CodiEsp |
| `Servidor/` | `servidor.py`, `log_config.json`, `requirements.txt` y los `.bat` de arranque |
| `Kaggle/` | Notebook de entrenamiento para 2 GPU T4 |
| `json_maestros/` | Juegos de preguntas: `Preguntas_Cliente.json`, `Preguntas_codiesp.json` |
| `Database/` | `clientes_laya.sql` y `Clientes.sdb` (datos de prueba inventados) |
| `Python/` | `codiesp_a_sqlite.py`: descarga CodiEsp y crea `codiesp.sdb` |
| `Evaluaciones/` | Destino de los `.jsonl` exportados y de los informes (no se suben) |

---

## 1. Instalar el servidor

Necesitas Python 3.10 o superior. En una ventana de comandos:

```bat
mkdir C:\LAYA
cd /d C:\LAYA
python -m venv venv
venv\Scripts\activate.bat
python -m pip install --upgrade pip
pip install torch --index-url https://download.pytorch.org/whl/cpu
pip install -r <ruta del repositorio>\Servidor\requirements.txt
```

Instalar PyTorch **antes** y en su versión CPU evita descargar varios GB de librerías CUDA que no
se usan sin GPU NVIDIA.

Arranca el servidor con `Servidor\arrancar_servidor_LAYA.bat`. **La primera vez** edita el `.bat`
y pon `LAYA_OFFLINE=0` para que descargue el modelo (unos 800 MB); después vuelve a `1`, y el
servidor arrancará sin consultar internet. Comprueba que responde en
<http://127.0.0.1:8000/salud>; la documentación interactiva está en <http://127.0.0.1:8000/docs>.

Los `.bat` suponen que el entorno virtual y los modelos están en `C:\LAYA` (variable `LAYA_HOME`).
El servidor escucha solo en `127.0.0.1`: no es accesible desde otros equipos.

| Variable | Uso |
|---|---|
| `LAYA_MODELO_RUTA` | Carpeta de un modelo afinado. Vacía = modelo de Hugging Face |
| `LAYA_MODELO_HUB` | Modelo de Hugging Face (por defecto `convaiinnovations/laya-multilingual`) |
| `LAYA_MODELO_NOMBRE` | Nombre que devuelve `/salud` y que se guarda en `FieldModel` |
| `LAYA_OFFLINE` | `1` = no consultar Hugging Face |

## 2. Instalar los componentes

1. Abre `Componentes\LayaRT.dpk` y compílalo.
2. Abre `Componentes\LayaDT.dpk`, compílalo e instálalo (clic derecho → *Install*).
3. Añade la carpeta `Componentes` en *Tools → Options → Language → Delphi → Library → Library path*.

Aparece la pestaña **LAYA** en la paleta. `LayaRT` requiere los paquetes `rtl`, `vcl` y `dbrtl`.

---

## 3. Componentes

### TLayaServer
Conexión con el servidor.

* **Propiedades:** `BaseURL`, `PredictPath`, `HealthPath`, `ConnectionTimeout`, `ResponseTimeout`,
  `StateKey`, `Questions`, `Results`.
* **Solo lectura:** `LastStatusCode`, `LastRequestBody`, `LastResponseBody`, `LastElapsedMs`,
  `LastError`, `ModelName`, `Busy`.
* **Métodos:** `CheckHealth`, `Predict` y `PredictAsync` (sin texto, lo leen de `Questions.InTXT`;
  con texto; o con componentes explícitos), `PredictState` para estados con varios campos.
* **Eventos:** `OnBeforeRequest`, `OnAfterRequest`, `OnError`, `OnLog`.
* Los errores de programación lanzan `ELayaError`; los de red o servidor no: `Predict` devuelve
  `False`, rellena `LastError` y dispara `OnError`. La versión asíncrona ejecuta resultados y
  eventos en el hilo principal.
* En diseño: clic derecho → *Probar conexión*.

### TLayaQuestions
Colección de preguntas editable en el Inspector. Tipos: `qkChoice` (elegir una opción), `qkScore`
(nivel en una escala ordenada) y `qkNoul` (sí/no con probabilidad).

* Por pregunta: `Name`, `Kind`, `Instructions`, `Options`, `AcceptThreshold`, `RejectThreshold`,
  `Aggregation`, `Enabled`.
* `InTXT`: memo con el texto a analizar.
* Métodos `AddChoice`, `AddScore`, `AddNoul`, `Validate`, `SaveToFile`, `LoadFromFile`.
* En diseño: *Editar preguntas*, *Cargar desde archivo*, *Guardar en archivo*.

### TLayaResults
Resultados de la última consulta. Cada `TLayaAnswer` tiene `Answer` (clave), `AnswerCaption`,
`Probability`, `Probabilities`, `PTrue`, `Score`, `Level` y `Decision`:

* `ldAccepted`: supera `AcceptThreshold` (en noul: "sí" con seguridad);
* `ldRejected`: en noul, "no" con seguridad (por debajo de `RejectThreshold`);
* `ldReview`: zona intermedia, para revisión humana.

Salidas automáticas a memos: `OutTXT` (texto legible; `TextAnswer` elige descripción o clave) y
`OutJSON` (respuesta del servidor). Métodos `AsText`, `FormattedJSON`, `ByName`, `Aggregate`,
`DisableOutputs`/`EnableOutputs`.

### TLayaDBAnalyzer
Recorre un `TDataSet`, pregunta a LAYA por cada registro y escribe las respuestas en sus campos.

* **Origen del texto:** `DataSetTarget`, `DataSetSource`, `FieldsSource` (varios campos
  separados por `;`), `LinkMode` (`lmSameDataSet`, `lmMasterDetail` o `lmFilter`),
  `FieldKeyTarget`, `FieldKeySource`.
* **Textos largos:** se trocean (`ChunkSize`, `ChunkOverlap`) y las respuestas se combinan con el
  `Aggregation` de cada pregunta. Varios informes de un mismo registro se combinan igual.
* **Escritura:** colección `Mappings` (pregunta → `FieldAnswer`, `FieldProbability`,
  `FieldDecision`, con `AnswerFormat` y `WriteMode`).
* **Control:** `ProcessMode` (`pmAll` o `pmEmpty`), `FieldLock` (registros revisados por una
  persona, que nunca se tocan), `FieldDate`, `FieldModel`, `MaxRecords`, `StopOnError`,
  `DisableControls`.
* **Métodos y eventos:** `Execute`, `ExecuteCurrent`, `Cancel`; `OnBeforeRecord`,
  `OnPrepareText`, `OnAfterRecord`, `OnWriteValue`, `OnProgress`, `OnRecordError`, `OnFinish`
  (con `TLayaDBStats`, que tiene `AsText` y `AsTable`).
* Proceso asíncrono: la ventana sigue respondiendo; todos los eventos van al hilo principal.
* En diseño: doble clic abre una **ventana de configuración** que lee los campos de las tablas,
  con asignación automática de los mappings por nombre.

### TLayaEvaluator
Vuelve a pasar el modelo por los registros revisados (`FieldLock`) sin escribir nada y compara
con las respuestas correctas: aciertos, errores decididos sin revisión, revisiones, confusiones,
umbral sugerido para una precisión objetivo (`TargetPrecision`) y lista de errores.
`AsText`, `AsTable`, `OutTXT`, `OnFinish`.

### TLayaTrainingExporter
Exporta los registros revisados a **JSON Lines** en el formato del conjunto
`LocalLLaMA/typed-decisions`, el que usa el notebook oficial de entrenamiento. Propiedades
`FileName`, `Workflow`, `FieldSplit` (o `TestPercent` y `Seed`) y `LabelSmoothing`.

---

## 4. Uso rápido

```pascal
LayaQuestions1.AddNoul('diabetes', '¿El paciente tiene diabetes mellitus?');
if LayaServer1.Predict(Memo1.Text) then
  ShowMessage(LayaResults1.ByName('diabetes').AnswerCaption);
```

Para una tabla: asigna `Server`, `DataSetTarget` y las preguntas a un `TLayaDBAnalyzer`, haz doble
clic para configurarlo y llama a `Execute`.

**Instrucciones en español.** Con textos en español, las preguntas escritas en español funcionan
mucho mejor que en inglés.

---

## 5. Entrenar con datos propios

1. **Revisar.** Marca en `FieldLock` los registros cuyas respuestas ha confirmado una persona.
2. **Medir** el modelo actual con `TLayaEvaluator`, separando unos casos de prueba.
3. **Exportar** con `TLayaTrainingExporter`. `LabelSmoothing = 0.05` da probabilidades mejor
   calibradas.
4. **Entrenar en Kaggle** con `Kaggle/laya_finetune_codiesp_v2_2xT4_kaggle.ipynb`: sube el
   `.jsonl` como dataset, activa *GPU T4 x2* e *Internet*, y lanza *Save Version → Save & Run All*.
   El notebook sobremuestrea las clases minoritarias, evalúa sobre la partición de test y empaqueta
   el modelo.
5. **Instalar** el zip en `C:\LAYA\modelos\...` y arrancar el servidor con `LAYA_MODELO_RUTA`.
6. **Medir otra vez** con `TLayaEvaluator` sobre los mismos casos de prueba. Si los textos son
   largos, pon `ChunkSize` por encima de su longitud para que lleguen enteros, como en el
   entrenamiento.

---

## 6. Caso de estudio: CodiEsp

1.000 casos clínicos en español con códigos CIE-10 (750 de entrenamiento y 250 de test, según el
reparto oficial). `Python/codiesp_a_sqlite.py` los descarga y deduce cinco etiquetas de los
códigos: diabetes, hipertensión, cáncer, insuficiencia renal y hábito tabáquico.

Exactitud en los 250 casos de test:

| Pregunta | Siempre "no" | Modelo base | Afinado v1 | Afinado v2 |
|---|---|---|---|---|
| diabetes | 89,6 % | 79,6 % | 98,8 % | **99,6 %** |
| hipertensión | 82,0 % | 59,2 % | 97,6 % | **99,6 %** |
| cáncer | 72,0 % | 77,2 % | 92,4 % | **92,8 %** |
| insuf. renal | 92,8 % | 51,2 % | **98,8 %** | 98,0 % |
| tabaco | 90,4 % | 91,6 % | 99,2 % | 99,2 % |

* El **modelo base** tiende a contestar "sí" en cuanto el texto roza el tema, y en tres preguntas
  acierta menos que contestar siempre "no". Las cifras del modelo base se obtuvieron troceando los
  textos en fragmentos de 2.000 caracteres; las de los modelos afinados, con el caso entero.
* **v1**: entrenado con etiquetas absolutas; acierta mucho, pero sus probabilidades no están
  calibradas (errores y aciertos llegan con la misma seguridad).
* **v2**: igual, con `LabelSmoothing = 0.05`. Las temperaturas de calibración quedan en rango y
  algunos errores ya caen en la zona de revisión.
* En cáncer, la revisión de los 18 fallos muestra que 6 son **errores de la etiqueta** (el modelo
  acertaba) y que los errores reales se concentran en **neoplasias hematológicas y sarcomas**,
  que no se nombran como "cáncer". El acierto real ronda el 96–97 %.

Con 18–26 casos positivos en algunas preguntas, estas cifras tienen un margen de variación de
varios puntos. El modelo aprende el criterio de los codificadores de CodiEsp, y los casos son
publicaciones clínicas, más cuidadas que un informe real.

---

## Aviso sobre uso clínico

Este proyecto es una **prueba técnica**. Las respuestas del modelo son sugerencias que deben
revisarse, no datos clínicos. Antes de usarlo con informes reales hay que validarlo con una muestra
revisada de esos mismos informes y contar con la autorización correspondiente para tratar datos
de salud. Todo el proceso se ejecuta en local, pero eso no sustituye a esa autorización.

## Licencia

Los componentes Delphi, las aplicaciones de demostración, el servidor, los scripts y el notebook
de este repositorio son © 2026 Juan Carlos y se distribuyen bajo la
**licencia Apache 2.0** (ver [LICENSE](LICENSE)).

Este proyecto usa materiales de terceros con sus propias licencias:

* **LAYA**, de Convai Innovations: Apache 2.0.
* **CodiEsp**, del Barcelona Supercomputing Center: CC BY 4.0.

Los detalles y la cita obligatoria de CodiEsp están en [NOTICE.md](NOTICE.md).
Los modelos entrenados y el corpus CodiEsp no se incluyen en el repositorio.
