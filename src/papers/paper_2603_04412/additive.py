"""
Developing Mind — Paper 2603.04412 Reproduction (Additive Markov Chains)
Role: Dimensionality reduction for high-order state spaces.
Solving recurrent amnesia by optimizing the representation of long-range dependencies.
"""

import numpy as np
from typing import List
from markovian_core.base import AdditiveMarkovChain

class AdditiveLLMModel(AdditiveMarkovChain):
    """
    Implements the N-order additive Markov chain approximation.
    Each historical token contributes independently to the next-token distribution.
    """
    
    def __init__(self, vocabulary_size: int, context_window: int):
        super().__init__(vocabulary_size, context_window)
        # Initialize memory functions (transition matrices for each depth k)
        # In a real scenario, these would be learned or distilled from the LLM.
        self.memory_functions = [np.eye(vocabulary_size) for _ in range(context_window)]
        self.weights = np.array([1.0 / context_window for _ in range(context_window)])

    def predict_next(self, history: List[int]) -> np.ndarray:
        """
        Calculates P(x_n | x_{n-K}, ..., x_{n-1}) = sum_{k=1}^K w_k * P(x_n | x_{n-k}).
        """
        # Ensure we only look at the last K tokens
        relevant_history = history[-self.K:]
        
        # Aggregate contributions from each depth
        # k=1 is the most recent (x_{n-1})
        probs = np.zeros(self.T)
        for i, token in enumerate(reversed(relevant_history)):
            k = i + 1 # Depth
            if k <= self.K:
                # Add contribution from depth k
                probs += self.weights[k-1] * self.memory_functions[k-1][token]
        
        # Normalize (ensure it's a valid distribution)
        return probs / np.sum(probs) if np.sum(probs) > 0 else np.ones(self.T) / self.T

