#pragma once
#include <jni.h> // necesario para crear el puente a Java mediante Java Native Interface
// NOTA: ajuste la ruta de java native interface.h de acuerdo con su entorno.
#include "pipeline_config.h"

#ifdef __cplusplus
extern "C" {
#endif

// Tipo opaco similar a lua_State
typedef struct AsciiState AsciiState;

// API C para gestionar el ciclo de vida del estado
AsciiState* ascii_newState(void);
void ascii_closeState(AsciiState* A);

// Métodos de configuración sobre el estado
void ascii_set_output(AsciiState* A, const char* inputFile, const char* outputFile, const char* txtOutputDir, bool preserveAudio);
void ascii_set_dimensions(AsciiState* A, int inW, int inH, int outW, int outH, int asciiCols);
void ascii_set_font(AsciiState* A, int cellW, int cellH, double fontScale, int thickness);
void ascii_set_fps(AsciiState* A, int fps);
void ascii_set_charset(AsciiState* A, const char* asciiCharset);

// Ejecución
bool ascii_process_frame(AsciiState* A, const unsigned char* rawRgbInput, bool isLastFrame);

// Punto de entrada invocado por la JVM (System.loadLibrary) para el registro dinámico JNI
JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM* vm, void* reserved);

#ifdef __cplusplus
}
#endif
