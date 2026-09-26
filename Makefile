CXX         := g++

# 1. Detección dinámica de JAVA_HOME si no viene definido en el entorno
# Busca la versión instalada en /opt/ (prioriza jdk-26, luego cualquier /opt/jdk*)
JDK_DIR     := $(firstword $(wildcard /opt/jdk-26* /opt/jdk*))
JAVA_HOME   ?= $(if $(JDK_DIR),$(JDK_DIR),/usr/lib/jvm/default)

JAVAC       := $(JAVA_HOME)/bin/javac
JAVA        := $(JAVA_HOME)/bin/java

# 2. Extracción dinámica de la versión mayor de Java (ej. '26', '27', '21')
JAVA_VER    := $(shell $(JAVA) -version 2>&1 | head -n 1 | awk -F '"' '{print $$2}' | awk -F '.' '{print $$1}')

# 3. Selección dinámica del JAR de OpenCV según la versión de Java
ifeq ($(shell test $(JAVA_VER) -ge 27 2>/dev/null && echo 1),1)
    OPENCV_JAR ?= /usr/share/java/opencv5/opencv-500.jar
else
    OPENCV_JAR ?= lib/opencv-4100.jar
endif

# Flags de compilación para C++ (-isystem silencia advertencias en cabeceras de terceros)
CXXFLAGS    := -O2 -Wall -Wextra -Wcast-align -Wcast-qual -std=c++17 -fPIC \
               -Iinclude \
               -isystem /usr/include/opencv5 \
               -I$(JAVA_HOME)/include \
               -I$(JAVA_HOME)/include/linux

LDFLAGS     := -lavcodec -lavformat -lavutil -lswscale -lopencv_core -lopencv_imgproc -lopencv_imgcodecs

TEST_CXXFLAGS := $(CXXFLAGS)
TEST_LDFLAGS  := $(LDFLAGS) -lopencv_videoio

VID ?= cat.mp4

SRC_DIR     := src
BUILD_DIR   := out
BIN_DIR     := bin

LIB_SRCS    := $(filter-out $(SRC_DIR)/draw.cpp $(SRC_DIR)/main.cpp, $(wildcard $(SRC_DIR)/*.cpp))

TARGET_SO   := libasciipipeline.so
TARGET_BIN  := $(BIN_DIR)/test_runner
DRAW_TARGET := $(BIN_DIR)/draw

# Archivos Java
JAVA_SRC_DIR := $(SRC_DIR)/proyecto
JAVA_SRCS    := $(wildcard $(JAVA_SRC_DIR)/*.java)
JAVA_CLASSES := $(patsubst $(JAVA_SRC_DIR)/%.java,$(BUILD_DIR)/proyecto/%.class,$(JAVA_SRCS))

.PHONY: all java clean test draw help

# Compila tanto Java como la librería C++ (.so)
all: java $(TARGET_SO)

# Compila las clases Java ajustando --release y el CP a la versión de JDK detectada
java: $(JAVA_CLASSES)

$(BUILD_DIR)/proyecto/%.class: $(JAVA_SRC_DIR)/%.java
	@mkdir -p $(BUILD_DIR)/proyecto
	$(JAVAC) --release $(JAVA_VER) -cp $(OPENCV_JAR):$(SRC_DIR) -d $(BUILD_DIR) $(JAVA_SRCS)
	@echo "Clases Java compiladas con éxito en $(BUILD_DIR) (Target: Java $(JAVA_VER))."

# Compilar la librería compartida .so (para JNI)
$(TARGET_SO): $(LIB_SRCS)
	@mkdir -p $(BUILD_DIR)
	$(CXX) $(CXXFLAGS) -shared $^ -o $@ $(LDFLAGS)
	@echo "--------------------------------------------------------"
	@echo "Librería dinámica creada con éxito: $@"
	@echo "--------------------------------------------------------"

$(DRAW_TARGET): $(SRC_DIR)/draw.cpp $(filter-out $(SRC_DIR)/main.cpp, $(LIB_SRCS))
	@mkdir -p $(BIN_DIR)
	$(CXX) $(CXXFLAGS) $^ -o $@ $(LDFLAGS)

draw: $(DRAW_TARGET)
	./$(DRAW_TARGET) ascii_txt_frames 30
	
test: $(SRC_DIR)/main.cpp $(LIB_SRCS)
	@mkdir -p $(BIN_DIR)
	$(CXX) $(TEST_CXXFLAGS) -DTEST_BUILD $^ -o $(TARGET_BIN) $(TEST_LDFLAGS)
	./$(TARGET_BIN) $(VID)

clean:
	rm -rf $(BUILD_DIR) $(BIN_DIR) $(TARGET_SO) *out*.mp4 ascii_txt_frames
	@echo "Limpieza completada."

help:
	@echo "Comandos disponibles:"
	@echo "  make                : Compila Java y la librería C++ (.so)"
	@echo "  make test           : Ejecuta la prueba nativa C++"
	@echo "  make draw           : Ejecuta el reproductor ASCII"
	@echo "  make clean          : Borra artefactos generados"