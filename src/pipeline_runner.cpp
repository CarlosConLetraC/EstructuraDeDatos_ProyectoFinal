#include "ascii_converter.h"
#include "video_encoder.h"
#include "pipeline_config.h"
#include <iostream>
#include <memory>
#include <vector>

static std::unique_ptr<AsciiConverter> g_converter = nullptr;
static std::unique_ptr<VideoEncoder> g_encoder = nullptr;
static std::vector<unsigned char> g_canvasBuffer;
static int g_frameCounter = 0;

extern "C" {
    bool process_ascii_video_pipeline(PipelineConfig* userConfig, const unsigned char* rawRgbInput, bool isLastFrame) {
        if (!userConfig) return false;

        pipeline_new_config(userConfig);

        if (!g_encoder) {
            g_encoder = std::make_unique<VideoEncoder>();
            std::string sourcePath = (userConfig->inputFile) ? userConfig->inputFile : "";
            if (!g_encoder->init(*userConfig, sourcePath)) {
                std::cerr << "[C++] Error al inicializar VideoEncoder con FFmpeg." << std::endl;
                return false;
            }
        }

        if (!g_converter) {
            g_converter = std::make_unique<AsciiConverter>(userConfig->asciiCharset, userConfig);
            g_frameCounter = 0;
        }

        if (rawRgbInput != nullptr) {
            g_converter->processFrameToAsciiCanvas(
                rawRgbInput, 
                *userConfig, 
                g_canvasBuffer, 
                g_frameCounter++
            );
            g_encoder->encodeFrame(g_canvasBuffer.data(), userConfig->outW, userConfig->outH);
        }

        if (isLastFrame) {
            g_encoder->close();
            g_encoder.reset();
            g_converter.reset();
            g_canvasBuffer.clear();
            g_frameCounter = 0;
            std::cout << "[C++] Pipeline de video guardado y recursos liberados." << std::endl;
        }

        return true;
    }
}