"""
Developing Mind — Paper 2407.13067 Reproduction
Role: Supportive Accountability and Persona-Driven Memory Continuity.
Solving recurrent amnesia by codifying engagement-sustaining agent architectures.

Title: Large Language Model Agents for Improving Engagement with Behavior
       Change Interventions: Application to Digital Mindfulness
Authors: Kumar, Yoo, Bernuy, Shi, Luo, Williams, Kuzminykh, Anderson, Kornfield
Venue: Under review (2024)
Arxiv: https://arxiv.org/abs/2407.13067

Abstract: Although engagement in self-directed wellness exercises typically
declines over time, integrating social support such as coaching can sustain it.
LLMs show promise in providing human-like dialogues that could emulate social
support. Two randomized experiments assessed the impact of LLM agents on user
engagement with mindfulness exercises: a single-session study (502 crowdworkers)
and a three-week study (54 participants). Two types of LLM agents were compared:
one providing information (friendly persona) and another facilitating self-
reflection. Both enhanced intentions to practice mindfulness, but only the
information-providing LLM featuring a friendly persona significantly improved
engagement with the exercises.

Core Contribution: A persona-driven supportive accountability framework for LLM
agents that sustains user engagement in digital behavior-change interventions
through memory continuity, intervention-type selection, and persona consistency.

Key Innovation: Not all social support is equal — a friendly informational agent
with consistent persona outperformed a reflective agent, demonstrating that
persona design and interaction type are critical for sustained engagement.

Proposition Encoded: "An LLM agent with a consistent friendly persona and
informational intervention strategy produces statistically significant
improvement in sustained user engagement compared to reflective or neutral
baselines, with engagement decay over time following a predictable
persona-mediated trajectory."

Traceability:
  Arxiv ID: 2407.13067
  Reproduction Date: 2026-06-11
  Ralph Iteration: 2/50
  Dependencies: markovian_core (states, chains)
"""

from .supportive_accountability import (
    PersonaProfile,
    PersonaType,
    EngagementState,
    EngagementPhase,
    MemoryContinuity,
    InterventionType,
    InterventionMessage,
    AccountabilitySession,
    SupportiveAccountabilityEngine,
    EngagementExperiment,
    EngagementAnalyzer,
)
