# Instructions for Jules AI: Implement Full Mission History

**Goal:** Transform the After-Action Report (AAR) from a simple "Mistake Tracker" into a "Full Mission History" that displays every question answered, coded by success or failure.

---

## 1. Update `GameManager.gd`
**Objective:** Modify the logging system to track all attempts, not just errors.

* **Action:** Locate the `log_mistake` function.
* **Action:** **REPLACE** the entire `log_mistake` function with the new `log_attempt` function below.
* **Reasoning:** We need to store a boolean (`is_correct`) to differentiate successful rescues from failed ones in the final report.

```gdscript
# Replaces log_mistake
func log_attempt(question_text, user_choice, correct_answer, is_correct):
	session_log.append({
		"question": question_text,
		"user_choice": user_choice,
		"correct_answer": correct_answer,
		"is_correct": is_correct
	})
2. Update GameSession.gd
Objective: Ensure every gameplay event (correct or wrong) is sent to the Game Manager.

Step A: Modify handle_correct
Action: Inside handle_correct(idx), add the logging logic before the citizens_saved calculation.

Code to Insert:

GDScript

# --- NEW LOGGING LOGIC ---
var q_data = GameManager.questions_pool[current_q_index]
var user_choice_text = buttons[idx].text
# For a correct answer, the user choice IS the correct text
GameManager.log_attempt(q_data["question"], user_choice_text, user_choice_text, true)
# -------------------------
Step B: Modify handle_wrong
Action: Inside handle_wrong(...), find the call to GameManager.log_mistake.

Action: REPLACE that line with the new log_attempt call.

Code Replacement:

GDScript

# Old: GameManager.log_mistake(q_data["question"], user_choice_text, correct_text)
# New:
GameManager.log_attempt(q_data["question"], user_choice_text, correct_text, false)
3. Update AARScreen.gd
Objective: Visualize the full history with color-coding (Green for Success, Red for Fail).

Action: Locate func display_results().

Action: Find the section commented # Populate Mistake List (around line 59).

Action: REPLACE the entire block (including the if/else check for empty logs) with the following implementation:

GDScript

	# --- FULL HISTORY DISPLAY LOGIC ---
	
	# Clear any dummy children first
	for child in mistake_container.get_children():
		child.queue_free()

	if GameManager.session_log.size() == 0:
		var lbl = Label.new()
		lbl.text = "NO DATA RECORDED."
		lbl.modulate = Color.GRAY
		mistake_container.add_child(lbl)
	else:
		for entry in GameManager.session_log:
			var entry_label = Label.new()
			
			# Default to Success styling
			var status_text = "[SUCCESS]"
			var status_color = Color.GREEN
			
			# Check for Failure
			if entry.has("is_correct") and entry["is_correct"] == false:
				status_text = "[FAIL]"
				status_color = Color(1, 0.4, 0.4) # Pale Red
			
			# Build the text string
			# Format: "Q: [Question] \n [SUCCESS] You chose: [Answer]"
			var final_text = "Q: " + entry["question"] + "\n" 
			final_text += status_text + " You chose: " + entry["user_choice"]
			
			# If wrong, append the correct answer
			if entry.has("is_correct") and entry["is_correct"] == false:
				final_text += " | Correct: " + entry["correct_answer"]
			
			final_text += "\n" # Spacing
			
			entry_label.text = final_text
			entry_label.modulate = status_color
			entry_label.autowrap_mode = TextServer.AUTOWRAP_WORD
			
			mistake_container.add_child(entry_label)