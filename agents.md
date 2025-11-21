# Jules: Development Tasks for Quiz Game Refactor

This document outlines the step-by-step refactoring plan to evolve the quiz game from a simple prototype into a robust educational simulation. Execute these tasks in order.

## Task 1: Refactor Data Layer & Schema

**Context:** We are moving from a rigid dictionary-based question format to a flexible array-based format to support answer shuffling and educational remediation.

**Step 1: Update the JSON Schema**
Convert `res://assets/questions/1110.json` (and others) to the new format:
- **Structure Change:** Replace `"options": {"A": "...", "B": "..."}` with an `"answers"` array.
- **Answer Object:** Each item in the array must be `{"text": "...", "is_correct": boolean}`.
- **New Field:** Add `"explanation": String` to the root of each question object.
- **Action:** Populate `"explanation"` with placeholder text (e.g., "Correct! [Context]") for existing data.

**Target JSON Example:**
```json
{
  "question": "What is the core mandate of GBA+?",
  "answers": [
    {"text": "To advocate for specific gender policies.", "is_correct": false},
    {"text": "To assess how diverse groups experience policies.", "is_correct": true},
    {"text": "To secure funding for women's organizations.", "is_correct": false}
  ],
  "explanation": "GBA+ is an analytical process used to assess how diverse groups experience policies."
}

Step 2: Update GameManager.gd

    Update load_course_data to validate and parse this new schema.

    Ensure questions_pool stores this structure correctly.

    Cleanup: Remove any logic relying on "A", "B", "C", "D" keys being present in the data.

Task 2: Decouple Logic & Implement Shuffling

Context: GameSession.gd currently uses hardcoded "A/B/C/D" mapping. We need dynamic button assignment to support randomized answers.

Step 1: Remove Magic Strings

    Remove index_to_letter dictionary.

    Remove any logic mapping correct_idx based on strings "A", "B", "C", "D".

Step 2: Dynamic Button Assignment

    In load_question(index):

        Retrieve the answers array from the question data.

        Shuffle the array.

        Assign answer text to buttons[0] through buttons[3].

        Store metadata (e.g., in a local array or on the buttons) to track which specific button index currently holds the is_correct: true answer.

Step 3: Update Input Handling

    Modify _on_button_pressed(selected_idx):

        Instead of comparing letters (selected_letter == correct_letter), check if the button at selected_idx is linked to the is_correct answer.

Task 3: Implement "The Learning Loop" (Remediation)

Context: We are shifting from a "test" (fail -> next) to a "simulation" (fail -> learn -> next). Feedback must be immediate.

Step 1: Create Feedback UI

    Create a new PopupPanel or Control node named RemediationPopup.

    Add a Label for the explanation text.

    Add an "Acknowledge" Button.

    Set default visibility to hidden.

Step 2: Modify handle_wrong

    Current Behavior: Logs mistake and queues next question immediately.

    New Behavior:

        Pause round_timer and question_timer.

        Visually highlight the Correct button (Green) and the Wrong button (Red).

        Show RemediationPopup populated with the explanation text.

        Stop: Do not call load_question automatically.

Step 3: Resume Flow

    Connect the "Acknowledge" button to a new function _on_remediation_acknowledged.

    Function Logic:

        Hide the popup.

        Resume round_timer.

        Proceed to load_question(current_q_index + 1) (or finish game).

Task 4: Persistent Progression (Metagame)

Context: Track mastery over time rather than just single-session scores.

Requirements:

    Data Structure: Define player_progress dictionary in GameManager.gd:
    GDScript

var player_progress = { 
    "1110": { "high_score": 0, "mastery_percent": 0.0 } 
}

Persistence: Implement save_game() and load_game() using FileAccess to write/read from user://savegame.save.

Initialization: Call load_game() in _ready(). Ensure reset_stats() does not clear this persistent data.

Update Logic: When a game finishes (in GameSession or AARScreen), calculate the percentage of questions answered correctly. Update player_progress for the current course_id and call save_game().