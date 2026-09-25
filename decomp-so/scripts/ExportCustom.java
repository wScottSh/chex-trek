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
//     If it is the high word of a double call argument whose low word is 0 (see
//     doubleHighWord), it is listed as that double instead (`va("%f", -131072.0)`).
// The C-escape rules (cString) and the x87 mnemonic set are duplicated in binary.py.
//
// Args: <outDir> <comma-separated classes> <file of extra qualified method names>
// A method-file line `name` exports every function of that name; `name @ <entry>` (Ghidra
// address, hex) exports only the overload at that entry, e.g. a custom overload of a stock method.
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

    /** kind: float, double, string, pointer (placeholder), immediate (float imm32 `bits`),
     *  immediate-double (`bits` is the high word of a double argument). */
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
        Set<String> methods = new HashSet<>();
        Set<String> overloads = new HashSet<>(); // "name@<entry offset, decimal>"
        for (String line : Files.readAllLines(Paths.get(args[2]))) {
            if (line.isBlank()) continue;
            int at = line.indexOf('@');
            if (at < 0) methods.add(line.trim());
            else overloads.add(line.substring(0, at).trim() + "@" + Long.parseLong(line.substring(at + 1).trim(), 16));
        }
        rodata = currentProgram.getMemory().getBlock(".rodata");
        got = gotAddress();

        List<Function> targets = new ArrayList<>();
        for (Function f : currentProgram.getFunctionManager().getFunctions(true)) {
            if (f.isThunk() || f.isExternal()) continue;
            String full = f.getName(true);
            String cls = full.contains("::") ? full.substring(0, full.lastIndexOf("::")) : "";
            if (classes.contains(cls) || methods.contains(full)
                    || overloads.contains(full + "@" + f.getEntryPoint().getOffset())) targets.add(f);
        }

        // Pass 1: find and type every literal, so pass 2 decompiles against typed data.
        Map<Function, List<Lit>> lits = new LinkedHashMap<>();
        List<Lit> typed = new ArrayList<>();
        for (Function f : targets) {
            List<Lit> list = literals(f);
            lits.put(f, list);
            for (Lit l : list) {
                if (l.kind().startsWith("immediate") || typed.stream().anyMatch(t -> overlaps(t, l))) continue; // keep the first of overlapping strings
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
        List<Instruction> insns = instructions(f);
        for (int k = 0; k < insns.size(); k++) {
            Instruction ins = insns.get(k);
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
                if (v != null) {
                    Double d = doubleHighWord(insns, k, bits);
                    found.add(d != null
                        ? new Lit(ins.getAddress(), "immediate-double", Double.toString(d), 4, bits)
                        : new Lit(ins.getAddress(), "immediate", Float.toString(v), 4, bits));
                }
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
        return shortDigits(Float.toString(Math.abs(v))) ? v : null;
    }

    static final int DOUBLE_WINDOW = 6, ARG_SLOT_MAX = 0x20;

    /** d for a dword operand [ESP + d] (no index) of ins, else null. */
    static Long espSlot(Instruction ins, int op) {
        if (!ins.getDefaultOperandRepresentation(op).toLowerCase().startsWith("dword ptr")) return null;
        Register base = null;
        long disp = 0;
        int regs = 0;
        for (Object o : ins.getOpObjects(op)) {
            if (o instanceof Register r) { base = r; regs++; }
            else if (o instanceof Scalar sc) disp = sc.getSignedValue();
        }
        return regs == 1 && base.getName().equals("ESP") ? disp : null;
    }

    static boolean writes(Instruction ins, Register r) {
        for (Object o : ins.getResultObjects()) {
            if (o instanceof Register w && w.getBaseRegister().equals(r.getBaseRegister())) return true;
        }
        return false;
    }

    /** Operand 1 of insns[j] is zero: imm 0, or a register last set by XOR r,r shortly before. */
    static boolean isZero(List<Instruction> insns, int j) {
        Object[] src = insns.get(j).getOpObjects(1);
        if (src.length != 1) return false;
        if (src[0] instanceof Scalar sc) return sc.getValue() == 0;
        if (!(src[0] instanceof Register r)) return false;
        for (int i = j - 1; i >= Math.max(0, j - DOUBLE_WINDOW); i--) {
            Instruction prev = insns.get(i);
            if (!writes(prev, r)) continue;
            Object[] a = prev.getOpObjects(0), b = prev.getOpObjects(1);
            return prev.getMnemonicString().equalsIgnoreCase("XOR") && a.length == 1 && b.length == 1
                && r.equals(a[0]) && r.equals(b[0]);
        }
        return false;
    }

    /** Mirrors binary.py _double_high_word: the MOV imm32 at insns[k] is the high word of a
     *  double call argument whose low word (stored at [esp+d-4]) is zero -> that double. */
    static Double doubleHighWord(List<Instruction> insns, int k, long bits) {
        Instruction ins = insns.get(k);
        Long slot = espSlot(ins, 0);
        Object[] dest = ins.getOpObjects(0);
        if (slot == null && dest.length == 1 && dest[0] instanceof Register reg) {
            for (int i = k + 1; i < Math.min(insns.size(), k + 1 + DOUBLE_WINDOW); i++) {
                Instruction later = insns.get(i);
                Object[] src = later.getNumOperands() == 2 ? later.getOpObjects(1) : new Object[0];
                if (later.getMnemonicString().equalsIgnoreCase("MOV") && src.length == 1 && reg.equals(src[0])) {
                    slot = espSlot(later, 0);
                    break;
                }
                if (writes(later, reg)) break;
            }
        }
        if (slot == null || slot > ARG_SLOT_MAX) return null;
        boolean call = false;
        for (int i = k + 1; i < Math.min(insns.size(), k + 1 + 2 * DOUBLE_WINDOW); i++) {
            call |= insns.get(i).getMnemonicString().equalsIgnoreCase("CALL");
        }
        if (!call) return null;
        for (int j = Math.max(0, k - DOUBLE_WINDOW); j < Math.min(insns.size(), k + DOUBLE_WINDOW + 1); j++) {
            Instruction st = insns.get(j);
            if (!st.getMnemonicString().equalsIgnoreCase("MOV") || st.getNumOperands() != 2) continue;
            Long lo = espSlot(st, 0);
            if (lo == null || lo != slot - 4 || !isZero(insns, j)) continue;
            double v = Double.longBitsToDouble(bits << 32);
            return shortDigits(Double.toString(Math.abs(v))) ? v : null;
        }
        return null;
    }

    static boolean shortDigits(String text) {
        String digits = text.split("E")[0].replace(".", "").replaceAll("^0+", "").replaceAll("0+$", "");
        return digits.length() <= 6;
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
        Set<Long> annotated = new HashSet<>();
        for (Lit l : lits) {
            if (!l.kind().startsWith("immediate") || !annotated.add(l.bits())) continue;
            String hex = String.format("0x%x", l.bits());
            String note = l.kind().equals("immediate") ? l.text() + "f" : "high word of double " + l.text();
            c = c.replaceAll("(?<![0-9A-Za-z_])" + hex + "(?![0-9A-Za-z_])",
                Matcher.quoteReplacement(hex + " /* " + note + " */"));
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
            boolean imm = l.kind().startsWith("immediate");
            String type = l.kind().equals("immediate") ? "float" : l.kind().equals("immediate-double") ? "double" : l.kind();
            sb.append("//   ").append(l.addr()).append("  ").append(String.format("%-6s", type))
              .append(" ").append(l.text())
              .append(!imm ? "" : l.kind().equals("immediate") ? String.format("  (immediate 0x%08x)", l.bits())
                  : String.format("  (immediate 0x%08x, high word; low word 0)", l.bits()))
              .append("\n");
        }
        return sb.toString();
    }
}
