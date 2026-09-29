# Requisitos funcionales — TAKIPUKARA Patrimonio V2

## Alcance
Proyecto nuevo, separado del prototipo actual. El prototipo se conserva como referencia y fuente de datos para migración.

## Identidad visual
- Mantener colores corporativos basados en el logo de TAKIPUKARA.
- Amarillo corporativo, negro/gris oscuro y blanco como base.
- No modificar el flujo funcional por razones puramente estéticas.

## Escaneo móvil
Objetivo: registrar entregas y devoluciones rápidamente desde celular/tablet.

Flujo de entrega:
1. Operador inicia sesión.
2. Selecciona o busca colaborador (DNI/nombre).
3. Escanea QR del activo o código/serie.
4. El sistema valida que el activo exista y su estado actual.
5. Si está disponible, se agrega a la entrega.
6. Si ya está asignado, se bloquea la entrega y se ofrece flujo de transferencia/devolución.
7. Se revisan los activos del cargo.
8. Se genera el formato de entrega.
9. Se registra el cargo y sus ítems de forma atómica.
10. Se adjunta el documento firmado como evidencia.
11. El documento queda vinculado al cargo exacto, no a todas las asignaciones del trabajador.

## QR permanente
- Se conserva el CODIGO SKU existente como identificador de negocio.
- Los QR existentes deben seguir funcionando.
- La ruta QR debe permanecer compatible con ver.html?codigo=<CODIGO_SKU> o redirigir a la nueva vista.

### Vista QR autenticada (uso interno)
Mostrar:
- Código SKU.
- Descripción.
- Marca.
- Modelo.
- N° de serie.
- Estado del activo.
- Responsable actual.
- Área del responsable.
- Cargo del responsable.
- Fecha de asignación.
- N° de cargo asociado.
- Ubicación actual cuando no está asignado.
- Acciones autorizadas según rol: devolución, transferencia, mantenimiento, historial.

### Vista QR sin autenticación
Mostrar únicamente:
- Código SKU.
- Descripción.
- Marca/modelo.
- N° de serie (opcional según política).
- Estado general: asignado / almacén / mantenimiento / baja.
- Identificación de empresa.

No mostrar DNI, teléfonos, documentos, firmas, archivos de evidencia ni historial personal.

## Evidencias
Cada evidencia debe estar vinculada al cargo, movimiento o activo que la originó.

Metadatos mínimos:
- cargo_id / movimiento_id
- nombre de archivo
- tipo MIME
- fecha de carga
- usuario que cargó
- ruta privada de almacenamiento
- hash opcional para integridad

### Almacenamiento recomendado
Primario:
- Supabase Storage en bucket privado.

Acceso:
- URLs firmadas temporales solo para usuarios autenticados/autorizados.

Respaldo:
- Exportación periódica a laptop, disco externo o almacenamiento corporativo.

No usar como solución principal:
- rutas locales C:\...
- archivos enlazados solo desde una laptop
- buckets públicos

## Migración
Migrar:
- Personal desde BD-PERSONAL.
- Activos desde Inventario_Bienes.
- Historial útil desde RECORD.
- Asignaciones válidas del prototipo.
- CODIGO SKU y QR existentes.
- Evidencias existentes cuando puedan asociarse inequívocamente a un cargo/asignación.

Antes de migrar:
- Validar duplicados de CODIGO SKU.
- Detectar registros sin status.
- Revisar asignados sin responsable.
- Separar personas de ubicaciones/custodios no personales.
- No importar automáticamente registros ambiguos.

## Documento de entrega
El formato de entrega del Excel se toma como formato oficial de referencia.

Debe incluir:
- N° de cargo único.
- Fecha.
- Apellidos y nombres.
- DNI.
- Cargo.
- Área.
- CeCo.
- Tabla de activos: SKU, descripción, marca, modelo, serie, IMEI, condición, estado funcional, accesorios, costo, observación.
- Total.
- Firma receptor.
- Firma logística.

El sistema debe generar un documento real (PDF recomendado para evidencia; DOCX opcional para edición), no HTML renombrado como .doc.
