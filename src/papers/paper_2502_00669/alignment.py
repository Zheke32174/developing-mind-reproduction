"""
Developing Mind — Paper 2502.00669 Reproduction (Safety Alignment Depth)
Role: Theoretical safety boundaries for output sequences.
Solving recurrent amnesia by codifying the designated refusal depth requirements.
"""

import numpy as np
from typing import Set, List
from markovian_core.base import SafetyMarkovChain

class SafetyDepthAnalyzer(SafetyMarkovChain):
    """
    Implements the Safety Depth formalization.
    Calculates refusal probabilities across output token positions.
    """
    
    def __init__(self, harmful_set: Set[int], vocab_size: int):
        super().__init__({str(s) for s in harmful_set})
        self.harmful_indices = harmful_set
        self.T = vocab_size

    def compute_safety_at_depth(self, Q: np.ndarray, initial_pi: np.ndarray, d: int) -> float:
        """
        Computes the probability of reaching a harmful state at token position d.
        P(X_d ∈ Y) = pi_0 * Q^d * e_Y where e_Y is indicator vector for harmful set.
        """
        # Exponentiate transition matrix to depth d
        Q_d = np.linalg.matrix_power(Q, d)
        
        # State distribution at depth d
        pi_d = np.dot(initial_pi, Q_d)
        
        # Probability of being in harmful set
        p_harmful = sum(pi_d[idx] for idx in self.harmful_indices if idx < len(pi_d))
        return p_harmful

    def group_permutation_augmentation(self, sequences: List[List[int]]) -> List[List[int]]:
        """
        Implements the cyclic group data augmentation proposed to tighten safety bounds.
        Rotates phrases to ensure refusal is learned at multiple depths.
        """
        augmented = []
        for seq in sequences:
            # Perform cyclic rotations
            for i in range(len(seq)):
                rotated = seq[i:] + seq[:i]
                augmented.append(rotated)
        return augmented

