### 1. Conversión de RGB a Escala de Grises ($Y(x,y)$)

$$Y(x,y) = 0.299 \cdot R(x,y) + 0.587 \cdot G(x,y) + 0.114 \cdot B(x,y)$$

```cpp
// Se encapsula el buffer RGB plano de entrada dentro de una matriz OpenCV
cv::Mat inputMat(inH, inW, CV_8UC3, const_cast<unsigned char*>(rgbInput));

// Conversión del espacio de color RGB a escala de grises
cv::Mat grayMat;
cv::cvtColor(inputMat, grayMat, cv::COLOR_RGB2GRAY);
```
* **Mapeo:** La función `cv::cvtColor(..., cv::COLOR_RGB2GRAY)` aplica internamente la fórmula ponderada de luma $Y(x,y)$ de la norma ITU-R BT.601 en punto fijo sobre toda la matriz del fotograma.

---

### 2. Muestreo por Celdas (Reducción de Resolución)

#### Ecuación Matemática Formal
$$\bar{Y}_{k,l} = \frac{1}{w_c \cdot h_c} \sum_{i=0}^{w_c-1} \sum_{j=0}^{h_c-1} Y(k \cdot w_c + i, \, l \cdot h_c + j)$$

#### Implementación Nativa C++
El promedio del bloque o celda $w_c \times h_c$ para calcular la matriz reducida de dimensiones `(asciiCols, asciiRows)` se ejecuta mediante el algoritmo de reescalado de área `cv::INTER_AREA`:

```cpp
// 1. Cálculo dinámico del número de filas ASCII manteniendo la relación de aspecto
double aspect = (inW > 0) ? static_cast<double>(inH) / inW : 0.5625;
int asciiRows = static_cast<int>(asciiCols * aspect * 0.55);
asciiRows = std::max(1, asciiRows);

// 2. Muestreo del área total de cada celda a un único píxel promedio
cv::Mat smallGray;
cv::resize(grayMat, smallGray, cv::Size(asciiCols, asciiRows), 0, 0, cv::INTER_AREA);
```

* **Mapeo:** `cv::INTER_AREA` re-muestrea la imagen de entrada sumando y dividiendo exactamente el valor de todos los píxeles contenidos dentro del área de la celda proyectada ($w_c \times h_c$), produciendo la matriz `smallGray` en la que cada celda $(r, c)$ contiene el valor escalar promedio $\bar{Y}_{k,l} \in [0, 255]$.

---

### 3. Mapeo Lineal a Rampa de Caracteres (LUT) y Selección del Carácter

#### Ecuación Matemática Formal
$$idx = \left\lfloor \frac{\bar{Y}_{k,l}}{255} \cdot (N - 1) \right\rfloor, \quad \text{Carácter asignado} = S[idx]$$

#### Implementación Nativa C++
Durante el recorrido de la matriz de grises reescalada `smallGray`, el cálculo del índice y la lectura del carácter se implementan en `processFrameToAsciiCanvas`:

```cpp
size_t numChars = asciiChars.length(); // N = cantidad total de caracteres en la rampa

for (int r = 0; r < asciiRows; ++r) {
    for (int c = 0; c < asciiCols; ++c) {
        // Obtener el valor promedio Y_{k,l} de la celda reducida
        unsigned char grayVal = smallGray.at<unsigned char>(r, c);
        
        // Mapeo lineal estricto a la rampa de caracteres
        size_t charIdx = (static_cast<size_t>(grayVal) * (numChars - 1)) / 255;
        charIdx = std::min(charIdx, numChars - 1); // Clamp de seguridad
        
        char ch = asciiChars[charIdx]; // Carácter S[idx] seleccionado
        
        // ... Renderizado visual o escritura a archivo
    }
}
```

* **Mapeo:**
  * `grayVal`: Representa el valor promedio $\bar{Y}_{k,l}$.
  * `numChars`: Es la longitud $N = \vert{}S\vert{}$ de la cadena de caracteres.
  * `(grayVal * (numChars - 1)) / 255`: Ejecuta la multiplicación y la truncación de división entera ($\lfloor \cdot \rfloor$).
  * `std::min(...)`: Previene accesos fuera de rango (*out of bounds*) en la cadena `asciiChars`.

---

### Mapeo Extra: Ordenamiento Previo de la Rampa por Densidad Cromática

Para que el mapeo del índice $idx$ coincida con el nivel numérico de densidad de la rampa $S$, el constructor de `AsciiConverter` llama a `sortCharsByDensity` para ordenar la rampa original `rawChars` evaluando el valor de la suma de sus píxeles activos al renderizar cada carácter:

```cpp
std::string AsciiConverter::sortCharsByDensity(const std::string& rawChars, const PipelineConfig* config) {
    // ...
    for (char c : rawChars) {
        // Dibuja el carácter en un lienzo monocromático aislado
        cv::Mat testCanvas = cv::Mat::zeros(localConfig.font.cellH, localConfig.font.cellW, CV_8UC1);
        cv::putText(testCanvas, std::string(1, c), cv::Point(4, 15), ...);

        // Calcula la integral / suma total de intensidad luminosa del carácter
        double totalPixelSum = cv::sum(testCanvas)[0];
        densities.push_back({c, totalPixelSum});
    }

    // Ordena de menor a mayor densidad luminosa
    std::sort(densities.begin(), densities.end(), [](const CharDensity& a, const CharDensity& b) {
        return a.density < b.density;
    });
    // ...
}
```