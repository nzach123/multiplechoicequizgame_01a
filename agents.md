# UI Translation Pipeline Architecture

This document outlines a 5-agent swarm designed to translate the existing Godot UI (`original.jpg` / `MainMenu.tscn`) into the target visual identity (`new_design.jpg`). The pipeline moves from visual analysis to asset preparation, theme generation, scene reconstruction, and final validation.

---

## Agent 1: The Visual Deconstructor (Analyst)
**Role:** Acts as the "eyes" of the pipeline. It analyzes the target design image to extract a structured design system and compares it against the original to identify the "delta" (what changed).

* **Inputs:**
    * Target Image: `new_design.jpg`
    * Reference Image: `original.jpg`
    * Project Metadata: List of available fonts in `assets/fonts/` (e.g., *PixelOperator8, LuckiestGuy, JetBrainsMono*)
* **Outputs:**
    * `design_spec.json`: A structured file containing:
        * **Palette:** Primary, Secondary, Background, Text colors (Hex codes).
        * **Typography:** Mappings for "Header", "Body", "Button" to specific font files found in `assets/`.
        * **Geometry:** Corner radius, border widths, shadow offsets.
        * **Layout Strategy:** VBox/HBox separation, margin sizes.
* **Handoff:** * Writes `design_spec.json` to the shared workspace.
    * Triggers **Agent 2** and **Agent 3**.
* **Success Measurement:** * Output JSON contains valid hex codes for all detected colors.
    * Selected fonts exist in the `assets/` directory.

---

## Agent 2: The Asset Synthesizer (Curator)
**Role:** Ensures all necessary raw materials exist. If the new design requires a specific button texture, icon, or panel style that doesn't exist in `resources/`, this agent generates or configures it.

* **Inputs:**
    * `design_spec.json`
    * `icon.svg` (Current application icon)
    * `resources/textures/` (Existing styleboxes)
* **Outputs:**
    * `assets_manifest.json`: A list of file paths to be used for the UI.
    * **Generated Assets:** New `StyleBoxFlat` or `StyleBoxTexture` resource files (`.tres`) for buttons and panels if the standard Godot theme properties are insufficient.
* **Handoff:** * Saves generated resources to `resources/generated/`.
    * Passes `assets_manifest.json` to **Agent 3**.
* **Success Measurement:** * All file paths in the manifest point to existing, valid files.
    * No "missing texture" errors reported during resource pre-load.

---

## Agent 3: The Theme Architect (Builder)
**Role:** Translates the abstract design spec into a Godot-native `Theme` resource. This isolates the visual style from the scene logic, making the design reusable across `MainMenu.tscn`, `quiz_scene.tscn`, and `AARScreen.tscn`.

* **Inputs:**
    * `design_spec.json`
    * `assets_manifest.json`
    * Existing Theme: `resources/themes/title_theme.tres` (used as a template structure)
* **Outputs:**
    * `new_design_theme.tres`: A complete Godot Theme file.
* **Handoff:** * Saves the `.tres` file.
    * Passes the file path (`res://resources/themes/new_design_theme.tres`) to **Agent 4**.
* **Success Measurement:** * The `.tres` file parses valid GDScript/Resource syntax.
    * Key properties (Button/styles/normal, Label/fonts/font) are populated and match `design_spec.json`.

---

## Agent 4: The Scene Refactorer (Mechanic)
**Role:** Modifies the actual Scene files (`.tscn`). It parses the node tree, applies the new Theme, and adjusts layout containers (Margins, VBoxes) to match the spatial composition of the new design.

* **Inputs:**
    * Target Scenes: `scenes/MainMenu.tscn`, `scenes/quiz_scene.tscn`
    * New Theme: `new_design_theme.tres`
    * `design_spec.json` (For layout specific overrides like specific padding integers)
* **Outputs:**
    * Refactored Scene Files: `scenes/MainMenu_v2.tscn` etc.
* **Handoff:** * Saves modified scenes.
    * Triggers **Agent 5** for validation.
* **Success Measurement:** * Scene file is syntactically valid (Godot Scene Format 3.0+).
    * Root node and script connections (`scripts/MainMenu.gd`) remain intact (no broken signals).
    * The `theme` property of the Root Control node is set to `new_design_theme.tres`.

---

## Agent 5: The Visual QA (Critic)
**Role:** Validates the conversion. Since it cannot run the game engine visually in this pipeline, it performs "Static Analysis" on the output files to ensure they meet the production criteria.

* **Inputs:**
    * `scenes/MainMenu_v2.tscn`
    * `new_design_theme.tres`
    * `design_spec.json`
* **Outputs:**
    * `QA_Report.md`: A pass/fail checklist.
* **Handoff:** * If **PASS**: Marks pipeline as Complete.
    * If **FAIL**: Outputs a "Correction Prompt" fed back to Agent 3 or 4.
* **Success Measurement:** * **Contrast Check:** Calculates contrast ratio between mapped Text Color and Background Color from the Theme (must be > 4.5:1).
    * **Font Consistency:** Verifies that no default "Arial" or system fonts are left fallback—all fonts must point to `assets/fonts/`.
    * **Node Integrity:** Confirms that essential nodes (e.g., "StartButton", "TitleLabel") defined in the original scene still exist in the new scene.