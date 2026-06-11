"""
Unit tests for Socratic Method implementation (Paper 2303.08769)
Tests the core structures and dialogue building capabilities.
"""

import unittest
from src.papers.paper_2303_08769.socratic_prompting import (
    SocraticTechnique,
    SocraticPrompt,
    SocraticDialogue,
    SocraticReasoningChain,
    apply_socratic_method_to_problem,
)


class TestSocraticTechnique(unittest.TestCase):
    """Test Socratic technique enumeration."""
    
    def test_all_techniques_present(self):
        """Verify all six Socratic techniques are defined."""
        techniques = [t.value for t in SocraticTechnique]
        self.assertIn("definition", techniques)
        self.assertIn("elenchus", techniques)
        self.assertIn("dialectic", techniques)
        self.assertIn("maieutics", techniques)
        self.assertIn("generalization", techniques)
        self.assertIn("counterfactual", techniques)
    
    def test_technique_count(self):
        """Exactly 6 techniques should be defined."""
        self.assertEqual(len(list(SocraticTechnique)), 6)


class TestSocraticPrompt(unittest.TestCase):
    """Test individual Socratic prompt structure."""
    
    def test_create_basic_prompt(self):
        """Create a basic Socratic prompt."""
        prompt = SocraticPrompt(
            technique=SocraticTechnique.DEFINITION,
            query="What is truth?",
        )
        self.assertEqual(prompt.technique, SocraticTechnique.DEFINITION)
        self.assertEqual(prompt.query, "What is truth?")
        self.assertIsNone(prompt.context)
        self.assertIsNone(prompt.intent)
    
    def test_prompt_with_context(self):
        """Create prompt with context and intent."""
        prompt = SocraticPrompt(
            technique=SocraticTechnique.ELENCHUS,
            query="Find the flaw in this argument",
            context="Logic and reasoning",
            intent="Understand critical thinking",
        )
        self.assertEqual(prompt.context, "Logic and reasoning")
        self.assertEqual(prompt.intent, "Understand critical thinking")
    
    def test_prompt_to_dict(self):
        """Convert prompt to dictionary."""
        prompt = SocraticPrompt(
            technique=SocraticTechnique.MAIEUTICS,
            query="What do you know?",
            context="Drawing knowledge",
            intent="Learn existing understanding",
        )
        d = prompt.to_dict()
        self.assertEqual(d["technique"], "maieutics")
        self.assertEqual(d["query"], "What do you know?")
        self.assertEqual(d["context"], "Drawing knowledge")
        self.assertEqual(d["intent"], "Learn existing understanding")


class TestSocraticDialogue(unittest.TestCase):
    """Test multi-turn Socratic dialogue."""
    
    def test_create_dialogue(self):
        """Create a basic dialogue."""
        dialogue = SocraticDialogue(
            goal="Understand quantum mechanics",
            user_intent="Prepare for physics exam"
        )
        self.assertEqual(dialogue.goal, "Understand quantum mechanics")
        self.assertEqual(dialogue.user_intent, "Prepare for physics exam")
        self.assertEqual(len(dialogue.turns), 0)
        self.assertEqual(len(dialogue.responses), 0)
    
    def test_add_turn(self):
        """Add dialogue turns."""
        dialogue = SocraticDialogue("Test goal")
        prompt = dialogue.add_turn(
            SocraticTechnique.DEFINITION,
            "What is energy?",
            context="Physics basics"
        )
        
        self.assertEqual(len(dialogue.turns), 1)
        self.assertEqual(prompt.technique, SocraticTechnique.DEFINITION)
        self.assertEqual(dialogue.turns[0], prompt)
    
    def test_add_response(self):
        """Add model responses to dialogue."""
        dialogue = SocraticDialogue("Test goal")
        dialogue.add_turn(SocraticTechnique.DEFINITION, "What is energy?")
        dialogue.add_response("Energy is the capacity to do work...")
        
        self.assertEqual(len(dialogue.responses), 1)
        self.assertEqual(dialogue.responses[0], "Energy is the capacity to do work...")
    
    def test_definition_phase(self):
        """Test definition phase generation."""
        dialogue = SocraticDialogue("Understand concepts")
        prompts = dialogue.definition_phase(
            term="algorithm",
            examples=["sorting", "search"]
        )
        
        self.assertEqual(len(prompts), 2)
        self.assertTrue(all(p.technique == SocraticTechnique.DEFINITION for p in prompts))
        self.assertIn("algorithm", prompts[0].query)
    
    def test_elenchus_phase(self):
        """Test elenchus (refutation) phase."""
        dialogue = SocraticDialogue("Test critical thinking")
        prompts = dialogue.elenchus_phase(
            initial_claim="All birds can fly",
            target_issue="Exceptions to general rules"
        )
        
        self.assertEqual(len(prompts), 2)
        self.assertTrue(all(p.technique == SocraticTechnique.ELENCHUS for p in prompts))
    
    def test_dialectic_phase(self):
        """Test dialectic (thesis-antithesis-synthesis)."""
        dialogue = SocraticDialogue("Resolve opposing views")
        prompts = dialogue.dialectic_phase(
            thesis="Technology always improves human life",
            antithesis="Technology creates new problems"
        )
        
        self.assertEqual(len(prompts), 2)
        self.assertTrue(all(p.technique == SocraticTechnique.DIALECTIC for p in prompts))
    
    def test_maieutics_phase(self):
        """Test maieutics (drawing out knowledge)."""
        dialogue = SocraticDialogue("Learn from existing knowledge")
        prompts = dialogue.maieutics_phase(
            topic="geometry",
            guided_questions=["What shapes do you know?", "How do you measure them?"]
        )
        
        self.assertEqual(len(prompts), 1)
        self.assertEqual(prompts[0].technique, SocraticTechnique.MAIEUTICS)
        self.assertIn("geometry", prompts[0].query)
    
    def test_generalization_phase(self):
        """Test generalization from concrete to abstract."""
        dialogue = SocraticDialogue("Find patterns")
        prompts = dialogue.generalization_phase(
            concrete_example="This square has 4 equal sides",
            abstract_pattern="Regular polygons"
        )
        
        self.assertEqual(len(prompts), 2)
        self.assertTrue(all(p.technique == SocraticTechnique.GENERALIZATION for p in prompts))
    
    def test_counterfactual_phase(self):
        """Test counterfactual (what-if) reasoning."""
        dialogue = SocraticDialogue("Understand mechanisms")
        prompts = dialogue.counterfactual_phase(
            scenario="The river flows downstream",
            variation="gravity were reversed"
        )
        
        self.assertEqual(len(prompts), 2)
        self.assertTrue(all(p.technique == SocraticTechnique.COUNTERFACTUAL for p in prompts))
    
    def test_build_prompts_with_intent(self):
        """Test building complete prompt sequence with intent."""
        dialogue = SocraticDialogue(
            goal="Solve a problem",
            user_intent="Find practical solution"
        )
        dialogue.add_turn(SocraticTechnique.DEFINITION, "Define the problem")
        dialogue.add_turn(SocraticTechnique.ELENCHUS, "Find issues")
        
        prompt_text = dialogue.build_prompts_with_intent()
        
        self.assertIn("CONTEXT: Goal=", prompt_text)
        self.assertIn("USER INTENT:", prompt_text)
        self.assertIn("DEFINITION", prompt_text)
        self.assertIn("ELENCHUS", prompt_text)
        self.assertIn("Turn 1:", prompt_text)
        self.assertIn("Turn 2:", prompt_text)
    
    def test_build_prompts_without_intent(self):
        """Test building prompts without explicit intent."""
        dialogue = SocraticDialogue(goal="Simple goal")
        dialogue.add_turn(SocraticTechnique.DEFINITION, "Question")
        
        prompt_text = dialogue.build_prompts_with_intent()
        
        self.assertIn("[GOAL:", prompt_text)
        self.assertNotIn("USER INTENT:", prompt_text)
    
    def test_get_reasoning_summary(self):
        """Test dialogue reasoning summary."""
        dialogue = SocraticDialogue(
            goal="Test goal",
            user_intent="Test intent"
        )
        dialogue.add_turn(SocraticTechnique.DEFINITION, "Q1")
        dialogue.add_turn(SocraticTechnique.DIALECTIC, "Q2")
        dialogue.add_response("R1")
        
        summary = dialogue.get_reasoning_summary()
        
        self.assertEqual(summary["goal"], "Test goal")
        self.assertEqual(summary["user_intent"], "Test intent")
        self.assertEqual(summary["total_turns"], 2)
        self.assertEqual(summary["num_responses"], 1)
        self.assertIn("definition", summary["techniques_used"])
        self.assertIn("dialectic", summary["techniques_used"])


class TestSocraticReasoningChain(unittest.TestCase):
    """Test chaining multiple Socratic dialogues."""
    
    def test_create_reasoning_chain(self):
        """Create a multi-dialogue reasoning chain."""
        chain = SocraticReasoningChain("Solve complex problem")
        self.assertEqual(chain.top_level_goal, "Solve complex problem")
        self.assertEqual(len(chain.dialogues), 0)
    
    def test_add_dialogue(self):
        """Add dialogues to chain."""
        chain = SocraticReasoningChain("Main goal")
        dialogue = SocraticDialogue("Subgoal 1")
        chain.add_dialogue(dialogue)
        
        self.assertEqual(len(chain.dialogues), 1)
        self.assertEqual(chain.dialogues[0], dialogue)
    
    def test_create_dialogue_helper(self):
        """Test helper to create and add dialogue."""
        chain = SocraticReasoningChain("Main goal")
        dialogue = chain.create_dialogue("Subgoal 1", "Intent 1")
        
        self.assertEqual(len(chain.dialogues), 1)
        self.assertEqual(dialogue.goal, "Subgoal 1")
        self.assertEqual(dialogue.user_intent, "Intent 1")
    
    def test_chain_trace(self):
        """Get trace of entire reasoning chain."""
        chain = SocraticReasoningChain("Solve problem")
        d1 = chain.create_dialogue("Step 1", "Intent 1")
        d1.add_turn(SocraticTechnique.DEFINITION, "Q1")
        
        d2 = chain.create_dialogue("Step 2", "Intent 2")
        d2.add_turn(SocraticTechnique.ELENCHUS, "Q2")
        d2.add_response("Response 2")
        
        trace = chain.get_chain_trace()
        
        self.assertEqual(len(trace), 2)
        self.assertEqual(trace[0]["total_turns"], 1)
        self.assertEqual(trace[1]["total_turns"], 1)
        self.assertEqual(trace[1]["num_responses"], 1)


class TestApplySocraticMethodHelper(unittest.TestCase):
    """Test the helper function for quick Socratic method application."""
    
    def test_apply_socratic_method_default(self):
        """Apply Socratic method with default techniques."""
        dialogue = apply_socratic_method_to_problem(
            problem_statement="How do we solve climate change?",
            user_intent="Find actionable solutions"
        )
        
        self.assertEqual(dialogue.goal, "How do we solve climate change?")
        self.assertEqual(dialogue.user_intent, "Find actionable solutions")
        # Should have turns from all default techniques
        self.assertGreater(len(dialogue.turns), 0)
    
    def test_apply_socratic_method_custom_sequence(self):
        """Apply Socratic method with custom technique sequence."""
        dialogue = apply_socratic_method_to_problem(
            problem_statement="Understand recursion",
            techniques_sequence=[
                SocraticTechnique.DEFINITION,
                SocraticTechnique.MAIEUTICS,
                SocraticTechnique.COUNTERFACTUAL,
            ]
        )
        
        # Should apply only the specified techniques
        techniques_used = [t.technique for t in dialogue.turns]
        self.assertIn(SocraticTechnique.DEFINITION, techniques_used)
        self.assertIn(SocraticTechnique.MAIEUTICS, techniques_used)
        self.assertIn(SocraticTechnique.COUNTERFACTUAL, techniques_used)
    
    def test_apply_with_no_intent(self):
        """Apply without explicit user intent."""
        dialogue = apply_socratic_method_to_problem("Question")
        self.assertEqual(dialogue.user_intent, "")


class TestSocraticIntegration(unittest.TestCase):
    """Integration tests for complete Socratic dialogue workflows."""
    
    def test_complete_problem_solving_flow(self):
        """Test a complete problem-solving with Socratic method."""
        # Create main reasoning chain
        chain = SocraticReasoningChain("Design a recommendation system")
        
        # Dialogue 1: Understand requirements
        requirements_dialogue = chain.create_dialogue(
            subgoal="Clarify what we're recommending",
            user_intent="Build system that users trust"
        )
        requirements_dialogue.definition_phase(
            term="recommendation",
            examples=["Netflix movie suggestions", "Amazon product recommendations"]
        )
        
        # Dialogue 2: Explore challenges
        challenges_dialogue = chain.create_dialogue(
            subgoal="Identify potential pitfalls",
            user_intent="Avoid poor user experience"
        )
        challenges_dialogue.elenchus_phase(
            initial_claim="Just recommend popular items",
            target_issue="Diversity and personalization"
        )
        
        # Dialogue 3: Compare approaches
        approaches_dialogue = chain.create_dialogue(
            subgoal="Evaluate design options",
            user_intent="Choose best architecture"
        )
        approaches_dialogue.dialectic_phase(
            thesis="Content-based filtering",
            antithesis="Collaborative filtering"
        )
        
        # Verify chain structure
        self.assertEqual(len(chain.dialogues), 3)
        chain_trace = chain.get_chain_trace()
        self.assertEqual(len(chain_trace), 3)
        self.assertGreater(chain_trace[0]["total_turns"], 0)
    
    def test_intent_alignment_feature(self):
        """Test the paper's key finding: explicit intent improves alignment."""
        # Without explicit intent
        dialogue_no_intent = SocraticDialogue(
            goal="Write better code",
            user_intent=""
        )
        dialogue_no_intent.definition_phase("code quality")
        
        # With explicit intent
        dialogue_with_intent = SocraticDialogue(
            goal="Write better code",
            user_intent="Make code maintainable for future team members"
        )
        dialogue_with_intent.definition_phase("code quality")
        
        # Both should have turns, but with intent should be more focused
        prompt_with = dialogue_with_intent.build_prompts_with_intent()
        
        self.assertIn("USER INTENT:", prompt_with)
        self.assertIn("Make code maintainable", prompt_with)


if __name__ == "__main__":
    unittest.main()
