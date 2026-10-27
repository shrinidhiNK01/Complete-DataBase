-- PostgreSQL Master Handbook companion schema
-- Purpose: disposable practice data. Read before running.
-- This drops and recreates ONLY the academy schema in the current database.

BEGIN;

DROP SCHEMA IF EXISTS academy CASCADE;
CREATE SCHEMA academy;

CREATE TABLE academy.student (
  student_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  full_name text NOT NULL CHECK (btrim(full_name) <> ''),
  email text NOT NULL UNIQUE CHECK (email = lower(btrim(email))),
  birth_date date,
  active boolean NOT NULL DEFAULT true,
  joined_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE academy.instructor (
  instructor_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  full_name text NOT NULL CHECK (btrim(full_name) <> ''),
  email text NOT NULL UNIQUE CHECK (email = lower(btrim(email))),
  hired_on date NOT NULL,
  active boolean NOT NULL DEFAULT true
);

CREATE TABLE academy.course (
  course_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  course_code text NOT NULL UNIQUE CHECK (course_code = upper(btrim(course_code))),
  title text NOT NULL CHECK (btrim(title) <> ''),
  description text,
  list_price numeric(10,2) NOT NULL CHECK (list_price >= 0),
  active boolean NOT NULL DEFAULT true,
  published boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE academy.enrollment (
  student_id bigint NOT NULL REFERENCES academy.student(student_id),
  course_id bigint NOT NULL REFERENCES academy.course(course_id),
  enrolled_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz,
  status text NOT NULL DEFAULT 'enrolled'
    CHECK (status IN ('enrolled', 'cancelled', 'completed')),
  final_score numeric(5,2) CHECK (final_score BETWEEN 0 AND 100),
  PRIMARY KEY (student_id, course_id),
  CHECK (
    (status = 'completed' AND completed_at IS NOT NULL)
    OR (status <> 'completed')
  )
);

CREATE TABLE academy.assignment (
  assignment_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  course_id bigint NOT NULL REFERENCES academy.course(course_id),
  title text NOT NULL CHECK (btrim(title) <> ''),
  max_score numeric(6,2) NOT NULL CHECK (max_score > 0),
  due_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (course_id, title)
);

CREATE TABLE academy.submission (
  submission_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  assignment_id bigint NOT NULL REFERENCES academy.assignment(assignment_id),
  student_id bigint NOT NULL REFERENCES academy.student(student_id),
  submitted_at timestamptz,
  score numeric(6,2),
  feedback text,
  UNIQUE (assignment_id, student_id)
);

INSERT INTO academy.student (full_name, email, birth_date, active, joined_at) VALUES
  ('Anika Rao', 'anika.rao@example.com', DATE '2001-03-14', true,  TIMESTAMPTZ '2026-01-10 09:00+05:30'),
  ('Ben Thomas', 'ben.thomas@example.com', DATE '1999-10-02', true, TIMESTAMPTZ '2026-02-05 12:00+05:30'),
  ('Chitra Nair', 'chitra.nair@example.com', NULL, true,           TIMESTAMPTZ '2026-03-18 18:30+05:30'),
  ('Dev Kumar', 'dev.kumar@example.com', DATE '2002-07-21', false, TIMESTAMPTZ '2025-10-03 10:15+05:30'),
  ('Elena Das', 'elena.das@example.com', DATE '1998-12-30', true,  TIMESTAMPTZ '2026-04-26 14:45+05:30');

INSERT INTO academy.instructor (full_name, email, hired_on, active) VALUES
  ('Asha Shah', 'asha.shah@example.com', DATE '2022-06-01', true),
  ('Naveen Iyer', 'naveen.iyer@example.com', DATE '2024-01-15', true),
  ('Ritu Bose', 'ritu.bose@example.com', DATE '2021-09-10', false);

INSERT INTO academy.course (course_code, title, description, list_price, active, published, created_at) VALUES
  ('SQL-101', 'SQL foundations', 'Relational basics, CRUD, and core querying.', 2999.00, true, true, TIMESTAMPTZ '2025-12-01 08:00+05:30'),
  ('PG-201', 'PostgreSQL query patterns', 'Joins, aggregation, window functions, and CTEs.', 3999.00, true, true, TIMESTAMPTZ '2026-01-05 08:00+05:30'),
  ('PG-301', 'PostgreSQL performance', 'Indexes, EXPLAIN, transactions, and operations.', 4999.00, true, false, TIMESTAMPTZ '2026-03-01 08:00+05:30'),
  ('ARCH-401', 'Data architecture', 'Historical course kept for reporting practice.', 5999.00, false, true, TIMESTAMPTZ '2024-05-01 08:00+05:30');

INSERT INTO academy.enrollment
  (student_id, course_id, enrolled_at, completed_at, status, final_score)
VALUES
  (1, 1, TIMESTAMPTZ '2026-01-11 09:00+05:30', TIMESTAMPTZ '2026-02-01 10:00+05:30', 'completed', 94.00),
  (1, 2, TIMESTAMPTZ '2026-02-12 09:00+05:30', NULL, 'enrolled', NULL),
  (2, 1, TIMESTAMPTZ '2026-02-06 09:00+05:30', TIMESTAMPTZ '2026-03-01 11:00+05:30', 'completed', 76.50),
  (2, 2, TIMESTAMPTZ '2026-03-10 09:00+05:30', TIMESTAMPTZ '2026-04-10 11:00+05:30', 'completed', 88.00),
  (3, 1, TIMESTAMPTZ '2026-03-19 09:00+05:30', NULL, 'cancelled', NULL),
  (3, 3, TIMESTAMPTZ '2026-04-02 09:00+05:30', NULL, 'enrolled', NULL),
  (4, 4, TIMESTAMPTZ '2025-10-05 09:00+05:30', TIMESTAMPTZ '2025-12-01 11:00+05:30', 'completed', 67.00);

INSERT INTO academy.assignment (course_id, title, max_score, due_at) VALUES
  (1, 'SELECT and WHERE', 100, TIMESTAMPTZ '2026-02-15 23:59+05:30'),
  (1, 'Aggregate report', 100, TIMESTAMPTZ '2026-02-28 23:59+05:30'),
  (2, 'Window functions', 100, TIMESTAMPTZ '2026-04-15 23:59+05:30');

INSERT INTO academy.submission (assignment_id, student_id, submitted_at, score, feedback) VALUES
  (1, 1, TIMESTAMPTZ '2026-02-12 18:00+05:30', 96, 'Clear and correct.'),
  (1, 2, TIMESTAMPTZ '2026-02-14 11:00+05:30', 79, 'Review NULL handling.'),
  (2, 1, TIMESTAMPTZ '2026-02-26 17:00+05:30', 91, 'Good grouping logic.');

CREATE INDEX enrollment_course_enrolled_at_idx
ON academy.enrollment (course_id, enrolled_at DESC);

CREATE INDEX enrollment_student_enrolled_at_idx
ON academy.enrollment (student_id, enrolled_at DESC);

COMMIT;

-- Start here after loading:
-- SELECT * FROM academy.student;
-- SELECT c.course_code, count(e.student_id)
-- FROM academy.course c LEFT JOIN academy.enrollment e USING (course_id)
-- GROUP BY c.course_id, c.course_code ORDER BY c.course_code;
