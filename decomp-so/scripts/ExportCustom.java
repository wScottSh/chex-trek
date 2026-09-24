// Decompile functions in custom classes / listed custom methods; one file per function.
import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.*;
import ghidra.program.model.listing.*;
import java.io.*;
import java.nio.file.*;
import java.util.*;

public class ExportCustom extends GhidraScript {
    @Override
    public void run() throws Exception {
        String[] args = getScriptArgs();
        Path outDir = Paths.get(args[0]);
        Set<String> classes = new HashSet<>(Arrays.asList(args[1].split(",")));
        Set<String> methods = new HashSet<>(Files.readAllLines(Paths.get(args[2])));
        DecompInterface d = new DecompInterface();
        d.openProgram(currentProgram);
        int n = 0;
        StringBuilder index = new StringBuilder();
        for (Function f : currentProgram.getFunctionManager().getFunctions(true)) {
            if (f.isThunk() || f.isExternal()) continue;
            String full = f.getName(true);
            String cls = full.contains("::") ? full.substring(0, full.lastIndexOf("::")) : "";
            if (!classes.contains(cls) && !methods.contains(full)) continue;
            DecompileResults r = d.decompileFunction(f, 120, monitor);
            if (!r.decompileCompleted()) { println("FAIL " + full); continue; }
            String safe = full.replaceAll("[^A-Za-z0-9_]+", "_") + "_" + f.getEntryPoint();
            String sig = f.getSignature().getPrototypeString();
            Files.writeString(outDir.resolve(safe + ".c"),
                "// " + full + " @ " + f.getEntryPoint() + "\n// " + sig + "\n" + r.getDecompiledFunction().getC());
            index.append(safe).append("\t").append(full).append("\t").append(f.getBody().getNumAddresses()).append("\n");
            n++;
        }
        Files.writeString(outDir.resolve("_index.tsv"), index.toString());
        println("EXPORTED " + n);
    }
}
