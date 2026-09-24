"""Tests for the verification harness and the reference outputs it guards.

    python -m unittest discover -s decomp-so/verify -v
"""
from __future__ import annotations

import re
import shutil
import struct
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import verify  # noqa: E402
from binary import GHIDRA_IMAGE_BASE, Binary, source_name  # noqa: E402

BINARY = Binary(verify.BINARY_PATH)
ROWS = verify.load_coverage()
ALLOW = verify.load_allowlist()
COVERED_GROUPS = sorted({r.group for r in ROWS if r.status == "covered"})


def reference(group: str) -> str:
    return (verify.REFERENCE_DIR / f"{group}.md").read_text(encoding="utf-8")


def missing_pairs(results) -> set[tuple[str, str]]:
    return {(r.row.function, verify.strip_params(c.name)) for r in results for c in r.missing}


class CalleeCoverage(unittest.TestCase):
    def test_every_covered_group_passes_check_1(self):
        self.assertIn("custom-ui", COVERED_GROUPS)
        for group in COVERED_GROUPS:
            with self.subTest(group=group):
                results = verify.check_group(group, BINARY, ROWS, ALLOW)
                self.assertTrue(results)
                self.assertEqual([l for r in results if not r.ok for l in verify.format_results([r])], [])

    def test_custom_ui_covers_its_scope(self):
        names = {r.function for r in ROWS if r.group == "custom-ui" and r.status == "covered"}
        self.assertEqual(
            names,
            {"idPlayer::useCustomUI", "idPlayer::clearCustomUI", "idCmdSystem::ArgCompletion_GuiName"}
            | {r.function for r in ROWS if r.function.startswith("idCustomUI::")},
        )
        self.assertEqual(len([r for r in ROWS if r.group == "custom-ui"]), 16)

    def test_end_level_stats_covers_its_scope(self):
        names = {r.function for r in ROWS if r.group == "end-level-stats" and r.status == "covered"}
        self.assertEqual(
            names,
            {"idPlayer::getLevelStats", "idPlayer::incSecretsFound", "idGameLocal::GetLevelStats", "idStr::FormatTime"}
            | {r.function for r in ROWS if r.function.startswith("idTarget_EndLevelGUI::")},
        )
        self.assertEqual(len([r for r in ROWS if r.group == "end-level-stats"]), 15)

    def test_objectives_covers_its_scope(self):
        names = {r.function for r in ROWS if r.group == "objectives" and r.status == "covered"}
        self.assertEqual(
            names,
            {"idPlayer::addObjective", "idPlayer::freeObjective", "idPlayer::addItemText"}
            | {r.function for r in ROWS if r.function.startswith("mkObjective::")},
        )
        self.assertEqual(len([r for r in ROWS if r.group == "objectives"]), 13)

    def test_class_declaration_names_the_base_constructor(self):
        """CreateInstance calls the superclass's constructor; CLASS_DECLARATION must name it."""
        cases = [  # group, class, its base, a wrong base
            ("end-level-stats", "idTarget_EndLevelGUI", "idCustomUI", "idEntity"),
            ("objectives", "mkObjective", "idEntity", "idCustomUI"),
        ]
        for group, cls, base, wrong in cases:
            with self.subTest(group=group):
                text = reference(group)
                macro = f"CLASS_DECLARATION( {base}, {cls} )"
                self.assertEqual(text.count(macro), 1)
                self.assertIn(f"class {cls} : public {base} {{", text)
                body = verify.find_macro_body(verify.implementation_block(text), f"{cls}::CreateInstance")
                self.assertIn(f"{base}::{base}()", body)
                results = verify.check_group(group, BINARY, ROWS, ALLOW,
                                             text.replace(macro, f"CLASS_DECLARATION( {wrong}, {cls} )"))
                self.assertEqual(missing_pairs(results), {(f"{cls}::CreateInstance", f"{base}::{{base ctor}}")})

    def test_deleting_a_call_fails_and_names_function_and_callee(self):
        text = reference("custom-ui")
        call = "\tsavefile->ReadBool( registered );\n"
        self.assertEqual(text.count(call), 1)
        results = verify.check_group("custom-ui", BINARY, ROWS, ALLOW, text.replace(call, ""))
        self.assertEqual(missing_pairs(results), {("idCustomUI::Restore", "idRestoreGame::ReadBool")})
        report = "\n".join(verify.format_results(results))
        self.assertIn("MISSING  idCustomUI::Restore @ 0x18e230: idRestoreGame::ReadBool(bool&)", report)
        self.assertIn("1 missing callee(s)", report)

    def test_every_checked_callee_is_load_bearing(self):
        """Mutation sweep: strip each callee mention from its function's definition -> reported."""
        for group in COVERED_GROUPS:
            text = reference(group)
            impl = verify.implementation_block(text)
            for row in (r for r in ROWS if r.group == group and r.status == "covered"):
                func = BINARY.by_raw[row.symbol]
                body = verify.find_definition(impl, source_name(func.name))
                if body is None:
                    continue  # macro-generated; covered by test_wrong_declaration_macro_fails
                for callee in BINARY.callees(func):
                    if callee.ignored or verify.allowed(func, callee, ALLOW):
                        continue
                    with self.subTest(function=row.function, at=hex(row.vaddr), callee=callee.name):
                        mutated_body = verify.callee_pattern(callee.name).sub("", body)
                        self.assertEqual(text.count(body), 1)
                        results = verify.check_group(group, BINARY, ROWS, ALLOW, text.replace(body, mutated_body))
                        hit = [r for r in results if r.row.vaddr == row.vaddr][0]
                        self.assertIn(callee, hit.missing)

    def test_a_mention_in_a_comment_does_not_count(self):
        text = reference("custom-ui")
        call = "\tidEntity::Hide();\n"
        self.assertEqual(text.count(call), 1)
        results = verify.check_group(
            "custom-ui", BINARY, ROWS, ALLOW, text.replace(call, "\t// idEntity::Hide(); \"Hide\"\n")
        )
        self.assertEqual(missing_pairs(results), {("idCustomUI::Event_Hide", "idEntity::Hide")})

    def test_implicit_base_destructor_may_be_named_in_a_comment(self):
        self.assertTrue(verify.is_structor("idEntity::{base dtor}()"))
        self.assertTrue(verify.is_structor("idEntity::{base ctor}()"))
        self.assertFalse(verify.is_structor("idEntity::Hide()"))

    def test_wrong_declaration_macro_fails(self):
        text = reference("custom-ui").replace("ABSTRACT_DECLARATION( idEntity, idCustomUI )",
                                              "CLASS_DECLARATION( idEntity, idCustomUI )")
        results = verify.check_group("custom-ui", BINARY, ROWS, ALLOW, text)
        self.assertEqual(missing_pairs(results), {("idCustomUI::CreateInstance", "idGameLocal::Error")})

    def test_missing_definition_is_an_error(self):
        text = reference("custom-ui").replace("void idCustomUI::setGUI(", "void idCustomUI::setGui(")
        results = verify.check_group("custom-ui", BINARY, ROWS, ALLOW, text)
        errors = {r.row.function: r.error for r in results if r.error}
        self.assertEqual(list(errors), ["idCustomUI::setGUI"])
        self.assertIn("no definition", errors["idCustomUI::setGUI"])


def literal_problems(results) -> set[tuple[str, str]]:
    out = {(r.row.function, lit.render()) for r in results for lit in r.missing_literals}
    out |= {(r.row.function, "mismatched " + s) for r in results for s in r.mismatched_strings}
    return out


def synthetic(function: str, group: str = "synthetic") -> list[verify.CoverageRow]:
    """A coverage record with one `covered` row for `function`, for tests on real binary
    functions whose group is not reconstructed yet."""
    f = BINARY.find(function)[0]
    return [verify.CoverageRow(function, f.raw, f.vaddr, "", group, "covered")]


def synthetic_reference(body: str) -> str:
    return f"```cpp\n// header\n```\n\n```cpp\n{body}\n```\n"


class ConstantsAndStrings(unittest.TestCase):
    """Check 2."""

    def test_changing_a_string_fails_and_names_it(self):
        text = reference("custom-ui")
        code = 'token->Icmp( "unregister" )'
        self.assertEqual(text.count(code), 1)
        results = verify.check_group(
            "custom-ui", BINARY, ROWS, ALLOW, text.replace(code, code.replace("unregister", "unregistr"))
        )
        self.assertEqual(
            literal_problems(results),
            {("idCustomUI::HandleCustomGUICommand", 'string "unregister"'),
             ("idCustomUI::HandleCustomGUICommand", "mismatched unregistr")},
        )
        report = "\n".join(verify.format_results(results))
        self.assertIn('LITERAL  idCustomUI::HandleCustomGUICommand @ 0x18e130: missing string "unregister"', report)
        self.assertIn('LITERAL  idCustomUI::HandleCustomGUICommand @ 0x18e130: mismatched "unregistr"', report)
        self.assertIn("2 missing/mismatched literal(s)", report)

    def test_changing_a_float_fails_and_names_it(self):
        # mkTrail::addNewAnchor reads 0.5, 1.5 and -0.5 (and the group is not reconstructed yet).
        rows = synthetic("mkTrail::addNewAnchor")
        body = "void mkTrail::addNewAnchor( void ) {{ a = b * 0.5f; c = {} - d; e = f * -0.5f; }}"
        ok = verify.check_group("synthetic", BINARY, rows, [], synthetic_reference(body.format("1.5f")))
        self.assertEqual(literal_problems(ok), set())
        bad = verify.check_group("synthetic", BINARY, rows, [], synthetic_reference(body.format("1.25f")))
        self.assertEqual(literal_problems(bad), {("mkTrail::addNewAnchor", "float 1.5")})
        report = "\n".join(verify.format_results(bad))
        self.assertIn("LITERAL  mkTrail::addNewAnchor @ 0x2a59d0: missing float 1.5", report)

    def test_sign_of_a_float_matters(self):
        rows = synthetic("mkTrail::addNewAnchor")
        body = "void mkTrail::addNewAnchor( void ) { a = b * 0.5f; c = 1.5f * d; e = f * 0.5f; }"
        results = verify.check_group("synthetic", BINARY, rows, [], synthetic_reference(body))
        self.assertEqual(literal_problems(results), {("mkTrail::addNewAnchor", "float -0.5")})
        # a unary -0.5f is not the constant 0.5; a binary `x-0.5f` is
        body = "void mkTrail::addNewAnchor( void ) { a = b * -0.5f; c = 1.5f * d; }"
        results = verify.check_group("synthetic", BINARY, rows, [], synthetic_reference(body))
        self.assertEqual(literal_problems(results), {("mkTrail::addNewAnchor", "float 0.5")})
        body = "void mkTrail::addNewAnchor( void ) { a = b-0.5f; c = 1.5f * d * -0.5f; }"
        results = verify.check_group("synthetic", BINARY, rows, [], synthetic_reference(body))
        self.assertEqual(literal_problems(results), set())

    def test_a_double_constant_must_not_be_written_as_float(self):
        rows = synthetic("mkTrail::UpdateRenderEntity")
        body = "bool mkTrail::UpdateRenderEntity( void ) {{ y = 1.5f * 0.5f * -0.5f; w = 1.0f; z < {}; }}"
        good = verify.check_group("synthetic", BINARY, rows, [], synthetic_reference(body.format("0.001")))
        self.assertEqual(literal_problems(good), set())
        bad = verify.check_group("synthetic", BINARY, rows, [], synthetic_reference(body.format("0.001f")))
        self.assertEqual(literal_problems(bad), {("mkTrail::UpdateRenderEntity", "double 0.001")})

    def test_a_literal_in_a_comment_does_not_count(self):
        text = reference("custom-ui").replace(
            'token->Icmp( "unregister" )', 'token->Icmp( cmd ) /* "unregister" */'
        )
        results = verify.check_group("custom-ui", BINARY, ROWS, ALLOW, text)
        self.assertEqual(literal_problems(results), {("idCustomUI::HandleCustomGUICommand", 'string "unregister"')})

    def test_every_checked_literal_is_load_bearing(self):
        """Mutation sweep: alter each binary string literal in its function's definition -> reported."""
        for group in COVERED_GROUPS:
            text = reference(group)
            impl = verify.implementation_block(text)
            for row in (r for r in ROWS if r.group == group and r.status == "covered"):
                func = BINARY.by_raw[row.symbol]
                body = verify.find_definition(impl, source_name(func.name))
                if body is None:
                    continue  # macro-generated; see test_macro_literals_are_checked
                for lit in BINARY.literals(func):
                    if lit.kind != "string":
                        continue  # float mutations: test_changing_a_float_fails_and_names_it and siblings
                    with self.subTest(function=row.function, literal=lit.render()):
                        quoted = verify.c_string(lit.value)
                        self.assertIn(quoted, body)
                        mutated = text.replace(body, body.replace(quoted, quoted[:-1] + '~"'))
                        results = verify.check_group(group, BINARY, ROWS, ALLOW, mutated)
                        hit = [r for r in results if r.row.vaddr == row.vaddr][0]
                        self.assertIn(lit, hit.missing_literals)
                        self.assertIn(lit.value + "~", hit.mismatched_strings)

    def test_macro_literals_are_checked(self):
        # ABSTRACT_DECLARATION's CreateInstance passes "idCustomUI" (#nameofclass) to gameLocal.Error.
        text = reference("custom-ui").replace("ABSTRACT_DECLARATION( idEntity, idCustomUI )",
                                              "CLASS_DECLARATION( idEntity, idCustomUI )")
        results = verify.check_group("custom-ui", BINARY, ROWS, ALLOW, text)
        self.assertEqual(
            literal_problems(results),
            {("idCustomUI::CreateInstance", 'string "idCustomUI"'),
             ("idCustomUI::CreateInstance", 'string "Cannot instanciate abstract class %s."')},
        )

    def test_literal_allowlist_accepts_a_documented_literal(self):
        rows = synthetic("mkTrail::Think")
        body = "void mkTrail::Think( void ) { GetPhysics(); c.Lerp( a, b, t ); x = idMath::InvSqrt( y ); }"
        allow = [verify.AllowEntry("mkTrail::Think", "float [01].5", "stock-inline", "idMath::InvSqrt Newton step")]
        results = verify.check_group("synthetic", BINARY, rows, [], synthetic_reference(body), allow)
        self.assertEqual(literal_problems(results), set())
        self.assertEqual(sorted(l.render() for l, _ in results[0].allowed_literals), ["float 0.5", "float 1.5"])
        self.assertIn("allow-listed float 0.5 (stock-inline)", "\n".join(verify.format_results(results)))

    def test_literal_allowlist_is_documented(self):
        for entry in verify.load_allowlist(verify.LITERAL_ALLOWLIST_PATH):
            self.assertEqual(entry.kind, "stock-inline")
            self.assertGreater(len(entry.reason), 20)


class LiteralParsing(unittest.TestCase):
    def test_string_literals_join_unescape_and_skip_comments(self):
        code = 'f( "a" /* x */ "b", "c\\n\\"q\\"\\x41\\101", \'"\' ); // "not code"\n g( "d" ); /* "no" */'
        self.assertEqual(verify.string_literals(code), ["ab", 'c\n"q"AA', "d"])
        self.assertEqual(verify.string_literals('x = "";'), [""])

    def test_float_tokens(self):
        code = verify.code_only(
            "a = 32.0f + .05 - 1e-3 * 2 + 0x1f + 7 + b.x + 1.5F; c = -0.5f; d = f()-4.0 + x*-2.0; // 9.0"
        )
        values = sorted({v for v, _ in verify.float_literals(code)})
        self.assertEqual(values, sorted({32.0, 0.05, 1e-3, 1.5, -0.5, 4.0, -2.0}))
        for unary in ("return -0.5f;", "case -1.0:", "x = (float)-3.0;", "x = ( const double ) - 3.0;"):
            self.assertLess(verify.float_literals(unary)[0][0], 0, unary)
        for binary in ("x = (a)-3.0;", "x = b[2] - 3.0;", "x = returned - 3.0;"):
            self.assertGreater(verify.float_literals(binary)[0][0], 0, binary)
        self.assertEqual(dict(verify.float_literals("a = 2.5f;")), {2.5: True})

    def test_rendering(self):
        from binary import Literal

        self.assertEqual(Literal("float", 32.0).render(), "float 32.0")
        self.assertEqual(Literal("float", 0.1).render(), "float 0.1")
        self.assertEqual(Literal("double", 0.001).render(), "double 0.001")
        self.assertEqual(Literal("string", 'a"b\n').render(), 'string "a\\"b\\n"')
        f01 = struct.unpack("<f", struct.pack("<f", 0.1))[0]
        self.assertEqual(Literal("float", f01).render(), "float 0.1")


class BinaryLiterals(unittest.TestCase):
    def test_float_immediates(self):
        from binary import float_immediate

        self.assertEqual(float_immediate(0x42000000), 32.0)
        self.assertEqual(float_immediate(0xBF800000), -1.0)
        self.assertAlmostEqual(float_immediate(0x42937AE1), 73.74, places=4)
        for integer in (0x14, 0x21080, 0x2B5549, 0x5F3759DF, 0x4A90BE59, 0x45E7B273, 0xFFFFFFFF):
            self.assertIsNone(float_immediate(integer), hex(integer))

    def test_double_argument_high_word_is_a_double(self):
        # initHudMap: `xor eax,eax; mov [esp+4],eax; mov eax,0xc1000000; mov [esp+8],eax` -> va( "%f", -131072.0 )
        lits = {l.render() for l in BINARY.literals(BINARY.find("idPlayer::initHudMap")[0])}
        self.assertIn("double -131072.0", lits)
        self.assertNotIn("float -8.0", lits)
        # a stack-local idVec3 ( 0, 1.0f, ... ) next to a zero stays a float
        foot = {l.render() for l in BINARY.literals(BINARY.find("idActor::Event_FootPrint")[0])}
        self.assertTrue({"float 1.0", "float -1.0", "float 8.0"} <= foot, foot)
        self.assertFalse([l for l in foot if l.startswith("double")], foot)

    def test_every_rodata_read_in_the_export_is_classified(self):
        for r in ROWS:
            refs = BINARY.rodata_refs(BINARY.by_raw[r.symbol])
            with self.subTest(function=r.function, at=hex(r.vaddr)):
                self.assertEqual([hex(x.at) for x in refs if x.kind == "unclassified"], [])

    def test_mktrail_spot_values(self):
        spawn = [l.render() for l in BINARY.literals(BINARY.find("mkTrail::Spawn")[0])]
        self.assertEqual(spawn[spawn.index('string "trailWidth"') + 1], 'string "32"')  # width 32.0, not 4.0
        for row in (r for r in ROWS if r.function == "mkTrail::mkTrail"):
            # the constructors store width 32.0 as an immediate (0x42000000) at this+0x4c
            ctor_lits = [l.render() for l in BINARY.literals(BINARY.by_raw[row.symbol])]
            self.assertEqual(ctor_lits, ["float 2.0", "float 32.0", "float 16.0"], hex(row.vaddr))
        anchor = {l.render() for l in BINARY.literals(BINARY.find("mkTrail::addNewAnchor")[0])}
        self.assertEqual(anchor, {"float 0.5", "float 1.5", "float -0.5"})
        render = {l.render() for l in BINARY.literals(BINARY.find("mkTrail::UpdateRenderEntity")[0])}
        # 0.5 is read through a register: `lea edx, [ebx-0x7651c]` then an x87 read of [edx].
        self.assertEqual(render, {"double 0.001", "float 0.5", "float 1.5", "float -0.5", "float 1.0"})


def export_literals(text: str) -> set[tuple[str, float | str]]:
    """(kind, value) from an export file's `// literals` block."""
    out = set()
    for line in text.splitlines():
        m = re.match(r"//\s+[0-9a-f]{8}\s+(float|double|string)\s+(.*?)(?:\s+\(immediate 0x[0-9a-f]{8}[^)]*\))?$", line)
        if not m:
            continue
        kind, raw = m.groups()
        if kind == "string":
            out.add((kind, verify.c_unescape(raw[1:-1])))
        else:
            out.add((kind, verify.to_precision(float(raw), kind)))
    return out


class EnrichedExport(unittest.TestCase):
    def read(self, row) -> str:
        return (verify.GHIDRA_DIR / row.export).read_text(encoding="utf-8")

    def test_every_export_lists_the_literals_the_binary_reads(self):
        """ExportCustom.java (Ghidra) and binary.py (capstone) find literals independently."""
        for r in ROWS:
            with self.subTest(export=r.export):
                text = self.read(r)
                self.assertRegex(text, r"^// .*\n// .*\n// literals")
                expected = {(l.kind, l.value) for l in BINARY.literals(BINARY.by_raw[r.symbol])}
                self.assertEqual(export_literals(text), expected)

    def test_mktrail_values_are_readable(self):
        by_fn = {r.function: self.read(r) for r in ROWS if r.function.startswith("mkTrail::")}
        for row in (r for r in ROWS if r.function == "mkTrail::mkTrail"):
            ctor = self.read(row)
            self.assertIn("(this + 0x4c) = 0x42000000 /* 32.0f */;", ctor.replace("*(undefined4 *)", ""))
        spawn = by_fn["mkTrail::Spawn"]
        self.assertRegex(spawn, r'"trailWidth"\);\s*\n\s*\w+ = "32";')
        anchor = by_fn["mkTrail::addNewAnchor"]
        body = anchor[anchor.index("{"):]
        for value in ("0.5", "1.5", "-0.5"):
            self.assertRegex(body, r"(?<![\w.])" + re.escape(value) + r"(?![\d])", value)
        self.assertNotIn("_LAB_0036b0e4", anchor)  # 0.5 used to be shown as this label
        render = by_fn["mkTrail::UpdateRenderEntity"]
        self.assertRegex(render[render.index("{"):], r"(?<![\w.])0\.001(?![\d])")  # the epsilon

    def test_immediates_are_annotated_once(self):
        for r in ROWS:
            with self.subTest(export=r.export):
                self.assertNotRegex(self.read(r), r"/\* [^*]* \*/ /\* ")
        hud = next(self.read(r) for r in ROWS if r.function == "idPlayer::initHudMap")
        self.assertIn("0xc1000000 /* high word of double -131072.0 */", hud)

    def test_callee_coverage_did_not_regress(self):
        """Each export still names at least as many direct callees as the first full export."""
        path = verify.VERIFY_DIR / "export-callee-baseline.tsv"
        baseline = {}
        for line in path.read_text(encoding="utf-8").splitlines():
            if line and not line.startswith("#"):
                export, found, total = line.split("\t")[:3]
                baseline[export] = (int(found), int(total))
        self.assertEqual(sorted(baseline), sorted(r.export for r in ROWS))
        for r in ROWS:
            text = self.read(r)
            callees = [c for c in BINARY.callees(BINARY.by_raw[r.symbol]) if not c.ignored]
            found = sum(1 for c in callees if verify.callee_pattern(c.name).search(text))
            with self.subTest(export=r.export):
                self.assertEqual(len(callees), baseline[r.export][1])
                self.assertGreaterEqual(found, baseline[r.export][0])


class HarnessRules(unittest.TestCase):
    def test_operator_names_are_normalized(self):
        new_arr = verify.callee_pattern("operator new[](unsigned int)")
        new_obj = verify.callee_pattern("idClass::operator new(unsigned int)")
        delete = verify.callee_pattern("idClass::operator delete(void*)")
        delete_arr = verify.callee_pattern("operator delete[](void*)")
        for text in ("operator_new__( n )", "p = new int[ 4 ];", "operator new[]( n )"):
            self.assertTrue(new_arr.search(text), text)
        self.assertFalse(new_arr.search("p = new idFoo;"))
        for text in ("p = new idFoo;", "idClass::operator new( n )", "operator_new( n )"):
            self.assertTrue(new_obj.search(text), text)
        self.assertFalse(new_obj.search("operator_new__( n )"))
        self.assertFalse(new_obj.search("p = new int[ 4 ];"))
        self.assertTrue(delete.search("delete p;"))
        self.assertFalse(delete.search("delete[] p;"))
        self.assertTrue(delete_arr.search("delete[] p;"))
        self.assertTrue(delete_arr.search("operator_delete__( p )"))
        self.assertEqual(verify.normalize_operator("operator_new__"), "new[]")
        self.assertEqual(verify.normalize_operator("operator new[]"), "new[]")

    def test_constructor_and_destructor_callees(self):
        base_dtor = verify.callee_pattern("idEntity::{base dtor}()")
        self.assertTrue(base_dtor.search("// runs idEntity::~idEntity()"))
        self.assertFalse(base_dtor.search("idEntity *ent;"))
        self.assertTrue(verify.callee_pattern("idEntity::{base ctor}()").search("idEntity::idEntity() first"))
        self.assertFalse(verify.callee_pattern("idEntity::Hide()").search("Event_Hide();"))

    def test_operator_names_keep_their_brackets(self):
        from binary import strip_params

        self.assertEqual(strip_params("idVec3::operator<(idVec3 const&)"), "idVec3::operator<")
        self.assertEqual(strip_params("idFoo::operator->()"), "idFoo::operator->")
        self.assertEqual(strip_params("idFoo::operator()(int)"), "idFoo::operator()")
        self.assertEqual(strip_params("idList<idStr>::Append(idStr const&)"), "idList<idStr>::Append")
        self.assertEqual(strip_params("operator new[](unsigned int)"), "operator new[]")
        self.assertEqual(strip_params("idStr::operator<<=(int)"), "idStr::operator<<=")

    def test_unterminated_comment_is_an_error_not_a_hang(self):
        with self.assertRaises(ValueError):
            verify.find_definition("void f( int a /* oops ", "f")

    def test_aliased_symbols_resolve(self):
        f = BINARY.by_raw["_ZN10idCustomUIC2Ev"]
        self.assertEqual((f.vaddr, f.size), (0x18DDB0, 72))

    def test_abi_clones_collapse_to_one_source_name(self):
        by_addr = {r.vaddr: BINARY.by_raw[r.symbol] for r in ROWS}
        self.assertEqual(source_name(by_addr[0x18dd60].name), "idCustomUI::idCustomUI")  # C1
        self.assertEqual(source_name(by_addr[0x18ddb0].name), "idCustomUI::idCustomUI")  # C2
        self.assertEqual(source_name(by_addr[0x199100].name), "idCustomUI::~idCustomUI")  # D0
        self.assertEqual(source_name(by_addr[0x199150].name), "idCustomUI::~idCustomUI")  # D1
        self.assertEqual(source_name(by_addr[0x18d3b0].name), "idCustomUI::GetType")  # const stripped

    def test_exception_helpers_and_pic_thunk_are_ignored(self):
        f = BINARY.find("idTarget::CreateInstance")[0]  # stock CLASS_DECLARATION expansion
        callees = {c.raw: c for c in BINARY.callees(f)}
        for raw in ("_Unwind_Resume", "__cxa_begin_catch", "__cxa_end_catch", "__i686.get_pc_thunk.bx"):
            self.assertTrue(callees[raw].ignored, raw)
        delete = next(c for c in callees.values() if "operator delete" in c.name)
        entry = verify.allowed(f, delete, ALLOW)
        self.assertIsNotNone(entry)
        self.assertEqual(entry.kind, "exception-only")

    def test_real_byte_range_comes_from_the_symbol_table(self):
        f = BINARY.find("idCustomUI::setGUI")[0]
        self.assertEqual((f.vaddr, f.size), (0x18D3D0, 198))  # Ghidra reports a 192-byte body

    def test_allowlist_is_documented(self):
        for entry in ALLOW:
            self.assertIn(entry.kind, {"exception-only", "abi-implicit", "stock-inline"})
            self.assertGreater(len(entry.reason), 20)
            if entry.kind == "stock-inline":  # one exact function, and the stock code named
                self.assertNotIn("*", entry.function)
                self.assertRegex(entry.reason, r"(idlib|game)/(\w+/)*\w+\.h")  # e.g. idlib/containers/List.h

    def test_every_allowlist_entry_is_used(self):
        """No stale entries: each one excuses at least one callee of a covered function."""
        used = set()
        for group in COVERED_GROUPS:
            for res in verify.check_group(group, BINARY, ROWS, ALLOW):
                used |= {(a.function, a.pattern) for _, a in res.allowed}
        self.assertEqual([(a.function, a.pattern) for a in ALLOW if (a.function, a.pattern) not in used], [])


class Records(unittest.TestCase):
    def test_coverage_record_lists_all_84_exported_functions(self):
        index = [l.split("\t") for l in verify.GHIDRA_INDEX.read_text(encoding="utf-8").splitlines()]
        self.assertEqual(len(ROWS), 84)
        self.assertEqual(sorted(r.export for r in ROWS), sorted(f"{safe}.c" for safe, _, _ in index))
        for r in ROWS:
            with self.subTest(export=r.export):
                self.assertTrue((verify.GHIDRA_DIR / r.export).exists())
                self.assertEqual(BINARY.by_raw[r.symbol].vaddr, r.vaddr)
                self.assertEqual(int(r.export.rsplit("_", 1)[1][:-2], 16), r.vaddr + GHIDRA_IMAGE_BASE)
                self.assertIn(r.status, {"covered", "pending"})
                self.assertTrue(r.group)

    def test_reference_files_state_model_and_export(self):
        files = [verify.REFERENCE_DIR / f"{g}.md" for g in COVERED_GROUPS]
        files.append(verify.REFERENCE_DIR / "idPlayer-additions.md")
        for path in files:
            with self.subTest(file=path.name):
                text = path.read_text(encoding="utf-8")
                self.assertRegex(text, r"\*\*Provenance:\*\*.*Claude Opus 5\.5")
                self.assertIn("decomp-so/ghidra-full/", text)

    def test_reference_files_have_header_implementation_and_notes(self):
        for group in COVERED_GROUPS:
            with self.subTest(group=group):
                text = reference(group)
                self.assertEqual(len(verify.cpp_blocks(text)), 2)
                for heading in ("## Header", "## Implementation", "## Notes"):
                    self.assertIn(heading, text)

    def test_idplayer_additions_have_unique_offsets(self):
        text = (verify.REFERENCE_DIR / "idPlayer-additions.md").read_text(encoding="utf-8")
        offsets = re.findall(r"^\| `\+(0x[0-9a-f]+)` \|", text, re.M)
        self.assertIn("0x1f0c", offsets)
        self.assertIn("0x1f10", offsets)
        self.assertIn("0x1ea4", offsets)
        self.assertIn("0x1ef4", offsets)
        self.assertIn("0x1f08", offsets)
        self.assertEqual(len(offsets), len(set(offsets)))


sys.path.insert(0, str(verify.COMPILE_DIR))
import worker  # noqa: E402


def md_line(text: str, needle: str) -> int:
    """1-based line of the (unique) line containing `needle`."""
    lines = [i for i, l in enumerate(text.splitlines(), 1) if needle in l]
    assert len(lines) == 1, (needle, lines)
    return lines[0]


class CompileSplicing(unittest.TestCase):
    """Check 3's preparation (compile/worker.py), without a compiler."""

    def test_job_line_numbers_point_at_the_blocks(self):
        text = reference("custom-ui")
        job = verify.compile_job("custom-ui", text)
        lines = text.splitlines()
        self.assertEqual(lines[job["header_line"] - 1], job["header"].splitlines()[0])
        self.assertEqual(lines[job["impl_line"] - 1], job["impl"].splitlines()[0])
        self.assertEqual(job["source"], "decomp-so/reference/custom-ui.md")

    def test_top_level_classes_of_the_custom_ui_header(self):
        header = verify.cpp_blocks(reference("custom-ui"))[0]
        found = [(c["name"], c["forward"]) for c in worker.top_level_classes(header)]
        self.assertEqual(found, [("idCustomUI", False), ("idCustomUI", True), ("idPlayer", False),
                                 ("idCmdSystem", False)])

    def test_declarators_after_a_class_body(self):
        text = "typedef struct a_s {\n\tint x;\n} a_t;\nclass idB {\n} g_b, *g_pb;\nclass idC { int y; };\n"
        found = worker.top_level_classes(text)
        self.assertEqual([c["name"] for c in found], ["a_s", "idB", "idC"])
        self.assertEqual(text[found[1]["start"]:found[1]["end"]], "class idB {\n} g_b, *g_pb;")
        with self.assertRaisesRegex(ValueError, "no ';'"):
            worker.top_level_classes("class idD {\n}\nvoid f() {}")
        with self.assertRaisesRegex(ValueError, "no ';'"):  # a missing ';' must not swallow the next declaration
            worker.top_level_classes("class idA {\n}\nclass idB;\n")

    def fake_neo(self, files: dict[str, str]) -> str:
        root = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, root, True)
        for rel, text in files.items():
            path = Path(root, rel)
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text, encoding="latin-1")
        return root

    def test_additions_are_spliced_into_the_stock_class_with_line_mapping(self):
        neo = self.fake_neo({
            "game/Player.h": "class idActor;\nclass idPlayer : public idActor {\npublic:\n\tint stock;\n};\n",
            "d3xp/Player.h": "class idPlayer : public idActor {\n};\n",  # expansion: not searched
        })
        header = ("// h\nclass idNew;\n\nclass idPlayer : public idActor {\n\t// ... stock members ...\n"
                  "public:\n\tidNew *added;\n};\n\nclass idNew {\n\tint x;\n};\n")
        job = {"group": "g", "source": "ref.md", "header": header, "header_line": 10, "impl": "int f;", "impl_line": 40}
        tu, splices = worker.prepare(neo, job)
        self.assertEqual(splices, [{"class": "idPlayer", "file": "game/Player.h", "line": 13}])
        stock = Path(neo, "game/Player.h").read_text(encoding="latin-1")
        self.assertEqual(
            stock,
            "class idActor;\nclass idPlayer : public idActor {\npublic:\n\tint stock;\n"
            '#line 13 "ref.md"\n\n\t// ... stock members ...\npublic:\n\tidNew *added;\n\n#line 5 "Player.h"\n};\n',
        )
        # forward declaration before the stock headers; the stock class's lines blanked, new class kept
        self.assertLess(tu.index('#line 11 "ref.md"\nclass idNew;'), tu.index('#include "Game_local.h"'))
        header_part = tu[tu.index('#line 10 "ref.md"\n') + len('#line 10 "ref.md"\n'): tu.index('#line 40')]
        self.assertEqual(header_part.count("\n"), header.count("\n") + 1)
        self.assertNotIn("idPlayer", header_part)
        self.assertIn("class idNew {\n\tint x;\n};", header_part)
        self.assertIn('#line 40 "ref.md"\nint f;', tu)

    def test_non_game_stock_header_path_and_one_line_close(self):
        neo = self.fake_neo({"framework/CmdSystem.h": "class idCmdSystem {\npublic:\n\tint a; };\n"})
        job = {"group": "g", "source": "r.md", "header": "class idCmdSystem {\n\tint b;\n};\n",
               "header_line": 1, "impl": "", "impl_line": 5}
        _, splices = worker.prepare(neo, job)
        self.assertEqual(splices, [{"class": "idCmdSystem", "file": "framework/CmdSystem.h", "line": 1}])
        stock = Path(neo, "framework/CmdSystem.h").read_text(encoding="latin-1")
        self.assertIn('\tint a; \n#line 1 "r.md"\n\n\tint b;\n\n#line 3 "../framework/CmdSystem.h"\n};', stock)

    def test_job_lists_the_header_blocks_it_depends_on(self):
        text = reference("end-level-stats")
        self.assertEqual(verify.header_deps(text), ["custom-ui"])
        job = verify.compile_job("end-level-stats", text)
        dep = verify.compile_job("custom-ui", reference("custom-ui"))
        self.assertEqual(dep["deps"], [])
        self.assertEqual(job["deps"], [{"source": dep["source"], "header": dep["header"],
                                        "header_line": dep["header_line"]}])

    def test_unknown_or_circular_dependency_is_an_error(self):
        body = "## Header\n```cpp\nint a;\n```\n## Implementation\n```cpp\nint b;\n```\n"
        with self.assertRaisesRegex(ValueError, "no reference file"):
            verify.compile_job("g", "**Depends on:** `no-such-group`\n" + body)
        with self.assertRaisesRegex(ValueError, "circular"):
            verify.compile_job("custom-ui", "**Depends on:** `custom-ui`\n" + body)

    def test_new_class_held_by_value_goes_before_the_stock_headers(self):
        neo = self.fake_neo({"game/Player.h": "class idPlayer : public idActor {\n};\n"})
        header = ("struct byValue_s {\n\tint a;\n};\nstruct byPointer_s {\n\tint b;\n};\n"
                  "class idPlayer : public idActor {\n\tbyValue_s held[ 2 ];\n\tbyPointer_s *ptr;\n};\n")
        job = {"group": "g", "source": "r.md", "header": header, "header_line": 1, "impl": "", "impl_line": 20}
        tu, _ = worker.prepare(neo, job)
        game_local = tu.index('#include "Game_local.h"')
        self.assertLess(tu.index('#line 1 "r.md"\nstruct byValue_s {'), game_local)
        self.assertGreater(tu.index("struct byPointer_s {"), game_local)
        self.assertEqual(tu.count("struct byValue_s {"), 1)

    def test_dependency_header_blocks_come_first(self):
        neo = self.fake_neo({"game/Player.h": "class idPlayer : public idActor {\n};\n"})
        dep = {"source": "dep.md", "header": "class idBase;\nclass idPlayer : public idActor {\n\tidBase *b;\n};\n"
               "class idBase {\n};\n", "header_line": 3}
        job = {"group": "g", "source": "own.md", "header": "class idPlayer : public idActor {\n\tint own;\n};\n"
               "class idDerived : public idBase {\n};\n", "header_line": 7, "impl": "int f;", "impl_line": 30,
               "deps": [dep]}
        tu, splices = worker.prepare(neo, job)
        self.assertEqual(splices, [{"class": "idPlayer", "file": "game/Player.h", "line": 4, "from": "dep.md"},
                                   {"class": "idPlayer", "file": "game/Player.h", "line": 7}])
        stock = Path(neo, "game/Player.h").read_text(encoding="latin-1")
        self.assertLess(stock.index("idBase *b;"), stock.index("int own;"))
        self.assertLess(tu.index("class idBase;"), tu.index('#include "Game_local.h"'))
        self.assertLess(tu.index("class idBase {"), tu.index("class idDerived"))
        self.assertLess(tu.index("class idDerived"), tu.index("int f;"))
        self.assertIn("(from dep.md)", verify.format_compile(verify.CompileResult("g", True, [], splices))[0])

    def test_ambiguous_stock_class_is_an_error(self):
        neo = self.fake_neo({"game/A.h": "class idX {\n};\n", "game/B.h": "class idX {\n};\n"})
        job = {"group": "g", "source": "r.md", "header": "class idX {\n};\n", "header_line": 1, "impl": "",
               "impl_line": 3}
        with self.assertRaisesRegex(ValueError, "more than one stock header"):
            worker.prepare(neo, job)


class Compile(unittest.TestCase):
    """Check 3 against the real toolchain (compile/Dockerfile). Needs a docker daemon:
    local, or DOCKER_HOST=ssh://qwen. One container run covers every case below."""

    MUTATIONS = {
        # name: (old, new, line of the error in custom-ui.md)
        "impl_syntax": ("\tregistered\t= false;\n", "\tregistered\t= false\n", "registered\t= false"),
        "header_syntax": ("\tvoid\t\t\t\t\tRegisterGUI( void );\n", "\tvoid\t\t\t\t\tRegisterGUI( void )\n",
                          "	void					RegisterGUI( void )"),
        "spliced_member": ("\tidCustomUI *\t\t\tcustomUIEntity;", "\tidCustomUI\t\t\tcustomUIEntity;",
                           "customUIEntity;\t\t// +0x1f0c"),
    }

    @classmethod
    def setUpClass(cls):
        if not verify.docker_reachable():
            raise unittest.SkipTest("check 3 needs docker (set DOCKER_HOST, e.g. ssh://qwen)")
        text = reference("custom-ui")
        jobs = [verify.compile_job("custom-ui", text)]
        cls.lines = {}
        for name, (old, new, needle) in cls.MUTATIONS.items():
            assert text.count(old) == 1, name
            mutated = text.replace(old, new)
            jobs.append(dict(verify.compile_job("custom-ui", mutated), group=name))
            cls.lines[name] = md_line(mutated, needle)
        ref = reference("end-level-stats")
        jobs.append(verify.compile_job("end-level-stats", ref))
        old = "\tplayerStats_s\t\t\tlevelStats[ 4 ];"
        assert ref.count(old) == 1
        mutated = ref.replace(old, "\tplayerStat_s\t\t\tlevelStats[ 4 ];")
        jobs.append(dict(verify.compile_job("end-level-stats", mutated), group="els_spliced_member"))
        cls.els_line = md_line(mutated, "playerStat_s\t")
        cls.toolchain, results = verify.run_compile(jobs)
        cls.results = {r.group: r for r in results}

    def test_toolchain_is_recorded(self):
        self.assertTrue(self.toolchain["compiler"].startswith("g++ (Debian 12."), self.toolchain)
        self.assertEqual(self.toolchain["doom3"], "a9c49da5afb18201d31e3f0a429a037e56ce2b9a")
        self.assertIn("-m32", self.toolchain["flags"])
        self.assertIn("a9c49da5afb18201d31e3f0a429a037e56ce2b9a", verify.DOCKERFILE.read_text())

    def test_custom_ui_compiles(self):
        res = self.results["custom-ui"]
        self.assertEqual(res.errors, [])
        self.assertTrue(res.ok)
        self.assertEqual({(s["class"], s["file"]) for s in res.splices},
                         {("idPlayer", "game/Player.h"), ("idCmdSystem", "framework/CmdSystem.h")})
        self.assertTrue(verify.format_compile(res)[0].startswith("  ok       compiles (check 3)"))

    def test_end_level_stats_compiles_on_top_of_custom_ui(self):
        res = self.results["end-level-stats"]
        self.assertEqual(res.errors, [])
        self.assertTrue(res.ok)
        self.assertEqual({(s["class"], s["file"], s.get("from")) for s in res.splices},
                         {("idPlayer", "game/Player.h", "decomp-so/reference/custom-ui.md"),
                          ("idCmdSystem", "framework/CmdSystem.h", "decomp-so/reference/custom-ui.md"),
                          ("idPlayer", "game/Player.h", None), ("idGameLocal", "game/Game_local.h", None),
                          ("idStr", "idlib/Str.h", None)})
        res = self.results["els_spliced_member"]  # an error in a spliced member of the second group
        self.assertFalse(res.ok)
        lines = [int(m.group(1)) for m in (re.match(r"decomp-so/reference/end-level-stats\.md:(\d+):", e)
                                           for e in res.errors) if m]
        self.assertIn(self.els_line, lines, res.errors)

    def test_a_syntax_error_fails_and_is_reported_at_its_markdown_line(self):
        for name in self.MUTATIONS:
            with self.subTest(mutation=name):
                res = self.results[name]
                self.assertFalse(res.ok)
                self.assertTrue(res.errors)
                where = [re.match(r"decomp-so/reference/custom-ui\.md:(\d+):", e) for e in res.errors]
                self.assertIn(self.lines[name], [int(m.group(1)) for m in where if m], res.errors)
                self.assertIn("COMPILE  decomp-so/reference/custom-ui.md:", "\n".join(verify.format_compile(res)))


class CleanupDriver(unittest.TestCase):
    def test_packet_has_each_function_its_callees_and_export(self):
        import cleanup_driver

        packet = cleanup_driver.build_packet("custom-ui")
        self.assertIn("UNCERTAIN", packet)
        for r in (r for r in ROWS if r.group == "custom-ui"):
            self.assertIn(f"export `{r.export}`", packet)
        self.assertIn("`idRestoreGame::ReadBool(bool&)`", packet)
        self.assertIn('"unregister"', packet)  # Ghidra export body is included
        self.assertIn('- literals (binary): `string "unregister"`', packet)


if __name__ == "__main__":
    unittest.main()
