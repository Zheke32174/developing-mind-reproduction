"""
Unit tests for SocREval implementation (Paper 2310.00074)
Tests the Socratic method for reference-free reasoning evaluation.
"""

import unittest
from src.papers.paper_2310_00074.socratic_reasoning_eval import (
    ReasoningQualityDimension,
    ReasoningChain,
    SocraticProbe,
    ProbeResponse,
    SocraticReasoningEvaluator,
    ReferenceFreeBenchmark,
)


class TestReasoningQualityDimension(unittest.TestCase):
    """Test reasoning quality dimensions."""
    
    def test_all_dimensions_present(self):
        """Verify all quality dimensions are defined."""
        dimensions = [d.value for d in ReasoningQualityDimension]
        self.assertIn("logical_coherence", dimensions)
        self.assertIn("completeness", dimensions)
        self.assertIn("justification", dimensions)
        self.assertIn("consistency", dimensions)
        self.assertIn("clarity", dimensions)
        self.assertIn("relevance", dimensions)
    
    def test_dimension_count(self):
        """Verify exactly 6 dimensions."""
        self.assertEqual(len(list(ReasoningQualityDimension)), 6)


class TestReasoningChain(unittest.TestCase):
    """Test reasoning chain representation."""
    
    def test_create_basic_chain(self):
        """Create a simple reasoning chain."""
        chain = ReasoningChain(
            goal="Determine if a number is prime",
            steps=["Check if n > 1", "Check if divisible by any number < n"],
            conclusion="If no divisors found, n is prime",
        )
        
        self.assertEqual(chain.goal, "Determine if a number is prime")
        self.assertEqual(len(chain.steps), 2)
        self.assertIsNone(chain.domain)
    
    def test_chain_with_domain(self):
        """Create a reasoning chain with domain information."""
        chain = ReasoningChain(
            goal="Solve a quadratic equation",
            steps=["Identify coefficients a, b, c", "Calculate discriminant b²-4ac"],
            conclusion="Solutions found using quadratic formula",
            domain="mathematics",
        )
        
        self.assertEqual(chain.domain, "mathematics")
    
    def test_chain_with_metadata(self):
        """Create a reasoning chain with metadata."""
        metadata = {"difficulty": "hard", "category": "algebra"}
        chain = ReasoningChain(
            goal="Test",
            steps=["Step 1"],
            conclusion="Done",
            metadata=metadata,
        )
        
        self.assertEqual(chain.metadata, metadata)
    
    def test_chain_to_dict(self):
        """Convert chain to dictionary."""
        chain = ReasoningChain(
            goal="Goal",
            steps=["Step 1", "Step 2"],
            conclusion="Conclusion",
            domain="math",
        )
        
        d = chain.to_dict()
        self.assertEqual(d["goal"], "Goal")
        self.assertEqual(d["num_steps"], 2)
        self.assertEqual(d["domain"], "math")
        self.assertEqual(d["conclusion"], "Conclusion")


class TestSocraticProbe(unittest.TestCase):
    """Test Socratic probing questions."""
    
    def test_create_probe(self):
        """Create a Socratic probe."""
        probe = SocraticProbe(
            dimension=ReasoningQualityDimension.LOGICAL_COHERENCE,
            question="Does each step follow logically?",
            aspect="step_to_step_logic",
            severity="critical",
        )
        
        self.assertEqual(probe.dimension, ReasoningQualityDimension.LOGICAL_COHERENCE)
        self.assertEqual(probe.severity, "critical")
    
    def test_probe_to_dict(self):
        """Convert probe to dictionary."""
        probe = SocraticProbe(
            dimension=ReasoningQualityDimension.JUSTIFICATION,
            question="Are claims supported?",
            aspect="claim_support",
            severity="critical",
        )
        
        d = probe.to_dict()
        self.assertEqual(d["dimension"], "justification")
        self.assertEqual(d["severity"], "critical")
    
    def test_severity_levels(self):
        """Test different severity levels."""
        critical = SocraticProbe(
            ReasoningQualityDimension.LOGICAL_COHERENCE,
            "Question", "aspect", "critical"
        )
        major = SocraticProbe(
            ReasoningQualityDimension.COMPLETENESS,
            "Question", "aspect", "major"
        )
        minor = SocraticProbe(
            ReasoningQualityDimension.CLARITY,
            "Question", "aspect", "minor"
        )
        
        self.assertEqual(critical.severity, "critical")
        self.assertEqual(major.severity, "major")
        self.assertEqual(minor.severity, "minor")


class TestProbeResponse(unittest.TestCase):
    """Test probe responses."""
    
    def test_create_response(self):
        """Create a probe response."""
        probe = SocraticProbe(
            ReasoningQualityDimension.LOGICAL_COHERENCE,
            "Does this follow?", "logic", "critical"
        )
        
        response = ProbeResponse(
            probe=probe,
            response="Yes, the logic is sound.",
            detected_issue=False,
            confidence=0.95,
        )
        
        self.assertEqual(response.detected_issue, False)
        self.assertEqual(response.confidence, 0.95)
    
    def test_response_with_issue(self):
        """Create a response that detects an issue."""
        probe = SocraticProbe(
            ReasoningQualityDimension.JUSTIFICATION,
            "Is this justified?", "support", "critical"
        )
        
        response = ProbeResponse(
            probe=probe,
            response="No, the claim is not supported.",
            detected_issue=True,
            issue_description="Missing evidence for key claim",
            confidence=0.92,
        )
        
        self.assertTrue(response.detected_issue)
        self.assertIsNotNone(response.issue_description)


class TestSocraticReasoningEvaluator(unittest.TestCase):
    """Test the Socratic reasoning evaluator."""
    
    def setUp(self):
        """Set up test evaluator."""
        self.evaluator = SocraticReasoningEvaluator()
    
    def test_evaluator_initialization(self):
        """Test evaluator initialization."""
        self.assertEqual(self.evaluator.model_name, "gpt-4")
        self.assertEqual(len(self.evaluator.probes), 6)  # 6 dimensions
    
    def test_probes_initialized(self):
        """Verify all dimension probes are initialized."""
        for dimension in ReasoningQualityDimension:
            probes = self.evaluator.get_probes_for_dimension(dimension)
            self.assertGreater(len(probes), 0)
    
    def test_get_probes_for_dimension(self):
        """Get probes for a specific dimension."""
        coherence_probes = self.evaluator.get_probes_for_dimension(
            ReasoningQualityDimension.LOGICAL_COHERENCE
        )
        
        self.assertGreater(len(coherence_probes), 0)
        self.assertTrue(
            all(p.dimension == ReasoningQualityDimension.LOGICAL_COHERENCE 
                for p in coherence_probes)
        )
    
    def test_get_critical_probes(self):
        """Get only critical-severity probes."""
        critical = self.evaluator.get_critical_probes()
        
        self.assertGreater(len(critical), 0)
        self.assertTrue(all(p.severity == "critical" for p in critical))
    
    def test_build_evaluation_prompt(self):
        """Test building an evaluation prompt."""
        chain = ReasoningChain(
            goal="Determine primality",
            steps=["Check divisibility", "Verify conclusion"],
            conclusion="Number is prime",
            domain="mathematics",
        )
        
        prompt = self.evaluator.build_evaluation_prompt(chain)
        
        self.assertIn("Determine primality", prompt)
        self.assertIn("Check divisibility", prompt)
        self.assertIn("Socratic method", prompt)
        self.assertIn("Logical Coherence", prompt)
        self.assertIn("Completeness", prompt)
    
    def test_evaluate_simple_chain(self):
        """Evaluate a simple reasoning chain."""
        chain = ReasoningChain(
            goal="Is 7 prime?",
            steps=[
                "7 is greater than 1",
                "7 is not divisible by 2",
                "7 is not divisible by 3",
                "7 is not divisible by 5",
                "Therefore, 7 is prime",
            ],
            conclusion="7 is prime",
            domain="mathematics",
        )
        
        result = self.evaluator.evaluate_reasoning_chain(chain)
        
        self.assertEqual(result["goal"], "Is 7 prime?")
        self.assertIn("overall_quality_score", result)
        self.assertIn("dimensions", result)
        self.assertEqual(len(result["dimensions"]), 6)
    
    def test_dimension_scores_in_range(self):
        """Verify dimension scores are between 0 and 1."""
        chain = ReasoningChain(
            goal="Test",
            steps=["Step 1", "Step 2"],
            conclusion="Conclusion",
        )
        
        result = self.evaluator.evaluate_reasoning_chain(chain)
        
        for dimension, score_info in result["dimensions"].items():
            score = score_info["score"]
            self.assertGreaterEqual(score, 0.0)
            self.assertLessEqual(score, 1.0)
    
    def test_overall_quality_score(self):
        """Verify overall quality score calculation."""
        chain = ReasoningChain(
            goal="Problem",
            steps=["Step 1", "Step 2", "Step 3"],
            conclusion="Solution",
        )
        
        result = self.evaluator.evaluate_reasoning_chain(chain)
        overall = result["overall_quality_score"]
        
        self.assertGreaterEqual(overall, 0.0)
        self.assertLessEqual(overall, 1.0)
    
    def test_evaluation_history(self):
        """Test that evaluations are recorded in history."""
        chain1 = ReasoningChain("Goal 1", ["Step"], "Conclusion 1")
        chain2 = ReasoningChain("Goal 2", ["Step"], "Conclusion 2")
        
        self.evaluator.evaluate_reasoning_chain(chain1)
        self.evaluator.evaluate_reasoning_chain(chain2)
        
        self.assertEqual(len(self.evaluator.evaluation_history), 2)
    
    def test_compare_chains(self):
        """Test comparing two reasoning chains."""
        strong_chain = ReasoningChain(
            goal="Prime check",
            steps=[
                "Check divisibility systematically",
                "Verify each step",
                "Draw conclusion",
                "Double-check result",
            ],
            conclusion="Number is prime",
        )
        
        weak_chain = ReasoningChain(
            goal="Prime check",
            steps=["Check number"],
            conclusion="Number is prime",
        )
        
        comparison = self.evaluator.compare_chains(strong_chain, weak_chain)
        
        self.assertIn("winner", comparison)
        self.assertIn("score_difference", comparison)
        self.assertIn("dimension_comparison", comparison)
    
    def test_get_evaluation_summary(self):
        """Test getting evaluation summary."""
        chain1 = ReasoningChain("Goal 1", ["Step 1"], "Conclusion 1")
        chain2 = ReasoningChain("Goal 2", ["Step 1", "Step 2"], "Conclusion 2")
        
        self.evaluator.evaluate_reasoning_chain(chain1)
        self.evaluator.evaluate_reasoning_chain(chain2)
        
        summary = self.evaluator.get_evaluation_summary()
        
        self.assertEqual(summary["total_evaluations"], 2)
        self.assertGreater(summary["average_quality_score"], 0)
        self.assertEqual(len(summary["dimension_averages"]), 6)
    
    def test_empty_summary(self):
        """Test summary with no evaluations."""
        evaluator = SocraticReasoningEvaluator()
        summary = evaluator.get_evaluation_summary()
        
        self.assertEqual(summary["total_evaluations"], 0)
        self.assertEqual(summary["average_quality_score"], 0.0)
    
    def test_custom_model_name(self):
        """Test creating evaluator with custom model."""
        evaluator = SocraticReasoningEvaluator(model_name="claude-3")
        self.assertEqual(evaluator.model_name, "claude-3")


class TestReferenceFreeBenchmark(unittest.TestCase):
    """Test the reference-free benchmark."""
    
    def setUp(self):
        """Set up test benchmark."""
        self.benchmark = ReferenceFreeBenchmark(
            name="Math Reasoning Benchmark",
            domain="mathematics",
        )
    
    def test_create_benchmark(self):
        """Create a benchmark."""
        self.assertEqual(self.benchmark.name, "Math Reasoning Benchmark")
        self.assertEqual(self.benchmark.domain, "mathematics")
        self.assertEqual(len(self.benchmark.chains), 0)
    
    def test_add_chain_without_score(self):
        """Add a chain without human quality score."""
        chain = ReasoningChain(
            goal="Is 5 prime?",
            steps=["Check divisibility"],
            conclusion="Yes, 5 is prime",
        )
        
        self.benchmark.add_chain(chain)
        
        self.assertEqual(len(self.benchmark.chains), 1)
    
    def test_add_chain_with_score(self):
        """Add a chain with human quality score."""
        chain = ReasoningChain(
            goal="Solve for x",
            steps=["Algebraic steps"],
            conclusion="x = 5",
        )
        
        self.benchmark.add_chain(chain, human_quality_score=0.95)
        
        self.assertEqual(len(self.benchmark.chains), 1)
        self.assertIn(chain.goal, self.benchmark.human_quality_scores)
    
    def test_evaluate_all_chains(self):
        """Evaluate all chains in benchmark."""
        evaluator = SocraticReasoningEvaluator()
        
        for i in range(3):
            chain = ReasoningChain(
                goal=f"Goal {i}",
                steps=[f"Step {i}"],
                conclusion=f"Result {i}",
            )
            self.benchmark.add_chain(chain, human_quality_score=0.5 + i * 0.2)
        
        results = self.benchmark.evaluate_all(evaluator)
        
        self.assertEqual(len(results), 3)
        self.assertTrue(all("overall_quality_score" in r for r in results))
    
    def test_correlation_with_human_scores(self):
        """Test correlation calculation with human scores."""
        evaluator = SocraticReasoningEvaluator()
        
        for i in range(5):
            chain = ReasoningChain(
                goal=f"Problem {i}",
                steps=[f"Step {i}"] * (i + 1),
                conclusion=f"Answer {i}",
            )
            self.benchmark.add_chain(chain, human_quality_score=0.4 + i * 0.15)
        
        correlation = self.benchmark.correlation_with_human_scores(evaluator)
        
        # Correlation should be a number between -1 and 1
        self.assertGreaterEqual(correlation, -1.0)
        self.assertLessEqual(correlation, 1.0)
    
    def test_correlation_with_few_chains(self):
        """Test correlation with insufficient data."""
        evaluator = SocraticReasoningEvaluator()
        chain = ReasoningChain("Goal", ["Step"], "Conclusion", None, None)
        self.benchmark.add_chain(chain, human_quality_score=0.5)
        
        correlation = self.benchmark.correlation_with_human_scores(evaluator)
        
        self.assertEqual(correlation, 0.0)


class TestSocraticEvaluationIntegration(unittest.TestCase):
    """Integration tests for Socratic reasoning evaluation."""
    
    def test_complete_evaluation_workflow(self):
        """Test a complete evaluation workflow."""
        # Create evaluator
        evaluator = SocraticReasoningEvaluator()
        
        # Create a reasoning chain
        chain = ReasoningChain(
            goal="Determine if 17 is prime",
            steps=[
                "17 > 1, so it could be prime",
                "17 is odd, so not divisible by 2",
                "Sum of digits: 1+7=8, not divisible by 3",
                "17 doesn't end in 0 or 5, not divisible by 5",
                "Since sqrt(17) ≈ 4.1, we only need to check up to 4",
                "No divisors found, therefore 17 is prime",
            ],
            conclusion="17 is prime",
            domain="mathematics",
        )
        
        # Evaluate
        result = evaluator.evaluate_reasoning_chain(chain)
        
        # Verify structure
        self.assertIn("overall_quality_score", result)
        self.assertIn("dimensions", result)
        self.assertEqual(len(result["dimensions"]), 6)
        
        # Verify all dimensions have scores
        for dimension in ReasoningQualityDimension:
            self.assertIn(dimension.value, result["dimensions"])
            self.assertIn("score", result["dimensions"][dimension.value])
    
    def test_comparison_reveals_quality_difference(self):
        """Test that comparison reveals quality differences."""
        evaluator = SocraticReasoningEvaluator()
        
        excellent_chain = ReasoningChain(
            goal="Solve quadratic",
            steps=[
                "Identify coefficients a, b, c",
                "Calculate discriminant Δ = b² - 4ac",
                "Find roots using formula: x = (-b ± √Δ) / 2a",
                "Verify roots by substitution",
                "Express final answer",
            ],
            conclusion="Roots found and verified",
        )
        
        poor_chain = ReasoningChain(
            goal="Solve quadratic",
            steps=["Use quadratic formula"],
            conclusion="Got roots",
        )
        
        comparison = evaluator.compare_chains(excellent_chain, poor_chain)
        
        # Excellent chain should score higher
        self.assertGreater(
            comparison["chain1_score"],
            comparison["chain2_score"]
        )
        self.assertEqual(comparison["winner"], "chain1")
    
    def test_benchmark_with_multiple_chains(self):
        """Test benchmark evaluation with multiple reasoning chains."""
        benchmark = ReferenceFreeBenchmark("Logic", "logic")
        evaluator = SocraticReasoningEvaluator()
        
        # Add chains with varying quality
        chains_data = [
            ("Is rain wet?", ["Water is wet", "Rain is water"], "Yes, rain is wet", 0.9),
            ("Solve x+2=5", ["Add 2 to both sides", "Result"], "x=3", 0.7),
            ("What is pi?", ["Mathematical constant"], "≈3.14159", 0.8),
        ]
        
        for goal, steps, conclusion, score in chains_data:
            chain = ReasoningChain(goal, steps, conclusion)
            benchmark.add_chain(chain, human_quality_score=score)
        
        # Evaluate all
        results = benchmark.evaluate_all(evaluator)
        self.assertEqual(len(results), 3)
        
        # Get summary
        summary = evaluator.get_evaluation_summary()
        self.assertEqual(summary["total_evaluations"], 3)


class TestSocraticMethodCharacteristics(unittest.TestCase):
    """Test that implementation captures Socratic method characteristics."""
    
    def test_probes_ask_questions(self):
        """Verify probes are formulated as questions."""
        evaluator = SocraticReasoningEvaluator()
        
        for dimension, probes in evaluator.probes.items():
            for probe in probes:
                # Probes should be questions (contain ? or start with question word)
                self.assertTrue(
                    "?" in probe.question or 
                    probe.question.lower().startswith(("what", "how", "does", "is", "are")),
                    f"Probe not formatted as question: {probe.question}"
                )
    
    def test_multiple_dimensions_for_comprehensive_evaluation(self):
        """Test that multiple dimensions enable comprehensive evaluation."""
        evaluator = SocraticReasoningEvaluator()
        
        # Should have at least 3 dimensions
        self.assertGreaterEqual(len(evaluator.probes), 3)
        
        # Should evaluate logic, structure, and communication aspects
        dimensions = list(evaluator.probes.keys())
        dimension_values = [d.value for d in dimensions]
        
        # Check for key aspects
        self.assertTrue(
            any("logic" in dv or "coherence" in dv for dv in dimension_values),
            "Should evaluate logical coherence"
        )
        self.assertTrue(
            any("complete" in dv or "justif" in dv for dv in dimension_values),
            "Should evaluate completeness/justification"
        )
    
    def test_severity_levels_for_prioritization(self):
        """Test that severity levels enable prioritization."""
        evaluator = SocraticReasoningEvaluator()
        
        critical = evaluator.get_critical_probes()
        all_probes = []
        for probes in evaluator.probes.values():
            all_probes.extend(probes)
        
        # Should have some critical probes
        self.assertGreater(len(critical), 0)
        
        # Should have probes with different severity levels
        severities = set()
        for probes in evaluator.probes.values():
            for probe in probes:
                severities.add(probe.severity)
        
        self.assertGreaterEqual(len(severities), 2,
                               "Should have multiple severity levels")


if __name__ == "__main__":
    unittest.main()
