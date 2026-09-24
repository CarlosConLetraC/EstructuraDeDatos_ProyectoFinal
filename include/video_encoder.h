#pragma once
#include <string>
#include "pipeline_config.h"

extern "C" { // dependencias de ffmpeg. . .
    #include <libavcodec/avcodec.h>
    #include <libavformat/avformat.h>
    #include <libswscale/swscale.h>
    #include <libavutil/imgutils.h>
    #include <libavutil/opt.h>
}

class VideoEncoder {
private:
    AVFormatContext* outFmtCtx = nullptr;
    AVFormatContext* inAudioFmtCtx = nullptr;
    
    AVCodecContext* videoCodecCtx = nullptr;
    AVStream* videoStream = nullptr;
    int audioStreamIndex = -1;
    int outAudioStreamIndex = -1;

    AVFrame* frame = nullptr;
    AVPacket* pkt = nullptr;
    SwsContext* swsCtx = nullptr;
    int64_t pts = 0;
    bool isInitialized = false;

    bool initAudioRemuxing(const std::string& inputSource);
    void copyAudioPackets();

public:
    VideoEncoder() = default;
    ~VideoEncoder();

    bool init(const PipelineConfig& config, const std::string& inputSource = "");
    bool encodeFrame(const unsigned char* rgbCanvas, int width, int height);
    void close();
    bool isReady() const { return isInitialized; }
};