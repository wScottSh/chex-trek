"""Tests for the verification harness and the reference outputs it guards.

    python -m unittest discover -s decomp-so/verify -v
"""
from __future__ import annotations

import re
import sys
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
            self.assertIn(entry.kind, {"exception-only", "abi-implicit"})
            self.assertGreater(len(entry.reason), 20)


class Records(unittest.TestCase):
    def test_coverage_record_lists_all_84_exported_functions(self):
        index = [l.split("\t") for l in verify.GHIDRA_INDEX.read_text().splitlines()]
        self.assertEqual(len(ROWS), 84)
        self.assertEqual(sorted(r.export for r in ROWS), sorted(f"{safe}.c" for safe, _, _ in index))
        for r in ROWS:
            with self.subTest(export=r.export):
                self.assertTrue((verify.DECOMP_DIR / "ghidra-full" / r.export).exists())
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
        self.assertEqual(len(offsets), len(set(offsets)))


class CleanupDriver(unittest.TestCase):
    def test_packet_has_each_function_its_callees_and_export(self):
        import cleanup_driver

        packet = cleanup_driver.build_packet("custom-ui")
        self.assertIn("UNCERTAIN", packet)
        for r in (r for r in ROWS if r.group == "custom-ui"):
            self.assertIn(f"export `{r.export}`", packet)
        self.assertIn("`idRestoreGame::ReadBool(bool&)`", packet)
        self.assertIn('"unregister"', packet)  # Ghidra export body is included


if __name__ == "__main__":
    unittest.main()
