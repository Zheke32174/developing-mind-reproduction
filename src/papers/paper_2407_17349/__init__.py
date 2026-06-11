"""
Developing Mind — Paper 2407.17349 Reproduction
Role: Socratic Method Inference for Conversational Mathematics Teaching
Solving recurrent amnesia by codifying pedagogy-driven LLM reasoning strategies.

Title: Boosting Large Language Models with Socratic Method for
       Conversational Mathematics Teaching
Authors: Ding, Hu, Zhou, Chen, Jiang, He
Venue: Under review (2024)
Arxiv: https://arxiv.org/abs/2407.17349

Abstract: With the introduction of large language models (LLMs), automatic math
reasoning has seen tremendous success. However, current methods primarily focus
on providing solutions or using techniques like Chain-of-Thought to enhance
problem-solving accuracy. In this paper, we focus on improving the capability
of mathematics teaching via a Socratic teaching-based LLM (SocraticLLM), which
guides learners toward profound thinking with clarity and self-discovery via
conversation. We collect and release a high-quality mathematical teaching
dataset, named SocraticMATH, which provides Socratic-style conversations of
problems with extra knowledge. Also, we propose a knowledge-enhanced LLM as a
strong baseline to generate reliable responses with review, guidance/heuristic,
rectification, and summarization. Experimental results show the great
advantages of SocraticLLM by comparing it with several strong generative
models.

Core Contribution: A Socratic method framework for LLM-driven mathematics
teaching that guides learners through guided inquiry, heuristic questioning,
and incremental knowledge construction rather than direct solution provision.

Key Innovation: Unlike chain-of-thought approaches that focus on solution
accuracy, Socratic teaching-based LLMs improve pedagogical outcomes by:
1. Guiding learners through questions rather than answers
2. Providing domain knowledge context to enable better guidance
3. Including review, guidance, rectification, and summarization steps
4. Creating a high-quality conversational teaching dataset (SocraticMATH)

Proposition Encoded: "An LLM-based Socratic teaching method that incorporates
knowledge-enhanced guidance, iterative rectification, and pedagogical
summarization produces superior learning outcomes and engagement compared to
direct solution provision or generic chain-of-thought approaches in
mathematics education."

Traceability:
  Arxiv ID: 2407.17349
  Reproduction Date: 2026-06-11
  Ralph Iteration: 2/50
  Dependencies: markovian_core (pedagogical_state_chains)
"""

from .socratic_mathematics import (
    SocraticQuestion,
    PedagogicalState,
    KnowledgeContext,
    GuidanceHeuristic,
    RectificationStep,
    SocraticTeachingSession,
    SocraticMathematicsEngine,
    PedagogicalAnalyzer,
    SocraticResponseGenerator,
)

__all__ = [
    "SocraticQuestion",
    "PedagogicalState",
    "KnowledgeContext",
    "GuidanceHeuristic",
    "RectificationStep",
    "SocraticTeachingSession",
    "SocraticMathematicsEngine",
    "PedagogicalAnalyzer",
    "SocraticResponseGenerator",
]
