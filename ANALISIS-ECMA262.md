# Auditoría de compatibilidad ECMAScript

Fecha: 2026-10-12. Alcance: fuentes, API pública, documentación, configuración de distribución y pruebas de `z-urlcode` 0.1.0.

## Dictamen

**Cobertura de operaciones URI: 4 de 4, equivalente al 100 % del inventario declarado.** Los algoritmos revisados son compatibles con ECMAScript en el dominio de cadenas UTF-8 válidas: no se encontraron discrepancias en la inspección ni en las pruebas diferenciales realizadas.

**Compatibilidad completa con las funciones JavaScript: no alcanza el 100 %.** La API tiene un dominio de entrada más reducido y omite la conversión `ToString`. Excluir `prototype` no elimina esas diferencias. Estas cuatro funciones son propiedades del objeto global; su algoritmo no requiere métodos de `prototype`.

El repositorio declara implementar la sección de funciones URI, no el objeto global completo ni `Object`. No corresponde exigirle las demás funciones de ECMAScript para evaluar su alcance actual.

## Inventario y correspondencia

| Operación ECMAScript | API Zig | Resultado de la revisión |
|---|---|---|
| `encodeURI(s)` | `encode(allocator, s, .uri)` | Implementada para UTF-8 válido |
| `encodeURIComponent(s)` | `encode(allocator, s, .component)` | Implementada para UTF-8 válido |
| `decodeURI(s)` | `decode(allocator, s, true)` | Implementada para UTF-8 válido |
| `decodeURIComponent(s)` | `decode(allocator, s, false)` | Implementada para UTF-8 válido |

La ausencia de cuatro nombres exportados individuales no supone una operación faltante: los modos de las dos funciones públicas cubren las cuatro operaciones.

Se comprobó lo siguiente:

- Caracteres sin escape: letras ASCII, dígitos y `-_.!~*'()`.
- Reservados preservados por `encodeURI`: `;/?:@&=+$,#`.
- `decodeURI` preserva también la escritura original del escape reservado, incluido su uso de mayúsculas o minúsculas.
- Codificación UTF-8 con escapes hexadecimales en mayúsculas y tratamiento correcto de caracteres fuera del BMP.
- Rechazo de escapes truncados, dígitos inválidos, continuaciones incorrectas, codificaciones sobrelargas, sustitutos codificados y puntos mayores que U+10FFFF.
- Decodificación en una sola pasada: `%252F` produce `%2F`; no vuelve a decodificarlo.
- `+` sigue siendo `+`; estas funciones no aplican la semántica de formularios que convierte `+` en espacio.
- Conservación de NUL, BOM y valores escalares no asignados o no caracteres, sin normalización Unicode.

Referencia normativa: [ECMA-262, URI Handling Functions](https://tc39.es/ecma262/multipage/global-object.html#sec-uri-handling-functions).

## Diferencias que impiden afirmar equivalencia completa

### 1. Dominio de cadenas UTF-16

Ubicación: `src/encode.zig:21`, `src/zurlcode.zig:3`, `README.md:33`.

JavaScript admite cadenas con sustitutos UTF-16 aislados. Ejemplos comprobados con Node.js:

```javascript
encodeURI("\uD800")          // URIError
encodeURIComponent("\uD800") // URIError
decodeURI("\uD800")          // devuelve el sustituto sin modificar
decodeURIComponent("\uD800") // devuelve el sustituto sin modificar
```

La API documentada de Zig usa UTF-8 válido, que no representa esos valores. Si se pasan los bytes WTF-8 `ED A0 80` a `encode`, devuelve `InvalidUtf8`; el anfitrión tendría que traducirlo a `URIError` cuando corresponda. `decode` copia bytes sin escape y puede conservar esos bytes, pero eso no constituye un contrato documentado de compatibilidad UTF-16/WTF-8.

La limitación afecta a la representación y al contrato de ambas direcciones. No basta con documentar únicamente el caso de error de `encode`.

Para cubrir todas las cadenas JavaScript sería necesario definir una interfaz UTF-16 o un contrato WTF-8 explícito: rechazar sustitutos aislados en codificación y conservarlos cuando aparezcan sin escape en decodificación. Los sustitutos escapados, como `%ED%A0%80`, deben continuar produciendo error.

### 2. Conversión de argumentos y errores JavaScript

Ubicación: `src/encode.zig:17`, `src/decode.zig:44`, `src/errors.zig`.

Las funciones ECMAScript realizan `ToString` antes del algoritmo. Esta biblioteca recibe exclusivamente `[]const u8`. No implementa conversiones de números, booleanos, `null`, `undefined`, objetos ni el error de conversión de símbolos.

Ejemplos: JavaScript admite `encodeURIComponent(123)` y `decodeURI()`; la API Zig exige que el anfitrión proporcione previamente las cadenas correspondientes. Si se busca una biblioteca de transformaciones tipadas, esta separación es razonable y debe figurar como parte del alcance. Si se busca una implementación completa de las funciones globales JavaScript, falta esa capa.

`MalformedUri` es una traducción apropiada de los fallos del algoritmo `Decode`; las excepciones JavaScript concretas requieren integración del anfitrión. `OutOfMemory` responde al modelo de memoria de Zig y no es un defecto del algoritmo URI.

### 3. Contrato de entrada inconsistente fuera del dominio válido

Ubicación: `src/encode.zig:21`, `src/decode.zig:50`.

`encode` valida toda la entrada, pero `decode` valida únicamente los octetos provenientes de escapes. Comprobación: `decode(allocator, "\xff", false)` devuelve `FF` sin error.

Esto no contradice ECMAScript para el dominio de UTF-8 válido, pero significa que `[]const u8` no garantiza por sí mismo la precondición anunciada. Conviene documentar expresamente la responsabilidad del llamador o definir una validación consistente. Agregar validación UTF-8 estricta a `decode` no solucionaría por sí solo la compatibilidad con sustitutos UTF-16.

## Evidencia ejecutada

Entorno: Node.js v26.5.0, Zig 0.16.0 y Zig 0.17.0.

| Verificación | Cobertura | Resultado |
|---|---|---|
| Suite del repositorio | 18 tests, Zig 0.16.0 | 18/18 pasan |
| Suite del repositorio | 18 tests, Zig 0.17.0 | 18/18 pasan |
| Codificación diferencial | Cadena con los 1.112.064 valores escalares Unicode, ambos modos | Sin diferencias |
| Decodificación diferencial de Unicode | Codificación componente de esa cadena, ambos modos, resultados esperados de Node.js | Sin diferencias |
| Decodificación diferencial de casos individuales | 321.570 entradas, cada una en ambos modos: 643.140 comparaciones | Sin diferencias |
| Sondeos del contrato | WTF-8 rechazado por `encode`; byte inválido literal conservado por `decode` | Comportamiento confirmado |

Las entradas individuales incluyen los 256 octetos escapados, las 65.536 parejas posibles de octetos, 40.960 combinaciones de tres octetos, 204.800 combinaciones de cuatro octetos seleccionadas por fronteras de validación, 18 casos específicos y 10.000 cadenas generadas con semilla fija.

La prueba Unicode usa una cadena concatenada que contiene todos los valores escalares, no 1.112.064 llamadas independientes por función. La selección de entradas inválidas no enumera todas las cadenas posibles. El éxito de estas pruebas aporta evidencia fuerte y no equivale a una demostración matemática universal.

No se ejecutó la suite oficial Test262. Las pruebas existentes mencionan Test262, pero no contienen un ejecutor de esa suite ni acreditan su cobertura completa.

## Reproducción de la auditoría

Los archivos auxiliares están en `/tmp/z-urlcode-audit/`: `generate.cjs` genera las expectativas con Node.js y `audit.zig` las compara con la biblioteca. No se modificaron las implementaciones ni los tests del repositorio. Los archivos de `/tmp` son temporales.

```bash
cd /home/sweb/z-urlcode
ZIG_GLOBAL_CACHE_DIR=/tmp/z-urlcode-audit-cache zig build test --summary all
node /tmp/z-urlcode-audit/generate.cjs
ZIG_GLOBAL_CACHE_DIR=/tmp/z-urlcode-audit-cache zig build-exe \
  --dep zurlcode \
  -Mroot=/tmp/z-urlcode-audit/audit.zig \
  -Mzurlcode=/home/sweb/z-urlcode/src/zurlcode.zig \
  -femit-bin=/tmp/z-urlcode-audit/audit
cd /tmp/z-urlcode-audit
./audit
```

Para repetir con 0.16.0, usar el ejecutable de esa versión y una caché separada. La auditoría diferencial se ejecutó con ambas versiones.

## Observaciones secundarias

- Las referencias de los comentarios a `Encode` como 19.2.6.1 y `Decode` como 19.2.6.2 no coinciden con la especificación consultada: son 19.2.6.5 y 19.2.6.6, respectivamente. La referencia general 19.2.6 del README sigue siendo correcta.
- `build.zig.zon` excluye `tests/` de `.paths`, aunque `build.zig` lo necesita para su paso predeterminado. Un paquete filtrado mediante esa lista no llevaría la suite necesaria para ejecutar `zig build test`. Esto afecta a la distribución y verificación del paquete, no a los cuatro algoritmos importados por consumidores.
- Los tests permanentes no cubren explícitamente entradas inválidas de `encode`, preservación de escapes reservados en minúsculas ni errores de `decodeURI` en modo `true`. Las pruebas temporales de esta auditoría amplían esa evidencia; convendría incorporar los casos relevantes y una verificación diferencial reproducible al proyecto.

## Criterio para declarar el 100 %

Para el alcance **“cuatro transformaciones URI sobre UTF-8 válido, con conversión de valores y traducción de errores a cargo del anfitrión”**, están presentes todas las operaciones y no se detectaron defectos semánticos. Conviene publicar ese alcance explícito y mantener pruebas que lo respalden.

Para el alcance **“equivalencia completa con las cuatro funciones JavaScript, excluyendo prototype”**, todavía faltan un contrato para todas las cadenas UTF-16 y la capa de conversión/integración JavaScript. No sería correcto anunciar ese 100 % con la API actual.
