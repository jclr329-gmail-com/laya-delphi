-- Tabla de prueba para TLayaDBAnalyzer (LinkMode = lmSameDataSet)
-- Los campos *_prct guardan probabilidades entre 0 y 1 (0,85 = 85 %).

DROP TABLE IF EXISTS "Clientes";

CREATE TABLE "Clientes" (
  "id"                INTEGER PRIMARY KEY AUTOINCREMENT,
  "Pregunta"          TEXT,             -- texto a analizar (memo)
  "Departamento_text" VARCHAR(20),      -- clave: facturacion / soporte / ventas
  "Departamento_prct" REAL,
  "Departamento_dec"  VARCHAR(10),      -- accepted / review / rejected
  "Urgencia_key"      INTEGER,          -- 0, 1, 2
  "Urgencia_name"     VARCHAR(20),      -- no urgente / pronto / bloqueante
  "Urgencia_prct"     REAL,
  "Baja_name"         VARCHAR(2),       -- S / N
  "Baja_prct"         REAL,             -- P(verdadero)
  "Baja_dec"          VARCHAR(10),
  "Revisado"          INTEGER DEFAULT 0, -- 1 = confirmado por una persona, no tocar
  "Fecha_analisis"    DATETIME,
  "Modelo"            VARCHAR(100)
);

-- Casos claros
INSERT INTO "Clientes" ("Pregunta") VALUES
('Cancelé hace dos semanas y sigo sin reembolso. Si no se soluciona me doy de baja.'),
('Me habéis cobrado dos veces la factura de marzo. Por favor, devolvedme el cargo duplicado.'),
('La aplicación se cierra sola cada vez que intento abrir un documento. No puedo trabajar.'),
('Quería información sobre el plan para empresas, estamos pensando contratar diez licencias.'),
('Buenos días, ¿podríais enviarme una copia de la factura del mes pasado? No corre prisa.'),
('Desde la actualización de ayer no puedo iniciar sesión y tengo una presentación en una hora.');

-- Casos dudosos o con trampa
INSERT INTO "Clientes" ("Pregunta") VALUES
('Estoy bastante harto del servicio, aunque de momento no pienso irme.'),
('El precio ha subido y la competencia es más barata. Me lo estoy pensando.'),
('He intentado pagar con tarjeta y me da error. ¿Es un problema vuestro o de mi banco?'),
('Todo funciona perfectamente, solo quería daros las gracias por la atención.'),
('Si no me arregláis hoy el fallo de sincronización, cancelo la suscripción y os denuncio.');

-- Registro vacío: debe saltarse (sin texto)
INSERT INTO "Clientes" ("Pregunta") VALUES ('');

-- Registro ya revisado por una persona: con LockField = Revisado no debe tocarse
INSERT INTO "Clientes" ("Pregunta", "Departamento_text", "Departamento_dec",
  "Urgencia_key", "Urgencia_name", "Baja_name", "Baja_dec", "Revisado") VALUES
('No me llega el correo de confirmación del pedido.', 'soporte', 'manual',
  1, 'pronto', 'N', 'manual', 1);

-- Registro largo: pon ChunkSize = 300 para ver el troceo y la agregación
INSERT INTO "Clientes" ("Pregunta") VALUES
('Les escribo porque llevo ya varias semanas con problemas y empiezo a estar cansado. '
 || 'Primero, el mes pasado recibí una factura con un importe que no corresponde a mi tarifa, '
 || 'y aunque llamé por teléfono y me dijeron que lo corregirían, este mes ha vuelto a pasar lo mismo. '
 || 'Además, desde hace unos días la aplicación del móvil no me deja consultar el consumo, '
 || 'se queda cargando indefinidamente. He probado a reinstalarla y a cambiar de móvil y nada. '
 || 'Entiendo que pueda haber errores, pero no que nadie me dé una solución. '
 || 'Les pido que revisen las dos facturas y me devuelvan la diferencia. '
 || 'Si antes de fin de mes no tengo respuesta, me daré de baja y me iré a otra compañía.');
