package proyecto;

public class AsciiPipeline implements AutoCloseable {
    static {
        System.loadLibrary("asciipipeline");
        registerNatives(); // Auto-registra los métodos nativos privados en la JVM usando la clase actual
    }

    private long statePtr;

    public AsciiPipeline() {
        this.statePtr = newState();
        if (this.statePtr == 0) throw new RuntimeException("No se pudo inicializar AsciiState nativo.");
    }

    private static native void registerNatives();

    private native long newState();
    private native void closeState(long statePtr);
    private native void setOutput(long statePtr, String inFile, String outFile, String outDir, boolean preserveAudio);
    private native void setDimensions(long statePtr, int inW, int inH, int outW, int outH, int cols);
    private native void setFont(long statePtr, int cellW, int cellH, double fontScale, int thickness);
    private native void setFps(long statePtr, int fps);
    private native void setCharset(long statePtr, String charset);
    private native boolean processFrame(long statePtr, byte[] frameData, boolean isLast);

    /***
     * Configura las salidas y especifica si se preserva el audio.
     ***/
    public void setOutput(String inFile, String outFile, String outDir, boolean preserveAudio) {
        this.checkState();
        this.setOutput(this.statePtr, inFile, outFile, outDir, preserveAudio);
    }

    /***
     * Sobrecarga: Preserva el audio del video por defecto (true).
     ***/
    public void setOutput(String inFile, String outFile, String outDir) {
        this.setOutput(inFile, outFile, outDir, true);
    }

    public void setDimensions(int inW, int inH, int outW, int outH, int cols) {
        this.checkState();
        this.setDimensions(this.statePtr, inW, inH, outW, outH, cols);
    }

    public void setFont(int cellW, int cellH, double fontScale, int thickness) {
        this.checkState();
        this.setFont(this.statePtr, cellW, cellH, fontScale, thickness);
    }

    public void setFps(int fps) {
        this.checkState();
        this.setFps(this.statePtr, fps);
    }

    public void setCharset(String charset) {
        this.checkState();
        this.setCharset(this.statePtr, charset);
    }

    public boolean processFrame(byte[] frameData, boolean isLast) {
        this.checkState();
        return this.processFrame(this.statePtr, frameData, isLast);
    }

    private void checkState() {
        if (this.statePtr == 0) throw new IllegalStateException("El estado del pipeline ya fue liberado por el garbage collector.");
    }

    @Override
    public void close() {
        if (this.statePtr != 0) {
            closeState(this.statePtr);
            this.statePtr = 0;
        }
    }
}
