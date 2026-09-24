#include "ascii_state.h"
#include <cstdlib>
#include <cstring>
#include <new>

// Definición interna del Estado (privada para C++)
struct AsciiState {
    PipelineConfig config;
};

// Declaración externa del pipeline C/C++ nativo original
extern "C" bool process_ascii_video_pipeline(
    PipelineConfig* userConfig,
    const unsigned char* rawRgbInput, 
    bool isLastFrame
);

// API C PURA: 
AsciiState* ascii_newState(void) {
    AsciiState* A = new (std::nothrow) AsciiState();
    if (A) {
        // Limpiar la estructura antes de inicializar. . .
        // std::memset(&(A->config), 0, sizeof(PipelineConfig));
        A->config = PipelineConfig{};
        
        // Delegar la asignación en heap de valores por defecto a pipeline_config.cpp. . .
        pipeline_new_config(&(A->config));
    }
    return A;
}

void ascii_closeState(AsciiState* A) {
    if (A) {
        // Liberación centralizada de las cadenas en heap
        pipeline_free_config(&(A->config));
        delete A;
    }
}

void ascii_set_output(AsciiState* A, const char* inputFile, const char* outputFile, const char* txtOutputDir, bool preserveAudio) {
    if (!A) return;
    
    if (inputFile && strlen(inputFile) > 0) {
        if (A->config.inputFile) free((void*)A->config.inputFile);
        A->config.inputFile = strdup(inputFile);
    }
    if (outputFile && strlen(outputFile) > 0) {
        if (A->config.outputFile) free((void*)A->config.outputFile);
        A->config.outputFile = strdup(outputFile);
    }
    if (txtOutputDir && strlen(txtOutputDir) > 0) {
        if (A->config.txtOutputDir) free((void*)A->config.txtOutputDir);
        A->config.txtOutputDir = strdup(txtOutputDir);
    }

    A->config.preserveAudio = preserveAudio; 
}

void ascii_set_dimensions(AsciiState* A, int inW, int inH, int outW, int outH, int asciiCols) {
    if (!A) return;
    A->config.inW = inW;
    A->config.inH = inH;
    A->config.outW = outW;
    A->config.outH = outH;
    A->config.asciiCols = asciiCols;
}

void ascii_set_font(AsciiState* A, int cellW, int cellH, double fontScale, int thickness) {
    if (!A) return;
    A->config.font.cellW = cellW;
    A->config.font.cellH = cellH;
    A->config.font.fontScale = fontScale;
    A->config.font.thickness = thickness;
}

void ascii_set_fps(AsciiState* A, int fps) {
    if (!A) return;
    A->config.fps = fps;
}

void ascii_set_charset(AsciiState* A, const char* asciiCharset) {
    if (!A) return;
    if (asciiCharset && strlen(asciiCharset) > 0) {
        if (A->config.asciiCharset) free((void*)A->config.asciiCharset);
        A->config.asciiCharset = strdup(asciiCharset);
    }
}

bool ascii_process_frame(AsciiState* A, const unsigned char* rawRgbInput, bool isLastFrame) {
    if (!A) return false;
    return process_ascii_video_pipeline(&(A->config), rawRgbInput, isLastFrame);
}

/* ================ *
 * CAPA WRAPPER JNI *
 * ================ */

static jlong jni_newState(JNIEnv*, jobject) {
    return reinterpret_cast<jlong>(ascii_newState());
}

static void jni_closeState(JNIEnv*, jobject, jlong statePtr) {
    ascii_closeState(reinterpret_cast<AsciiState*>(statePtr));
}

static void jni_setOutput(JNIEnv* env, jobject, jlong statePtr, jstring inFile, jstring outFile, jstring outDir, jboolean preserveAudio) {
    AsciiState* A = reinterpret_cast<AsciiState*>(statePtr);
    const char* c_inFile  = inFile  ? env->GetStringUTFChars(inFile, nullptr)  : nullptr;
    const char* c_outFile = outFile ? env->GetStringUTFChars(outFile, nullptr) : nullptr;
    const char* c_outDir  = outDir  ? env->GetStringUTFChars(outDir, nullptr)  : nullptr;
    ascii_set_output(A, c_inFile, c_outFile, c_outDir, (preserveAudio != JNI_FALSE));
    if (inFile  && c_inFile)  env->ReleaseStringUTFChars(inFile, c_inFile);
    if (outFile && c_outFile) env->ReleaseStringUTFChars(outFile, c_outFile);
    if (outDir  && c_outDir)  env->ReleaseStringUTFChars(outDir, c_outDir);
}

static void jni_setDimensions(JNIEnv*, jobject, jlong statePtr, jint inW, jint inH, jint outW, jint outH, jint cols) {
    ascii_set_dimensions(reinterpret_cast<AsciiState*>(statePtr), inW, inH, outW, outH, cols);
}

static void jni_setFont(JNIEnv*, jobject, jlong statePtr, jint cellW, jint cellH, jdouble fontScale, jint thickness) {
    ascii_set_font(reinterpret_cast<AsciiState*>(statePtr), cellW, cellH, fontScale, thickness);
}

static void jni_setFps(JNIEnv*, jobject, jlong statePtr, jint fps) {
    ascii_set_fps(reinterpret_cast<AsciiState*>(statePtr), fps);
}

static void jni_setCharset(JNIEnv* env, jobject, jlong statePtr, jstring charset) {
    AsciiState* A = reinterpret_cast<AsciiState*>(statePtr);
    const char* c_charset = charset ? env->GetStringUTFChars(charset, nullptr) : nullptr;
    ascii_set_charset(A, c_charset);
    if (charset && c_charset) env->ReleaseStringUTFChars(charset, c_charset);
}

static jboolean jni_processFrame(JNIEnv* env, jobject, jlong statePtr, jbyteArray frameData, jboolean isLast) {
    AsciiState* A = reinterpret_cast<AsciiState*>(statePtr);
    jbyte* bytes = frameData ? env->GetByteArrayElements(frameData, nullptr) : nullptr;
    bool res = ascii_process_frame(A, reinterpret_cast<const unsigned char*>(bytes), isLast == JNI_TRUE);
    if (frameData && bytes) env->ReleaseByteArrayElements(frameData, bytes, JNI_ABORT);
    return res ? JNI_TRUE : JNI_FALSE;
}

// ============================================================================
// TABLA DE REGISTRO DINÁMICO DE MÉTODOS DE INSTANCIA
// ============================================================================

static JNINativeMethod g_ascii_methods[] = {
    {(char*)"newState",      (char*)"()J",                                                          (void*)jni_newState},
    {(char*)"closeState",    (char*)"(J)V",                                                         (void*)jni_closeState},
    {(char*)"setOutput",     (char*)"(JLjava/lang/String;Ljava/lang/String;Ljava/lang/String;Z)V",  (void*)jni_setOutput},
    {(char*)"setDimensions", (char*)"(JIIIII)V",                                                    (void*)jni_setDimensions},
    {(char*)"setFont",       (char*)"(JIIDI)V",                                                     (void*)jni_setFont},
    {(char*)"setFps",        (char*)"(JI)V",                                                        (void*)jni_setFps},
    {(char*)"setCharset",    (char*)"(JLjava/lang/String;)V",                                       (void*)jni_setCharset},
    {(char*)"processFrame",  (char*)"(J[BZ)Z",                                                      (void*)jni_processFrame}
};
/**
 * Estructura de registro dinámico de métodos nativos en JNI (JNINativeMethod).
 * Cada elemento define el mapeo entre Java y C++ mediante 3 campos:
 *
 *  1. (char*) Nombre del método en Java:
 *     Identificador exacto de la función nativa tal como se declaró en la clase Java.
 *
 *  2. (char*) Firma de tipo en JNI (JNI Type Signature):
 *     Descriptor del método con formato "(Parámetros)TipoDeRetorno".
 *     - Tipos primitivos: J = long, I = int, D = double, Z = boolean, V = void.
 *     - Arreglos: [B = byte[] (arreglo de bytes).
 *     - Objetos: Lclase/Completa; (ej. Ljava/lang/String; para String).
 *
 *  3. (void*) Puntero a la función en C++:
 *     Dirección de memoria de la función wrapper en C++ que responderá a la llamada.
 *     Se castea a (void*) para coincidir con la definición de la struct JNINativeMethod.
 */


// Método nativo estático invocado desde Java para auto-registrar los métodos
static void jni_registerNatives(JNIEnv* env, jclass clazz) {
    env->RegisterNatives(
        clazz, 
        g_ascii_methods, 
        sizeof(g_ascii_methods) / sizeof(g_ascii_methods[0])
    );
}

// Registro explícito del método estático usando la convención estándar de nombres JNI
extern "C" JNIEXPORT void JNICALL Java_proyecto_AsciiPipeline_registerNatives(JNIEnv* env, jclass clazz) {
    jni_registerNatives(env, clazz);
}

JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM* vm, void* reserved) {
    (void)reserved;
    JNIEnv* env = nullptr;
    if (vm->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_8) != JNI_OK) return JNI_ERR;
    return JNI_VERSION_1_8;
}