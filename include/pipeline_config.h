#pragma once

typedef struct FontConfig {
    int cellW;
    int cellH;
    int fontFace;
    double fontScale;
    int thickness;
} FontConfig;

typedef struct PipelineConfig {
    const char* inputFile = nullptr;
    const char* outputFile = nullptr;
    const char* txtOutputDir = nullptr;
    const char* asciiCharset = nullptr;

    // Se inicializan en -1 como valor centinela "no establecido"
    int fps = -1;
    int inW = -1;
    int inH = -1;
    int asciiCols = -1;
    int outW = -1;
    int outH = -1;
    int saveTxtFrames = -1; // -1: No definido, 0: false, 1: true
    bool preserveAudio = true;

    // Unión con configuración de tipografía para cálculo de densidad
    union {
        FontConfig font;
    };
} PipelineConfig;

#ifdef __cplusplus
extern "C" {
#endif

void pipeline_new_config(PipelineConfig* plc);
void pipeline_free_config(PipelineConfig* plc);

#ifdef __cplusplus
}
#endif