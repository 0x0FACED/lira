import unittest

from extract_release_notes import extract_release_notes


class ReleaseNotesTests(unittest.TestCase):
    def test_selects_exact_version_without_neighbouring_release_changes(self):
        changelog = """# Changelog
## [Unreleased]
- Future change
## [0.5.10] - 2026-10-24
- Different version
## [0.5.1] - 2026-10-23
### Fixed
- Восстановление прогресса чтения
### Changed
- Новый ридер
## [0.5.0] - 2026-04-12
- Old change
"""
        self.assertEqual(
            extract_release_notes(changelog, "v0.5.1"),
            "### Fixed\n- Восстановление прогресса чтения\n### Changed\n- Новый ридер\n",
        )

    def test_fenced_headings_do_not_truncate_notes(self):
        for fence in ("```", "~~~~"):
            with self.subTest(fence=fence):
                changelog = (
                    f"## [0.5.1]\n{fence}markdown\n## [0.5.0]\n{fence}\n"
                    "- Current change\n## [0.5.0]\n- Old change\n"
                )
                notes = extract_release_notes(changelog, "v0.5.1")
                self.assertIn(f"{fence}markdown\n## [0.5.0]\n{fence}", notes)
                self.assertIn("- Current change", notes)
                self.assertNotIn("- Old change", notes)

    def test_any_next_level_two_heading_ends_the_release_section(self):
        changelog = "## [0.5.1]\n- Current change\n## References\n- Not a release change\n"
        self.assertEqual(extract_release_notes(changelog, "v0.5.1"), "- Current change\n")

    def test_leading_code_indentation_is_preserved(self):
        changelog = "## [0.5.1]\n\n    command --flag\n\n## [0.5.0]\n- Old change\n"
        self.assertEqual(extract_release_notes(changelog, "v0.5.1"), "    command --flag\n")

    def test_missing_version_does_not_fall_back_to_unreleased(self):
        changelog = "## [Unreleased]\n- Future change\n## [0.5.0]\n- Old change\n"
        with self.assertRaises(ValueError):
            extract_release_notes(changelog, "v0.5.1")

    def test_duplicate_version_is_rejected_instead_of_choosing_a_body(self):
        changelog = "## [0.5.1]\n- First body\n## [0.5.1]\n- Second body\n"
        with self.assertRaises(ValueError):
            extract_release_notes(changelog, "v0.5.1")

    def test_empty_section_cannot_be_published_as_release_notes(self):
        changelog = "## [0.5.1]\n\n  \n## [0.5.0]\n- Old change\n"
        with self.assertRaises(ValueError):
            extract_release_notes(changelog, "v0.5.1")


if __name__ == "__main__":
    unittest.main()
