"""
Developing Mind — Paper 2506.07298 Reproduction (ICL for HMMs)
Role: Inferring latent states from observable environmental traces.
Solving recurrent amnesia by modeling hidden structures in scientific and system data.
"""

import numpy as np
from typing import List, Tuple
from markovian_core.base import HiddenMarkovModel

class HMMInference(HiddenMarkovModel):
    """
    Implements the filtering and prediction logic described in the study of LLMs as HMM learners.
    Approximates how ICL converges toward the theoretical Bayesian optimum.
    """
    
    def __init__(self, latent_transition: np.ndarray, emission_matrix: np.ndarray, initial_pi: np.ndarray):
        num_states, observation_size = emission_matrix.shape
        super().__init__(num_states, observation_size)
        self.A = latent_transition
        self.B = emission_matrix
        self.pi = initial_pi

    def forward_filter(self, observations: List[int]) -> np.ndarray:
        """
        Bayesian Filtering: P(S_t | O_{1:t}).
        This represents the 'latent state belief' the LLM implicitly maintains.
        """
        belief = self.pi
        for obs in observations:
            # Prediction step: S_t | O_{1:t-1}
            belief = np.dot(belief, self.A)
            
            # Update step: S_t | O_{1:t}
            likelihood = self.B[:, obs]
            belief = belief * likelihood
            
            # Normalize
            sum_belief = np.sum(belief)
            if sum_belief > 0:
                belief /= sum_belief
            else:
                belief = np.ones(self.N) / self.N
        return belief

    def predict_next(self, observations: List[int]) -> np.ndarray:
        """
        Calculates P(O_{t+1} | O_{1:t}).
        Marginalizes belief over transitions and emissions.
        """
        current_belief = self.forward_filter(observations)
        
        # Propagate to next state: P(S_{t+1} | O_{1:t})
        next_state_belief = np.dot(current_belief, self.A)
        
        # Marginalize over emissions: P(O_{t+1} | O_{1:t})
        obs_probs = np.dot(next_state_belief, self.B)
        return obs_probs

