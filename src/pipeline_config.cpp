#include "pipeline_config.h"
#include <cstring>
#include <cstdlib>

void pipeline_new_config(PipelineConfig* plc) {
    if (!plc) return;

    // Cadenas / C-strings (asignación en heap con strdup para evitar free(): invalid pointer)
    plc->inputFile    = (plc->inputFile != nullptr)    ? plc->inputFile    : strdup("");
    plc->outputFile   = (plc->outputFile != nullptr)   ? plc->outputFile   : strdup("output.mp4");
    plc->txtOutputDir = (plc->txtOutputDir != nullptr) ? plc->txtOutputDir : strdup("ascii_txt_frames");
    plc->asciiCharset = (plc->asciiCharset != nullptr) ? plc->asciiCharset : strdup(" !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~");

    // Dimensiones y rendimiento
    plc->fps       = (plc->fps > 0)       ? plc->fps       : 30;
    plc->inW       = (plc->inW > 0)       ? plc->inW       : 1280;
    plc->inH       = (plc->inH > 0)       ? plc->inH       : 720;
    plc->asciiCols = (plc->asciiCols > 0) ? plc->asciiCols : 160;
    plc->outW      = (plc->outW > 0)      ? plc->outW      : 1280;
    plc->outH      = (plc->outH > 0)      ? plc->outH      : 720;

    // Banderas (-1: No definido / Usa valor por defecto true)
    plc->saveTxtFrames = (plc->saveTxtFrames >= 0) ? plc->saveTxtFrames : 1;
    // preserveAudio no se toca, ya que se inicializa por defecto en el PipelineConfig.

    // Configuración de fuente por defecto para densidad
    plc->font.cellW     = (plc->font.cellW > 0)     ? plc->font.cellW     : 32;
    plc->font.cellH     = (plc->font.cellH > 0)     ? plc->font.cellH     : 32;
    plc->font.fontFace  = (plc->font.fontFace >= 0) ? plc->font.fontFace  : 0; // cv::FONT_HERSHEY_PLAIN := 0
    plc->font.fontScale = (plc->font.fontScale > 0) ? plc->font.fontScale : 0.1;
    plc->font.thickness = (plc->font.thickness > 0) ? plc->font.thickness : 1;
}

void pipeline_free_config(PipelineConfig* plc) {
    if (!plc) return;

    // Liberación de memoria dinámica y limpieza de punteros con ternarios
    plc->inputFile    ? (free((void*)plc->inputFile),    plc->inputFile = nullptr)    : nullptr;
    plc->outputFile   ? (free((void*)plc->outputFile),   plc->outputFile = nullptr)   : nullptr;
    plc->txtOutputDir ? (free((void*)plc->txtOutputDir), plc->txtOutputDir = nullptr) : nullptr;
    plc->asciiCharset ? (free((void*)plc->asciiCharset), plc->asciiCharset = nullptr) : nullptr;
}