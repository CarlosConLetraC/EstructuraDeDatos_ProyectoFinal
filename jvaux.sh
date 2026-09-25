#!/bin/bash

JAVA_HOME="/opt/jdk-26.0.2"
JAVAC="$JAVA_HOME/bin/javac"
JAVA="$JAVA_HOME/bin/java"

OPENCV_JAR="/usr/share/java/opencv5/opencv-500.jar"
NATIVE_LIB_PATH=".:/usr/lib:/usr/lib64:/usr/share/java/opencv5"

# URL directa al paquete oficial de OpenCV 5.0.0 compatible
MAVEN_OPENCV5_URL="https://repo1.maven.org/maven2/org/bytedeco/opencv/5.0.0-1.5.10/opencv-5.0.0-1.5.10.jar"

pkg_fetch_and_replace() {
    local target_jar="/tmp/opencv5_download.jar"
    
    echo "Detectada incompatibilidad o daño en $OPENCV_JAR"
    echo "Descargando Build compatible de OpenCV 5 en /tmp..."

    if curl -sSL -o "$target_jar" "$MAVEN_OPENCV5_URL"; then
        echo "Reemplazando $OPENCV_JAR mediante sudo..."
        if sudo cp "$target_jar" "$OPENCV_JAR"; then
            rm -f "$target_jar"
            return 0
        fi
    fi
    rm -f "$target_jar"
    return 1
}

check_jar_integrity() {
    if [ ! -f "$OPENCV_JAR" ]; then
        return 1
    fi

    if ! "$JAVA_HOME/bin/jar" -tf "$OPENCV_JAR" > /dev/null 2>&1; then
        return 1
    fi

    return 0
}

compress_video() {
    local input="$1"
    
    if [ -z "$input" ]; then
        echo "Error: argumento #1 invalido."
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

    echo "Comprimiendo '$input'. . ."
    
    ffmpeg -i "$input" -vcodec libx264 -crf 28 -acodec aac -b:a 128k "$temp"
    
    if [ $? -eq 0 ]; then
        mv "$temp" "$input"
        echo "Archivo original ha sido reemplazado con la versión comprimida."
    else
        echo "Hubo un error durante la compresión."
        rm -f "$temp"
        return 1
    fi
}

_get_classpath() {
    local cp="out:src:$OPENCV_JAR"
    echo "$cp"
}

function javarun() {
    mkdir -p out
    
    if ! check_jar_integrity; then
        pkg_fetch_and_replace || return 1
    fi

    local javac_log
    javac_log=$(mktemp)

    if ! "$JAVAC" -cp "$OPENCV_JAR:src:." -d out "$1.java" 2>&1 | tee "$javac_log"; then
        if grep -qE "zip END header not found|error reading|UnsupportedClassVersionError" "$javac_log"; then
            rm -f "$javac_log"
            if pkg_fetch_and_replace; then
                javarun "$1"
                return $?
            fi
        fi
        rm -f "$javac_log"
        return 1
    fi
    rm -f "$javac_log"

    local log_out
    log_out=$(mktemp)

    "$JAVA" --enable-native-access=ALL-UNNAMED \
         -Djava.library.path="$NATIVE_LIB_PATH" \
         -cp "$OPENCV_JAR:src:out:." "$1" 2>&1 | tee "$log_out"

    if grep -qE "UnsupportedClassVersionError|has been compiled by a more recent version" "$log_out"; then
        rm -f "$log_out"
        if pkg_fetch_and_replace; then
            javarun "$1"
        fi
    else
        rm -f "$log_out"
    fi
}

javacompile() {
    if [ -f "Makefile" ]; then
        echo "Makefile detectado. Compilando C++ y Java..."
        
        if ! check_jar_integrity; then
            if ! pkg_fetch_and_replace; then
                echo "Error: No se pudo verificar la integridad de $OPENCV_JAR."
                return 1
            fi
        fi

        local make_log
        make_log=$(mktemp)

        if ! make 2>&1 | tee "$make_log"; then
            if grep -qE "zip END header not found|error reading|UnsupportedClassVersionError" "$make_log"; then
                rm -f "$make_log"
                if pkg_fetch_and_replace; then
                    javacompile
                    return $?
                fi
            else
                echo "Error al compilar con make"
                rm -f "$make_log"
                return 1
            fi
        fi
        rm -f "$make_log"
    else
        echo "Error: No se encuentra el archivo 'Makefile'."
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

    echo "Ejecutando $1..."
    
    local log_out
    log_out=$(mktemp)

    "$JAVA" --enable-native-access=ALL-UNNAMED \
         -Djava.library.path="$NATIVE_LIB_PATH" \
         -cp "$cp" "$@" 2>&1 | tee "$log_out"

    if grep -qE "UnsupportedClassVersionError|has been compiled by a more recent version" "$log_out"; then
        rm -f "$log_out"
        if pkg_fetch_and_replace; then
            javaexecute "$@"
        fi
    else
        rm -f "$log_out"
    fi
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