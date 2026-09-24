#pragma once
#include <vector>
#include <string>
#include <algorithm>
#include <filesystem>
#include <opencv2/opencv.hpp>
#include "pipeline_config.h"

class AsciiConverter {
private:
    std::string asciiChars;
    std::string sortCharsByDensity(const std::string& rawChars, const PipelineConfig* config = nullptr);

public:
    AsciiConverter(const std::string& rawChars = "", const PipelineConfig* config = nullptr);
    
    void processFrameToAsciiCanvas(
        const unsigned char* rgbInput, 
        const PipelineConfig& config,
        std::vector<unsigned char>& outCanvasRGB,
        int frameNumber = -1
    );
};