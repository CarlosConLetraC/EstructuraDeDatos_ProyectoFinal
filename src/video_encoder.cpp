#include "video_encoder.h"
#include <iostream>

VideoEncoder::~VideoEncoder() {
    close();
}

bool VideoEncoder::initAudioRemuxing(const std::string& inputSource) {
    if (inputSource.empty()) return false;

    if (avformat_open_input(&inAudioFmtCtx, inputSource.c_str(), nullptr, nullptr) < 0) {
        std::cerr << "[C++ FFmpeg] No se pudo abrir la fuente de audio: " << inputSource << std::endl;
        return false;
    }

    if (avformat_find_stream_info(inAudioFmtCtx, nullptr) < 0) return false;

    // Buscar el primer stream de audio
    for (unsigned int i = 0; i < inAudioFmtCtx->nb_streams; i++) {
        if (inAudioFmtCtx->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_AUDIO) {
            audioStreamIndex = i;
            break;
        }
    }

    if (audioStreamIndex == -1) return false; // El video original no contiene pista de audio

    // Crear un nuevo stream de audio en el contenedor de salida
    AVStream* inAudioStream = inAudioFmtCtx->streams[audioStreamIndex];
    AVStream* outAudioStream = avformat_new_stream(outFmtCtx, nullptr);
    if (!outAudioStream) return false;

    // Copiar los parámetros del códec sin re-codificar
    if (avcodec_parameters_copy(outAudioStream->codecpar, inAudioStream->codecpar) < 0) return false;
    outAudioStream->time_base = inAudioStream->time_base;
    outAudioStreamIndex = outAudioStream->index;

    return true;
}

bool VideoEncoder::init(const PipelineConfig& config, const std::string& inputSource) {
    avformat_alloc_output_context2(&outFmtCtx, nullptr, nullptr, config.outputFile);
    if (!outFmtCtx) return false;

    // 1. Inicializar la codificación de video (H.264)
    const AVCodec* codec = avcodec_find_encoder(AV_CODEC_ID_H264);
    if (!codec) return false;

    videoStream = avformat_new_stream(outFmtCtx, codec);
    if (!videoStream) return false;

    videoCodecCtx = avcodec_alloc_context3(codec);
    videoCodecCtx->width = config.outW;
    videoCodecCtx->height = config.outH;
    videoCodecCtx->time_base = {1, config.fps};
    videoStream->time_base = videoCodecCtx->time_base;
    videoCodecCtx->pix_fmt = AV_PIX_FMT_YUV420P;

    av_opt_set(videoCodecCtx->priv_data, "preset", "ultrafast", 0);

    if (outFmtCtx->oformat->flags & AVFMT_GLOBALHEADER)
        videoCodecCtx->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;

    if (avcodec_open2(videoCodecCtx, codec, nullptr) < 0) return false;
    avcodec_parameters_from_context(videoStream->codecpar, videoCodecCtx);

    // 2. Si preserveAudio está activo, configurar el remuxing nativo
    if (config.preserveAudio && !inputSource.empty()) initAudioRemuxing(inputSource);

    // 3. Abrir archivo de salida y escribir cabecera
    if (!(outFmtCtx->oformat->flags & AVFMT_NOFILE)) {
        if (avio_open(&outFmtCtx->pb, config.outputFile, AVIO_FLAG_WRITE) < 0) return false;
    }

    if (avformat_write_header(outFmtCtx, nullptr) < 0) return false;

    frame = av_frame_alloc();
    frame->format = videoCodecCtx->pix_fmt;
    frame->width = config.outW;
    frame->height = config.outH;
    av_frame_get_buffer(frame, 0);

    pkt = av_packet_alloc();
    pts = 0;
    isInitialized = true;

    return true;
}

bool VideoEncoder::encodeFrame(const unsigned char* rgbCanvas, int width, int height) {
    if (!isInitialized) return false;

    swsCtx = sws_getCachedContext(
        swsCtx,
        width, height, AV_PIX_FMT_RGB24,
        width, height, AV_PIX_FMT_YUV420P,
        SWS_BICUBIC, nullptr, nullptr, nullptr
    );

    const uint8_t* inData[1] = { rgbCanvas };
    int inLinesize[1] = { 3 * width };

    av_frame_make_writable(frame);
    sws_scale(swsCtx, inData, inLinesize, 0, height, frame->data, frame->linesize);

    frame->pts = pts++;

    if (avcodec_send_frame(videoCodecCtx, frame) < 0) return false;

    while (avcodec_receive_packet(videoCodecCtx, pkt) == 0) {
        av_packet_rescale_ts(pkt, videoCodecCtx->time_base, videoStream->time_base);
        pkt->stream_index = videoStream->index;
        av_interleaved_write_frame(outFmtCtx, pkt);
        av_packet_unref(pkt);
    }

    return true;
}

void VideoEncoder::copyAudioPackets() {
    if (!inAudioFmtCtx || audioStreamIndex == -1 || outAudioStreamIndex == -1) return;

    AVPacket* audioPkt = av_packet_alloc();
    AVStream* inStream = inAudioFmtCtx->streams[audioStreamIndex];
    AVStream* outStream = outFmtCtx->streams[outAudioStreamIndex];

    while (av_read_frame(inAudioFmtCtx, audioPkt) >= 0) {
        if (audioPkt->stream_index == audioStreamIndex) {
            // Re-escalar las marcas de tiempo (timestamps) para el nuevo contenedor
            av_packet_rescale_ts(audioPkt, inStream->time_base, outStream->time_base);
            audioPkt->stream_index = outAudioStreamIndex;
            
            av_interleaved_write_frame(outFmtCtx, audioPkt);
        }
        av_packet_unref(audioPkt);
    }

    av_packet_free(&audioPkt);
}

void VideoEncoder::close() {
    if (!isInitialized) return;

    // Flush de los fotogramas de video pendientes
    avcodec_send_frame(videoCodecCtx, nullptr);
    while (avcodec_receive_packet(videoCodecCtx, pkt) == 0) {
        av_packet_rescale_ts(pkt, videoCodecCtx->time_base, videoStream->time_base);
        pkt->stream_index = videoStream->index;
        av_interleaved_write_frame(outFmtCtx, pkt);
        av_packet_unref(pkt);
    }

    // Copiar los paquetes de audio directo de la fuente original al archivo de salida
    copyAudioPackets();

    av_write_trailer(outFmtCtx);

    // Liberar recursos de audio
    if (inAudioFmtCtx) {
        avformat_close_input(&inAudioFmtCtx);
    }

    // Liberar recursos de video
    av_frame_free(&frame);
    av_packet_free(&pkt);
    avcodec_free_context(&videoCodecCtx);
    if (!(outFmtCtx->oformat->flags & AVFMT_NOFILE)) {
        avio_closep(&outFmtCtx->pb);
    }
    avformat_free_context(outFmtCtx);
    sws_freeContext(swsCtx);

    isInitialized = false;
}