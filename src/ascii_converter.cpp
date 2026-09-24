#include "ascii_converter.h"
#include <algorithm>
#include <cmath>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <sstream>
#include <opencv2/opencv.hpp>

struct CharDensity {
    char character;
    double density;
};

std::string AsciiConverter::sortCharsByDensity(const std::string& rawChars, const PipelineConfig* config) {
    std::vector<CharDensity> densities;
    
    PipelineConfig localConfig;
    if (config != nullptr) localConfig = *config;
    pipeline_new_config(&localConfig);

    for (char c : rawChars) {
        cv::Mat testCanvas = cv::Mat::zeros(localConfig.font.cellH, localConfig.font.cellW, CV_8UC1);
        std::string text(1, c);
        
        cv::putText(
            testCanvas, text, cv::Point(4, 15), 
            localConfig.font.fontFace, localConfig.font.fontScale, 
            cv::Scalar(255), localConfig.font.thickness, cv::LINE_AA
        );

        double totalPixelSum = cv::sum(testCanvas)[0];
        densities.push_back({c, totalPixelSum});
    }

    std::sort(densities.begin(), densities.end(), [](const CharDensity& a, const CharDensity& b) {
        return a.density < b.density;
    });
    
    std::string sortedResult = "";
    for (const auto& item : densities) sortedResult += item.character;
    return sortedResult;
}

AsciiConverter::AsciiConverter(const std::string& rawChars, const PipelineConfig* config) {
    PipelineConfig defaultConfig;
    if (config != nullptr) {
        defaultConfig = *config;
    }
    pipeline_new_config(&defaultConfig);

    std::string charset = (rawChars.empty()) 
        ? defaultConfig.asciiCharset 
        : rawChars;

    this->asciiChars = sortCharsByDensity(charset, &defaultConfig);
}

void AsciiConverter::processFrameToAsciiCanvas(
    const unsigned char* rgbInput, 
    const PipelineConfig& config,
    std::vector<unsigned char>& outCanvasRGB,
    int frameNumber) 
{
    // 1. Validaciones básicas de puntero y dimensiones mínimas
    if (!rgbInput) return;

    int inW = (config.inW > 0) ? config.inW : 1280;
    int inH = (config.inH > 0) ? config.inH : 720;
    int outW = (config.outW > 0) ? config.outW : inW;
    int outH = (config.outH > 0) ? config.outH : inH;
    int asciiCols = (config.asciiCols > 0) ? config.asciiCols : 120;

    // 2. Prevenir desbordamiento de memoria limita tamaños a rangos seguros (4K máx)
    outW = std::clamp(outW, 1, 3840);
    outH = std::clamp(outH, 1, 2160);

    // 3. Matriz de entrada segura
    cv::Mat inputMat(inH, inW, CV_8UC3, const_cast<unsigned char*>(rgbInput));
    if (inputMat.empty()) return;

    cv::Mat grayMat;
    cv::cvtColor(inputMat, grayMat, cv::COLOR_RGB2GRAY);

    // 4. Cálculo de filas ASCII previniendo división entre cero y asegurando mínimo de 1
    double aspect = (inW > 0) ? static_cast<double>(inH) / inW : 0.5625;
    int asciiRows = static_cast<int>(asciiCols * aspect * 0.55);
    asciiRows = std::max(1, asciiRows);

    cv::Mat smallGray;
    cv::resize(grayMat, smallGray, cv::Size(asciiCols, asciiRows), 0, 0, cv::INTER_AREA);

    // 5. Canvas seguro
    cv::Mat outputCanvas = cv::Mat::zeros(outH, outW, CV_8UC3);

    double cellW = static_cast<double>(outW) / asciiCols;
    double cellH = static_cast<double>(outH) / asciiRows;

    // Uso de fontScale de la config si existe, o fallback dinámico seguro
    double fontScale = (config.font.fontScale > 0.0) 
                     ? config.font.fontScale 
                     : std::min(cellW, cellH) / 12.0;

    int thickness = (config.font.thickness > 0) ? config.font.thickness : 1;
    int fontFace = cv::FONT_HERSHEY_PLAIN;

    size_t numChars = asciiChars.length();
    if (numChars == 0) return; // Protección contra charset vacío

    std::string txtFrameContent = "";

    // 6. Recorrido de matriz con límites estrictos
    for (int r = 0; r < asciiRows; ++r) {
        for (int c = 0; c < asciiCols; ++c) {
            unsigned char grayVal = smallGray.at<unsigned char>(r, c);
            
            // Garantizar que el índice nunca exceda el arreglo
            size_t charIdx = (static_cast<size_t>(grayVal) * (numChars - 1)) / 255;
            charIdx = std::min(charIdx, numChars - 1);
            char ch = asciiChars[charIdx];

            if (config.saveTxtFrames == 1) {
                txtFrameContent += ch;
            }

            if (ch == ' ') continue;

            int x = static_cast<int>(c * cellW);
            int y = static_cast<int>((r + 1) * cellH - (cellH * 0.15));

            // Clamping para no dibujar fuera de coordenadas de pantalla
            x = std::clamp(x, 0, outW - 1);
            y = std::clamp(y, 0, outH - 1);

            std::string text(1, ch);
            cv::putText(
                outputCanvas, text, cv::Point(x, y), 
                fontFace, fontScale, cv::Scalar(255, 255, 255), thickness, cv::LINE_AA
            );
        }
        if (config.saveTxtFrames == 1) {
            txtFrameContent += '\n';
        }
    }

    // 7. Guardado seguro en disco
    if (config.saveTxtFrames == 1 && config.txtOutputDir != nullptr && config.txtOutputDir[0] != '\0' && frameNumber >= 0) {
        std::error_code ec;
        std::filesystem::create_directories(config.txtOutputDir, ec);
        
        if (!ec) {
            std::ostringstream filename;
            filename << config.txtOutputDir << "/frame_" << std::setfill('0') << std::setw(6) << frameNumber << ".txt";

            std::ofstream txtFile(filename.str());
            if (txtFile.is_open()) {
                txtFile << txtFrameContent;
                txtFile.close();
            }
        }
    }

    // 8. Copia limpia al buffer de salida
    size_t bufferSize = static_cast<size_t>(outW) * outH * 3;
    if (outCanvasRGB.size() != bufferSize) {
        outCanvasRGB.resize(bufferSize);
    }
    std::memcpy(outCanvasRGB.data(), outputCanvas.data, bufferSize);
}