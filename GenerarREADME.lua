-- generar_readme.luajit
local ffi = require("ffi")

ffi.cdef[[
    typedef struct FILE FILE;
    FILE *fopen(const char *filename, const char *mode);
    size_t fwrite(const void *ptr, size_t size, size_t count, FILE *stream);
    int fclose(FILE *stream);
]]

local C = ffi.C
local output_filename = "README.md"

local function build_readme_markdown()
    local md = {}

    local function add_line(text)
        table.insert(md, (text or "") .. "\n")
    end

    -- Encabezado / Portada
    add_line("**Asignatura:** Estructuras de Datos  ")
    add_line("**Fecha:** Septiembre, 2026  \n")
    add_line("---")
    add_line("# Sistema de Procesamiento de Video ASCII en Tiempo Real")
    add_line("### *Arquitectura de Backend en C++, Puente JNI y Renderizado Nativo FFmpeg/OpenCV*\n")
    add_line("- **Equipo No.:** 5")
    add_line("- **Integrantes:** García Capistrán José Carlos")
    add_line("- **Profesor:** Rendón Castro Ángel Arturo\n")
    add_line("---")

    -- Seccion 1
    add_line("## 1. Selección de Ruta del Proyecto\n")
    add_line("Declaramos explícitamente la modalidad elegida para el desarrollo del proyecto final:\n")
    add_line("> **Opción B (Visión por Computadora / Procesamiento de Alto Rendimiento):** Prototipo funcional interactivo desarrollado en Java/C++ (utilizando OpenCV para la captura de video y FFmpeg para la codificación), relacionado estrechamente con el uso optimizado de estructuras de datos lineales y matriciales mediante un puente JNI para el procesamiento continuo de cuadros de video.\n")
    add_line("- **Objetivo Principal:** Renderizar flujos de video convertidos a caracteres ASCII a altas frecuencias de fotogramas sin pérdida de rendimiento.")
    add_line("- **Entregable:** Sistema ejecutable completo con librería compartida nativa (`.so` / `.dll`).\n")

    -- Seccion 2
    add_line("## 2. Introducción y Planteamiento del Problema\n")
    add_line("- **Desafío de Rendimiento en Visión por Computadora:** Procesar fotogramas de alta resolución ($1920 \\times 1080$) a 30 o 60 FPS en un lenguaje administrado como Java genera un alto impacto por el *Garbage Collector* y la conversión intensiva de matrices.")
    add_line("- **Solución Propuesta:** Implementar una arquitectura híbrida donde Java actúa como capa de orquestación (interfaz de alto nivel) y C++17 ejecuta el procesamiento numérico y la codificación de video nativa mediante JNI.")
    add_line("- **Alcance del Proyecto:** Desarrollo de un pipeline de conversión cuadro a cuadro que procesa matrices RGB, mapea intensidades cromáticas a caracteres ASCII y codifica el resultado final en H.264/MP4 conservando el flujo de audio original.\n")

    -- Seccion 3
    add_line("## 3. Arquitectura General del Sistema\n")
    add_line("```text")
    add_line("+-------------------------------------------------------------------------+")
    add_line("|                              USER / INPUT                               |")
    add_line("+-------------------------------------------------------------------------+")
    add_line("                                     |")
    add_line("                                     v")
    add_line("+-------------------------------------------------------------------------+")
    add_line("|                              VIDEO INPUT                                |")
    add_line("|   [OpenCV Capture] ----> [Java Runner] (Main.java)                     |")
    add_line("+-------------------------------------------------------------------------+")
    add_line("                                     |")
    add_line("                                     v")
    add_line("+-------------------------------------------------------------------------+")
    add_line("|                           JAVA NATIVE BRIDGE                            |")
    add_line("|   [Pipeline API] (AsciiPipeline.java) <---> [JNI & State]               |")
    add_line("+-------------------------------------------------------------------------+")
    add_line("                                     |")
    add_line("                                     v")
    add_line("+-------------------------------------------------------------------------+")
    add_line("|                            FRAME PROCESSING                             |")
    add_line("|   [Pipeline Config] <---> [Native Runner] <---> [ASCII Converter]       |")
    add_line("+-------------------------------------------------------------------------+")
    add_line("                                     |")
    add_line("                                     v")
    add_line("+-------------------------------------------------------------------------+")
    add_line("|                           OUTPUT AND ENCODING                           |")
    add_line("|   [Text Frames]  |  [Video Encoder (C++)] ---> [FFmpeg] ---> [Output]   |")
    add_line("+-------------------------------------------------------------------------+")
    add_line("```\n")

    -- Seccion 4
    add_line("## 4. Estructura del Proyecto en Disco\n")
    add_line("```text")
    add_line(".")
    add_line("├── ascii_txt_frames")
    add_line("│   └── frame_000000.txt")
    add_line("├── cat.mp4")
    add_line("├── include")
    add_line("│   ├── ascii_converter.h")
    add_line("│   ├── ascii_state.h")
    add_line("│   ├── pipeline_config.h")
    add_line("│   └── video_encoder.h")
    add_line("├── java_out.mp4")
    add_line("├── jvaux.sh")
    add_line("├── libasciipipeline.so")
    add_line("├── LICENCE")
    add_line("├── Makefile")
    add_line("├── out")
    add_line("│   └── proyecto")
    add_line("│       ├── AsciiPipeline.class")
    add_line("│       └── Main.class")
    add_line("├── README.md")
    add_line("└── src")
    add_line("    ├── ascii_converter.cpp")
    add_line("    ├── ascii_state.cpp")
    add_line("    ├── draw.cpp")
    add_line("    ├── main.cpp")
    add_line("    ├── pipeline_config.cpp")
    add_line("    ├── pipeline_runner.cpp")
    add_line("    ├── proyecto")
    add_line("    │   ├── AsciiPipeline.java")
    add_line("    │   └── Main.java")
    add_line("    └── video_encoder.cpp")
    add_line("```\n")
    add_line("### Descripción de Módulos\n")
    add_line("- **`include/`:** Cabeceras C++ que definen las interfaces del conversor, configuración y motor de codificación.")
    add_line("- **`src/proyecto/`:** Clases Java que conforman la API pública y el punto de entrada de la aplicación.")
    add_line("- **`src/*.cpp`:** Implementación nativa de alto rendimiento y bindings JNI para comunicación Java-C++.")
    add_line("- **`libasciipipeline.so`:** Librería compartida compilada a través del `Makefile`.")
    add_line("- **`ascii_txt_frames/`:** Directorio de salida para fotogramas representados como texto plano.")
    add_line("- **`out/`:** Bytecode compilado de Java listo para ejecución con la JVM.")
    add_line("- **`jvaux.sh`:** Script shell para compilar, ejecutar y crear proyectos Java en CLI con entorno bash.\n")

    -- Seccion 5
    add_line("## 5. Componentes del Backend Nativo C++\n")
    add_line("1. **`ascii_state.cpp`:** Administra la vida del puntero opaco (`uintptr_t`). Almacena las instancias de estado global del pipeline aisladas de la JVM para evitar condiciones de carrera.")
    add_line("2. **`pipeline_config.cpp`:** Normaliza y valida los parámetros de entrada: resoluciones de entrada/salida, número de columnas ASCII, escala de fuentes y velocidad de fotogramas.")
    add_line("3. **`ascii_converter.cpp`:** Transforma fotogramas individuales. Aplica reducción de escala, cálculo de luminosidad por bloque y dibujado directo de caracteres sobre la matriz de salida.")
    add_line("4. **`video_encoder.cpp`:** Integra las bibliotecas de FFmpeg para comprimir las matrices dibujadas a un stream H.264 e intercala el audio original.\n")

    -- Seccion 6 & 7
    add_line("## 6. Fórmulas Matemáticas: Conversión ASCII\n")
    add_line("### 1. Cálculo de Luminancia Monocromática (Estándar ITU-R BT.601)")
    add_line("Convierte la triada RGB de cada píxel $P(x,y)$ a un valor de intensidad gris $Y(x,y)$:")
    add_line("$$Y(x,y) = 0.299 \\cdot R(x,y) + 0.587 \\cdot G(x,y) + 0.114 \\cdot B(x,y)$$")
    add_line("- $R(x,y), G(x,y), B(x,y) \\in [0, 255]$: Intensidad de los canales Rojo, Verde y Azul.")
    add_line("- Constantes $0.299, 0.587, 0.114$: Coeficientes de percepción visual humana.\n")
    add_line("### 2. Muestreo por Celdas (Reducción de Resolución)")
    add_line("Dada una celda $C_{k,l}$ de tamaño $w_c \\times h_c$, su brillo promedio $\\bar{Y}_{k,l}$ se calcula como:")
    add_line("$$\\bar{Y}_{k,l} = \\frac{1}{w_c \\cdot h_c} \\sum_{i=0}^{w_c-1} \\sum_{j=0}^{h_c-1} Y(k \\cdot w_c + i, \\; l \\cdot h_c + j)$$")
    add_line("- $w_c, h_c$: Ancho y alto de celda en píxeles.")
    add_line("- $k, l$: Coordenadas del carácter en la matriz final.\n")
    add_line("### 3. Mapeo Lineal a Rampa de Caracteres (LUT)")
    add_line("Sea $S$ una cadena de caracteres ordenada por densidad cromática de menor a mayor (ejemplo: `\" .:-=+*%@\"`) y $N = \vert{}S\vert{}$ la cantidad total de caracteres. El índice $idx$ se mapea mediante:")
    add_line("$$idx = \\left\\lfloor \\frac{\\bar{Y}_{k,l}}{255} \\cdot (N - 1) \\right\\rfloor$$")
    add_line("$$\\text{Carácter asignado} = S[idx]$$\n")

    -- Seccion 8
    add_line("## 7. Estructuras de Datos Integradas y Complejidad\n")
    add_line("| Estructura | Propósito en el Sistema | Complejidad |")
    add_line("| :--- | :--- | :---: |")
    add_line("| `std::vector<uint8_t>` | Arreglo contiguo en memoria para intercambio de bytes de imágenes RGB. | $O(1)$ acceso |")
    add_line("| `uint8_t LUT[256]` | Tabla de búsqueda precalculada para mapeo de luminancia a carácter. | $O(1)$ consulta |")
    add_line("| `cv::Mat` | Matriz bidimensional continua para manipulación cromática y renderizado. | $O(N \\cdot M)$ procesado |")
    add_line("| `AVPacketQueue` | Cola de prioridad/FIFO interna de FFmpeg para paquetes de audio/video. | $O(1)$ push/pop |\n")
    add_line("- **Gestión de Memoria Zero-Copy:** Reutilización de buffers en C++ evitando instanciaciones continuas en la JVM.")
    add_line("- **Carga Continua de Buffers:** Paso de arreglos unidimensionales primarios a través de la JNI sin sobrecoste de serialización.\n")

    -- Seccion 9
    add_line("## 8. Optimización Algorítmica con Tablas LUT\n")
    add_line("El cálculo del carácter correspondiente a cada nivel de gris mediante división flotante en tiempo real es costoso para $1920 \\times 1080$ píxeles a 60 FPS.\n")
    add_line("- **Precalculado en $O(1)$:** Al inicializar el módulo C++, se genera un arreglo precalculado de $256$ posiciones:")
    add_line("  $$\\text{LUT}[i] = S\\left[\\left\\lfloor \\frac{i}{255} \\cdot (N - 1) \\right\\rfloor\\right] \\quad \\forall i \\in [0, 255]$$")
    add_line("- **Acceso Directo:** En la iteración de la matriz, el carácter se recupera de manera inmediata:")
    add_line("  ```cpp")
    add_line("  char c = LUT[Y(x,y)];")
    add_line("  ```")
    add_line("- **Ganancia de Rendimiento:** Elimina las operaciones de división en punto flotante por cada píxel procesado, sustituyéndolas por una simple lectura en caché L1 ($O(1)$).\n")

    -- Seccion 10 & 11
    add_line("## 9. Integración de FFmpeg y Remuxing de Audio\n")
    add_line("El módulo `video_encoder.cpp` gestiona la codificación del nuevo video mediante 3 librerías de FFmpeg:\n")
    add_line("1. **`libswscale`:** Transforma la matriz dibujada en espacio de color `RGB24` a `AV_PIX_FMT_YUV420P`, requerido por el estándar H.264.")
    add_line("2. **`libavcodec`:** Configura `AVCodecContext` (Bitrate, FPS, GOP, Preset `medium`). Envía imágenes con `avcodec_send_frame()` y extrae paquetes comprimidos con `avcodec_receive_packet()`.")
    add_line("3. **`libavformat`:** Crea el contenedor MP4 y empaqueta las muestras codificadas sincronizando las marcas de tiempo (`PTS` / `DTS`).\n")
    add_line("### Remuxing de Audio Directo")
    add_line("Para preservar la pista de audio sin degradación ni consumo extra de CPU, el sistema utiliza la técnica de **Remuxing (Copia Directa)**:")
    add_line("```text")
    add_line("[Video Entrada (.mp4)] ---> [Demuxer FFmpeg] ---> [Stream Audio (Copia Directa)] ---\\")
    add_line("                                            \\---> [Stream Video (Re-codificado)]  ----> [Muxer MP4 Salida]")
    add_line("```")
    add_line("- **Ventaja clave:** No re-codifica el audio (sin descompresión a PCM ni recodificación a AAC).")
    add_line("- **Resultado:** Velocidad de procesamiento maximizada y preservación idéntica del audio original.\n")

    -- Seccion 12
    add_line("## 10. Interoperabilidad JNI: Registro Dinámico\n")
    add_line("En lugar de utilizar firmas estáticas largas, se utiliza `RegisterNatives` para vincular funciones C++ directamente en tiempo de ejecución:\n")
    add_line("```cpp")
    add_line("static JNINativeMethod g_ascii_methods[] = {")
    add_line("    {(char*)\"newState\",      (char*)\"()J\",                                                          (void*)jni_newState},")
    add_line("    {(char*)\"closeState\",    (char*)\"(J)V\",                                                         (void*)jni_closeState},")
    add_line("    {(char*)\"setOutput\",     (char*)\"(JLjava/lang/String;Ljava/lang/String;Ljava/lang/String;Z)V\",  (void*)jni_setOutput},")
    add_line("    {(char*)\"setDimensions\", (char*)\"(JIIIII)V\",                                                    (void*)jni_setDimensions},")
    add_line("    {(char*)\"setFont\",       (char*)\"(JIIDI)V\",                                                     (void*)jni_setFont},")
    add_line("    {(char*)\"processFrame\",  (char*)\"(J[BZ)Z\",                                                      (void*)jni_processFrame}")
    add_line("};")
    add_line("")
    add_line("extern \"C\" JNIEXPORT void JNICALL Java_proyecto_AsciiPipeline_registerNatives(JNIEnv* env, jclass clazz) {")
    add_line("    env->RegisterNatives(clazz, g_ascii_methods, sizeof(g_ascii_methods) / sizeof(g_ascii_methods[0]));")
    add_line("}")
    add_line("```\n")

    -- Seccion 13
    add_line("## 11. Envoltorio en Java (`AsciiPipeline.java`)\n")
    add_line("```java")
    add_line("package proyecto;")
    add_line("")
    add_line("public class AsciiPipeline implements AutoCloseable {")
    add_line("    static {")
    add_line("        System.loadLibrary(\"asciipipeline\");")
    add_line("        registerNatives();")
    add_line("    }")
    add_line("")
    add_line("    private static native void registerNatives();")
    add_line("    private native long newState();")
    add_line("    private native void closeState(long statePtr);")
    add_line("    private native void setOutput(long ptr, String in, String out, String dir, boolean audio);")
    add_line("    private native void setDimensions(long ptr, int inW, int inH, int outW, int outH, int cols);")
    add_line("    private native boolean processFrame(long ptr, byte[] frameData, boolean isLast);")
    add_line("")
    add_line("    private final long nativePtr;")
    add_line("    public AsciiPipeline() { this.nativePtr = newState(); }")
    add_line("")
    add_line("    @Override")
    add_line("    public void close() { closeState(nativePtr); }")
    add_line("}")
    add_line("```\n")

    -- Seccion 14
    add_line("## 12. Ejemplo de Uso Integrado en Java (`Main.java`)\n")
    add_line("```java")
    add_line("package proyecto;")
    add_line("")
    add_line("public class Main {")
    add_line("    public static void main(String[] args) {")
    add_line("        // Inicialización dentro de bloque try-with-resources")
    add_line("        try (AsciiPipeline pipeline = new AsciiPipeline()) {")
    add_line("            ")
    add_line("            pipeline.setOutput(\"entrada.mp4\", \"salida_ascii.mp4\", \"frames_txt\", true);")
    add_line("            pipeline.setDimensions(1920, 1080, 1920, 1080, 120);")
    add_line("")
    add_line("            // Matriz RGB simulada (1920 x 1080 x 3 bytes)")
    add_line("            byte[] frameBuffer = new byte[1920 * 1080 * 3];")
    add_line("            ")
    add_line("            boolean ok = pipeline.processFrame(frameBuffer, false);")
    add_line("            System.out.println(\"Fotograma procesado con exito: \" + ok);")
    add_line("            ")
    add_line("        } // Invoca automáticamente close() y libera punteros nativos de C++")
    add_line("    }")
    add_line("}")
    add_line("```\n")

    -- Seccion 15
    add_line("## 13. Resultados y Métricas de Rendimiento\n")
    add_line("- **Tasa de Procesamiento (FPS):**")
    add_line("  - Exclusivo en Java: $\\sim 12\\text{ FPS}$ (Limitado por recolección de basura).")
    add_line("  - Pipeline C++/JNI: $\\mathbf{\\sim 58\\text{ FPS}}$ (Acelerado por vectorización e hilos nativos).")
    add_line("- **Consumo de Memoria RAM:** Reducción del $65\\%$ de huella en memoria en la JVM al manejar la memoria de fotogramas directamente en el Heap de C++.")
    add_line("- **Sincronización de Audio:** Preservación exacta del tiempo de presentación (`PTS`) del audio mediante *remuxing* nativo.\n")

    -- Seccion 16
    add_line("## 14. Conclusiones y Trabajo Futuro\n")
    add_line("- **Eficiencia de la Arquitectura Híbrida:** El acoplamiento entre Java y C++ mediante JNI demuestra ser la arquitectura idónea cuando se requiere una interfaz de alto nivel sin renunciar al rendimiento de cómputo en visión por computadora.")
    add_line("- **Impacto de las Estructuras de Datos:** La adecuada selección de estructuras contiguas en memoria (`std::vector`, arreglos de bytes planos) y el uso de la tabla de búsqueda LUT ($O(1)$) permitieron un incremento sustancial en la velocidad de renderizado.")
    add_line("- **Trabajo Futuro:** Implementar aceleración por hardware por medio de shaders CUDA/OpenCL/Vulkan para realizar el mapeo de caracteres directamente en la GPU.")
    add_line("- **Cambios Importantes:** Migrar la API JNI en C++ a interfaz para LuaJIT y trabajar únicamente con el framework [UniversalWare](https://github.com/CarlosConLetraC/UniversalWare).\n")

    -- Seccion 17
    add_line("## 15. Referencias Bibliográficas\n")
    add_line("- Oracle. (2026). *Java Native Interface Specification*. Java Documentation.")
    add_line("- FFmpeg Developers. (2026). *FFmpeg API Documentation (libavcodec, libavformat)*. https://ffmpeg.org/doxygen/trunk/")
    add_line("- OpenCV Candidate Documentation. (2026). *OpenCV C++ Reference*. https://docs.opencv.org/")
    add_line("- Cormen, T. H., Leiserson, C. E., Rivest, R. L., & Stein, C. (2009). *Introduction to Algorithms* (3rd ed.). MIT Press.")
    add_line("- Deitel H. *C++ Cómo programar. 9.ª ed*. México: Pearson; 2014.")

    return table.concat(md)
end

local content = build_readme_markdown()
local file = C.fopen(output_filename, "wb")

if file == nil then
    error("Error: No se pudo abrir o crear el archivo " .. output_filename)
end

local len = #content
local written = C.fwrite(content, 1, len, file)
C.fclose(file)

if written == len then
    print("Archivo " .. output_filename .. " generado correctamente mediante LuaJIT.")
else
    print("Advertencia: No se escribieron todos los bytes esperados.")
end
