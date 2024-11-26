-- Create Database (if it doesn't exist)
CREATE DATABASE IF NOT EXISTS StudentPerformance1;
USE StudentPerformance1student_data1;

SELECT * FROM student_data;

-- Drop existing tables
DROP TABLE IF EXISTS student_data;
DROP TABLE IF EXISTS dim_student;
DROP TABLE IF EXISTS dim_tutoring;
DROP TABLE IF EXISTS dim_teacher;
DROP TABLE IF EXISTS dim_school;
DROP TABLE IF EXISTS dim_resources;
DROP TABLE IF EXISTS dim_motivation;
DROP TABLE IF EXISTS fact_student_performance;


--  Create the staging table
CREATE TABLE IF NOT EXISTS student_data (
    Student_ID INT AUTO_INCREMENT PRIMARY KEY,
    Hours_Studied DECIMAL(5, 2),
    Attendance DECIMAL(5, 2),
    Parental_Involvement VARCHAR(50),
    Access_to_Resources VARCHAR(50),
    Extracurricular_Activities VARCHAR(50),
    Sleep_Hours DECIMAL(5, 2),
    Previous_Scores DECIMAL(5, 2),
    Motivation_Level VARCHAR(50),
    Internet_Access VARCHAR(50),
    Family_Income VARCHAR(50),
    Teacher_Quality VARCHAR(50),
    School_Type VARCHAR(50),
    Peer_Influence VARCHAR(50),
    Physical_Activity_HW DECIMAL(5, 2),
    Learning_Disabilities VARCHAR(50),
    Parental_Education_Level VARCHAR(50),
    Distance_from_Home VARCHAR(50),
    Gender VARCHAR(10),
    Exam_Score DECIMAL(5, 2)
);

-- Import your data here

--  Clean and Standardize Data
-- Replace NULL values in 'Attendance' with 0
UPDATE student_data
SET Attendance = 0
WHERE Attendance IS NULL;

-- Disable safe mode for the current session
SET SQL_SAFE_UPDATES = 0;

-- Standardize 'Gender' to be all lowercase
UPDATE student_data
SET Gender = LOWER(Gender);

-- Remove outliers in 'Exam_Score' (values outside 3 standard deviations)
DELETE FROM student_data 
WHERE Exam_Score > (
    SELECT upper_bound FROM (
        SELECT AVG(Exam_Score) + 3 * STDDEV(Exam_Score) AS upper_bound FROM student_data
    ) AS bounds
)
OR Exam_Score < (
    SELECT lower_bound FROM (
        SELECT AVG(Exam_Score) - 3 * STDDEV(Exam_Score) AS lower_bound FROM student_data
    ) AS bounds
);

-- Fill null values for numeric columns with the average
-- For Hours_Studied
UPDATE student_data
SET Hours_Studied = (SELECT avg_hours FROM (SELECT AVG(Hours_Studied) AS avg_hours FROM student_data) AS temp)
WHERE Hours_Studied IS NULL;

-- For Attendance
UPDATE student_data
SET Attendance = (SELECT avg_attendance FROM (SELECT AVG(Attendance) AS avg_attendance FROM student_data) AS temp)
WHERE Attendance IS NULL;

UPDATE student_data
SET Sleep_Hours = (SELECT avg_sleep_hours FROM (SELECT AVG(Sleep_Hours) AS avg_sleep_hours FROM student_data) AS temp)
WHERE Sleep_Hours IS NULL;

UPDATE student_data
SET Previous_Scores = (SELECT avg_prev_scores FROM (SELECT AVG(Previous_Scores) AS avg_prev_scores FROM student_data) AS temp)
WHERE Previous_Scores IS NULL;

UPDATE student_data
SET Tutoring_Sessions = (SELECT avg_tutoring FROM (SELECT AVG(Tutoring_Sessions) AS avg_tutoring FROM student_data) AS temp)
WHERE Tutoring_Sessions IS NULL;

-- Fix typo: replace 'Femlae' with 'Female' in 'Gender'
UPDATE student_data
SET Gender = 'Female'
WHERE Gender = 'Femlae';

-- Fix typo: replace 'Mlae' with 'Male' in 'Gender'
UPDATE student_data
SET Gender = 'Male'
WHERE Gender = 'Mlae';

-- Standardize Gender
UPDATE student_data
SET Gender = TRIM(LOWER(Gender));

-- Standardize School_Type
UPDATE student_data
SET School_Type = TRIM(LOWER(School_Type));

-- Standardize Parental_Involvement
UPDATE student_data
SET Parental_Involvement = TRIM(LOWER(Parental_Involvement));

-- Standardize Access_to_Resources
UPDATE student_data
SET Access_to_Resources = TRIM(LOWER(Access_to_Resources));

-- Standardize Extracurricular_Activities
UPDATE student_data
SET Extracurricular_Activities = TRIM(LOWER(Extracurricular_Activities));

-- Standardize Motivation_Level
UPDATE student_data
SET Motivation_Level = TRIM(LOWER(Motivation_Level));

-- Standardize Internet_Access
UPDATE student_data
SET Internet_Access = TRIM(LOWER(Internet_Access));

-- Standardize Tutoring_Sessions
UPDATE student_data
SET Tutoring_Sessions = TRIM(LOWER(Tutoring_Sessions));

-- Standardize Teacher_Quality
UPDATE student_data
SET Teacher_Quality = TRIM(LOWER(Teacher_Quality));

-- Standardize Peer_Influence
UPDATE student_data
SET Peer_Influence = TRIM(LOWER(Peer_Influence));

-- Create Dimension Tables
CREATE TABLE IF NOT EXISTS dim_student (
    student_dim_id INT AUTO_INCREMENT PRIMARY KEY,
    gender VARCHAR(10),
    family_income INT,
    peer_influence VARCHAR(50),
    learning_disabilities VARCHAR(50),
    distance_from_home INT
);

CREATE TABLE IF NOT EXISTS dim_tutoring (
    tutoring_id INT AUTO_INCREMENT PRIMARY KEY,
    tutoring_sessions INT
);

CREATE TABLE IF NOT EXISTS dim_teacher (
    teacher_id INT AUTO_INCREMENT PRIMARY KEY,
    teacher_quality VARCHAR(50)
);

CREATE TABLE IF NOT EXISTS dim_school (
    school_id INT AUTO_INCREMENT PRIMARY KEY,
    school_type VARCHAR(50)
);

CREATE TABLE IF NOT EXISTS dim_resources (
    resource_id INT AUTO_INCREMENT PRIMARY KEY,
    access_to_resources VARCHAR(50),
    parental_involvement VARCHAR(50)
);

CREATE TABLE IF NOT EXISTS dim_motivation (
    motivation_id INT AUTO_INCREMENT PRIMARY KEY,
    motivation_level VARCHAR(50)
);

-- Populate Dimension Tables
-- Calculate the mean of Family_Income for non-null values
SET @mean_family_income = (
    SELECT AVG(CASE 
        WHEN LOWER(TRIM(Family_Income)) = 'low' THEN 20000
        WHEN LOWER(TRIM(Family_Income)) = 'moderate' THEN 50000
        WHEN LOWER(TRIM(Family_Income)) = 'high' THEN 100000
        ELSE NULL 
    END) 
    FROM student_data 
    WHERE Family_Income IS NOT NULL
);

-- Calculate the mean of Distance_from_Home for non-null values
SET @mean_distance_from_home = (
    SELECT AVG(CASE 
        WHEN LOWER(TRIM(Distance_from_Home)) = 'near' THEN 5
        WHEN LOWER(TRIM(Distance_from_Home)) = 'moderate' THEN 10
        WHEN LOWER(TRIM(Distance_from_Home)) = 'far' THEN 20
        ELSE NULL 
    END) 
    FROM student_data 
    WHERE Distance_from_Home IS NOT NULL
);

--  Insert into dim_student
INSERT INTO dim_student (gender, family_income, peer_influence, learning_disabilities, distance_from_home)
SELECT DISTINCT 
    Gender, 
    CASE
        WHEN LOWER(TRIM(Family_Income)) = 'low' THEN 20000
        WHEN LOWER(TRIM(Family_Income)) = 'moderate' THEN 50000
        WHEN LOWER(TRIM(Family_Income)) = 'high' THEN 100000
        ELSE @mean_family_income
    END AS Family_Income,
    Peer_Influence,
    Learning_Disabilities,
    CASE
        WHEN LOWER(TRIM(Distance_from_Home)) = 'near' THEN 5
        WHEN LOWER(TRIM(Distance_from_Home)) = 'moderate' THEN 10
        WHEN LOWER(TRIM(Distance_from_Home)) = 'far' THEN 20
        ELSE @mean_distance_from_home
    END AS Distance_from_Home
FROM student_data
GROUP BY Gender, Family_Income, Peer_Influence, Learning_Disabilities, Distance_from_Home;

-- Insert into dim_tutoring
INSERT INTO dim_tutoring (tutoring_sessions)
SELECT DISTINCT Tutoring_Sessions
FROM student_data
GROUP BY Tutoring_Sessions;

-- Insert into dim_teacher
INSERT INTO dim_teacher (teacher_quality)
SELECT DISTINCT Teacher_Quality
FROM student_data
GROUP BY Teacher_Quality;

-- Insert into dim_school
INSERT INTO dim_school (school_type)
SELECT DISTINCT School_Type
FROM student_data
GROUP BY School_Type;

-- Insert into dim_resources
INSERT INTO dim_resources (access_to_resources, parental_involvement)
SELECT DISTINCT Access_to_Resources, Parental_Involvement
FROM student_data
GROUP BY Access_to_Resources, Parental_Involvement;

-- Insert into dim_motivation
INSERT INTO dim_motivation (motivation_level)
SELECT DISTINCT Motivation_Level
FROM student_data
GROUP BY Motivation_Level;


-- Create the fact_student_performance table
CREATE TABLE fact_student_performance (
    student_id INT,
    hours_studied DECIMAL(5, 2),
    attendance DECIMAL(5, 2),
    sleep_hours DECIMAL(5, 2),
    previous_scores DECIMAL(5, 2),
    exam_score DECIMAL(5, 2),
    tutoring_id INT,
    teacher_id INT,
    school_id INT,
    resource_id INT,
    motivation_id INT,
    gender VARCHAR(10),
    family_income INT,
    peer_influence VARCHAR(10),
    learning_disabilities VARCHAR(10),
    distance_from_home VARCHAR(10)
);

-- Populate the Fact Table
INSERT INTO fact_student_performance (
    student_id,
    hours_studied,
    attendance,
    sleep_hours,
    previous_scores,
    exam_score,
    tutoring_id,
    teacher_id,
    school_id,
    resource_id,
    motivation_id,
    gender,
    family_income,
    peer_influence,
    learning_disabilities,
    distance_from_home
)
SELECT 
    staging.Student_ID,
    staging.Hours_Studied,
    staging.Attendance,
    staging.Sleep_Hours,
    staging.Previous_Scores,
    staging.Exam_Score,
    (SELECT dim_tutoring.tutoring_id 
     FROM dim_tutoring 
     WHERE dim_tutoring.tutoring_sessions = staging.Tutoring_Sessions 
     LIMIT 1) AS tutoring_id,
    (SELECT dim_teacher.teacher_id 
     FROM dim_teacher 
     WHERE dim_teacher.teacher_quality = staging.Teacher_Quality 
     LIMIT 1) AS teacher_id,
    (SELECT dim_school.school_id 
     FROM dim_school 
     WHERE dim_school.school_type = staging.School_Type 
     LIMIT 1) AS school_id,
    (SELECT dim_resources.resource_id 
     FROM dim_resources 
     WHERE dim_resources.access_to_resources = staging.Access_to_Resources 
     AND dim_resources.parental_involvement = staging.Parental_Involvement 
     LIMIT 1) AS resource_id,
    (SELECT dim_motivation.motivation_id 
     FROM dim_motivation 
     WHERE dim_motivation.motivation_level = staging.Motivation_Level 
     LIMIT 1) AS motivation_id,
    COALESCE(TRIM(staging.Gender), '') AS gender,
    CASE 
        WHEN LOWER(TRIM(staging.Family_Income)) = 'low' THEN 20000
        WHEN LOWER(TRIM(staging.Family_Income)) = 'moderate' THEN 50000
        WHEN LOWER(TRIM(staging.Family_Income)) = 'high' THEN 100000
        ELSE NULL  -- or 0 if needed, but using NULL will allow for more meaningful aggregation
    END AS family_income,
    COALESCE(TRIM(staging.Peer_Influence), '') AS peer_influence,
    COALESCE(TRIM(staging.Learning_Disabilities), '') AS learning_disabilities,
    CASE 
        WHEN LOWER(TRIM(staging.Distance_from_Home)) = 'near' THEN 5
        WHEN LOWER(TRIM(staging.Distance_from_Home)) = 'moderate' THEN 10
        WHEN LOWER(TRIM(staging.Distance_from_Home)) = 'far' THEN 20
        ELSE NULL  -- or 0, depending on how you want to handle missing values
    END AS distance_from_home
FROM 
    student_data AS staging 
WHERE 
    staging.Student_ID IS NOT NULL;



-- Remove duplicate rows from dim_student
DELETE FROM dim_student 
WHERE student_dim_id NOT IN (
    SELECT MIN(student_dim_id)
    FROM dim_student
    GROUP BY gender, family_income, peer_influence, learning_disabilities, distance_from_home
);

-- Remove duplicate rows from dim_motivation
DELETE FROM dim_motivation
WHERE motivation_id NOT IN (
    SELECT MIN(motivation_id)
    FROM (SELECT motivation_id, motivation_level FROM dim_motivation) AS subquery
    GROUP BY motivation_level
);

-- The script is ready to execute. 

-- After you run this,  you should be able to query your star schema. 
-- For example:

-- Average exam score for students with high family income
SELECT AVG(exam_score) 
FROM fact_student_performance 
WHERE family_income = 100000;

-- Count of students by gender and school type
SELECT 
    gender, 
    school_type, 
    COUNT(*) 
FROM fact_student_performance
JOIN dim_school ON fact_student_performance.school_id = dim_school.school_id
GROUP BY gender, school_type;

-- Validate 'dim_student' table
SELECT 
    gender, 
    family_income, 
    peer_influence, 
    learning_disabilities, 
    distance_from_home, 
    COUNT(*) AS count 
FROM dim_student 
GROUP BY 
    gender, 
    family_income, 
    peer_influence, 
    learning_disabilities, 
    distance_from_home
HAVING COUNT(*) > 1;

-- Validate 'dim_tutoring' table
SELECT 
    tutoring_sessions, 
    COUNT(*) AS count 
FROM dim_tutoring 
GROUP BY tutoring_sessions
HAVING COUNT(*) > 1;

-- Validate 'dim_teacher' table
SELECT 
    teacher_quality, 
    COUNT(*) AS count 
FROM dim_teacher 
GROUP BY teacher_quality
HAVING COUNT(*) > 1;

-- Validate 'dim_school' table
SELECT 
    school_type, 
    COUNT(*) AS count 
FROM dim_school 
GROUP BY school_type
HAVING COUNT(*) > 1;

-- Validate 'dim_resources' table
SELECT 
    access_to_resources, 
    parental_involvement, 
    COUNT(*) AS count 
FROM dim_resources 
GROUP BY access_to_resources, parental_involvement
HAVING COUNT(*) > 1;

-- Validate 'dim_motivation' table
SELECT 
    motivation_level, 
    COUNT(*) AS count 
FROM dim_motivation 
GROUP BY motivation_level
HAVING COUNT(*) > 1;


-- Validate 'fact_student_performance' table (check for missing foreign keys)
SELECT 
    fact_student_performance.student_id
FROM fact_student_performance 
LEFT JOIN dim_student ON fact_student_performance.student_dim_id = dim_student.student_dim_id
WHERE dim_student.student_dim_id IS NULL;

SELECT 
    fact_student_performance.student_id
FROM fact_student_performance 
LEFT JOIN dim_tutoring ON fact_student_performance.tutoring_id = dim_tutoring.tutoring_id
WHERE dim_tutoring.tutoring_id IS NULL;

SELECT 
    fact_student_performance.student_id
FROM fact_student_performance 
LEFT JOIN dim_teacher ON fact_student_performance.teacher_id = dim_teacher.teacher_id
WHERE dim_teacher.teacher_id IS NULL;

SELECT 
    fact_student_performance.student_id
FROM fact_student_performance 
LEFT JOIN dim_school ON fact_student_performance.school_id = dim_school.school_id
WHERE dim_school.school_id IS NULL;

SELECT 
    fact_student_performance.student_id
FROM fact_student_performance 
LEFT JOIN dim_resources ON fact_student_performance.resource_id = dim_resources.resource_id
WHERE dim_resources.resource_id IS NULL;

SELECT 
    fact_student_performance.student_id
FROM fact_student_performance 
LEFT JOIN dim_motivation ON fact_student_performance.motivation_id = dim_motivation.motivation_id
WHERE dim_motivation.motivation_id IS NULL;

-- Validate data types and values in fact table
SELECT 
    student_id, 
    hours_studied, 
    attendance, 
    sleep_hours, 
    previous_scores, 
    exam_score, 
    tutoring_id, 
    teacher_id, 
    school_id, 
    resource_id, 
    motivation_id, 
    gender, 
    family_income, 
    peer_influence, 
    learning_disabilities, 
    distance_from_home 
FROM fact_student_performance 
WHERE 
    hours_studied < 0 OR 
    attendance < 0 OR 
    sleep_hours < 0 OR 
    previous_scores < 0 OR 
    exam_score < 0 OR 
    tutoring_id < 0 OR 
    teacher_id < 0 OR 
    school_id < 0 OR 
    resource_id < 0 OR 
    motivation_id < 0 OR 
    gender NOT IN ('male', 'female') OR 
    family_income NOT IN (20000, 50000, 100000) OR 
    peer_influence NOT IN ('positive', 'neutral', 'negative', 'some') OR 
    learning_disabilities NOT IN ('yes', 'no', 'none') OR 
    distance_from_home NOT IN (5, 10, 20);

-- Validate the presence of data in each table
SELECT 
    'dim_student' AS table_name, 
    COUNT(*) AS row_count 
FROM dim_student
UNION ALL
SELECT 
    'dim_tutoring' AS table_name, 
    COUNT(*) AS row_count 
FROM dim_tutoring
UNION ALL
SELECT 
    'dim_teacher' AS table_name, 
    COUNT(*) AS row_count 
FROM dim_teacher
UNION ALL
SELECT 
    'dim_school' AS table_name, 
    COUNT(*) AS row_count 
FROM dim_school
UNION ALL
SELECT 
    'dim_resources' AS table_name, 
    COUNT(*) AS row_count 
FROM dim_resources
UNION ALL
SELECT 
    'dim_motivation' AS table_name, 
    COUNT(*) AS row_count 
FROM dim_motivation
UNION ALL
SELECT 
    'fact_student_performance' AS table_name, 
    COUNT(*) AS row_count 
FROM fact_student_performance;

-- Validate 'dim_student' table
SELECT 
    gender, 
    family_income, 
    peer_influence, 
    learning_disabilities, 
    distance_from_home, 
    COUNT(*) AS count 
FROM dim_student 
GROUP BY 
    gender, 
    family_income, 
    peer_influence, 
    learning_disabilities, 
    distance_from_home
HAVING COUNT(*) > 1;

-- Validate 'dim_tutoring' table
SELECT 
    tutoring_sessions, 
    COUNT(*) AS count 
FROM dim_tutoring 
GROUP BY tutoring_sessions
HAVING COUNT(*) > 1;

-- Validate 'dim_teacher' table
SELECT 
    teacher_quality, 
    COUNT(*) AS count 
FROM dim_teacher 
GROUP BY teacher_quality
HAVING COUNT(*) > 1;

-- Validate 'dim_school' table
SELECT 
    school_type, 
    COUNT(*) AS count 
FROM dim_school 
GROUP BY school_type
HAVING COUNT(*) > 1;

-- Validate 'dim_resources' table
SELECT 
    access_to_resources, 
    parental_involvement, 
    COUNT(*) AS count 
FROM dim_resources 
GROUP BY access_to_resources, parental_involvement
HAVING COUNT(*) > 1;

-- Validate 'dim_motivation' table
SELECT 
    motivation_level, 
    COUNT(*) AS count 
FROM dim_motivation 
GROUP BY motivation_level
HAVING COUNT(*) > 1;

-- Validate 'fact_student_performance' table (check for missing foreign keys)
-- student_dim_id
SELECT 
    fact_student_performance.student_id
FROM fact_student_performance 
LEFT JOIN dim_student ON fact_student_performance.student_dim_id = dim_student.student_dim_id
WHERE dim_student.student_dim_id IS NULL;
-- tutoring_id
SELECT 
    fact_student_performance.student_id
FROM fact_student_performance 
LEFT JOIN dim_tutoring ON fact_student_performance.tutoring_id = dim_tutoring.tutoring_id
WHERE dim_tutoring.tutoring_id IS NULL;
-- teacher_id
SELECT 
    fact_student_performance.student_id
FROM fact_student_performance 
LEFT JOIN dim_teacher ON fact_student_performance.teacher_id = dim_teacher.teacher_id
WHERE dim_teacher.teacher_id IS NULL;
-- school_id
SELECT 
    fact_student_performance.student_id
FROM fact_student_performance 
LEFT JOIN dim_school ON fact_student_performance.school_id = dim_school.school_id
WHERE dim_school.school_id IS NULL;
-- resource_id
SELECT 
    fact_student_performance.student_id
FROM fact_student_performance 
LEFT JOIN dim_resources ON fact_student_performance.resource_id = dim_resources.resource_id
WHERE dim_resources.resource_id IS NULL;
-- motivation_id
SELECT 
    fact_student_performance.student_id
FROM fact_student_performance 
LEFT JOIN dim_motivation ON fact_student_performance.motivation_id = dim_motivation.motivation_id
WHERE dim_motivation.motivation_id IS NULL;

-- Validate data types and values in fact table
SELECT 
    student_id, 
    hours_studied, 
    attendance, 
    sleep_hours, 
    previous_scores, 
    exam_score, 
    tutoring_id, 
    teacher_id, 
    school_id, 
    resource_id, 
    motivation_id, 
    gender, 
    family_income, 
    peer_influence, 
    learning_disabilities, 
    distance_from_home 
FROM fact_student_performance 
WHERE 
    hours_studied < 0 OR  -- Check if hours studied is negative
    attendance < 0 OR  -- Check if attendance is negative
    sleep_hours < 0 OR  -- Check if sleep hours is negative
    previous_scores < 0 OR  -- Check if previous scores is negative
    exam_score < 0 OR  -- Check if exam score is negative
    tutoring_id < 0 OR  -- Check if tutoring ID is negative
    teacher_id < 0 OR  -- Check if teacher ID is negative
    school_id < 0 OR  -- Check if school ID is negative
    resource_id < 0 OR  -- Check if resource ID is negative
    motivation_id < 0 OR  -- Check if motivation ID is negative
    gender NOT IN ('male', 'female') OR  -- Check if gender is valid
    family_income NOT IN (20000, 50000, 100000) OR  -- Check if family income is valid
    peer_influence NOT IN ('positive', 'neutral', 'negative', 'some') OR  -- Check if peer influence is valid
    learning_disabilities NOT IN ('yes', 'no', 'none') OR  -- Check if learning disabilities is valid
    distance_from_home NOT IN (5, 10, 20);  -- Check if distance from home is valid

-- Validate the presence of data in each table
SELECT 
    'dim_student' AS table_name, 
    COUNT(*) AS row_count 
FROM dim_student
UNION ALL
SELECT 
    'dim_tutoring' AS table_name, 
    COUNT(*) AS row_count 
FROM dim_tutoring
UNION ALL
SELECT 
    'dim_teacher' AS table_name, 
    COUNT(*) AS row_count 
FROM dim_teacher
UNION ALL
SELECT 
    'dim_school' AS table_name, 
    COUNT(*) AS row_count 
FROM dim_school
UNION ALL
SELECT 
    'dim_resources' AS table_name, 
    COUNT(*) AS row_count 
FROM dim_resources
UNION ALL
SELECT 
    'dim_motivation' AS table_name, 
    COUNT(*) AS row_count 
FROM dim_motivation
UNION ALL
SELECT 
    'fact_student_performance' AS table_name, 
    COUNT(*) AS row_count 
FROM fact_student_performance;


CREATE TABLE fact_student_performance (
    student_id INT,
    hours_studied DECIMAL(5, 2),
    attendance DECIMAL(5, 2),
    sleep_hours DECIMAL(5, 2),
    previous_scores DECIMAL(5, 2),
    exam_score DECIMAL(5, 2),
    tutoring_id INT,
    teacher_id INT,
    school_id INT,
    resource_id INT,
    motivation_id INT,
    student_dim_id INT,  -- Add this column
    gender VARCHAR(10),
    family_income INT,
    peer_influence VARCHAR(10),
    learning_disabilities VARCHAR(10),
    distance_from_home VARCHAR(10)
);
INSERT INTO fact_student_performance (
    student_id,
    hours_studied,
    attendance,
    sleep_hours,
    previous_scores,
    exam_score,
    tutoring_id,
    teacher_id,
    school_id,
    resource_id,
    motivation_id,
    student_dim_id,
    gender,
    family_income,
    peer_influence,
    learning_disabilities,
    distance_from_home
)
SELECT 
    staging.Student_ID,
    staging.Hours_Studied,
    staging.Attendance,
    staging.Sleep_Hours,
    staging.Previous_Scores,
    staging.Exam_Score,
    (SELECT dim_tutoring.tutoring_id 
     FROM dim_tutoring 
     WHERE dim_tutoring.tutoring_sessions = staging.Tutoring_Sessions 
     LIMIT 1) AS tutoring_id,
    (SELECT dim_teacher.teacher_id 
     FROM dim_teacher 
     WHERE dim_teacher.teacher_quality = staging.Teacher_Quality 
     LIMIT 1) AS teacher_id,
    (SELECT dim_school.school_id 
     FROM dim_school 
     WHERE dim_school.school_type = staging.School_Type 
     LIMIT 1) AS school_id,
    (SELECT dim_resources.resource_id 
     FROM dim_resources 
     WHERE dim_resources.access_to_resources = staging.Access_to_Resources 
     AND dim_resources.parental_involvement = staging.Parental_Involvement 
     LIMIT 1) AS resource_id,
    (SELECT dim_motivation.motivation_id 
     FROM dim_motivation 
     WHERE dim_motivation.motivation_level = staging.Motivation_Level 
     LIMIT 1) AS motivation_id,
    (SELECT dim_student.student_dim_id 
     FROM dim_student 
     WHERE 
         dim_student.gender = staging.Gender 
         AND dim_student.family_income = CASE 
             WHEN staging.Family_Income = 'Low' THEN 20000 
             WHEN staging.Family_Income = 'Moderate' THEN 50000 
             WHEN staging.Family_Income = 'High' THEN 100000 
             ELSE NULL 
         END 
         AND dim_student.peer_influence = staging.Peer_Influence 
         AND dim_student.learning_disabilities = staging.Learning_Disabilities 
         AND dim_student.distance_from_home = CASE 
             WHEN staging.Distance_from_Home = 'Near' THEN 5 
             WHEN staging.Distance_from_Home = 'Moderate' THEN 10 
             WHEN staging.Distance_from_Home = 'Far' THEN 20 
             ELSE NULL 
         END 
     LIMIT 1) AS student_dim_id,
    COALESCE(TRIM(staging.Gender), '') AS gender,
    CASE 
        WHEN LOWER(TRIM(staging.Family_Income)) = 'low' THEN 20000
        WHEN LOWER(TRIM(staging.Family_Income)) = 'moderate' THEN 50000
        WHEN LOWER(TRIM(staging.Family_Income)) = 'high' THEN 100000
        ELSE NULL  -- or 0 if needed, but using NULL will allow for more meaningful aggregation
    END AS family_income,
    COALESCE(TRIM(staging.Peer_Influence), '') AS peer_influence,
    COALESCE(TRIM(staging.Learning_Disabilities), '') AS learning_disabilities,
    CASE 
        WHEN LOWER(TRIM(staging.Distance_from_Home)) = 'near' THEN 5
        WHEN LOWER(TRIM(staging.Distance_from_Home)) = 'moderate' THEN 10
        WHEN LOWER(TRIM(staging.Distance_from_Home)) = 'far' THEN 20
        ELSE NULL  -- or 0, depending on how you want to handle missing values
    END AS distance_from_home
FROM 
    student_data AS staging 
WHERE 
    staging.Student_ID IS NOT NULL;
    
   DELETE FROM fact_student_performance 
WHERE 
    student_id IS NULL OR 
    hours_studied IS NULL OR 
    attendance IS NULL OR 
    sleep_hours IS NULL OR 
    previous_scores IS NULL OR 
    exam_score IS NULL OR 
    tutoring_id IS NULL OR 
    teacher_id IS NULL OR 
    school_id IS NULL OR 
    resource_id IS NULL OR 
    motivation_id IS NULL OR 
    gender IS NULL OR 
    family_income IS NULL OR 
    peer_influence IS NULL OR 
    learning_disabilities IS NULL OR 
    distance_from_home IS NULL;

    
    -- Use the StudentPerformance database
USE StudentPerformance1;

-- 1. Descriptive Statistics: 
-- Average Exam Score
SELECT AVG(exam_score) AS Average_Exam_Score 
FROM fact_student_performance; 

-- Median Exam Score
SELECT 
    s.school_type,
    (
        SELECT exam_score 
        FROM fact_student_performance fp 
        JOIN dim_school ds ON fp.school_id = ds.school_id 
        WHERE ds.school_type = s.school_type
        ORDER BY exam_score
        LIMIT 1 OFFSET (COUNT(*) - 1) / 2 
    ) AS Median_Exam_Score
FROM 
    dim_school s;
--  bug doesn't want to fixed 
-- Variance of Exam Score
SELECT VAR_POP(exam_score) AS Variance_Exam_Score 
FROM fact_student_performance;

-- 2. Visualizations:
-- Scatter Plot (Hours Studied vs. Exam Score) - Requires external tools (Python/Pandas)
-- (We'll cover this integration later)

-- 3. Trends and Correlations:
-- Average Exam Score by Gender
SELECT gender, AVG(exam_score) AS Average_Exam_Score 
FROM fact_student_performance 
GROUP BY gender;

-- Average Exam Score by Family Income
SELECT family_income, AVG(exam_score) AS Average_Exam_Score 
FROM fact_student_performance 
GROUP BY family_income; 

-- Average Exam Score by School Type
SELECT school_type, AVG(exam_score) AS Average_Exam_Score
FROM fact_student_performance
JOIN dim_school ON fact_student_performance.school_id = dim_school.school_id
GROUP BY school_type;

-- Correlation between Study Time and Exam Score
-- This requires a correlation function, not available in MySQL directly
-- We'll cover this using Python/Pandas

-- 4. Distributions:
-- Distribution of Study Hours
SELECT hours_studied, COUNT(*) AS count
FROM fact_student_performance
GROUP BY hours_studied
ORDER BY hours_studied;

-- Distribution of Sleep Hours
SELECT sleep_hours, COUNT(*) AS count
FROM fact_student_performance
GROUP BY sleep_hours
ORDER BY sleep_hours;

-- Distribution of Attendance
SELECT attendance, COUNT(*) AS count
FROM fact_student_performance
GROUP BY attendance
ORDER BY attendance;

-- Distribution of Previous Scores
SELECT previous_scores, COUNT(*) AS count
FROM fact_student_performance
GROUP BY previous_scores
ORDER BY previous_scores;

-- 5. Cross-Tabulations (Contingency Tables)
-- Example: Gender vs. Parental Involvement
SELECT 
    gender, 
    parental_involvement, 
    COUNT(*) AS count 
FROM fact_student_performance
JOIN dim_resources ON fact_student_performance.resource_id = dim_resources.resource_id
GROUP BY gender, parental_involvement
ORDER BY gender, parental_involvement;

-- import mysql.connector
-- import pandas as pd

-- mydb = mysql.connector.connect(
   -- host="your_host",
   -- user="your_user",
   -- password="your_password",
   -- database="StudentPerformance"
-- )

-- mycursor = mydb.cursor()
-- mycursor.execute("SELECT * FROM fact_student_performance")

-- df = pd.DataFrame(mycursor.fetchall(), columns=[desc[0] for desc in mycursor.description])
