package proyecto;

import org.opencv.core.Core;
import org.opencv.core.Mat;
import org.opencv.imgproc.Imgproc;
import org.opencv.videoio.VideoCapture;
import org.opencv.videoio.Videoio;
import static java.lang.System.out;
import static java.lang.System.err;

public class Main {
    static {
        // Carga robusta de la biblioteca nativa de OpenCV
        try {
            System.loadLibrary(Core.NATIVE_LIBRARY_NAME);
        } catch (UnsatisfiedLinkError e1) {
            try {
                System.loadLibrary("opencv_java500");
            } catch (UnsatisfiedLinkError e2) {
                System.loadLibrary("opencv_java");
            }
        }
    }

    public static void main(String[] args) {
        String videoPath = (args.length > 0) ? args[0] : "cat.mp4"; // fallback a cat.mp4 por ahora. . .
        out.printf(">>> Iniciando procesador ASCII con el video: %s\n", videoPath);

        // 1. Abrir la captura de video con OpenCV
        VideoCapture capture = new VideoCapture(videoPath);
        if (!capture.isOpened()) {
            err.printf("Error: No se pudo abrir el archivo de video %s\n", videoPath);
            return;
        }

        // Obtener propiedades del video de entrada
        int inW = (int) capture.get(Videoio.CAP_PROP_FRAME_WIDTH);
        int inH = (int) capture.get(Videoio.CAP_PROP_FRAME_HEIGHT);
        int fps = (int) capture.get(Videoio.CAP_PROP_FPS);
        int totalFrames = (int) capture.get(Videoio.CAP_PROP_FRAME_COUNT);

        if (fps <= 0) fps = 30; // Valor por defecto en caso de fallback

        out.printf("Información del Video: %dx%d @ %d FPS (Total Frames: %d)%n", inW, inH, fps, totalFrames);

        // 2. Inicializar y configurar el pipeline nativo ASCII
        try (AsciiPipeline pipeline = new AsciiPipeline()) {
            pipeline.setOutput(
                videoPath,
                args.length > 1 ? args[1] : "java_out.mp4",
                args.length > 2 ? args[2] : "ascii_txt_frames"
            );
            
            // Configurar dimensiones de entrada, salida y columnas ASCII
            pipeline.setDimensions(inW, inH, inW, inH, 1024);
            
            // out.printf("inW: %d\ninH: %d\n", inW, inH);
            
            pipeline.setFont(64, 64, 0.125, 1);
            pipeline.setFps(fps);
            pipeline.setCharset("!?@$%#mM0123456789*+=-:;.,/()[\\]<=>'\"{|}~`_ ");
            // pipeline.setCharset("<=>&?#@$%~+*^-?Mmdbpq_/|\\'\".:{}[]() ");
            // pipeline.setCharset("#@%^$/\\!:;.,-{|}$<=> ");
            // pipeline.setCharset("@#^~[]{}()/|.:'\"\\<=>$-+* ");

            out.println("Pipeline configurado. Comenzando procesamiento de frames...");

            Mat frame = new Mat();
            Mat frameRGB = new Mat();
            byte[] frameBuffer = new byte[inW * inH * 3]; // Buffer RGB
            int frameCount = 0;

            long startTime = System.currentTimeMillis();

            // 3. Bucle de procesamiento de frames
            while (capture.read(frame)) {
                if (frame.empty()) break;

                frameCount++;
                boolean isLastFrame = (frameCount == totalFrames);

                // Convertir espacio de color de BGR (OpenCV) a RGB (FFmpeg). . .
                Imgproc.cvtColor(frame, frameRGB, Imgproc.COLOR_BGR2RGB, 3);

                // Copiar el buffer de la matriz de OpenCV convertida a nuestro arreglo de bytes. . .
                frameRGB.get(0, 0, frameBuffer);

                // Enviar buffer crudo al pipeline C++. . .
                boolean ok = pipeline.processFrame(frameBuffer, isLastFrame);
                if (!ok) {
                    err.printf("Error procesando el frame nativo #%d\n", frameCount);
                    break;
                }

                // if (frameCount % fps == 0 || isLastFrame) {
                    out.printf("Procesados %d/%d frames...%n", frameCount, totalFrames);
                // }
                frame.release();
                frameRGB.release();
            }

            long elapsedTime = System.currentTimeMillis() - startTime;
            out.printf("¡Procesamiento finalizado exitosamente! %d frames procesados en %.2f segundos.%n", frameCount, elapsedTime / 1000.0);

        } catch (Exception e) {
            err.println("Excepción durante la ejecución del pipeline:");
            e.printStackTrace();
        } finally {
            capture.release();
        }
    }
}