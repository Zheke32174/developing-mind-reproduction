"""
Unit tests for Socratic Mathematics Teaching System
Paper: 2407.17349
"""

import pytest
from datetime import datetime
from src.papers.paper_2407_17349.socratic_mathematics import (
    SocraticQuestion,
    QuestionType,
    PedagogicalState,
    KnowledgeContext,
    KnowledgeCategory,
    GuidanceHeuristic,
    RectificationStep,
    SocraticTeachingSession,
    SocraticResponseGenerator,
    SocraticMathematicsEngine,
    PedagogicalAnalyzer,
)


class TestSocraticQuestion:
    """Test Socratic question generation and properties."""

    def test_question_creation(self):
        """Test creating a Socratic question."""
        q = SocraticQuestion(
            question_type=QuestionType.CLARIFICATION,
            content="What do you mean by 'solution'?",
            pedagogical_intent="Ensure understanding of terminology",
            expected_insight="Student can define solution precisely",
        )
        assert q.question_type == QuestionType.CLARIFICATION
        assert q.content == "What do you mean by 'solution'?"
        assert q.follow_up_threshold == 0.7

    def test_question_types(self):
        """Test all Socratic question types."""
        types = [
            QuestionType.CLARIFICATION,
            QuestionType.PROBING,
            QuestionType.HYPOTHETICAL,
            QuestionType.LEADING,
            QuestionType.REVIEWING,
        ]
        for qt in types:
            q = SocraticQuestion(
                question_type=qt,
                content="Test question",
                pedagogical_intent="Test intent",
                expected_insight="Test insight",
            )
            assert q.question_type == qt


class TestPedagogicalState:
    """Test pedagogical state progression."""

    def test_state_enumeration(self):
        """Test all pedagogical states."""
        states = [
            PedagogicalState.PROBLEM_PRESENTATION,
            PedagogicalState.INITIAL_EXPLORATION,
            PedagogicalState.GUIDED_INQUIRY,
            PedagogicalState.KNOWLEDGE_APPLICATION,
            PedagogicalState.RECTIFICATION,
            PedagogicalState.REFLECTION_SUMMARIZATION,
        ]
        assert len(states) == 6
        assert PedagogicalState.PROBLEM_PRESENTATION == PedagogicalState.PROBLEM_PRESENTATION


class TestKnowledgeContext:
    """Test domain knowledge representation."""

    def test_knowledge_context_creation(self):
        """Test creating knowledge context."""
        kc = KnowledgeContext(
            category=KnowledgeCategory.THEOREMS,
            content="The Pythagorean Theorem: a² + b² = c²",
            relevance_score=0.95,
            applicable_phases=[PedagogicalState.GUIDED_INQUIRY],
        )
        assert kc.category == KnowledgeCategory.THEOREMS
        assert kc.relevance_score == 0.95
        assert PedagogicalState.GUIDED_INQUIRY in kc.applicable_phases

    def test_knowledge_categories(self):
        """Test all knowledge categories."""
        categories = [
            KnowledgeCategory.DEFINITIONS,
            KnowledgeCategory.THEOREMS,
            KnowledgeCategory.HEURISTICS,
            KnowledgeCategory.COMMON_MISTAKES,
            KnowledgeCategory.PREREQUISITE,
        ]
        assert len(categories) == 5


class TestGuidanceHeuristic:
    """Test pedagogical heuristics."""

    def test_heuristic_creation(self):
        """Test creating a guidance heuristic."""
        h = GuidanceHeuristic(
            name="Variable Isolation",
            description="Isolate the variable step by step",
            steps=["Move constants", "Divide by coefficient"],
            mathematical_principle="Equality preservation",
            difficulty_level=2,
        )
        assert h.name == "Variable Isolation"
        assert len(h.steps) == 2
        assert h.difficulty_level == 2


class TestRectificationStep:
    """Test rectification and error correction."""

    def test_rectification_creation(self):
        """Test creating a rectification step."""
        q = SocraticQuestion(
            question_type=QuestionType.PROBING,
            content="Why did you divide by 2?",
            pedagogical_intent="Clarify procedure",
            expected_insight="Student explains reasoning",
        )
        r = RectificationStep(
            identified_misconception="Dividing by coefficient before isolating variable",
            corrective_guidance="We must first move all constants to the other side",
            reinforcing_question=q,
            validation_strategy="Ask student to redo step",
        )
        assert "Dividing by coefficient" in r.identified_misconception
        assert r.reinforcing_question.question_type == QuestionType.PROBING


class TestSocraticTeachingSession:
    """Test teaching session management."""

    def test_session_creation(self):
        """Test creating a teaching session."""
        session = SocraticTeachingSession(
            session_id="sess_001",
            problem_statement="Solve 2x + 3 = 7",
            mathematical_domain="algebra",
            student_level="beginner",
        )
        assert session.session_id == "sess_001"
        assert session.mathematical_domain == "algebra"
        assert session.student_level == "beginner"
        assert session.current_pedagogical_state == PedagogicalState.PROBLEM_PRESENTATION

    def test_phase_advancement(self):
        """Test advancing through pedagogical phases."""
        session = SocraticTeachingSession(
            session_id="sess_002",
            problem_statement="Test problem",
            mathematical_domain="algebra",
            student_level="beginner",
        )
        assert session.current_pedagogical_state == PedagogicalState.PROBLEM_PRESENTATION
        
        session.advance_phase(PedagogicalState.INITIAL_EXPLORATION)
        assert session.current_pedagogical_state == PedagogicalState.INITIAL_EXPLORATION
        
        session.advance_phase(PedagogicalState.GUIDED_INQUIRY)
        assert session.current_pedagogical_state == PedagogicalState.GUIDED_INQUIRY

    def test_dialogue_recording(self):
        """Test recording dialogue exchanges."""
        session = SocraticTeachingSession(
            session_id="sess_003",
            problem_statement="Solve x + 2 = 5",
            mathematical_domain="algebra",
            student_level="beginner",
        )
        assert session.get_session_length() == 0
        
        session.add_dialogue_turn("What is x + 2 = 5?", "x = 3")
        assert session.get_session_length() == 1
        
        session.add_dialogue_turn("How did you get 3?", "I subtracted 2 from both sides")
        assert session.get_session_length() == 2

    def test_rectification_tracking(self):
        """Test tracking rectifications."""
        session = SocraticTeachingSession(
            session_id="sess_004",
            problem_statement="Solve 2x = 8",
            mathematical_domain="algebra",
            student_level="beginner",
        )
        assert len(session.rectifications_made) == 0
        
        q = SocraticQuestion(
            question_type=QuestionType.PROBING,
            content="What operation did you use?",
            pedagogical_intent="Clarify",
            expected_insight="Student explains",
        )
        r = RectificationStep(
            identified_misconception="Wrong operation",
            corrective_guidance="Divide both sides by 2",
            reinforcing_question=q,
            validation_strategy="Verify",
        )
        session.add_rectification(r)
        assert len(session.rectifications_made) == 1


class TestSocraticResponseGenerator:
    """Test response generation."""

    def test_generator_creation(self):
        """Test creating a response generator."""
        gen = SocraticResponseGenerator()
        assert isinstance(gen.knowledge_base, dict)
        assert isinstance(gen.heuristic_library, dict)

    def test_question_generation(self):
        """Test generating Socratic questions."""
        gen = SocraticResponseGenerator()
        question = gen.generate_question(
            student_response="x = 3",
            current_state=PedagogicalState.INITIAL_EXPLORATION,
            knowledge_context=[],
        )
        assert isinstance(question, SocraticQuestion)
        assert question.question_type == QuestionType.CLARIFICATION

    def test_guidance_generation(self):
        """Test generating heuristic guidance."""
        gen = SocraticResponseGenerator()
        guidance = gen.generate_guidance(
            student_response="I subtracted",
            mathematical_domain="algebra",
        )
        assert guidance is not None
        assert guidance.name == "Variable Isolation Heuristic"
        assert len(guidance.steps) == 3


class TestSocraticMathematicsEngine:
    """Test the core teaching engine."""

    def test_engine_creation(self):
        """Test creating the engine."""
        engine = SocraticMathematicsEngine()
        assert isinstance(engine.active_sessions, dict)
        assert len(engine.active_sessions) == 0

    def test_session_lifecycle(self):
        """Test complete session lifecycle."""
        engine = SocraticMathematicsEngine()
        
        # Create session
        session = engine.create_session(
            session_id="test_001",
            problem_statement="Solve x + 5 = 12",
            mathematical_domain="algebra",
            student_level="beginner",
        )
        assert session.session_id == "test_001"
        assert session.session_id in engine.active_sessions
        
        # Present problem
        response = engine.present_problem("test_001")
        assert "Solve x + 5 = 12" in response
        
        # Process response
        next_q, state = engine.process_response("test_001", "x = 7")
        assert isinstance(next_q, str)
        assert state in PedagogicalState
        
        # Complete session
        summary = engine.complete_session("test_001")
        assert summary["session_id"] == "test_001"
        assert "dialogue_turns" in summary

    def test_invalid_session(self):
        """Test handling invalid sessions."""
        engine = SocraticMathematicsEngine()
        response, state = engine.process_response("nonexistent", "test")
        assert "Session not found" in response


class TestPedagogicalAnalyzer:
    """Test analysis of teaching effectiveness."""

    def test_analyzer_creation(self):
        """Test creating an analyzer."""
        analyzer = PedagogicalAnalyzer()
        assert analyzer is not None

    def test_session_analysis(self):
        """Test analyzing a teaching session."""
        session = SocraticTeachingSession(
            session_id="analyze_001",
            problem_statement="Solve 3x = 9",
            mathematical_domain="algebra",
            student_level="beginner",
        )
        session.add_dialogue_turn("How do we solve 3x = 9?", "Divide by 3")
        session.add_dialogue_turn("Good, what do we get?", "x = 3")
        
        analyzer = PedagogicalAnalyzer()
        analysis = analyzer.analyze_session(session)
        
        assert analysis["session_id"] == "analyze_001"
        assert analysis["total_dialogue_turns"] == 2
        assert analysis["rectifications_needed"] == 0

    def test_effectiveness_scoring(self):
        """Test effectiveness computation."""
        session = SocraticTeachingSession(
            session_id="score_001",
            problem_statement="Problem",
            mathematical_domain="algebra",
            student_level="beginner",
        )
        # Add multiple dialogue turns for engagement score
        for i in range(5):
            session.add_dialogue_turn(f"Q{i}", f"A{i}")
        
        analyzer = PedagogicalAnalyzer()
        effectiveness = analyzer.compute_pedagogical_effectiveness(session)
        
        assert 0.0 <= effectiveness <= 1.0
        # With 5 turns and no rectifications, should score reasonably well
        assert effectiveness > 0.4


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
