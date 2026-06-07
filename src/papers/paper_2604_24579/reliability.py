"""
Developing Mind — Paper 2604.24579 Reproduction (TraceToChain)
Role: Reliability modeling for agent execution traces.
Solving recurrent amnesia by providing an audited model for failure prediction.
"""

import numpy as np
from typing import List, Dict, Set
from markovian_core.base import AbsorbingMarkovChain

class TraceToChain(AbsorbingMarkovChain):
    """
    Implements TRACETOCHAIN pipeline.
    Estimates transitions with Laplace-smoothed maximum-likelihood estimation (MLE).
    """
    
    def __init__(self, transient_states: List[str], success_states: Set[str], failure_states: Set[str]):
        super().__init__(transient_states)
        self.success_states = success_states
        self.failure_states = failure_states
        self.state_to_idx = {s: i for i, s in enumerate(transient_states)}
        
        n = len(transient_states)
        self.Q = np.zeros((n, n))
        self.R_plus = np.zeros((n, len(success_states)))
        self.R_minus = np.zeros((n, len(failure_states)))

    def fit_traces(self, traces: List[List[str]], alpha: float = 1.0):
        """
        Fits traces using MLE with Laplace smoothing (alpha).
        """
        for trace in traces:
            for i in range(len(trace) - 1):
                s_curr = trace[i]
                s_next = trace[i+1]
                
                if s_curr in self.state_to_idx:
                    row = self.state_to_idx[s_curr]
                    if s_next in self.state_to_idx:
                        self.Q[row, self.state_to_idx[s_next]] += 1
                    elif s_next in self.success_states:
                        # Map success state to idx 0 for simplicity if multiple
                        self.R_plus[row, 0] += 1
                    elif s_next in self.failure_states:
                        self.R_minus[row, 0] += 1
        
        # Apply Laplace smoothing and normalize
        n = len(self.states)
        for i in range(n):
            total = np.sum(self.Q[i]) + np.sum(self.R_plus[i]) + np.sum(self.R_minus[i])
            self.Q[i] = (self.Q[i] + alpha) / (total + alpha * (n + 2))
            self.R_plus[i] = (self.R_plus[i] + alpha) / (total + alpha * (n + 2))
            self.R_minus[i] = (self.R_minus[i] + alpha) / (total + alpha * (n + 2))

    def reliability_at_step(self, d: int) -> float:
        """
        Proposition 1: Calculates analytic reliability R(d).
        R(d) = sum(pi_0 * Q^k * R_plus) for k in 0 to d-1.
        """
        n = len(self.states)
        pi = np.zeros(n)
        pi[0] = 1.0 # Assume first transient state is start
        
        total_reliability = 0.0
        current_pi = pi
        
        for k in range(d):
            # Probability of succeeding at this exact step
            p_success = np.sum(np.dot(current_pi, self.R_plus))
            total_reliability += p_success
            # Move to next transient distribution
            current_pi = np.dot(current_pi, self.Q)
            
        return total_reliability
