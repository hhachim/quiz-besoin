-- Activation de l'extension pour générer des UUID
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

--------------------------------------------------
-- Table des utilisateurs
--------------------------------------------------
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username TEXT UNIQUE NOT NULL,
    email TEXT UNIQUE NOT NULL,
    password TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

--------------------------------------------------
-- Table des quiz
--------------------------------------------------
CREATE TABLE quizzes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    description TEXT,
    difficulty_level TEXT CHECK (difficulty_level IN ('beginner', 'intermediate', 'expert')),
    duration INT, -- Durée en secondes
    score_threshold NUMERIC, -- Score minimal pour valider le quiz
    state TEXT CHECK (state IN ('draft', 'published', 'archived', 'in_revision')),
    visibility TEXT CHECK (visibility IN ('public', 'private')) DEFAULT 'private',
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    deleted_at TIMESTAMPTZ  -- Pour soft delete
);

--------------------------------------------------
-- Table des dépendances entre quiz
--------------------------------------------------
CREATE TABLE quiz_dependencies (
    id SERIAL PRIMARY KEY,
    quiz_id UUID REFERENCES quizzes(id) ON DELETE CASCADE,           -- Quiz dont l'accès est restreint
    dependency_quiz_id UUID REFERENCES quizzes(id) ON DELETE CASCADE, -- Quiz prérequis
    condition JSONB,  -- Conditions de réussite (ex : score minimal requis)
    UNIQUE (quiz_id, dependency_quiz_id)
);

--------------------------------------------------
-- Table des questions
--------------------------------------------------
CREATE TABLE questions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    text TEXT NOT NULL,
    type TEXT CHECK (type IN (
        'multiple_choice', 
        'true_false', 
        'short_answer', 
        'long_answer', 
        'association', 
        'ordering', 
        'fill_in_the_blanks'
    )),
    is_required BOOLEAN DEFAULT TRUE,
    default_time INT,       -- Temps par défaut (en secondes)
    default_points NUMERIC, -- Points par défaut
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

--------------------------------------------------
-- Table d'association entre quiz et questions
-- Permet d'utiliser la même question dans plusieurs quiz avec des valeurs spécifiques (durée, points, ordre)
--------------------------------------------------
CREATE TABLE quiz_questions (
    id SERIAL PRIMARY KEY,
    quiz_id UUID REFERENCES quizzes(id) ON DELETE CASCADE,
    question_id UUID REFERENCES questions(id) ON DELETE CASCADE,
    order_num INT,          -- Ordre de la question dans le quiz
    time_override INT,      -- Temps personnalisé pour ce quiz
    points_override NUMERIC, -- Points personnalisés pour ce quiz
    UNIQUE (quiz_id, question_id)
);

--------------------------------------------------
-- Table des tentatives (participation aux quiz)
--------------------------------------------------
CREATE TABLE attempts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    quiz_id UUID REFERENCES quizzes(id) ON DELETE CASCADE,
    started_at TIMESTAMPTZ DEFAULT now(),
    finished_at TIMESTAMPTZ,
    score NUMERIC,
    status TEXT CHECK (status IN ('in_progress', 'completed', 'failed'))
);

--------------------------------------------------
-- Table des réponses aux questions dans une tentative
--------------------------------------------------
CREATE TABLE attempt_responses (
    id SERIAL PRIMARY KEY,
    attempt_id UUID REFERENCES attempts(id) ON DELETE CASCADE,
    quiz_question_id INT REFERENCES quiz_questions(id) ON DELETE CASCADE,
    response JSONB,          -- Stockage flexible pour différents types de réponses
    response_time INT,       -- Temps passé sur cette question (en secondes)
    is_correct BOOLEAN,
    answered_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (attempt_id, quiz_question_id)
);

--------------------------------------------------
-- Table des tags (catégorisation des quiz)
--------------------------------------------------
CREATE TABLE tags (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT UNIQUE NOT NULL
);

--------------------------------------------------
-- Table d'association entre quiz et tags
--------------------------------------------------
CREATE TABLE quiz_tags (
    quiz_id UUID REFERENCES quizzes(id) ON DELETE CASCADE,
    tag_id UUID REFERENCES tags(id) ON DELETE CASCADE,
    PRIMARY KEY (quiz_id, tag_id)
);
