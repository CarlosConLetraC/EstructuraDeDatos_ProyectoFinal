#include "ascii_converter.h"
#include "video_encoder.h"
#include "pipeline_config.h"
#include <iostream>
#include <memory>
#include <vector>
#include <cmath>

#ifdef TEST_BUILD
#include <opencv2/opencv.hpp>
#endif

extern "C" bool process_ascii_video_pipeline(PipelineConfig* userConfig, const unsigned char* rawRgbInput, bool isLastFrame);

#ifdef TEST_BUILD
int main(int argc, char** argv) {
    if (argc < 2) {
        std::cerr << "[C++ Test Error] Debe especificar la ruta del video de entrada.\n";
        std::cerr << "Uso: ./bin/test_runner <ruta_al_video> [asciiCols]\n";
        return 1;
    }

    std::string inputVideo = argv[1];
    cv::VideoCapture cap(inputVideo);

    if (!cap.isOpened()) {
        std::cerr << "[C++ Test Error] No se pudo abrir el archivo de video: " << inputVideo << "\n";
        return 1;
    }

    int videoWidth = static_cast<int>(cap.get(cv::CAP_PROP_FRAME_WIDTH));
    int videoHeight = static_cast<int>(cap.get(cv::CAP_PROP_FRAME_HEIGHT));
    double fpsVal = cap.get(cv::CAP_PROP_FPS);
    int fps = (fpsVal > 0) ? static_cast<int>(std::round(fpsVal)) : 30;
    int totalFrames = static_cast<int>(cap.get(cv::CAP_PROP_FRAME_COUNT));

    PipelineConfig config;
    pipeline_new_config(&config);

    // Permitir sobreescribir asciiCols opcionalmente por argumento de CLI
    int targetCols = (argc >= 3) ? std::atoi(argv[2]) : 200;
    if (targetCols <= 0) targetCols = 200;

    /* CALCULO DINAMICO DE CELDAS Y FUENTE. . . */
    // Columnas ASCII ajustadas
    config.asciiCols = targetCols;

    // Ancho de la celda en px según la resolución del video
    int calculatedCellW = static_cast<int>(std::max(1, videoWidth / config.asciiCols)) * 3;

    // Altura de la celda (relación de aspecto típica de caracteres monospaciados 1:1.8)
    int calculatedCellH = static_cast<int>(calculatedCellW * 1.8) * 3;
    if (calculatedCellH < 1) calculatedCellH = 1;

    // fontScale proporcional al tamaño de la celda con cellW = 8px
    double calculatedFontScale = (double)calculatedCellW * 0.1; 
    if (calculatedFontScale < 0.2) calculatedFontScale = 0.2;

    // Thickness ajustado dinámicamente si la celda es muy grande
    int calculatedThickness = (calculatedCellW > 16) ? 2 : 1;

    config.inputFile = inputVideo.c_str();
    config.outputFile = argc > 2 ? argv[2] : "test_native_out.mp4";
    config.txtOutputDir = argc > 3 ? argv[3] : "ascii_txt_frames";
    config.asciiCharset = "!?@$%#mMqpdb^0123456789*+=-:;.,/()[\\]<=>'\"{|}~`_ ";
    config.fps = fps;
    config.inW = videoWidth;
    config.inH = videoHeight;
    config.outW = videoWidth;
    config.outH = videoHeight;
    
    // Asignación de valores dinámicos
    config.font.cellW = calculatedCellW;
    config.font.cellH = calculatedCellH;
    config.font.fontScale = calculatedFontScale;
    config.font.thickness = calculatedThickness;

    std::cout << "--- Ejecutando Test Nativo C++ ---" << std::endl;
    std::cout << "Video original : " << inputVideo << " (" << videoWidth << "x" << videoHeight << " @ " << fps << " FPS)" << std::endl;
    std::cout << "Config ASCII   : " << config.asciiCols << " cols | Celda: " << config.font.cellW << "x" << config.font.cellH << " px" << std::endl;
    std::cout << "Fuente         : Scale=" << config.font.fontScale << " | Thickness=" << config.font.thickness << std::endl;
    std::cout << "Total frames   : " << totalFrames << std::endl;

    cv::Mat frameBGR, frameRGB;
    std::vector<unsigned char> rawBuffer(videoWidth * videoHeight * 3);
    int frameCount = 0;

    while (cap.read(frameBGR)) {
        if (frameBGR.empty()) break;

        cv::cvtColor(frameBGR, frameRGB, cv::COLOR_BGR2RGB);
        std::memcpy(rawBuffer.data(), frameRGB.data, rawBuffer.size());

        process_ascii_video_pipeline(&config, rawBuffer.data(), false);

        frameCount++;
        // if (frameCount % fps == 0 || frameCount == totalFrames) {
        std::cout << "Procesando frame " << frameCount << "/" << totalFrames << "...\r" << std::flush;
        // }
    }

    process_ascii_video_pipeline(&config, nullptr, true);

    std::cout << "\n[C++] Test finalizado. Salida generada: " << config.outputFile << std::endl;
    return 0;
}
#endif