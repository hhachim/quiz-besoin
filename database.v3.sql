-- -----------------------------------------------------
-- Schéma amélioré pour l'API de Quiz
-- Combinaison des éléments de database.sql et database.v2.sql
-- -----------------------------------------------------

-- Activation de l'extension pour générer des UUID
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Table des utilisateurs
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    uuid UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    username VARCHAR(100) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP,
    last_login_at TIMESTAMP,
    deleted_at TIMESTAMP,
    CONSTRAINT users_email_check CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

-- Table des rôles
CREATE TABLE roles (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Table d'association utilisateurs-rôles
CREATE TABLE user_roles (
    user_id INTEGER NOT NULL,
    role_id INTEGER NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, role_id),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE
);

-- Table des permissions
CREATE TABLE permissions (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Table d'association rôles-permissions
CREATE TABLE role_permissions (
    role_id INTEGER NOT NULL,
    permission_id INTEGER NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (role_id, permission_id),
    FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE,
    FOREIGN KEY (permission_id) REFERENCES permissions(id) ON DELETE CASCADE
);

-- Table des catégories
CREATE TABLE categories (
    id SERIAL PRIMARY KEY,
    uuid UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    parent_id INTEGER,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP,
    created_by INTEGER,
    updated_by INTEGER,
    deleted_at TIMESTAMP,
    FOREIGN KEY (parent_id) REFERENCES categories(id) ON DELETE SET NULL,
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (updated_by) REFERENCES users(id) ON DELETE SET NULL
);

-- Table des tags
CREATE TABLE tags (
    id SERIAL PRIMARY KEY,
    uuid UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    name VARCHAR(50) NOT NULL UNIQUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by INTEGER,
    deleted_at TIMESTAMP,
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL
);

-- Table des quiz
CREATE TABLE quizzes (
    id SERIAL PRIMARY KEY,
    uuid UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    difficulty_level VARCHAR(20) CHECK (difficulty_level IN ('BEGINNER', 'EASY', 'MEDIUM', 'HARD', 'EXPERT')),
    time_limit INTEGER, -- Durée en secondes, NULL = pas de limite
    passing_score NUMERIC(5,2), -- Score minimum pour réussir (pourcentage)
    status VARCHAR(20) NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT', 'PUBLISHED', 'ARCHIVED', 'REVIEWING')),
    is_public BOOLEAN DEFAULT FALSE,
    category_id INTEGER,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP,
    created_by INTEGER NOT NULL,
    updated_by INTEGER,
    deleted_at TIMESTAMP,
    FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL,
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE RESTRICT,
    FOREIGN KEY (updated_by) REFERENCES users(id) ON DELETE SET NULL
);

-- Table d'association quiz-tags
CREATE TABLE quiz_tags (
    quiz_id INTEGER NOT NULL,
    tag_id INTEGER NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (quiz_id, tag_id),
    FOREIGN KEY (quiz_id) REFERENCES quizzes(id) ON DELETE CASCADE,
    FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
);

-- Table des dépendances entre quiz (améliorée avec JSONB)
CREATE TABLE quiz_dependencies (
    quiz_id INTEGER NOT NULL,
    prerequisite_quiz_id INTEGER NOT NULL,
    required_score NUMERIC(5,2), -- NULL = juste participation, sinon score minimum requis
    conditions JSONB, -- Conditions additionnelles de réussite en format flexible
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by INTEGER,
    PRIMARY KEY (quiz_id, prerequisite_quiz_id),
    FOREIGN KEY (quiz_id) REFERENCES quizzes(id) ON DELETE CASCADE,
    FOREIGN KEY (prerequisite_quiz_id) REFERENCES quizzes(id) ON DELETE CASCADE,
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL,
    CHECK (quiz_id != prerequisite_quiz_id) -- Empêcher l'auto-référence
);

-- Table des types de questions
CREATE TABLE question_types (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Insertion des types de questions de base
INSERT INTO question_types (name, description) VALUES
('MULTIPLE_CHOICE', 'Question à choix multiple avec une ou plusieurs réponses correctes'),
('TRUE_FALSE', 'Question vrai ou faux'),
('SHORT_ANSWER', 'Question à réponse courte'),
('LONG_ANSWER', 'Question à réponse longue/rédaction'),
('MATCHING', 'Question d''association entre éléments'),
('ORDERING', 'Question d''ordonnancement d''éléments'),
('FILL_BLANKS', 'Texte à trous');

-- Table des questions
CREATE TABLE questions (
    id SERIAL PRIMARY KEY,
    uuid UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    content TEXT NOT NULL,
    explanation TEXT, -- Explication de la réponse correcte
    question_type_id INTEGER NOT NULL,
    default_time_limit INTEGER, -- Temps par défaut en secondes, NULL = pas de limite
    default_points NUMERIC(5,2) DEFAULT 1.0, -- Points par défaut
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP,
    created_by INTEGER NOT NULL,
    updated_by INTEGER,
    deleted_at TIMESTAMP,
    additional_settings JSONB, -- Paramètres spécifiques au type de question (pour plus de flexibilité)
    FOREIGN KEY (question_type_id) REFERENCES question_types(id) ON DELETE RESTRICT,
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE RESTRICT,
    FOREIGN KEY (updated_by) REFERENCES users(id) ON DELETE SET NULL
);

-- Table d'association quiz-questions
CREATE TABLE quiz_questions (
    quiz_id INTEGER NOT NULL,
    question_id INTEGER NOT NULL,
    order_num INTEGER NOT NULL, -- Ordre de la question dans le quiz
    is_required BOOLEAN DEFAULT TRUE,
    time_limit INTEGER, -- Temps spécifique pour cette question dans ce quiz, NULL = utiliser la valeur par défaut
    points NUMERIC(5,2), -- Points spécifiques pour cette question dans ce quiz, NULL = utiliser la valeur par défaut
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP,
    PRIMARY KEY (quiz_id, question_id),
    FOREIGN KEY (quiz_id) REFERENCES quizzes(id) ON DELETE CASCADE,
    FOREIGN KEY (question_id) REFERENCES questions(id) ON DELETE CASCADE
);

-- Table des choix pour les questions à choix multiples et d'association
CREATE TABLE answer_choices (
    id SERIAL PRIMARY KEY,
    uuid UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    question_id INTEGER NOT NULL,
    content TEXT NOT NULL,
    match_content TEXT, -- Pour les questions d'association, le contenu correspondant
    is_correct BOOLEAN DEFAULT FALSE, -- Pour les QCM et vrai/faux
    order_num INTEGER, -- Pour l'ordre dans les questions d'ordonnancement
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP,
    FOREIGN KEY (question_id) REFERENCES questions(id) ON DELETE CASCADE
);

-- Table des tentatives de quiz
CREATE TABLE quiz_attempts (
    id SERIAL PRIMARY KEY,
    uuid UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    user_id INTEGER NOT NULL,
    quiz_id INTEGER NOT NULL,
    start_time TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    end_time TIMESTAMP,
    total_time INTEGER, -- Temps total en secondes (calculé)
    score NUMERIC(5,2), -- Score final
    is_completed BOOLEAN DEFAULT FALSE,
    is_passed BOOLEAN, -- NULL = non évalué, TRUE/FALSE = résultat
    status VARCHAR(20) DEFAULT 'IN_PROGRESS' CHECK (status IN ('IN_PROGRESS', 'COMPLETED', 'FAILED')), -- Ajout du statut explicite
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (quiz_id) REFERENCES quizzes(id) ON DELETE CASCADE
);

-- Table des réponses des utilisateurs (améliorée avec JSONB)
CREATE TABLE attempt_responses (
    id SERIAL PRIMARY KEY,
    uuid UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    attempt_id INTEGER NOT NULL,
    question_id INTEGER NOT NULL,
    start_time TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    end_time TIMESTAMP,
    response_time INTEGER, -- Temps de réponse en secondes (calculé)
    text_response TEXT, -- Pour les réponses textuelles simples
    response_data JSONB, -- Pour stocker des réponses complexes (ordonnancement, association, etc.)
    is_correct BOOLEAN, -- NULL = non évalué, TRUE/FALSE = résultat
    points_earned NUMERIC(5,2), -- Points gagnés
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP,
    FOREIGN KEY (attempt_id) REFERENCES quiz_attempts(id) ON DELETE CASCADE,
    FOREIGN KEY (question_id) REFERENCES questions(id) ON DELETE CASCADE,
    CONSTRAINT unique_attempt_question UNIQUE (attempt_id, question_id)
);

-- Table des choix sélectionnés pour les QCM et autres types similaires
CREATE TABLE attempt_response_choices (
    response_id INTEGER NOT NULL,
    choice_id INTEGER NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (response_id, choice_id),
    FOREIGN KEY (response_id) REFERENCES attempt_responses(id) ON DELETE CASCADE,
    FOREIGN KEY (choice_id) REFERENCES answer_choices(id) ON DELETE CASCADE
);

-- Table des badges
CREATE TABLE badges (
    id SERIAL PRIMARY KEY,
    uuid UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    image_url VARCHAR(255),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by INTEGER,
    deleted_at TIMESTAMP,
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL
);

-- Table d'attribution des badges aux utilisateurs
CREATE TABLE user_badges (
    user_id INTEGER NOT NULL,
    badge_id INTEGER NOT NULL,
    awarded_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    awarded_by INTEGER,
    PRIMARY KEY (user_id, badge_id),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (badge_id) REFERENCES badges(id) ON DELETE CASCADE,
    FOREIGN KEY (awarded_by) REFERENCES users(id) ON DELETE SET NULL
);

-- Table de statistiques utilisateur (agrégées)
CREATE TABLE user_statistics (
    user_id INTEGER PRIMARY KEY,
    total_attempts INTEGER DEFAULT 0,
    completed_attempts INTEGER DEFAULT 0,
    passed_attempts INTEGER DEFAULT 0,
    total_score NUMERIC(10,2) DEFAULT 0,
    average_score NUMERIC(5,2) DEFAULT 0,
    total_time INTEGER DEFAULT 0, -- Temps total en secondes
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Table de journalisation d'audit
CREATE TABLE audit_logs (
    id SERIAL PRIMARY KEY,
    user_id INTEGER,
    action VARCHAR(50) NOT NULL,
    entity_type VARCHAR(50) NOT NULL,
    entity_id VARCHAR(100) NOT NULL,
    details JSONB,
    ip_address VARCHAR(45),
    user_agent TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
);

-- Fonction pour mettre à jour les timestamps des enregistrements modifiés
CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
   NEW.updated_at = CURRENT_TIMESTAMP;
   RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE TABLE quiz_dependency_conditions (
    id SERIAL PRIMARY KEY,
    quiz_dependency_id INTEGER NOT NULL,
    condition_type VARCHAR(50) NOT NULL, -- ex: 'MIN_SCORE', 'COMPLETION_TIME'
    condition_value VARCHAR(255) NOT NULL,
    FOREIGN KEY (quiz_dependency_id) REFERENCES quiz_dependencies(id) ON DELETE CASCADE
);

CREATE TABLE question_parameters (
    id SERIAL PRIMARY KEY,
    question_id INTEGER NOT NULL,
    parameter_name VARCHAR(50) NOT NULL,
    parameter_value TEXT NOT NULL,
    FOREIGN KEY (question_id) REFERENCES questions(id) ON DELETE CASCADE,
    UNIQUE (question_id, parameter_name)
);

CREATE TABLE ordering_responses (
    id SERIAL PRIMARY KEY,
    attempt_response_id INTEGER NOT NULL,
    item_id INTEGER NOT NULL,
    position INTEGER NOT NULL,
    FOREIGN KEY (attempt_response_id) REFERENCES attempt_responses(id) ON DELETE CASCADE
);

CREATE TABLE matching_responses (
    id SERIAL PRIMARY KEY,
    attempt_response_id INTEGER NOT NULL,
    source_id INTEGER NOT NULL,
    target_id INTEGER NOT NULL,
    FOREIGN KEY (attempt_response_id) REFERENCES attempt_responses(id) ON DELETE CASCADE
);

-- Triggers pour mettre à jour les timestamps automatiquement
CREATE TRIGGER update_users_timestamp BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_timestamp();
CREATE TRIGGER update_categories_timestamp BEFORE UPDATE ON categories FOR EACH ROW EXECUTE FUNCTION update_timestamp();
CREATE TRIGGER update_quizzes_timestamp BEFORE UPDATE ON quizzes FOR EACH ROW EXECUTE FUNCTION update_timestamp();
CREATE TRIGGER update_questions_timestamp BEFORE UPDATE ON questions FOR EACH ROW EXECUTE FUNCTION update_timestamp();
CREATE TRIGGER update_quiz_questions_timestamp BEFORE UPDATE ON quiz_questions FOR EACH ROW EXECUTE FUNCTION update_timestamp();
CREATE TRIGGER update_answer_choices_timestamp BEFORE UPDATE ON answer_choices FOR EACH ROW EXECUTE FUNCTION update_timestamp();
CREATE TRIGGER update_quiz_attempts_timestamp BEFORE UPDATE ON quiz_attempts FOR EACH ROW EXECUTE FUNCTION update_timestamp();
CREATE TRIGGER update_attempt_responses_timestamp BEFORE UPDATE ON attempt_responses FOR EACH ROW EXECUTE FUNCTION update_timestamp();
CREATE TRIGGER update_user_statistics_timestamp BEFORE UPDATE ON user_statistics FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- Indexes pour améliorer les performances
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_uuid ON users(uuid);
CREATE INDEX idx_quizzes_uuid ON quizzes(uuid);
CREATE INDEX idx_quizzes_status ON quizzes(status) WHERE deleted_at IS NULL;
CREATE INDEX idx_quizzes_category ON quizzes(category_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_quizzes_created_by ON quizzes(created_by);
CREATE INDEX idx_questions_uuid ON questions(uuid);
CREATE INDEX idx_questions_type ON questions(question_type_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_quiz_questions_order ON quiz_questions(quiz_id, order_num);
CREATE INDEX idx_quiz_attempts_uuid ON quiz_attempts(uuid);
CREATE INDEX idx_quiz_attempts_user ON quiz_attempts(user_id);
CREATE INDEX idx_quiz_attempts_quiz ON quiz_attempts(quiz_id);
CREATE INDEX idx_quiz_attempts_completed ON quiz_attempts(is_completed);
CREATE INDEX idx_quiz_attempts_status ON quiz_attempts(status);
CREATE INDEX idx_attempt_responses_uuid ON attempt_responses(uuid);
CREATE INDEX idx_attempt_responses_attempt ON attempt_responses(attempt_id);
CREATE INDEX idx_audit_logs_user ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_entity ON audit_logs(entity_type, entity_id);
CREATE INDEX idx_audit_logs_action ON audit_logs(action);