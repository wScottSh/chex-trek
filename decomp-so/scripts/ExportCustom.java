// Decompile functions in custom classes / listed custom methods; one file per function.
//
// Enriched export (spec #16, issue #18): every float constant and string literal a target
// function reads from .rodata is resolved from the bytes and typed in the listing (float,
// double or C string) before anything is decompiled, and any label of one of the function's
// literals still left in the pseudo-C is replaced by its value, so the pseudo-C shows values
// instead of label addresses (`_LAB_0036b0e4` -> 0.5, `&LAB_00370e03` -> "32", and
// `0x42000000` -> `0x42000000 /* 32.0f */`). Each file also starts with
// a `// literals:` block listing them. The verification harness (decomp-so/verify) finds the same
// literals from the binary on its own; its tests check that the two lists agree.
//
// Mirrors decomp-so/verify/binary.py (Binary.literals), which the tests compare it with:
//   - PIC register: one seen to receive _GLOBAL_OFFSET_TABLE_ (start of .got.plt) from
//     `call __i686.get_pc_thunk.<r>` / `call next; pop <r>` followed by `add <r>, imm`.
//   - float/double: an x87 read (FLD FADD FSUB FSUBR FMUL FDIV FDIVR FCOM FCOMP) of a
//     dword/qword at [pic + disp] in .rodata, or through a register that a LEA of such an
//     address loaded (that LEA is then a pointer, not a string).
//   - string: LEA of [pic + disp] in .rodata pointing at a NUL-terminated printable run.
//   - float immediate: `mov <4-byte dest>, imm32` whose bits read as a float with
//     1/65536 <= |x| <= 2^24 and at most 6 significant digits (0x42000000 = 32.0). It is not
//     in .rodata, so it is listed as `(immediate ...)` and annotated where the hex appears.
// The C-escape rules (cString) and the x87 mnemonic set are duplicated in binary.py.
//
// Args: <outDir> <comma-separated classes> <file of extra qualified method names>
// Run (fresh project, Ghidra 12.1.4 headless; this produced decomp-so/ghidra-full/):
//   analyzeHeadless <projDir> chex -import gamex86.so -scriptPath <scripts>
//     -preScript NoReturnOff.java -postScript ExportCustom.java <outDir>
//     mkTrail,mkObjective,matt_func_envshot,idCustomUI,idTarget_EndLevelGUI targets.txt
import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.*;
import ghidra.program.model.address.*;
import ghidra.program.model.data.*;
import ghidra.program.model.lang.Register;
import ghidra.program.model.listing.*;
import ghidra.program.model.mem.*;
import ghidra.program.model.scalar.Scalar;
import java.io.*;
import java.nio.file.*;
import java.util.*;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class ExportCustom extends GhidraScript {
    static final Set<String> X87_READS = Set.of("FLD", "FADD", "FSUB", "FSUBR", "FMUL", "FDIV", "FDIVR", "FCOM", "FCOMP");

    /** kind: float, double, string, pointer (placeholder), immediate (float imm32 `bits`). */
    record Lit(Address addr, String kind, String text, int length, long bits) {
        Lit(Address addr, String kind, String text, int length) { this(addr, kind, text, length, 0); }
    }
    record LeaRef(int index, Address addr) {}

    MemoryBlock rodata;
    long got;

    @Override
    public void run() throws Exception {
        String[] args = getScriptArgs();
        Path outDir = Paths.get(args[0]);
        Set<String> classes = new HashSet<>(Arrays.asList(args[1].split(",")));
        Set<String> methods = new HashSet<>(Files.readAllLines(Paths.get(args[2])));
        rodata = currentProgram.getMemory().getBlock(".rodata");
        got = gotAddress();

        List<Function> targets = new ArrayList<>();
        for (Function f : currentProgram.getFunctionManager().getFunctions(true)) {
            if (f.isThunk() || f.isExternal()) continue;
            String full = f.getName(true);
            String cls = full.contains("::") ? full.substring(0, full.lastIndexOf("::")) : "";
            if (classes.contains(cls) || methods.contains(full)) targets.add(f);
        }

        // Pass 1: find and type every literal, so pass 2 decompiles against typed data.
        Map<Function, List<Lit>> lits = new LinkedHashMap<>();
        List<Lit> typed = new ArrayList<>();
        for (Function f : targets) {
            List<Lit> list = literals(f);
            lits.put(f, list);
            for (Lit l : list) {
                if (l.kind().equals("immediate") || typed.stream().anyMatch(t -> overlaps(t, l))) continue; // keep the first of overlapping strings
                typeLiteral(l);
                typed.add(l);
            }
        }

        DecompInterface d = new DecompInterface();
        d.openProgram(currentProgram);
        int n = 0;
        StringBuilder index = new StringBuilder();
        for (Function f : targets) {
            String full = f.getName(true);
            DecompileResults r = d.decompileFunction(f, 120, monitor);
            if (!r.decompileCompleted()) { println("FAIL " + full); continue; }
            String safe = full.replaceAll("[^A-Za-z0-9_]+", "_") + "_" + f.getEntryPoint();
            String sig = f.getSignature().getPrototypeString();
            Files.writeString(outDir.resolve(safe + ".c"),
                "// " + full + " @ " + f.getEntryPoint() + "\n// " + sig + "\n"
                + literalBlock(lits.get(f)) + resolveLabels(r.getDecompiledFunction().getC(), lits.get(f)));
            index.append(safe).append("\t").append(full).append("\t").append(f.getBody().getNumAddresses()).append("\n");
            n++;
        }
        Files.writeString(outDir.resolve("_index.tsv"), index.toString());
        println("EXPORTED " + n + ", TYPED " + typed.size() + " literals");
    }

    /** What the PIC register holds: the start of .got.plt (the ABI's _GLOBAL_OFFSET_TABLE_).
     *  Ghidra's own `_GLOBAL_OFFSET_TABLE_` label is not used: a trial run with it resolved
     *  every PIC operand to the wrong strings. */
    long gotAddress() {
        return currentProgram.getMemory().getBlock(".got.plt").getStart().getOffset();
    }

    /** The function's instructions from its entry up to the next function's entry. Ghidra's
     *  own function body is not used: it is unreliable here (issue #16, "Further Notes"). */
    List<Instruction> instructions(Function f) {
        Function next = getFunctionAfter(f);
        Address end = next == null ? null : next.getEntryPoint();
        List<Instruction> out = new ArrayList<>();
        for (Instruction ins : currentProgram.getListing().getInstructions(f.getEntryPoint(), true)) {
            if (end != null && ins.getAddress().compareTo(end) >= 0) break;
            out.add(ins);
        }
        return out;
    }

    List<Lit> literals(Function f) throws Exception {
        // Candidates in instruction order; a LEA candidate becomes null ("pointer") when an x87
        // read goes through its register: the LEA took the address of a float, not a string.
        List<Lit> found = new ArrayList<>();
        Map<Register, LeaRef> leaRegs = new HashMap<>();
        Set<String> clobbered = Set.of("EAX", "ECX", "EDX"); // caller-saved
        Set<Register> pic = new HashSet<>();
        Register pendingReg = null;
        long pendingValue = -1; // return address a thunk / `call next` left in pendingReg
        for (Instruction ins : instructions(f)) {
            String mn = ins.getMnemonicString().toUpperCase();
            if (mn.equals("CALL")) {
                leaRegs.keySet().removeIf(r -> clobbered.contains(r.getName()));
                Address[] flows = ins.getFlows();
                if (flows.length == 1) {
                    Function callee = getFunctionAt(flows[0]);
                    long next = ins.getAddress().getOffset() + ins.getLength();
                    if (callee != null && callee.getName().startsWith("__i686.get_pc_thunk.")) {
                        String sfx = callee.getName().substring("__i686.get_pc_thunk.".length());
                        pendingReg = currentProgram.getRegister("E" + sfx.toUpperCase());
                        pendingValue = next;
                    } else if (flows[0].getOffset() == next) {
                        pendingReg = null;
                        pendingValue = next; // `call next; pop <r>`
                    }
                }
                continue;
            }
            if (pendingValue >= 0 && pendingReg == null && mn.equals("POP")
                    && ins.getOpObjects(0).length == 1 && ins.getOpObjects(0)[0] instanceof Register r) {
                pendingReg = r;
                continue;
            }
            if (pendingValue >= 0 && pendingReg != null && mn.equals("ADD")
                    && ins.getOpObjects(0).length == 1 && pendingReg.equals(ins.getOpObjects(0)[0])
                    && ins.getOpObjects(1).length == 1 && ins.getOpObjects(1)[0] instanceof Scalar imm) {
                if (((pendingValue + imm.getSignedValue()) & 0xffffffffL) == got) pic.add(pendingReg);
                pendingReg = null;
                pendingValue = -1;
                continue;
            }
            if (mn.equals("MOV") && ins.getNumOperands() == 2 && ins.getOpObjects(1).length == 1
                    && ins.getOpObjects(1)[0] instanceof Scalar imm && fourBytes(ins)) {
                long bits = imm.getUnsignedValue() & 0xffffffffL;
                Float v = floatImmediate(bits);
                if (v != null) found.add(new Lit(ins.getAddress(), "immediate", Float.toString(v), 4, bits));
            }
            boolean x87 = X87_READS.contains(mn);
            boolean lea = mn.equals("LEA");
            int leaIndex = -1;
            if (x87 || lea) {
                for (int i = 0; i < ins.getNumOperands(); i++) {
                    Register reg = null;
                    int regs = 0;
                    long disp = 0;
                    boolean hasDisp = false;
                    for (Object o : ins.getOpObjects(i)) {
                        if (o instanceof Register r) { reg = r; regs++; }
                        else if (o instanceof Scalar s) { disp = s.getSignedValue(); hasDisp = true; }
                    }
                    if (regs != 1) continue; // want exactly [reg + disp]
                    // Ghidra spells x87 operands `float ptr` / `double ptr` (`dword` / `qword` elsewhere).
                    String repr = ins.getDefaultOperandRepresentation(i).toLowerCase();
                    boolean single = repr.startsWith("float ptr") || repr.startsWith("dword ptr");
                    boolean dbl = repr.startsWith("double ptr") || repr.startsWith("qword ptr");
                    Address a;
                    if (x87 && leaRegs.containsKey(reg.getBaseRegister())) {
                        LeaRef ref = leaRegs.get(reg.getBaseRegister());
                        found.set(ref.index(), null);
                        a = ref.addr().add(disp);
                    } else {
                        if (!hasDisp || !pic.contains(reg)) continue;
                        a = toAddr((got + disp) & 0xffffffffL);
                    }
                    if (!rodata.contains(a)) continue;
                    if (x87 && (single || dbl)) {
                        String v = dbl ? Double.toString(Double.longBitsToDouble(getLong(a)))
                                       : Float.toString(Float.intBitsToFloat(getInt(a)));
                        found.add(new Lit(a, dbl ? "double" : "float", v, dbl ? 8 : 4));
                    } else if (lea) {
                        String s = cString(a);
                        // keep a placeholder even for non-strings so an x87 read can reclassify it
                        found.add(new Lit(a, s == null ? "pointer" : "string", s, s == null ? 1 : s.length() + 1));
                        leaIndex = found.size() - 1;
                    }
                }
            }
            for (Object o : ins.getResultObjects()) {
                if (o instanceof Register r) leaRegs.remove(r.getBaseRegister());
            }
            if (leaIndex >= 0) {
                Object[] dest = ins.getOpObjects(0);
                if (dest.length == 1 && dest[0] instanceof Register r)
                    leaRegs.put(r.getBaseRegister(), new LeaRef(leaIndex, found.get(leaIndex).addr()));
            }
        }
        Map<Address, Lit> out = new LinkedHashMap<>();
        for (Lit l : found) {
            if (l != null && !l.kind().equals("pointer")) out.putIfAbsent(l.addr(), l);
        }
        return new ArrayList<>(out.values());
    }

    /** Destination of a MOV is 4 bytes: a 32-bit register or a dword memory operand. */
    static boolean fourBytes(Instruction ins) {
        Object[] dest = ins.getOpObjects(0);
        if (dest.length == 1 && dest[0] instanceof Register r) return r.getBitLength() == 32;
        return ins.getDefaultOperandRepresentation(0).toLowerCase().startsWith("dword ptr");
    }

    static final double FLOAT_IMM_MIN = Math.pow(2, -16), FLOAT_IMM_MAX = Math.pow(2, 24);

    /** The float an imm32 encodes, or null if it does not look like a float constant. */
    static Float floatImmediate(long bits) {
        float v = Float.intBitsToFloat((int) bits);
        if (!Float.isFinite(v) || Math.abs(v) < FLOAT_IMM_MIN || Math.abs(v) > FLOAT_IMM_MAX) return null;
        // Float.toString is the shortest round-trip text (JDK 19+), like binary.py's shortest_float
        String digits = Float.toString(Math.abs(v)).split("E")[0].replace(".", "")
            .replaceAll("^0+", "").replaceAll("0+$", "");
        return digits.length() <= 6 ? v : null;
    }

    /** NUL-terminated printable ASCII at a, C-escaped with quotes; null if not a string. */
    String cString(Address a) throws Exception {
        StringBuilder sb = new StringBuilder("\"");
        for (int i = 0; i < 4096; i++) {
            int c = getByte(a.add(i)) & 0xff;
            if (c == 0) return sb.append('"').toString();
            if (c == '\\') sb.append("\\\\");
            else if (c == '"') sb.append("\\\"");
            else if (c == '\n') sb.append("\\n");
            else if (c == '\t') sb.append("\\t");
            else if (c == '\r') sb.append("\\r");
            else if (c >= 0x20 && c < 0x7f) sb.append((char) c);
            else return null;
        }
        return null;
    }

    static boolean overlaps(Lit x, Lit y) {
        long xs = x.addr().getOffset(), ys = y.addr().getOffset();
        return xs < ys + y.length() && ys < xs + x.length();
    }

    /** Clear whatever analysis put there (rodata is sometimes disassembled) and type the literal. */
    void typeLiteral(Lit l) {
        Listing listing = currentProgram.getListing();
        DataType dt = switch (l.kind()) {
            case "float" -> FloatDataType.dataType;
            case "double" -> DoubleDataType.dataType;
            default -> TerminatedStringDataType.dataType;
        };
        try {
            listing.clearCodeUnits(l.addr(), l.addr().add(l.length() - 1), false);
            listing.createData(l.addr(), dt, l.length());
        } catch (Exception e) {
            println("TYPE-FAIL " + l.addr() + " " + l.kind() + ": " + e.getMessage());
        }
    }

    // A label Ghidra prints for a data address: `LAB_0036b0e4`, `_LAB_...` (read through it),
    // `FLOAT_...` / `DOUBLE_...` (typed data), `DAT_...`; `_N` is an offcut (address + N).
    static final Pattern LABEL = Pattern.compile(
        "(?<![A-Za-z0-9])(&?)_?(?:LAB|DAT|FLOAT|DOUBLE)_([0-9a-f]{8})(?:_(\\d+))?(?![A-Za-z0-9_])");

    /** Replace labels of this function's literals with their values. Typing the data first
     *  resolves most of them; this catches the rest (overlapping strings, offcut labels, and
     *  float data the decompiler still prints by name). */
    static String resolveLabels(String c, List<Lit> lits) {
        Map<Long, Lit> byAddr = new HashMap<>();
        for (Lit l : lits) byAddr.put(l.addr().getOffset(), l);
        for (Lit l : lits) {
            if (!l.kind().equals("immediate")) continue;
            String hex = String.format("0x%x", l.bits());
            c = c.replaceAll("(?<![0-9A-Za-z_])" + hex + "(?![0-9A-Za-z_])",
                Matcher.quoteReplacement(hex + " /* " + l.text() + "f */"));
        }
        Matcher m = LABEL.matcher(c);
        StringBuilder sb = new StringBuilder();
        while (m.find()) {
            long a = Long.parseLong(m.group(2), 16) + (m.group(3) == null ? 0 : Long.parseLong(m.group(3)));
            Lit l = byAddr.get(a);
            boolean addrOf = !m.group(1).isEmpty();
            String rep = m.group(0);
            if (l != null && l.kind().equals("string") && addrOf) rep = l.text();
            else if (l != null && (l.kind().equals("float") || l.kind().equals("double")) && !addrOf) rep = l.text();
            m.appendReplacement(sb, Matcher.quoteReplacement(rep));
        }
        m.appendTail(sb);
        return sb.toString();
    }

    static String literalBlock(List<Lit> lits) {
        if (lits.isEmpty()) return "// literals: none\n";
        StringBuilder sb = new StringBuilder(
            "// literals (Ghidra address of the data, or of the instruction for an immediate; type; value):\n");
        for (Lit l : lits) {
            boolean imm = l.kind().equals("immediate");
            sb.append("//   ").append(l.addr()).append("  ").append(String.format("%-6s", imm ? "float" : l.kind()))
              .append(" ").append(l.text())
              .append(imm ? String.format("  (immediate 0x%08x)", l.bits()) : "").append("\n");
        }
        return sb.toString();
    }
}
