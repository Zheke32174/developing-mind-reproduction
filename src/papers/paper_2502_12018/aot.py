"""
Developing Mind — Paper 2502.12018 Reproduction (Atom of Thoughts)
Role: Memoryless reasoning trajectory management.
Solving recurrent amnesia by transforming history-dependent thoughts into self-contained states.
"""

import json
from typing import List, Optional, Callable
from markovian_core.base import ReasoningState

class AtomOfThoughts:
    """
    Implements the Markovian reasoning process.
    Focuses on 'Thought-to-State' transformation to eliminate historical redundancy.
    """
    
    def __init__(self, model_executor: Callable[[str], str]):
        self.model = model_executor

    def step(self, state: ReasoningState) -> ReasoningState:
        """
        Transition function: T(state_i) -> state_{i+1}.
        The prompt is engineered to force the model to output a self-contained state.
        """
        prompt = (
            "You are an atomic reasoning unit. Given the CURRENT STATE, "
            "produce the NEXT STATE. Do NOT include history. "
            "Output valid JSON with fields: conclusion, pending_subproblems.\n\n"
            f"CURRENT STATE:\n{state.to_prompt()}"
        )
        
        raw_response = self.model(prompt)
        try:
            # Simple heuristic parser for the atomic update
            data = json.loads(raw_response)
            return ReasoningState(
                problem_description=state.problem,
                current_conclusion=data.get("conclusion", state.conclusion),
                remaining_subproblems=data.get("pending_subproblems", [])
            )
        except:
            # Fallback/Safety
            return state

    def solve(self, problem: str, max_steps: int = 5) -> str:
        """
        Iterative reasoning loop. 
        Each iteration is memoryless relative to the trajectory.
        """
        state = ReasoningState(problem, "Initial analysis", ["Solve core problem"])
        for _ in range(max_steps):
            if not state.pending:
                break
            state = self.step(state)
        return state.conclusion

