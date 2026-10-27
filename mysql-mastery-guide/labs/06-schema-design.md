# Lab 06 — Schema design and integrity

Design a lightweight course-enrollment system. Do not begin with SQL. First document entity grain, primary key, alternate unique key, nullable fields, and deletion rules.

Required entities: students, instructors, courses, course offerings (a course delivered in a term by an instructor), and enrollments. A student can enroll in an offering once; an offering has many students; a course code is unique; capacity must be positive; enrollment time is stored.

1. Draw an ER diagram.
2. Write `CREATE TABLE` statements using InnoDB, explicit keys, meaningful constraint names, `NOT NULL`, `UNIQUE`, `CHECK`, and foreign keys.
3. Decide the `ON DELETE` behaviour for every relationship and defend it. Would deleting an instructor delete history?
4. Insert valid seed rows.
5. Demonstrate and explain failures for a duplicate enrollment, invalid capacity, and enrollment referencing a missing student.
6. Add an index to support “show all enrollments for a student, newest first”; explain its column order.
7. Write one report: course offering, instructor, enrolled count, capacity, seats remaining. Ensure offerings with zero enrollments still appear.

**Stretch:** Add waitlisting without allowing a student to be both enrolled and waitlisted for the same offering.

