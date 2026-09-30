"""
CodiEsp -> SQLite para las pruebas de LAYA.

Descarga el corpus CodiEsp (casos clínicos en español codificados en CIE-10,
Barcelona Supercomputing Center, licencia CC BY 4.0), deduce unas etiquetas
a partir de los códigos de diagnóstico y crea la base codiesp.sdb con la
tabla Casos, lista para TLayaDBAnalyzer, TLayaEvaluator y
TLayaTrainingExporter.

Uso (con el entorno de LAYA activado, o con cualquier Python 3):
    python codiesp_a_sqlite.py
    python codiesp_a_sqlite.py --zip C:\\Descargas\\codiesp.zip   (si ya lo has bajado)

Cita obligatoria (CC BY 4.0):
    Miranda-Escalada A, Gonzalez-Agirre A, Armengol-Estapé J, Krallinger M.
    Overview of automatic clinical coding: annotations, guidelines, and
    solutions for non-English clinical cases at CodiEsp track of CLEF eHealth
    2020. CLEF (Working Notes), 2020. https://doi.org/10.5281/zenodo.3837305

Etiquetas (reglas sobre los códigos CIE-10-CM de diagnóstico del caso):
    Diabetes      S si hay E08-E13 (diabetes mellitus), N si no
    Hipertension  S si hay I10-I16 (hipertensión arterial; NO cuenta I27,
                  hipertensión pulmonar), N si no
    Cancer        S si hay C00-C96 (neoplasia maligna) o Z85 (antecedente
                  personal de neoplasia maligna), N si no
    Insuf_renal   S si hay N17-N19 (insuficiencia renal aguda o crónica)
    Tabaco        fumador (F17, Z72.0), exfumador (Z87.891), no_consta

Aviso: "N" significa "no codificado", no "comprobado que no lo tiene". Un
codificador solo registra lo que considera relevante, así que habrá casos
en los que el texto lo menciona de pasada y la etiqueta dice N. Es ruido
normal en este tipo de conjuntos; el evaluador ayudará a verlo.
"""

import argparse
import csv
import os
import sqlite3
import sys
import urllib.request
import zipfile
from pathlib import Path

ZIP_URL = "https://zenodo.org/records/3837305/files/codiesp.zip?download=1"
SPLITS = ("train", "dev", "test")


# ---------------------------------------------------------------- etiquetas --

def norm(code: str) -> str:
    """'e11.9' -> 'E119'"""
    return code.strip().upper().replace(".", "")


def in_range(codes, letter, lo, hi):
    """True si algún código empieza por letter + número de 2 cifras entre lo y hi."""
    for c in codes:
        if len(c) >= 3 and c[0] == letter and c[1:3].isdigit():
            if lo <= int(c[1:3]) <= hi:
                return True
    return False


def starts(codes, *prefixes):
    return any(c.startswith(p) for c in codes for p in prefixes)


def labels(codes):
    sn = lambda b: "S" if b else "N"
    if starts(codes, "F17", "Z720"):
        tabaco = "fumador"
    elif starts(codes, "Z87891"):
        tabaco = "exfumador"
    else:
        tabaco = "no_consta"
    return {
        "Diabetes": sn(in_range(codes, "E", 8, 13)),
        "Hipertension": sn(in_range(codes, "I", 10, 16)),
        "Cancer": sn(in_range(codes, "C", 0, 96) or starts(codes, "Z85")),
        "Insuf_renal": sn(in_range(codes, "N", 17, 19)),
        "Tabaco": tabaco,
    }


# ------------------------------------------------------------------ corpus --

def get_zip(path_arg: str | None) -> Path:
    if path_arg:
        p = Path(path_arg)
        if not p.exists():
            sys.exit(f"No existe {p}")
        return p
    p = Path("codiesp.zip")
    if p.exists():
        print("Usando codiesp.zip ya descargado.")
        return p
    print("Descargando CodiEsp de Zenodo (11 MB)...")
    try:
        urllib.request.urlretrieve(ZIP_URL, p)
    except Exception as e:
        sys.exit(
            f"No se pudo descargar ({e}).\n"
            f"Descárgalo a mano desde {ZIP_URL}\n"
            "y ejecuta: python codiesp_a_sqlite.py --zip ruta\\codiesp.zip")
    return p


def find_split_dirs(root: Path):
    """Busca las carpetas train/dev/test que contienen text_files."""
    found = {}
    for dirpath, dirnames, _ in os.walk(root):
        name = os.path.basename(dirpath).lower()
        if name in SPLITS and "text_files" in dirnames:
            found[name] = Path(dirpath)
    return found


def read_diagnoses(split_dir: Path):
    """{articleID: [códigos]} a partir del fichero *D.tsv de la carpeta."""
    tsvs = [p for p in split_dir.glob("*.tsv") if p.stem.upper().endswith("D")]
    if not tsvs:
        return None
    codes = {}
    with open(tsvs[0], encoding="utf-8", newline="") as f:
        for row in csv.reader(f, delimiter="\t"):
            if len(row) < 2:
                continue
            art, code = row[0].strip(), row[1].strip()
            if not art or not code or art.lower() == "articleid":
                continue
            codes.setdefault(art, []).append(norm(code))
    return codes


# ------------------------------------------------------------------ SQLite --

DDL = """
DROP TABLE IF EXISTS "Casos";
CREATE TABLE "Casos" (
  "id"             INTEGER PRIMARY KEY AUTOINCREMENT,
  "Articulo"       VARCHAR(40),
  "Particion"      VARCHAR(10),       -- train / dev / test (reparto oficial)
  "Texto"          TEXT,              -- caso clínico
  "Codigos"        VARCHAR(2000),     -- códigos CIE-10 de diagnóstico
  "Diabetes"       VARCHAR(2),        -- S / N
  "Hipertension"   VARCHAR(2),
  "Cancer"         VARCHAR(2),
  "Insuf_renal"    VARCHAR(2),
  "Tabaco"         VARCHAR(20),       -- fumador / exfumador / no_consta
  "Revisado"       INTEGER DEFAULT 1, -- etiquetas fiables: se usan como verdad
  "Fecha_analisis" DATETIME,
  "Modelo"         VARCHAR(100)
);
"""


def main():
    ap = argparse.ArgumentParser(description="CodiEsp -> SQLite para LAYA")
    ap.add_argument("--zip", help="ruta a codiesp.zip si ya lo tienes")
    ap.add_argument("--out", default="codiesp.sdb", help="base SQLite a crear")
    args = ap.parse_args()

    zpath = get_zip(args.zip)
    extract = Path("codiesp_extraido")
    if not extract.exists():
        print("Descomprimiendo...")
        with zipfile.ZipFile(zpath) as z:
            z.extractall(extract)

    dirs = find_split_dirs(extract)
    if not dirs:
        sys.exit("No se encontraron las carpetas train/dev/test en el zip.")

    con = sqlite3.connect(args.out)
    con.executescript(DDL)

    total = 0
    counts = {}
    for split in SPLITS:
        d = dirs.get(split)
        if d is None:
            print(f"Aviso: no se encontró la partición {split}")
            continue
        codes = read_diagnoses(d)
        if codes is None:
            print(f"Aviso: {split} no tiene fichero de diagnósticos (*D.tsv)")
            continue
        n = 0
        for txt in sorted((d / "text_files").glob("*.txt")):
            art = txt.stem
            text = txt.read_text(encoding="utf-8").strip()
            c = codes.get(art, [])
            lab = labels(c)
            con.execute(
                'INSERT INTO "Casos" ("Articulo","Particion","Texto","Codigos",'
                '"Diabetes","Hipertension","Cancer","Insuf_renal","Tabaco") '
                "VALUES (?,?,?,?,?,?,?,?,?)",
                (art, split, text, " ".join(c), lab["Diabetes"],
                 lab["Hipertension"], lab["Cancer"], lab["Insuf_renal"],
                 lab["Tabaco"]))
            for k, v in lab.items():
                counts.setdefault((split, k, v), 0)
                counts[(split, k, v)] += 1
            n += 1
        print(f"{split}: {n} casos")
        total += n
    con.commit()

    # resumen de etiquetas por partición
    print(f"\nTotal: {total} casos en {args.out}\n")
    print(f"{'etiqueta':<14}{'valor':<11}" + "".join(f"{s:>8}" for s in SPLITS))
    keys = sorted({(k, v) for (_, k, v) in counts})
    for k, v in keys:
        print(f"{k:<14}{v:<11}" + "".join(
            f"{counts.get((s, k, v), 0):>8}" for s in SPLITS))

    lens = [len(r[0]) for r in con.execute('SELECT "Texto" FROM "Casos"')]
    if lens:
        lens.sort()
        print(f"\nLongitud del texto (caracteres): mediana {lens[len(lens)//2]}, "
              f"máxima {lens[-1]}")
    con.close()


if __name__ == "__main__":
    main()
