#!/bin/bash

# Configuración del JDK portable (puedes cambiarlo aquí o sobreescribirlo al ejecutar: JDK_DIR=/opt/jdk-27 jrun ...)
JDK_DIR="${JDK_DIR:-/opt/jdk-26.0.2}"

JAVA_HOME="$JDK_DIR"
JAVAC="$JAVA_HOME/bin/javac"
JAVA="$JAVA_HOME/bin/java"

# Validar que exista el binario del JDK
if [ ! -x "$JAVAC" ] || [ ! -x "$JAVA" ]; then
    echo "Error: No se encontró un JDK válido en '$JAVA_HOME'."
    echo "Asegúrate de que la ruta exista en /opt o usa: JDK_DIR=/opt/tu-jdk jrun ..."
    return 1 2>/dev/null || exit 1
fi

# Detectar la versión mayor de Java (ej: 26, 27, 21)
JAVA_MAJOR_VERSION=$("$JAVA" -version 2>&1 | head -n 1 | awk -F '"' '{print $2}' | awk -F '.' '{print $1}')

# Definición de URLs y rutas dinámicas según compatibilidad de versión
if [ "$JAVA_MAJOR_VERSION" -ge 27 ]; then
    # Java 27+: Compatible con el paquete opencv 5.x de CachyOS/Arch
    OPENCV_JAR="${OPENCV_JAR:-/usr/share/java/opencv5/opencv-500.jar}"
    OPENCV_URL=""
elif [ "$JAVA_MAJOR_VERSION" -ge 21 ]; then
    # Java 21 a 26: Usa OpenCV 4.10.0 / 4.9.0 (compilado con bytecode <= 70.0)
    OPENCV_JAR="${OPENCV_JAR_26:-$PWD/lib/opencv-4100.jar}"
    OPENCV_URL="https://repo1.maven.org/maven2/org/bytedeco/opencv/4.10.0-1.5.11/opencv-4.10.0-1.5.11.jar"
else
    # Fallback legacy para Java 17 o inferior
    OPENCV_JAR="${OPENCV_JAR_LEGACY:-$PWD/lib/opencv-490.jar}"
    OPENCV_URL="https://repo1.maven.org/maven2/org/bytedeco/opencv/4.9.0-1.5.10/opencv-4.9.0-1.5.10.jar"
fi

NATIVE_LIB_PATH=".:/usr/lib:/usr/lib64:/usr/share/java/opencv5:$(dirname "$OPENCV_JAR")"

download_opencv_jar() {
    local target_jar="$1"
    local url="$2"

    if [ -z "$url" ]; then
        return 1
    fi

    echo "[!] Descargando JAR de OpenCV compatible con Java $JAVA_MAJOR_VERSION..."
    echo "[!] URL: $url"
    
    mkdir -p "$(dirname "$target_jar")"

    if command -v curl >/dev/null 2>&1; then
        curl -L -o "$target_jar" "$url"
    elif command -v wget >/dev/null 2>&1; then
        wget -O "$target_jar" "$url"
    else
        echo "Error: Se requiere 'curl' o 'wget' para descargar el JAR de OpenCV."
        return 1
    fi

    if [ $? -eq 0 ] && [ -f "$target_jar" ]; then
        echo "[✓] Descarga completada exitosamente en: $target_jar"
        return 0
    else
        echo "[✕] Error al descargar el JAR desde la fuente."
        return 1
    fi
}

pkg_install_opencv() {
    # Si estamos en Java 27+, intentamos reinstalar desde pacman/gestor del sistema
    if [ "$JAVA_MAJOR_VERSION" -ge 27 ]; then
        echo "[!] Reparando/Reinstalando paquete de OpenCV desde el gestor de paquetes del sistema..."
        if [ -f /etc/os-release ]; then
            sudo pacman -S --noconfirm --overwrite '*' opencv 2>/dev/null || true
        fi
        return 0
    fi

    # Si estamos en Java < 27, procedemos con la descarga automática del mirror/Maven
    if [ -n "$OPENCV_URL" ]; then
        download_opencv_jar "$OPENCV_JAR" "$OPENCV_URL"
        return $?
    fi

    return 1
}

check_jar_integrity() {
    if [ ! -f "$OPENCV_JAR" ]; then
        echo "[!] $OPENCV_JAR no existe en el sistema."
        return 1
    fi

    if ! "$JAVA_HOME/bin/jar" -tf "$OPENCV_JAR" > /dev/null 2>&1; then
        echo "[!] $OPENCV_JAR está corrupto o es inválido para la herramienta jar en $JAVA_HOME."
        return 1
    fi

    return 0
}

pkg_fetch_and_replace() {
    if ! check_jar_integrity; then
        pkg_install_opencv
        return $?
    fi
    return 0
}

compress_video() {
    local input="$1"
    
    if [ -z "$input" ]; then
        echo "Error: argumento #1 inválido."
        echo "Uso: compress_video archivo.mp4"
        return 1
    fi

    if [ ! -f "$input" ]; then
        echo "Error: El archivo '$input' no existe."
        return 1
    fi

    local ext="${input##*.}"
    local base="${input%.*}"
    local temp="${base}_temp.${ext}"

    echo "Comprimiendo '$input'..."
    
    ffmpeg -i "$input" -vcodec libx264 -crf 28 -acodec aac -b:a 128k "$temp"
    
    if [ $? -eq 0 ]; then
        mv "$temp" "$input"
        echo "Archivo original reemplazado con la versión comprimida."
    else
        echo "Hubo un error durante la compresión."
        rm -f "$temp"
        return 1
    fi
}

_get_classpath() {
    echo "out:src:$OPENCV_JAR"
}

javarun() {
    mkdir -p out
    
    if ! check_jar_integrity; then
        pkg_fetch_and_replace || return 1
    fi

    if ! "$JAVAC" -cp "$OPENCV_JAR:src:." -d out "$1.java"; then
        echo "Error al compilar $1.java"
        return 1
    fi

    "$JAVA" --enable-native-access=ALL-UNNAMED \
         -Djava.library.path="$NATIVE_LIB_PATH" \
         -cp "$OPENCV_JAR:src:out:." "$1"
}

javacompile() {
    if [ ! -f "Makefile" ]; then
        echo "Error: No se encuentra el archivo 'Makefile'."
        return 1
    fi

    echo "Makefile detectado. Compilando C++ y Java (Detectado Java $JAVA_MAJOR_VERSION)..."
    
    if ! check_jar_integrity; then
        pkg_fetch_and_replace || return 1
    fi

    # Se pasa la variable JAVA_HOME al Makefile
    if ! make JAVA_HOME="$JAVA_HOME"; then
        echo "Error al compilar con make."
        return 1
    fi
}

javaexecute() {
    if [ -z "$1" ]; then
        echo "Uso: javaexecute Paquete.ClasePrincipal [argumentos...]"
        echo "Ejemplo: javaexecute proyecto.Main cat.mp4"
        return 1
    fi

    if [ ! -d "out" ]; then
        echo "Error: No se encuentra la carpeta de salida ('out'). Compila el proyecto primero con 'make'."
        return 1
    fi

    local cp
    cp=$(_get_classpath)

    echo "Ejecutando $1 con JDK $JAVA_MAJOR_VERSION ($JAVA_HOME)..."
    echo "Usando JAR de OpenCV: $OPENCV_JAR"
    
    "$JAVA" --enable-native-access=ALL-UNNAMED \
         -Djava.library.path="$NATIVE_LIB_PATH" \
         -cp "$cp" "$@"
}

jrun() {
    local main_class="proyecto.Main"

    if [[ "$1" == *.* ]]; then
        main_class="$1"
        shift
    fi

    if javacompile; then
        javaexecute "$main_class" "$@"
    else
        return 1
    fi
}

mkjavaproj() {
    local proj_name="${1:-$(basename "$PWD")}"
    mkdir -p "src/$proj_name"

    local main_file="src/$proj_name/Main.java"
    if [ ! -f "$main_file" ]; then
        cat << EOF > "$main_file"
package $proj_name;

public class Main {
    public static void main(String[] args) {
        // src
    }
}
EOF
        echo "¡Plantilla creada en 'src/$proj_name/Main.java'!"
    else
        echo "El archivo Main.java ya existe en 'src/$proj_name'."
    fi
}

mkjavaclass() {
    local pkg_name="$1"
    local class_name="$2"

    if [ -z "$pkg_name" ] || [ -z "$class_name" ]; then
        echo "Uso: mkjavaclass <Paquete> <NombreClase>"
        return 1
    fi

    local dir_path="src/$pkg_name"
    mkdir -p "$dir_path"

    local class_file="$dir_path/$class_name.java"
    if [ ! -f "$class_file" ]; then
        cat << EOF > "$class_file"
package $pkg_name;

public class $class_name {

}
EOF
        echo "¡Clase '$class_name' creada en '$dir_path'!"
    else
        echo "El archivo '$class_name.java' ya existe en '$dir_path'."
    fi
}