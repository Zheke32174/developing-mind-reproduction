import numpy as np
from typing import List, Dict, Any

class StateSpace:
    """Definition 3.1: Finite state space VK* of tokens."""
    def __init__(self, vocabulary_size: int, context_window: int):
        self.T = vocabulary_size
        self.K = context_window

class MarkovProcess:
    """Proposition 3.2: LLM as a Markov Chain MC(VK*, Qf)."""
    def __init__(self, state_space: StateSpace):
        self.space = state_space
        self.Q = None # Transition matrix
