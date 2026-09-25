// Pre-analysis: stop Ghidra inferring "non-returning" functions (it wrongly flags PLT imports here, truncating bodies).
import ghidra.app.script.GhidraScript;

public class NoReturnOff extends GhidraScript {
    @Override
    public void run() throws Exception {
        setAnalysisOption(currentProgram, "Non-Returning Functions - Discovered", "false");
        println("NoReturnOff: discovered-noreturn analysis disabled");
    }
}
