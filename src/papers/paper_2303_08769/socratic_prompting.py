"""
Developing Mind — Paper 2303.08769 Reproduction
Role: Socratic Method implementation for LLM prompting.
Solving recurrent amnesia by codifying dialog-driven reasoning techniques.

Title: Prompting Large Language Models With the Socratic Method
Authors: Edward Y. Chang
Abstract: Systematic approach to using Socratic method in developing prompt templates 
for LLMs. Covers definition, elenchus, dialectic, maieutics, generalization, and 
counterfactual reasoning techniques.

Core Contribution: Framework for structuring multi-turn LLM interactions using 
Socratic dialogue patterns that guide the model toward precise answers and justifications
while fostering creative reasoning.

Arxiv: https://arxiv.org/abs/2303.08769
"""

from typing import List, Dict, Callable, Optional, Tuple
from enum import Enum
from dataclasses import dataclass


class SocraticTechnique(Enum):
    """Socratic dialogue techniques for LLM prompting."""
    DEFINITION = "definition"
    ELENCHUS = "elenchus"  # Refutation/contradiction
    DIALECTIC = "dialectic"  # Thesis-antithesis-synthesis
    MAIEUTICS = "maieutics"  # Midwifery of ideas
    GENERALIZATION = "generalization"  # Abstract to concrete
    COUNTERFACTUAL = "counterfactual"  # What-if reasoning


@dataclass
class SocraticPrompt:
    """Structure for a single Socratic dialogue turn."""
    technique: SocraticTechnique
    query: str
    context: Optional[str] = None
    intent: Optional[str] = None  # User intent for better model alignment
    
    def to_dict(self) -> Dict:
        return {
            "technique": self.technique.value,
            "query": self.query,
            "context": self.context,
            "intent": self.intent,
        }


class SocraticDialogue:
    """Multi-turn Socratic dialogue sequence."""
    
    def __init__(self, goal: str, user_intent: str = ""):
        """
        Initialize dialogue with goal and user intent.
        
        Args:
            goal: The ultimate objective of the dialogue
            user_intent: Context about what user actually wants (improves LLM alignment)
        """
        self.goal = goal
        self.user_intent = user_intent
        self.turns: List[SocraticPrompt] = []
        self.responses: List[str] = []
        self.reasoning_trace: List[Dict] = []
    
    def add_turn(self, technique: SocraticTechnique, query: str, 
                 context: Optional[str] = None) -> SocraticPrompt:
        """
        Add a Socratic dialogue turn.
        
        Args:
            technique: Which Socratic technique to apply
            query: The question/prompt
            context: Optional background information
            
        Returns:
            The created SocraticPrompt
        """
        prompt = SocraticPrompt(
            technique=technique,
            query=query,
            context=context,
            intent=self.user_intent
        )
        self.turns.append(prompt)
        return prompt
    
    def add_response(self, response: str) -> None:
        """Record model's response to the last turn."""
        self.responses.append(response)
    
    def definition_phase(self, term: str, examples: List[str] = None) -> List[SocraticPrompt]:
        """
        Definition technique: Ask LLM to define a core concept.
        
        Args:
            term: The concept to define
            examples: Optional list of examples to guide definition
            
        Returns:
            List of prompts for definition phase
        """
        prompts = []
        
        # First, ask for simple definition
        definition_query = f"What is '{term}'? Provide a precise, concise definition."
        if examples:
            definition_query += f"\n\nConsider these examples:\n" + "\n".join(f"- {ex}" for ex in examples)
        
        prompts.append(self.add_turn(
            SocraticTechnique.DEFINITION,
            definition_query,
            context=f"Defining {term}"
        ))
        
        # Ask for characteristics
        prompts.append(self.add_turn(
            SocraticTechnique.DEFINITION,
            f"What are the essential characteristics of {term}?",
            context=f"Breaking down {term} into components"
        ))
        
        return prompts
    
    def elenchus_phase(self, initial_claim: str, target_issue: str) -> List[SocraticPrompt]:
        """
        Elenchus technique: Guide toward contradiction of initial false belief.
        
        Args:
            initial_claim: A potentially problematic claim to examine
            target_issue: What aspect should be refuted/refined
            
        Returns:
            List of prompts for elenchus phase
        """
        prompts = []
        
        prompts.append(self.add_turn(
            SocraticTechnique.ELENCHUS,
            f"Consider this statement: '{initial_claim}'\n\nWhat problems or contradictions might arise from this claim?",
            context=f"Examining: {target_issue}"
        ))
        
        prompts.append(self.add_turn(
            SocraticTechnique.ELENCHUS,
            f"How would you refine or correct: '{initial_claim}'?",
            context=f"Refining claim about: {target_issue}"
        ))
        
        return prompts
    
    def dialectic_phase(self, thesis: str, antithesis: str) -> List[SocraticPrompt]:
        """
        Dialectic technique: Thesis-antithesis-synthesis resolution.
        
        Args:
            thesis: Main position
            antithesis: Opposing position
            
        Returns:
            List of prompts for dialectic phase
        """
        prompts = []
        
        prompts.append(self.add_turn(
            SocraticTechnique.DIALECTIC,
            f"Consider two perspectives:\nThesis: {thesis}\nAntithesis: {antithesis}\n\nWhat are the strengths of each position?",
            context="Comparing opposing viewpoints"
        ))
        
        prompts.append(self.add_turn(
            SocraticTechnique.DIALECTIC,
            f"How can we synthesize or resolve the tension between these positions?",
            context="Finding synthesis"
        ))
        
        return prompts
    
    def maieutics_phase(self, topic: str, guided_questions: List[str] = None) -> List[SocraticPrompt]:
        """
        Maieutics technique: "Midwifery of ideas" - draw out existing knowledge.
        
        Args:
            topic: The knowledge domain to explore
            guided_questions: Optional list of guiding questions
            
        Returns:
            List of prompts for maieutics phase
        """
        prompts = []
        
        base_query = f"What do you already know about {topic}?"
        if guided_questions:
            base_query += "\n\nConsider:\n" + "\n".join(f"- {q}" for q in guided_questions)
        
        prompts.append(self.add_turn(
            SocraticTechnique.MAIEUTICS,
            base_query,
            context=f"Drawing out knowledge on: {topic}"
        ))
        
        return prompts
    
    def generalization_phase(self, concrete_example: str, 
                            abstract_pattern: str = None) -> List[SocraticPrompt]:
        """
        Generalization technique: Move from concrete to abstract patterns.
        
        Args:
            concrete_example: Specific instance or example
            abstract_pattern: Optional target pattern to guide toward
            
        Returns:
            List of prompts for generalization phase
        """
        prompts = []
        
        prompts.append(self.add_turn(
            SocraticTechnique.GENERALIZATION,
            f"Given this example: {concrete_example}\n\nWhat general principle or pattern does this illustrate?",
            context="Finding abstract pattern"
        ))
        
        if abstract_pattern:
            prompts.append(self.add_turn(
                SocraticTechnique.GENERALIZATION,
                f"How does this pattern apply to other cases beyond the original example?",
                context=f"Generalizing pattern: {abstract_pattern}"
            ))
        
        return prompts
    
    def counterfactual_phase(self, scenario: str, 
                           variation: str = None) -> List[SocraticPrompt]:
        """
        Counterfactual technique: What-if reasoning for understanding mechanisms.
        
        Args:
            scenario: The baseline scenario
            variation: How to vary it (if not specified, explore variations)
            
        Returns:
            List of prompts for counterfactual phase
        """
        prompts = []
        
        if variation:
            prompts.append(self.add_turn(
                SocraticTechnique.COUNTERFACTUAL,
                f"Given: {scenario}\n\nWhat if {variation}? How would the outcome change?",
                context="Counterfactual analysis"
            ))
        else:
            prompts.append(self.add_turn(
                SocraticTechnique.COUNTERFACTUAL,
                f"Given: {scenario}\n\nWhat are other possible outcomes if key elements were different?",
                context="Exploring counterfactuals"
            ))
        
        prompts.append(self.add_turn(
            SocraticTechnique.COUNTERFACTUAL,
            f"What does this reveal about the causal mechanisms at work?",
            context="Understanding mechanisms"
        ))
        
        return prompts
    
    def build_prompts_with_intent(self) -> str:
        """
        Build complete prompt sequence with intent statement.
        
        Key insight from paper: Explicitly stating user intent and task goal 
        at dialogue start improves LLM alignment and effectiveness.
        
        Returns:
            Complete formatted prompt with intent
        """
        prompt_text = ""
        
        # Intent statement at beginning (paper's key finding)
        if self.user_intent:
            prompt_text += f"[CONTEXT: Goal={self.goal}]\n"
            prompt_text += f"[USER INTENT: {self.user_intent}]\n"
            prompt_text += f"[MODE: Socratic Dialogue]\n\n"
        else:
            prompt_text += f"[GOAL: {self.goal}]\n"
            prompt_text += f"[MODE: Socratic Dialogue]\n\n"
        
        for i, turn in enumerate(self.turns, 1):
            prompt_text += f"\n--- Turn {i}: {turn.technique.value.upper()} ---\n"
            if turn.context:
                prompt_text += f"[Context: {turn.context}]\n"
            prompt_text += f"Query: {turn.query}\n"
        
        return prompt_text
    
    def get_reasoning_summary(self) -> Dict:
        """Get summary of dialogue reasoning flow."""
        return {
            "goal": self.goal,
            "user_intent": self.user_intent,
            "total_turns": len(self.turns),
            "techniques_used": [t.technique.value for t in self.turns],
            "num_responses": len(self.responses),
        }


class SocraticReasoningChain:
    """
    Chains multiple Socratic dialogues to solve complex reasoning problems.
    """
    
    def __init__(self, top_level_goal: str):
        self.top_level_goal = top_level_goal
        self.dialogues: List[SocraticDialogue] = []
    
    def add_dialogue(self, dialogue: SocraticDialogue) -> None:
        """Add a Socratic dialogue to the chain."""
        self.dialogues.append(dialogue)
    
    def create_dialogue(self, subgoal: str, user_intent: str = "") -> SocraticDialogue:
        """Create and add a new dialogue for a subgoal."""
        dialogue = SocraticDialogue(subgoal, user_intent)
        self.add_dialogue(dialogue)
        return dialogue
    
    def get_chain_trace(self) -> List[Dict]:
        """Get the complete trace of all dialogues."""
        return [d.get_reasoning_summary() for d in self.dialogues]


def apply_socratic_method_to_problem(
    problem_statement: str,
    user_intent: str = "",
    techniques_sequence: List[SocraticTechnique] = None
) -> SocraticDialogue:
    """
    Helper function to quickly apply Socratic method to a problem.
    
    Args:
        problem_statement: The problem to solve
        user_intent: What the user actually wants
        techniques_sequence: Which techniques to apply (in order)
        
    Returns:
        Configured SocraticDialogue ready for model interaction
    """
    dialogue = SocraticDialogue(problem_statement, user_intent)
    
    # Default sequence if not specified
    if techniques_sequence is None:
        techniques_sequence = [
            SocraticTechnique.DEFINITION,
            SocraticTechnique.ELENCHUS,
            SocraticTechnique.DIALECTIC,
            SocraticTechnique.GENERALIZATION,
            SocraticTechnique.COUNTERFACTUAL,
        ]
    
    # Apply each technique in sequence
    for technique in techniques_sequence:
        if technique == SocraticTechnique.DEFINITION:
            dialogue.definition_phase("core concept")
        elif technique == SocraticTechnique.ELENCHUS:
            dialogue.elenchus_phase("Initial approach", "potential issues")
        elif technique == SocraticTechnique.DIALECTIC:
            dialogue.dialectic_phase("Pro argument", "Con argument")
        elif technique == SocraticTechnique.MAIEUTICS:
            dialogue.maieutics_phase("key understanding")
        elif technique == SocraticTechnique.GENERALIZATION:
            dialogue.generalization_phase("Specific case")
        elif technique == SocraticTechnique.COUNTERFACTUAL:
            dialogue.counterfactual_phase("Current scenario")
    
    return dialogue
