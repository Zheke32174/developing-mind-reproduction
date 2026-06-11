"""
Developing Mind — Paper 2310.00074 Reproduction
Role: Reference-free reasoning evaluation using Socratic method.
Solving recurrent amnesia by codifying automated reasoning assessment techniques.

Title: SocREval: Large Language Models with the Socratic Method for Reference-Free Reasoning Evaluation
Authors: Zhang et al.
Abstract: A novel approach for prompt design in reference-free reasoning evaluation using 
the Socratic method. Leverages GPT-4 to automatically evaluate reasoning chain quality, 
removing the dependency on human-written reasoning chains for both fine-tuning and evaluation.

Core Contribution: SocREval uses Socratic questioning to probe reasoning chains and assess
their quality without human references. The approach is cost-efficient, robust to prompt 
variations, and demonstrates superior performance on multiple benchmark datasets.

Key Innovation: By breaking down reasoning evaluation into a series of probing questions
(Socratic method), the evaluator can identify logical gaps, unsupported claims, and 
reasoning inconsistencies more effectively than traditional metrics.

Arxiv: https://arxiv.org/abs/2310.00074
"""

from typing import List, Dict, Optional, Tuple, Any
from dataclasses import dataclass
from enum import Enum


class ReasoningQualityDimension(Enum):
    """Dimensions of reasoning quality assessed through Socratic probing."""
    LOGICAL_COHERENCE = "logical_coherence"      # Does reasoning follow logically?
    COMPLETENESS = "completeness"                # Are all necessary steps present?
    JUSTIFICATION = "justification"              # Are claims properly justified?
    CONSISTENCY = "consistency"                  # Are there internal contradictions?
    CLARITY = "clarity"                          # Is reasoning clearly articulated?
    RELEVANCE = "relevance"                      # Are steps relevant to the goal?


@dataclass
class ReasoningChain:
    """Represents a step-by-step reasoning sequence."""
    goal: str                              # What is being reasoned about
    steps: List[str]                       # Individual reasoning steps
    conclusion: str                        # Final conclusion
    domain: Optional[str] = None           # Domain of reasoning (math, logic, etc.)
    metadata: Optional[Dict[str, Any]] = None  # Additional context
    
    def to_dict(self) -> Dict:
        return {
            "goal": self.goal,
            "steps": self.steps,
            "conclusion": self.conclusion,
            "domain": self.domain,
            "num_steps": len(self.steps),
            "metadata": self.metadata or {},
        }


@dataclass
class SocraticProbe:
    """A single Socratic probing question for reasoning evaluation."""
    dimension: ReasoningQualityDimension
    question: str
    aspect: str              # Which aspect of reasoning this probes
    severity: str            # "critical", "major", "minor" - importance of finding issues
    
    def to_dict(self) -> Dict:
        return {
            "dimension": self.dimension.value,
            "question": self.question,
            "aspect": self.aspect,
            "severity": self.severity,
        }


@dataclass
class ProbeResponse:
    """Response to a Socratic probe."""
    probe: SocraticProbe
    response: str                        # Model's response to probe
    detected_issue: bool                 # Does this reveal a problem?
    issue_description: Optional[str] = None  # What problem was found
    confidence: float = 0.5              # Confidence in the assessment (0-1)


class SocraticReasoningEvaluator:
    """
    Evaluates reasoning chains using the Socratic method.
    
    The key insight from SocREval: By asking probing questions about each
    aspect of reasoning, we can assess quality without human references.
    """
    
    def __init__(self, model_name: str = "gpt-4"):
        """
        Initialize the evaluator.
        
        Args:
            model_name: Which LLM to use for evaluation (e.g., "gpt-4", "claude")
        """
        self.model_name = model_name
        self.probes: Dict[ReasoningQualityDimension, List[SocraticProbe]] = {}
        self._initialize_probes()
        self.evaluation_history: List[Dict] = []
    
    def _initialize_probes(self) -> None:
        """Initialize Socratic probes for each reasoning quality dimension."""
        
        # Logical coherence probes
        self.probes[ReasoningQualityDimension.LOGICAL_COHERENCE] = [
            SocraticProbe(
                dimension=ReasoningQualityDimension.LOGICAL_COHERENCE,
                question="Does each step logically follow from the previous steps?",
                aspect="step_to_step_logic",
                severity="critical"
            ),
            SocraticProbe(
                dimension=ReasoningQualityDimension.LOGICAL_COHERENCE,
                question="Are there any logical fallacies or invalid inferences?",
                aspect="inference_validity",
                severity="critical"
            ),
        ]
        
        # Completeness probes
        self.probes[ReasoningQualityDimension.COMPLETENESS] = [
            SocraticProbe(
                dimension=ReasoningQualityDimension.COMPLETENESS,
                question="Are all necessary steps included to reach the conclusion?",
                aspect="step_coverage",
                severity="major"
            ),
            SocraticProbe(
                dimension=ReasoningQualityDimension.COMPLETENESS,
                question="Are there any unstated assumptions that should be explicit?",
                aspect="assumption_explicitness",
                severity="major"
            ),
        ]
        
        # Justification probes
        self.probes[ReasoningQualityDimension.JUSTIFICATION] = [
            SocraticProbe(
                dimension=ReasoningQualityDimension.JUSTIFICATION,
                question="Is each claim supported by reasoning or evidence?",
                aspect="claim_support",
                severity="critical"
            ),
            SocraticProbe(
                dimension=ReasoningQualityDimension.JUSTIFICATION,
                question="Would a skeptical reader find the justifications convincing?",
                aspect="justification_strength",
                severity="major"
            ),
        ]
        
        # Consistency probes
        self.probes[ReasoningQualityDimension.CONSISTENCY] = [
            SocraticProbe(
                dimension=ReasoningQualityDimension.CONSISTENCY,
                question="Are there any internal contradictions in the reasoning?",
                aspect="contradiction_detection",
                severity="critical"
            ),
            SocraticProbe(
                dimension=ReasoningQualityDimension.CONSISTENCY,
                question="Do all steps align with the stated goal and domain?",
                aspect="goal_alignment",
                severity="major"
            ),
        ]
        
        # Clarity probes
        self.probes[ReasoningQualityDimension.CLARITY] = [
            SocraticProbe(
                dimension=ReasoningQualityDimension.CLARITY,
                question="Is each step clearly explained and easy to understand?",
                aspect="step_clarity",
                severity="minor"
            ),
            SocraticProbe(
                dimension=ReasoningQualityDimension.CLARITY,
                question="Could the reasoning be more concisely stated?",
                aspect="conciseness",
                severity="minor"
            ),
        ]
        
        # Relevance probes
        self.probes[ReasoningQualityDimension.RELEVANCE] = [
            SocraticProbe(
                dimension=ReasoningQualityDimension.RELEVANCE,
                question="Does each step contribute to answering the goal?",
                aspect="step_relevance",
                severity="major"
            ),
            SocraticProbe(
                dimension=ReasoningQualityDimension.RELEVANCE,
                question="Are there any tangential or off-topic steps?",
                aspect="tangential_content",
                severity="minor"
            ),
        ]
    
    def get_probes_for_dimension(
        self, 
        dimension: ReasoningQualityDimension
    ) -> List[SocraticProbe]:
        """Get all Socratic probes for a specific quality dimension."""
        return self.probes.get(dimension, [])
    
    def get_critical_probes(self) -> List[SocraticProbe]:
        """Get only the critical-severity probes."""
        critical = []
        for probe_list in self.probes.values():
            critical.extend([p for p in probe_list if p.severity == "critical"])
        return critical
    
    def build_evaluation_prompt(self, reasoning_chain: ReasoningChain) -> str:
        """
        Build a complete evaluation prompt using Socratic method.
        
        The prompt guides the LLM to probe the reasoning systematically.
        This is the core of the SocREval approach.
        
        Args:
            reasoning_chain: The reasoning to evaluate
            
        Returns:
            Formatted evaluation prompt
        """
        prompt = f"""You are a rigorous reasoning evaluator using the Socratic method.
        
TASK: Evaluate the following reasoning chain by asking probing questions.

GOAL: {reasoning_chain.goal}

REASONING STEPS:
"""
        for i, step in enumerate(reasoning_chain.steps, 1):
            prompt += f"\n{i}. {step}"
        
        prompt += f"\n\nCONCLUSION: {reasoning_chain.conclusion}"
        
        if reasoning_chain.domain:
            prompt += f"\n\nDOMAIN: {reasoning_chain.domain}"
        
        prompt += """

EVALUATION APPROACH:
Apply the Socratic method by asking systematic probing questions about:
1. Logical Coherence: Do steps follow logically?
2. Completeness: Are all necessary steps present?
3. Justification: Are claims properly supported?
4. Consistency: Are there contradictions?
5. Clarity: Is the reasoning clearly articulated?
6. Relevance: Do steps contribute to the goal?

For each probe question, assess:
- Whether an issue is detected
- The severity if an issue is found (critical/major/minor)
- Overall confidence in your assessment

Provide a structured evaluation."""
        
        return prompt
    
    def evaluate_reasoning_chain(
        self, 
        reasoning_chain: ReasoningChain
    ) -> Dict[str, Any]:
        """
        Evaluate a reasoning chain using Socratic probing.
        
        Args:
            reasoning_chain: The reasoning to evaluate
            
        Returns:
            Evaluation results with dimension scores and overall quality score
        """
        evaluation = {
            "goal": reasoning_chain.goal,
            "chain_summary": reasoning_chain.to_dict(),
            "dimensions": {},
            "issues_found": [],
            "overall_quality_score": 0.0,
            "reasoning_summary": "",
        }
        
        # Evaluate each dimension
        total_score = 0
        dimension_count = 0
        
        for dimension in ReasoningQualityDimension:
            dimension_probes = self.get_probes_for_dimension(dimension)
            dimension_score = self._evaluate_dimension(
                dimension, dimension_probes, reasoning_chain
            )
            
            evaluation["dimensions"][dimension.value] = {
                "score": dimension_score,
                "num_probes": len(dimension_probes),
            }
            
            total_score += dimension_score
            dimension_count += 1
        
        # Calculate overall score
        evaluation["overall_quality_score"] = total_score / dimension_count if dimension_count > 0 else 0.0
        
        # Store in history
        self.evaluation_history.append(evaluation)
        
        return evaluation
    
    def _evaluate_dimension(
        self,
        dimension: ReasoningQualityDimension,
        probes: List[SocraticProbe],
        reasoning_chain: ReasoningChain
    ) -> float:
        """
        Evaluate a specific dimension by probing.
        
        Args:
            dimension: The quality dimension to evaluate
            probes: Probing questions for this dimension
            reasoning_chain: The reasoning to evaluate
            
        Returns:
            Score for this dimension (0-1)
        """
        if not probes:
            return 0.5  # No probes available, neutral score
        
        # Each probe contributes to the dimension score
        # In a real implementation, we would call an LLM here
        # For now, simulate scoring based on reasoning chain properties
        
        issues_detected = 0
        for probe in probes:
            # This would be replaced with actual LLM evaluation
            # For now, heuristics based on reasoning characteristics
            if self._probe_detects_issue(dimension, probe, reasoning_chain):
                issues_detected += 1
        
        # Convert issue count to score (fewer issues = higher score)
        issue_rate = issues_detected / len(probes) if probes else 0
        score = max(0.0, 1.0 - issue_rate)  # Score decreases with more issues
        
        return round(score, 2)
    
    def _probe_detects_issue(
        self,
        dimension: ReasoningQualityDimension,
        probe: SocraticProbe,
        reasoning_chain: ReasoningChain
    ) -> bool:
        """
        Determine if a probe would detect an issue in the reasoning.
        
        In a real implementation, this would call an LLM to evaluate.
        Here we use heuristics based on reasoning characteristics.
        
        Args:
            dimension: The quality dimension
            probe: The specific probe
            reasoning_chain: The reasoning to evaluate
            
        Returns:
            Whether an issue was detected
        """
        # Heuristic-based detection for demonstration
        num_steps = len(reasoning_chain.steps)
        
        # Very short chains might have completeness issues
        if dimension == ReasoningQualityDimension.COMPLETENESS:
            return num_steps < 3
        
        # Consistency is generally harder to verify heuristically
        # Would rely on LLM evaluation in practice
        if dimension == ReasoningQualityDimension.CONSISTENCY:
            return False
        
        # Clarity improves with explicit steps
        if dimension == ReasoningQualityDimension.CLARITY:
            avg_step_length = sum(len(step) for step in reasoning_chain.steps) / num_steps
            return avg_step_length < 20
        
        return False
    
    def compare_chains(
        self,
        chain1: ReasoningChain,
        chain2: ReasoningChain
    ) -> Dict[str, Any]:
        """
        Compare two reasoning chains using Socratic evaluation.
        
        Args:
            chain1: First reasoning chain
            chain2: Second reasoning chain
            
        Returns:
            Comparison results with scores and differences
        """
        eval1 = self.evaluate_reasoning_chain(chain1)
        eval2 = self.evaluate_reasoning_chain(chain2)
        
        return {
            "chain1_score": eval1["overall_quality_score"],
            "chain2_score": eval2["overall_quality_score"],
            "winner": "chain1" if eval1["overall_quality_score"] > eval2["overall_quality_score"] else 
                     "chain2" if eval2["overall_quality_score"] > eval1["overall_quality_score"] else 
                     "tie",
            "score_difference": abs(eval1["overall_quality_score"] - eval2["overall_quality_score"]),
            "dimension_comparison": self._compare_dimensions(eval1, eval2),
        }
    
    def _compare_dimensions(self, eval1: Dict, eval2: Dict) -> Dict:
        """Compare dimension scores between two evaluations."""
        comparison = {}
        for dimension in eval1["dimensions"]:
            score1 = eval1["dimensions"][dimension]["score"]
            score2 = eval2["dimensions"][dimension]["score"]
            comparison[dimension] = {
                "chain1": score1,
                "chain2": score2,
                "difference": abs(score1 - score2),
            }
        return comparison
    
    def get_evaluation_summary(self) -> Dict:
        """Get summary statistics from all evaluations performed."""
        if not self.evaluation_history:
            return {
                "total_evaluations": 0,
                "average_quality_score": 0.0,
                "dimension_averages": {},
            }
        
        total_score = sum(e["overall_quality_score"] for e in self.evaluation_history)
        avg_score = total_score / len(self.evaluation_history)
        
        # Calculate dimension averages
        dimension_averages = {}
        for dimension in ReasoningQualityDimension:
            dim_key = dimension.value
            scores = [
                e["dimensions"][dim_key]["score"] 
                for e in self.evaluation_history 
                if dim_key in e["dimensions"]
            ]
            if scores:
                dimension_averages[dim_key] = round(sum(scores) / len(scores), 2)
        
        return {
            "total_evaluations": len(self.evaluation_history),
            "average_quality_score": round(avg_score, 2),
            "dimension_averages": dimension_averages,
        }


class ReferenceFreeBenchmark:
    """
    Benchmark for reference-free reasoning evaluation.
    
    Allows comparing the Socratic evaluation approach against other methods
    without requiring human-annotated reference chains.
    """
    
    def __init__(self, name: str, domain: str):
        """
        Initialize benchmark.
        
        Args:
            name: Benchmark name
            domain: Reasoning domain (e.g., "math", "logic", "coding")
        """
        self.name = name
        self.domain = domain
        self.chains: List[ReasoningChain] = []
        self.human_quality_scores: Dict[str, float] = {}
    
    def add_chain(self, chain: ReasoningChain, human_quality_score: Optional[float] = None) -> None:
        """Add a reasoning chain to the benchmark."""
        self.chains.append(chain)
        if human_quality_score is not None:
            self.human_quality_scores[chain.goal] = human_quality_score
    
    def evaluate_all(self, evaluator: SocraticReasoningEvaluator) -> List[Dict]:
        """Evaluate all chains in the benchmark."""
        results = []
        for chain in self.chains:
            eval_result = evaluator.evaluate_reasoning_chain(chain)
            eval_result["human_quality_score"] = self.human_quality_scores.get(chain.goal)
            results.append(eval_result)
        return results
    
    def correlation_with_human_scores(self, evaluator: SocraticReasoningEvaluator) -> float:
        """
        Calculate correlation between Socratic evaluation and human scores.
        
        This demonstrates that the reference-free approach correlates well
        with human judgment (key finding of SocREval paper).
        """
        results = self.evaluate_all(evaluator)
        
        model_scores = []
        human_scores = []
        
        for result in results:
            if result["human_quality_score"] is not None:
                model_scores.append(result["overall_quality_score"])
                human_scores.append(result["human_quality_score"])
        
        if len(model_scores) < 2:
            return 0.0
        
        # Simple Pearson correlation
        n = len(model_scores)
        mean_model = sum(model_scores) / n
        mean_human = sum(human_scores) / n
        
        numerator = sum(
            (model_scores[i] - mean_model) * (human_scores[i] - mean_human) 
            for i in range(n)
        )
        
        model_variance = sum((x - mean_model) ** 2 for x in model_scores)
        human_variance = sum((x - mean_human) ** 2 for x in human_scores)
        
        denominator = (model_variance * human_variance) ** 0.5
        
        if denominator == 0:
            return 0.0
        
        return round(numerator / denominator, 3)
