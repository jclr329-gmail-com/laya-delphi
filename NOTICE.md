# LAYA para Delphi

Copyright 2026 Carlos Liñan

Este producto se distribuye bajo la licencia Apache 2.0 (ver `LICENSE`) e incluye
o utiliza software y materiales de terceros, que se detallan a continuación.

# Avisos de terceros

## LAYA

Modelo y librería `laya` de **Convai Innovations**, licencia **Apache 2.0**.
https://huggingface.co/convaiinnovations/laya · https://github.com/NandhaKishorM/laya

El notebook `Kaggle/laya\_finetune\_codiesp\_v2\_2xT4\_kaggle.ipynb` es una adaptación del notebook
oficial `laya\_finetune\_typed\_decisions\_2xT4\_kaggle.ipynb` (Apache 2.0).
Los modelos entrenados a partir de LAYA no se incluyen en este repositorio.

## CodiEsp

Corpus de casos clínicos en español codificados en CIE-10, del Barcelona Supercomputing Center,
licencia **Creative Commons Atribución 4.0 (CC BY 4.0)**. El corpus no se incluye: el script
`Python/codiesp\_a\_sqlite.py` lo descarga de Zenodo y crea la base de datos.

Cita obligatoria:

> Miranda-Escalada A, Gonzalez-Agirre A, Armengol-Estapé J, Krallinger M. \*Overview of automatic
> clinical coding: annotations, guidelines, and solutions for non-English clinical cases at CodiEsp
> track of CLEF eHealth 2020.\* CLEF (Working Notes), 2020. https://doi.org/10.5281/zenodo.3837305

Las etiquetas `Diabetes`, `Hipertension`, `Cancer`, `Insuf\_renal` y `Tabaco` se derivan
automáticamente de los códigos CIE-10 del corpus; no forman parte del corpus original.

