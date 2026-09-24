#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <filesystem>
#include <algorithm>
#include <thread>
#include <chrono>
#include <termios.h>
#include <unistd.h>
#include <cstdio>

namespace fs = std::filesystem;

inline void gotoxy(int x, int y) { std::cout << "\033[" << y << ";" << x << "H"; }
inline void hideCursor() { std::cout << "\033[?25l"; }
inline void showCursor() { std::cout << "\033[?25h"; }

bool getCursorPosition(int& x, int& y) {
    char buf[32];
    unsigned int i = 0;

    struct termios raw, save;
    tcgetattr(STDIN_FILENO, &save);
    raw = save;
    raw.c_lflag &= ~(ICANON | ECHO);
    tcsetattr(STDIN_FILENO, TCSANOW, &raw);

    if (write(STDOUT_FILENO, "\033[6n", 4) != 4) {
        tcsetattr(STDIN_FILENO, TCSANOW, &save);
        return false;
    }

    while (i < sizeof(buf) - 1) {
        if (read(STDIN_FILENO, &buf[i], 1) != 1) break;
        if (buf[i] == 'R') break;
        i++;
    }
    buf[i] = '\0';

    tcsetattr(STDIN_FILENO, TCSANOW, &save);

    if (buf[0] == '\033' && buf[1] == '[' && sscanf(&buf[2], "%d;%d", &y, &x) == 2) return true; /*{
        if (sscanf(&buf[2], "%d;%d", &y, &x) == 2) return true;
    }*/
    return false;
}

int main(int argc, char** argv) {
    std::string directoryPath = "ascii_txt_frames";
    int fps = 30;

    if (argc >= 2) directoryPath = argv[1];
    if (argc >= 3) fps = std::stoi(argv[2]);

    if (!fs::exists(directoryPath) || !fs::is_directory(directoryPath)) {
        std::cerr << "[Error] El directorio '" << directoryPath << "' no existe o no es válido.\n";
        return 1;
    }

    std::vector<fs::path> frameFiles;
    for (const auto& entry : fs::directory_iterator(directoryPath)) {
        if (entry.is_regular_file() && entry.path().extension() == ".txt") {
            frameFiles.push_back(entry.path());
        }
    }

    if (frameFiles.empty()) {
        std::cerr << "[Error] No se encontraron archivos .txt en '" << directoryPath << "'.\n";
        return 1;
    }

    std::sort(frameFiles.begin(), frameFiles.end());

    // 1. Logs iniciales
    std::cout << "Cargados " << frameFiles.size() << " frames desde " << directoryPath << std::endl;
    std::cout << "Reproduciendo a " << fps << " FPS..." << std::endl;
    std::cout << "log generado..." << std::endl;
    std::cout << std::flush;

    // 2. Obtener punto exacto del cursor tras el log
    int currentX = 1, currentY = 1;
    if (!getCursorPosition(currentX, currentY)) {
        currentX = 1;
        currentY = 4;
    }

    const int POS_X = currentX;
    const int POS_Y = currentY;

    hideCursor();

    auto frameDuration = std::chrono::milliseconds(1000 / fps);

    // 3. Renderizado puro mediante sobrescritura
    for (const auto& filePath : frameFiles) {
        auto startTime = std::chrono::steady_clock::now();

        std::ifstream file(filePath);
        if (!file.is_open()) continue;

        std::string frameBuffer = "";
        std::string line;
        bool firstLine = true;

        while (std::getline(file, line)) {
            if (!firstLine) {
                frameBuffer += "\n";
            }
            frameBuffer += line;
            firstLine = false;
        }

        gotoxy(POS_X, POS_Y);
        std::cout << frameBuffer << std::flush;

        auto elapsedTime = std::chrono::steady_clock::now() - startTime;
        if (elapsedTime < frameDuration) {
            std::this_thread::sleep_for(frameDuration - elapsedTime);
        }
    }

    showCursor();
    std::cout << "\n\n[OK] Reproducción finalizada.\n";
    return 0;
}