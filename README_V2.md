# TAKIPUKARA PATRIMONIO V2

Esta rama prepara la evolución del prototipo hacia un sistema de trazabilidad patrimonial para operación minera.

## Principios

- QR permanente por activo.
- Historial de movimientos sin borrar trazabilidad.
- Cargos de entrega atómicos.
- Autenticación con Supabase Auth.
- Autorización con roles + Row Level Security.
- Evidencias almacenadas en bucket privado.
- Separación entre activo, persona, ubicación, cargo y movimiento.
- Acceso público al QR limitado a datos no sensibles.

## Estructura prevista

```
frontend/
  dashboard-v2.html
  ver-v2.html
  js/

supabase/
  migrations/
    001_core_schema.sql

docs/
  ROADMAP_V2.md
```

## Puesta en marcha

1. Ejecutar `supabase/migrations/001_core_schema.sql` en el SQL Editor de Supabase.
2. Crear usuarios mediante Supabase Auth.
3. Crear su fila correspondiente en `profiles` con el rol adecuado.
4. Crear el bucket privado `evidencias`.
5. Configurar las políticas de Storage para usuarios autenticados.
6. Verificar datos existentes antes de migrarlos desde las tablas antiguas.
7. Mantener `main` como respaldo hasta validar V2 en pruebas.

## Nota

La clave anon de Supabase puede existir en el frontend; la seguridad no debe depender de ocultarla. La protección real debe estar en RLS, políticas de Storage y funciones transaccionales.
