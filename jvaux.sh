#!/bin/bash

JAVA_HOME="/opt/jdk-26.0.2"
JAVAC="$JAVA_HOME/bin/javac"
JAVA="$JAVA_HOME/bin/java"

# ffmpeg -i java_out.mp4 -vcodec libx264 -crf 28 -acodec aac -b:a 128k salida.mp4

OPENCV_JAR="/usr/share/java/opencv5/opencv-500.jar"
NATIVE_LIB_PATH=".:/usr/lib"

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

    # Generar nombre temporal en la misma ruta
    local ext="${input##*.}"
    local base="${input%.*}"
    local temp="${base}_temp.${ext}"

    echo "Comprimiendo '$input'. . ."
    
    ffmpeg -i "$input" -vcodec libx264 -crf 28 -acodec aac -b:a 128k "$temp"
    
    # Verificar si ffmpeg terminó correctamente
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
    "$JAVAC" -cp "$OPENCV_JAR:src:." -d out "$1.java"
    "$JAVA" --enable-native-access=ALL-UNNAMED \
         -Djava.library.path="$NATIVE_LIB_PATH" \
         -cp "$OPENCV_JAR:src:out:." "$1"
}

# Compilar proyecto Java + C++ usando el Makefile
javacompile() {
    if [ -f "Makefile" ]; then
        echo "Makefile detectado. Compilando C++ y Java..."
        make || { echo "Error al compilar con make"; return 1; }
    else
        echo "Error: No se encuentra el archivo 'Makefile'."
        return 1
    fi
}

# Ejecutar proyecto Java
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
    "$JAVA" --enable-native-access=ALL-UNNAMED \
         -Djava.library.path="$NATIVE_LIB_PATH" \
         -cp "$cp" "$@"
}

# Compilar y ejecutar en un solo comando
jrun() {
    local main_class="proyecto.Main"

    if [[ "$1" == *.* ]]; then
        main_class="$1"
        shift
    fi

    if javacompile; then
        javaexecute "$main_class" "$@"
    fi
}

# Crear paquete en la carpeta src
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

# Crear clase en el directorio src/<Paquete>
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