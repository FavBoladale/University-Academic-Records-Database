-- ============================================================
-- LuxUniversity DB
-- FILE: 03_insert_sample_data.sql
-- PURPOSE: Seed the OLTP database with reference data,
--          all 14 OAU faculties, departments, programmes,
--          courses, students, registrations, and results.
-- RUN AFTER: 01_create_oltp.sql
-- ============================================================

USE luxuniversity_db;
GO
SET NOCOUNT ON;
GO

-- ============================================================
-- 1. GRADE SCALE
-- ============================================================
INSERT INTO grade_scale (grade, min_score, max_score, grade_point, remark) VALUES
('A', 70, 100, 5.0, 'Excellent'),
('B', 60,  69, 4.0, 'Good'),
('C', 50,  59, 3.0, 'Average'),
('D', 45,  49, 2.0, 'Pass'),
('E', 40,  44, 1.0, 'Marginal Pass'),
('F',  0,  39, 0.0, 'Fail');
GO

-- ============================================================
-- 2. STUDENT LEVELS
-- ============================================================
INSERT INTO student_level (level_name, level_number, description) VALUES
('100L', 100, 'First Year / Part I'),
('200L', 200, 'Second Year / Part II'),
('300L', 300, 'Third Year / Part III'),
('400L', 400, 'Fourth Year / Part IV'),
('500L', 500, 'Fifth Year — Medicine, Pharmacy, Architecture'),
('600L', 600, 'Sixth Year — Medicine, Dentistry'),
('700L', 700, 'Seventh Year — Extended Medical Programme');
GO

-- ============================================================
-- 3. DEGREE TYPES
-- ============================================================
INSERT INTO degree_type (degree_code, degree_name) VALUES
('B.Sc',    'Bachelor of Science'),
('B.A',     'Bachelor of Arts'),
('B.Tech',  'Bachelor of Technology'),
('B.Eng',   'Bachelor of Engineering'),
('MBBS',    'Bachelor of Medicine, Bachelor of Surgery'),
('B.DS',    'Bachelor of Dental Surgery'),
('B.Pharm', 'Bachelor of Pharmacy'),
('LL.B',    'Bachelor of Laws'),
('B.Ed',    'Bachelor of Education'),
('B.Agric', 'Bachelor of Agriculture'),
('B.F.A',   'Bachelor of Fine Arts');
GO

-- ============================================================
-- 4. COLLEGE
-- ============================================================
INSERT INTO college (college_name, abbreviation) VALUES
('College of Health Sciences', 'CHS');
GO

-- ============================================================
-- 5. FACULTIES (All 14 OAU Faculties)
-- ============================================================
INSERT INTO faculty (college_id, faculty_name, abbreviation, established_year) VALUES
(NULL, 'Faculty of Administration',                      'ADMIN',   1962),
(NULL, 'Faculty of Agriculture',                         'AGRIC',   1962),
(NULL, 'Faculty of Arts',                                'ARTS',    1962),
(1,    'Faculty of Basic Medical Sciences',              'BMS',     1975),
(1,    'Faculty of Clinical Sciences',                   'CLINSCI', 1975),
(1,    'Faculty of Dentistry',                           'DENT',    1984),
(NULL, 'Faculty of Education',                           'EDU',     1962),
(NULL, 'Faculty of Environmental Design and Management', 'EDM',     1972),
(NULL, 'Faculty of Law',                                 'LAW',     1967),
(1,    'Faculty of Pharmacy',                            'PHARM',   1975),
(NULL, 'Faculty of Science',                             'SCI',     1962),
(NULL, 'Faculty of Social Sciences',                     'SOC',     1962),
(NULL, 'Faculty of Technology',                          'TECH',    1966),
(NULL, 'Faculty of Computing Science and Technology',    'CST',     2013);
GO

-- ============================================================
-- 6. DEPARTMENTS
-- ============================================================
-- Administration
INSERT INTO department (faculty_id, department_name, abbreviation) VALUES
(1,'Public Administration','PUB_ADMIN'),(1,'Business Administration','BUS_ADMIN'),
(1,'Accounting','ACCT'),(1,'Finance','FIN');

-- Agriculture
INSERT INTO department (faculty_id, department_name, abbreviation) VALUES
(2,'Crop Science and Horticulture','CSH'),(2,'Animal Science','ANS'),
(2,'Agricultural Economics','AGE'),(2,'Food Science and Technology','FST');

-- Arts
INSERT INTO department (faculty_id, department_name, abbreviation) VALUES
(3,'English','ENG'),(3,'History and International Studies','HIS'),
(3,'Linguistics and African Languages','LIN'),(3,'Philosophy','PHI'),
(3,'Religious Studies','REL');

-- Basic Medical Sciences
INSERT INTO department (faculty_id, department_name, abbreviation) VALUES
(4,'Anatomy','ANAT'),(4,'Physiology','PHYS'),(4,'Biochemistry','BIOC');

-- Clinical Sciences
INSERT INTO department (faculty_id, department_name, abbreviation) VALUES
(5,'Medicine and Surgery','MED'),(5,'Paediatrics','PAED'),
(5,'Obstetrics and Gynaecology','OBG');

-- Dentistry
INSERT INTO department (faculty_id, department_name, abbreviation) VALUES
(6,'Oral and Maxillofacial Surgery','OMS'),(6,'Restorative Dentistry','RD'),
(6,'Preventive Dentistry','PD');

-- Education
INSERT INTO department (faculty_id, department_name, abbreviation) VALUES
(7,'Educational Administration','EDADM'),(7,'Guidance and Counselling','GNC'),
(7,'Science Education','SCIED'),(7,'Arts and Social Science Education','ASSED');

-- EDM
INSERT INTO department (faculty_id, department_name, abbreviation) VALUES
(8,'Architecture','ARCH'),(8,'Urban and Regional Planning','URP'),
(8,'Estate Management','ESTMGT'),(8,'Building','BUILD');

-- Law
INSERT INTO department (faculty_id, department_name, abbreviation) VALUES
(9,'Private and Property Law','PPL'),(9,'Public Law','PBL'),(9,'Commercial Law','COML');

-- Pharmacy
INSERT INTO department (faculty_id, department_name, abbreviation) VALUES
(10,'Clinical Pharmacy and Pharmacy Administration','CPPA'),
(10,'Pharmaceutical Chemistry','PHARMCHEM'),
(10,'Pharmacognosy','PGNOSY'),
(10,'Pharmaceutics and Industrial Pharmacy','PIP');

-- Science
INSERT INTO department (faculty_id, department_name, abbreviation) VALUES
(11,'Mathematics','MATH'),(11,'Physics','PHY'),(11,'Chemistry','CHEM'),
(11,'Biology','BIO'),(11,'Statistics','STAT'),(11,'Zoology','ZOO'),
(11,'Botany','BOT'),(11,'Geology','GEOL');

-- Social Sciences
INSERT INTO department (faculty_id, department_name, abbreviation) VALUES
(12,'Economics','ECON'),(12,'Political Science','POLSCI'),
(12,'Sociology and Anthropology','SOC'),(12,'Psychology','PSYCH');

-- Technology
INSERT INTO department (faculty_id, department_name, abbreviation) VALUES
(13,'Mechanical Engineering','MECHENG'),(13,'Electrical and Electronic Engineering','EEE'),
(13,'Civil Engineering','CIVENG'),(13,'Chemical Engineering','CHEMENG'),
(13,'Agricultural Engineering','AGENG');

-- Computing
INSERT INTO department (faculty_id, department_name, abbreviation) VALUES
(14,'Computer Science','CSC'),(14,'Management Information Systems','MIS'),
(14,'Cybersecurity','CYB'),(14,'Artificial Intelligence','AI'),
(14,'Software Engineering','SWE');
GO

-- ============================================================
-- 7. PROGRAMMES
-- ============================================================
INSERT INTO programme (department_id, degree_type_id, programme_name, duration_years)
SELECT d.department_id, dt.degree_type_id, v.prog, v.yrs
FROM (VALUES
    ('Accounting',          'B.Sc','B.Sc Accounting',4),
    ('Business Administration','B.Sc','B.Sc Business Administration',4),
    ('Finance',             'B.Sc','B.Sc Finance',4),
    ('Public Administration','B.Sc','B.Sc Public Administration',4),
    ('Crop Science and Horticulture','B.Agric','B.Agric Crop Science',5),
    ('Animal Science',      'B.Agric','B.Agric Animal Science',5),
    ('Agricultural Economics','B.Sc','B.Sc Agricultural Economics',4),
    ('Food Science and Technology','B.Sc','B.Sc Food Science and Technology',4),
    ('English',             'B.A','B.A English',4),
    ('History and International Studies','B.A','B.A History',4),
    ('Linguistics and African Languages','B.A','B.A Linguistics',4),
    ('Philosophy',          'B.A','B.A Philosophy',4),
    ('Religious Studies',   'B.A','B.A Religious Studies',4),
    ('Anatomy',             'B.Sc','B.Sc Anatomy',4),
    ('Physiology',          'B.Sc','B.Sc Physiology',4),
    ('Biochemistry',        'B.Sc','B.Sc Biochemistry',4),
    ('Medicine and Surgery','MBBS','MBBS Medicine and Surgery',6),
    ('Preventive Dentistry','B.DS','B.DS Dental Surgery',5),
    ('Educational Administration','B.Ed','B.Ed Educational Administration',4),
    ('Guidance and Counselling','B.Ed','B.Ed Guidance and Counselling',4),
    ('Architecture',        'B.Sc','B.Sc Architecture',5),
    ('Urban and Regional Planning','B.Sc','B.Sc Urban and Regional Planning',4),
    ('Estate Management',   'B.Sc','B.Sc Estate Management',4),
    ('Building',            'B.Sc','B.Sc Building',4),
    ('Private and Property Law','LL.B','LL.B Law',5),
    ('Clinical Pharmacy and Pharmacy Administration','B.Pharm','B.Pharm Pharmacy',5),
    ('Mathematics',         'B.Sc','B.Sc Mathematics',4),
    ('Physics',             'B.Sc','B.Sc Physics',4),
    ('Chemistry',           'B.Sc','B.Sc Chemistry',4),
    ('Biology',             'B.Sc','B.Sc Biology',4),
    ('Statistics',          'B.Sc','B.Sc Statistics',4),
    ('Zoology',             'B.Sc','B.Sc Zoology',4),
    ('Botany',              'B.Sc','B.Sc Botany',4),
    ('Geology',             'B.Sc','B.Sc Geology',4),
    ('Economics',           'B.Sc','B.Sc Economics',4),
    ('Political Science',   'B.Sc','B.Sc Political Science',4),
    ('Sociology and Anthropology','B.Sc','B.Sc Sociology',4),
    ('Psychology',          'B.Sc','B.Sc Psychology',4),
    ('Mechanical Engineering','B.Eng','B.Eng Mechanical Engineering',5),
    ('Electrical and Electronic Engineering','B.Eng','B.Eng Electrical and Electronics Engineering',5),
    ('Civil Engineering',   'B.Eng','B.Eng Civil Engineering',5),
    ('Chemical Engineering','B.Eng','B.Eng Chemical Engineering',5),
    ('Agricultural Engineering','B.Eng','B.Eng Agricultural Engineering',5),
    ('Computer Science',    'B.Sc','B.Sc Computer Science',4),
    ('Management Information Systems','B.Sc','B.Sc Management Information Systems',4),
    ('Cybersecurity',       'B.Sc','B.Sc Cybersecurity',4),
    ('Artificial Intelligence','B.Sc','B.Sc Artificial Intelligence',4),
    ('Software Engineering','B.Sc','B.Sc Software Engineering',4)
) v(dept, deg, prog, yrs)
JOIN department d ON d.department_name = v.dept
JOIN degree_type dt ON dt.degree_code = v.deg;
GO

-- ============================================================
-- 8. COURSE CATEGORIES
-- ============================================================
INSERT INTO course_category (category_code, category_name, description) VALUES
('MAJOR',         'Major Course',               'Core courses specific to the student''s department/programme'),
('ELECTIVE',      'Elective Course',            'Optional courses student can choose from approved list'),
('COMPULSORY_SE', 'Compulsory Special Elective','University-wide compulsory courses — SER001 for all 100L students'),
('GEN_STUDIES',   'General Studies',            'University-wide general studies courses'),
('COMMON',        'Common Course',              'Courses shared across multiple programmes');
GO

-- ============================================================
-- 9. ACADEMIC SESSIONS & SEMESTERS
-- ============================================================
INSERT INTO academic_session (session_name, start_date, end_date, is_current) VALUES
('2021/2022','2021-09-01','2022-07-31',0),
('2022/2023','2022-09-01','2023-07-31',0),
('2023/2024','2023-09-01','2024-07-31',0),
('2024/2025','2024-09-01','2025-07-31',1);
GO

INSERT INTO semester (session_id, semester_name, start_date, end_date, reg_deadline, is_current)
SELECT s.session_id, v.sem, v.sd, v.ed, v.rd, v.ic
FROM (VALUES
    ('2021/2022','First', '2021-09-13','2022-01-28','2021-10-01',0),
    ('2021/2022','Second','2022-02-14','2022-06-30','2022-03-04',0),
    ('2022/2023','First', '2022-09-12','2023-01-27','2022-09-30',0),
    ('2022/2023','Second','2023-02-13','2023-06-30','2023-03-03',0),
    ('2023/2024','First', '2023-09-11','2024-01-26','2023-09-29',0),
    ('2023/2024','Second','2024-02-12','2024-06-28','2024-03-01',0),
    ('2024/2025','First', '2024-09-09','2025-01-31','2024-09-27',0),
    ('2024/2025','Second','2025-02-10','2025-07-11','2025-03-01',1)
) v(sn, sem, sd, ed, rd, ic)
JOIN academic_session s ON s.session_name = v.sn;
GO

-- ============================================================
-- 10. COURSES (SER001 + representative courses across faculties)
-- ============================================================

-- SER001 — Compulsory Special Elective
INSERT INTO course (department_id, category_id, course_code, course_title, course_description,
    credit_units, level_id, semester_offered, is_compulsory_se)
SELECT d.department_id, cc.category_id,
    'SER001','Use of English',
    'Compulsory general English language course for all 100-level students. Covers reading comprehension, essay writing, grammar, vocabulary development, and oral communication skills. University-wide requirement for all Part I students regardless of faculty or department.',
    2, sl.level_id, 'First', 1
FROM department d, course_category cc, student_level sl
WHERE d.department_name='English' AND cc.category_code='COMPULSORY_SE' AND sl.level_number=100;

-- General Studies
INSERT INTO course (department_id, category_id, course_code, course_title, course_description, credit_units, level_id, semester_offered)
SELECT d.department_id, cc.category_id, v.code, v.title, v.descr, v.cu, sl.level_id, v.sem
FROM (VALUES
    ('English','GEN_STUDIES','GST101','Communication in English I','Introduction to academic writing, oral communication, and critical reading.',2,100,'First'),
    ('English','GEN_STUDIES','GST102','Communication in English II','Advanced writing, research methods, and presentation techniques.',2,100,'Second'),
    ('Mathematics','GEN_STUDIES','GST111','Elementary Mathematics I','Sets, algebra, functions, limits, differentiation, and basic integration.',3,100,'First'),
    ('Mathematics','GEN_STUDIES','GST112','Elementary Mathematics II','Integral calculus, statistics, probability, and vectors.',3,100,'Second')
) v(dept,cat,code,title,descr,cu,lvl,sem)
JOIN department d ON d.department_name=v.dept
JOIN course_category cc ON cc.category_code=v.cat
JOIN student_level sl ON sl.level_number=v.lvl;

-- Computer Science
INSERT INTO course (department_id, category_id, course_code, course_title, course_description, credit_units, level_id, semester_offered)
SELECT d.department_id, cc.category_id, v.code, v.title, v.descr, v.cu, sl.level_id, v.sem
FROM (VALUES
    ('Computer Science','MAJOR','CSC101','Introduction to Computer Science','History of computing, number systems, hardware concepts, software, and problem-solving with algorithms.',3,100,'First'),
    ('Computer Science','MAJOR','CSC102','Introduction to Programming','Python programming fundamentals: data types, control structures, functions, file I/O, and debugging.',3,100,'Second'),
    ('Computer Science','MAJOR','CSC103','Computer Hardware Fundamentals','CPU architecture, memory systems, I/O devices, digital logic, and number conversions.',2,100,'First'),
    ('Computer Science','MAJOR','CSC201','Data Structures and Algorithms','Arrays, linked lists, stacks, queues, trees, graphs, sorting and searching with complexity analysis.',3,200,'First'),
    ('Computer Science','MAJOR','CSC202','Object-Oriented Programming','Java OOP: classes, inheritance, polymorphism, encapsulation, interfaces, and exception handling.',3,200,'Second'),
    ('Computer Science','MAJOR','CSC203','Discrete Mathematics','Logic, sets, relations, functions, graph theory, combinatorics, and Boolean algebra.',3,200,'First'),
    ('Computer Science','MAJOR','CSC204','Computer Organisation and Architecture','Instruction sets, pipelining, cache hierarchy, I/O organisation, and multiprocessor systems.',3,200,'Second'),
    ('Computer Science','MAJOR','CSC301','Operating Systems','Process management, scheduling, memory management, virtual memory, file systems, and concurrency.',3,300,'First'),
    ('Computer Science','MAJOR','CSC302','Database Management Systems','Relational model, SQL, normalisation up to BCNF, transactions, indexing, and query optimisation.',3,300,'First'),
    ('Computer Science','MAJOR','CSC303','Computer Networks','OSI and TCP/IP models, routing, switching, transport layer, DNS, HTTP, and network security.',3,300,'Second'),
    ('Computer Science','MAJOR','CSC304','Software Engineering I','SDLC, requirements engineering, UML diagrams, design patterns, and project management.',3,300,'Second'),
    ('Computer Science','ELECTIVE','CSC305','Mobile Application Development','Android and iOS development with React Native; UI/UX, state management, and API integration.',3,300,'Second'),
    ('Computer Science','ELECTIVE','CSC306','Web Development','HTML5, CSS3, JavaScript ES6+, REST APIs, Node.js, and responsive design.',3,300,'First'),
    ('Computer Science','MAJOR','CSC401','Artificial Intelligence','Search algorithms, knowledge representation, ML fundamentals, neural networks, NLP overview.',3,400,'First'),
    ('Computer Science','MAJOR','CSC402','Final Year Project I','Research proposal, literature review, problem definition, and preliminary system design.',3,400,'First'),
    ('Computer Science','MAJOR','CSC403','Final Year Project II','Implementation, testing, documentation, and project presentation.',3,400,'Second'),
    ('Computer Science','MAJOR','CSC404','Computer Security','Cryptography, network security, ethical hacking, web security, and security policy frameworks.',3,400,'First'),
    ('Computer Science','ELECTIVE','CSC405','Cloud Computing','Cloud service models (IaaS, PaaS, SaaS), AWS/Azure/GCP fundamentals, Docker, Kubernetes.',3,400,'Second'),
    ('Computer Science','ELECTIVE','CSC406','Data Science and Analytics','Statistical analysis, data wrangling, predictive modelling, and visualisation with Python.',3,400,'Second')
) v(dept,cat,code,title,descr,cu,lvl,sem)
JOIN department d ON d.department_name=v.dept
JOIN course_category cc ON cc.category_code=v.cat
JOIN student_level sl ON sl.level_number=v.lvl;

-- Artificial Intelligence
INSERT INTO course (department_id, category_id, course_code, course_title, course_description, credit_units, level_id, semester_offered)
SELECT d.department_id, cc.category_id, v.code, v.title, v.descr, v.cu, sl.level_id, v.sem
FROM (VALUES
    ('Artificial Intelligence','MAJOR','AIT101','Foundations of Artificial Intelligence','AI history, intelligent agents, search (BFS, DFS, A*), and heuristic problem solving.',3,100,'First'),
    ('Artificial Intelligence','MAJOR','AIT201','Machine Learning I','Supervised learning, unsupervised learning, regression, classification, and model evaluation.',3,200,'First'),
    ('Artificial Intelligence','MAJOR','AIT202','Machine Learning II','Ensemble methods, neural networks, backpropagation, and hyperparameter tuning.',3,200,'Second'),
    ('Artificial Intelligence','MAJOR','AIT301','Deep Learning','CNNs, RNNs, attention, Transformers, computer vision, and transfer learning.',3,300,'First'),
    ('Artificial Intelligence','MAJOR','AIT302','Natural Language Processing','Text preprocessing, word embeddings, BERT, LLMs, sentiment analysis, and NER.',3,300,'Second'),
    ('Artificial Intelligence','MAJOR','AIT401','AI Ethics and Governance','Bias, fairness, explainability (XAI), privacy-preserving ML, and regulatory frameworks.',3,400,'First'),
    ('Artificial Intelligence','ELECTIVE','AIT402','Robotics and Intelligent Systems','Sensors, actuators, ROS, SLAM, autonomous navigation, and human-robot interaction.',3,400,'Second')
) v(dept,cat,code,title,descr,cu,lvl,sem)
JOIN department d ON d.department_name=v.dept
JOIN course_category cc ON cc.category_code=v.cat
JOIN student_level sl ON sl.level_number=v.lvl;

-- Software Engineering
INSERT INTO course (department_id, category_id, course_code, course_title, course_description, credit_units, level_id, semester_offered)
SELECT d.department_id, cc.category_id, v.code, v.title, v.descr, v.cu, sl.level_id, v.sem
FROM (VALUES
    ('Software Engineering','MAJOR','SWE101','Introduction to Software Engineering','Software development fundamentals, agile vs waterfall, Git version control, and code quality basics.',3,100,'First'),
    ('Software Engineering','MAJOR','SWE201','Software Design Principles','SOLID principles, design patterns (GoF), UML diagrams, and refactoring techniques.',3,200,'First'),
    ('Software Engineering','MAJOR','SWE301','Software Testing and Quality Assurance','Unit testing, TDD, integration testing, code reviews, and software quality metrics.',3,300,'First'),
    ('Software Engineering','MAJOR','SWE302','DevOps and Continuous Integration','CI/CD pipelines, Docker, Kubernetes, IaC, monitoring, and deployment strategies.',3,300,'Second'),
    ('Software Engineering','MAJOR','SWE401','Enterprise Software Architecture','Microservices, event-driven architecture, API design (REST/GraphQL), and distributed systems.',3,400,'First'),
    ('Software Engineering','ELECTIVE','SWE402','Blockchain Technology','Distributed ledgers, consensus mechanisms, smart contracts, Ethereum development.',3,400,'Second')
) v(dept,cat,code,title,descr,cu,lvl,sem)
JOIN department d ON d.department_name=v.dept
JOIN course_category cc ON cc.category_code=v.cat
JOIN student_level sl ON sl.level_number=v.lvl;

-- Cybersecurity
INSERT INTO course (department_id, category_id, course_code, course_title, course_description, credit_units, level_id, semester_offered)
SELECT d.department_id, cc.category_id, v.code, v.title, v.descr, v.cu, sl.level_id, v.sem
FROM (VALUES
    ('Cybersecurity','MAJOR','CYB101','Introduction to Cybersecurity','Threat landscape, CIA triad, attack types, vulnerability management, and career paths.',3,100,'First'),
    ('Cybersecurity','MAJOR','CYB201','Network Security','Firewalls, VPNs, IDS/IPS, secure protocols, and wireless security.',3,200,'First'),
    ('Cybersecurity','MAJOR','CYB301','Ethical Hacking and Penetration Testing','Reconnaissance, vulnerability assessment, Metasploit, post-exploitation, and reporting.',3,300,'First'),
    ('Cybersecurity','MAJOR','CYB302','Digital Forensics','Evidence collection, forensic tools (Autopsy, FTK), chain of custody, and network forensics.',3,300,'Second'),
    ('Cybersecurity','MAJOR','CYB401','Security Operations Center Management','SIEM, incident response, threat hunting, log analysis, playbooks, and SOC metrics.',3,400,'First'),
    ('Cybersecurity','ELECTIVE','CYB402','Malware Analysis','Static and dynamic malware analysis, reverse engineering basics, sandboxing, and threat intel.',3,400,'Second')
) v(dept,cat,code,title,descr,cu,lvl,sem)
JOIN department d ON d.department_name=v.dept
JOIN course_category cc ON cc.category_code=v.cat
JOIN student_level sl ON sl.level_number=v.lvl;

-- Economics
INSERT INTO course (department_id, category_id, course_code, course_title, course_description, credit_units, level_id, semester_offered)
SELECT d.department_id, cc.category_id, v.code, v.title, v.descr, v.cu, sl.level_id, v.sem
FROM (VALUES
    ('Economics','MAJOR','ECO101','Introduction to Economics I','Demand, supply, market equilibrium, elasticity, consumer theory, and production costs.',3,100,'First'),
    ('Economics','MAJOR','ECO102','Introduction to Economics II','GDP, inflation, unemployment, monetary and fiscal policy, and economic indicators.',3,100,'Second'),
    ('Economics','MAJOR','ECO201','Microeconomic Theory I','Advanced consumer choice, production theory, cost functions, and market structures.',3,200,'First'),
    ('Economics','MAJOR','ECO202','Macroeconomic Theory I','Keynesian model, IS-LM framework, aggregate demand and supply, and business cycles.',3,200,'Second'),
    ('Economics','MAJOR','ECO301','Econometrics I','OLS estimation, hypothesis testing, heteroscedasticity, and multicollinearity detection.',3,300,'First'),
    ('Economics','MAJOR','ECO302','Development Economics','Theories of development, poverty measurement, inequality, structural transformation.',3,300,'Second'),
    ('Economics','ELECTIVE','ECO303','International Trade','Comparative advantage, balance of payments, exchange rates, WTO, and trade policy.',3,300,'Second'),
    ('Economics','MAJOR','ECO401','Advanced Econometrics','Time series (ARIMA), panel data, instrumental variables, and VAR models.',3,400,'First'),
    ('Economics','ELECTIVE','ECO402','Financial Economics','CAPM, APT, portfolio theory, financial markets, derivatives pricing.',3,400,'Second')
) v(dept,cat,code,title,descr,cu,lvl,sem)
JOIN department d ON d.department_name=v.dept
JOIN course_category cc ON cc.category_code=v.cat
JOIN student_level sl ON sl.level_number=v.lvl;

-- Accounting
INSERT INTO course (department_id, category_id, course_code, course_title, course_description, credit_units, level_id, semester_offered)
SELECT d.department_id, cc.category_id, v.code, v.title, v.descr, v.cu, sl.level_id, v.sem
FROM (VALUES
    ('Accounting','MAJOR','ACC101','Principles of Accounting I','Double-entry bookkeeping, trial balance, income statement, and balance sheet preparation.',3,100,'First'),
    ('Accounting','MAJOR','ACC102','Principles of Accounting II','Partnership accounts, company accounts, cash flow statements, and depreciation methods.',3,100,'Second'),
    ('Accounting','MAJOR','ACC201','Intermediate Accounting I','Revenue recognition, inventory valuation (FIFO/LIFO), PPE accounting, and impairment.',3,200,'First'),
    ('Accounting','MAJOR','ACC301','Auditing and Assurance','Audit planning, risk assessment, internal controls evaluation, ethics, and audit reporting.',3,300,'First'),
    ('Accounting','MAJOR','ACC302','Taxation','Nigerian personal and company income tax, capital gains tax, VAT, and FIRS compliance.',3,300,'Second'),
    ('Accounting','ELECTIVE','ACC303','Forensic Accounting','Fraud detection, forensic investigation, litigation support, and expert witness roles.',3,300,'Second'),
    ('Accounting','MAJOR','ACC401','Advanced Financial Accounting','Business combinations, consolidation, foreign currency translation, IFRS 9 and IFRS 16.',3,400,'First')
) v(dept,cat,code,title,descr,cu,lvl,sem)
JOIN department d ON d.department_name=v.dept
JOIN course_category cc ON cc.category_code=v.cat
JOIN student_level sl ON sl.level_number=v.lvl;

-- Mathematics
INSERT INTO course (department_id, category_id, course_code, course_title, course_description, credit_units, level_id, semester_offered)
SELECT d.department_id, cc.category_id, v.code, v.title, v.descr, v.cu, sl.level_id, v.sem
FROM (VALUES
    ('Mathematics','MAJOR','MAT101','Elementary Mathematics I','Sets, functions, limits, differentiation, and introduction to integral calculus.',3,100,'First'),
    ('Mathematics','MAJOR','MAT102','Elementary Mathematics II','ODEs, sequences, series (Taylor, Maclaurin), complex numbers, and hyperbolic functions.',3,100,'Second'),
    ('Mathematics','MAJOR','MAT201','Linear Algebra I','Vectors, matrices, determinants, eigenvalues, eigenvectors, and linear transformations.',3,200,'First'),
    ('Mathematics','MAJOR','MAT202','Real Analysis I','Metric spaces, limits, continuity, differentiability, and Riemann integration.',3,200,'Second'),
    ('Mathematics','MAJOR','MAT301','Numerical Analysis','Numerical solutions of equations, interpolation, numerical differentiation and integration.',3,300,'First'),
    ('Mathematics','ELECTIVE','MAT302','Operations Research','Linear programming, transportation/assignment problems, queuing theory, and decision analysis.',3,300,'Second'),
    ('Mathematics','MAJOR','MAT401','Abstract Algebra','Groups, rings, fields, and introduction to Galois theory with applications.',3,400,'First')
) v(dept,cat,code,title,descr,cu,lvl,sem)
JOIN department d ON d.department_name=v.dept
JOIN course_category cc ON cc.category_code=v.cat
JOIN student_level sl ON sl.level_number=v.lvl;

-- Law
INSERT INTO course (department_id, category_id, course_code, course_title, course_description, credit_units, level_id, semester_offered)
SELECT d.department_id, cc.category_id, v.code, v.title, v.descr, v.cu, sl.level_id, v.sem
FROM (VALUES
    ('Private and Property Law','MAJOR','LAW101','Nigerian Legal System','Sources of Nigerian law, court hierarchy, constitutional framework, and statutory interpretation.',3,100,'First'),
    ('Private and Property Law','MAJOR','LAW102','Law of Contract I','Offer, acceptance, consideration, capacity, and contractual intention principles.',3,100,'Second'),
    ('Private and Property Law','MAJOR','LAW201','Law of Contract II','Terms, misrepresentation, discharge, breach remedies, and frustration doctrine.',3,200,'First'),
    ('Private and Property Law','MAJOR','LAW202','Constitutional Law I','Constitutional supremacy, fundamental rights, separation of powers, and judicial review.',3,200,'Second'),
    ('Private and Property Law','MAJOR','LAW301','Commercial Law','Sale of goods, agency, negotiable instruments, hire purchase, and consumer protection.',3,300,'First'),
    ('Private and Property Law','MAJOR','LAW302','Criminal Law','Elements of crime, offence categories, defences, sentencing, and criminal procedure.',3,300,'Second'),
    ('Private and Property Law','ELECTIVE','LAW303','Intellectual Property Law','Copyright, patents, trademarks, trade secrets, and digital IP rights.',3,300,'Second'),
    ('Private and Property Law','MAJOR','LAW401','Evidence and Civil Procedure','Rules of evidence, burdens of proof, pleadings, pre-trial, and appellate practice.',3,400,'First'),
    ('Private and Property Law','MAJOR','LAW402','Legal Drafting and Mooting','Contract drafting, affidavits, pleadings, moot court, and advocacy techniques.',3,400,'Second')
) v(dept,cat,code,title,descr,cu,lvl,sem)
JOIN department d ON d.department_name=v.dept
JOIN course_category cc ON cc.category_code=v.cat
JOIN student_level sl ON sl.level_number=v.lvl;

-- Mechanical Engineering
INSERT INTO course (department_id, category_id, course_code, course_title, course_description, credit_units, level_id, semester_offered)
SELECT d.department_id, cc.category_id, v.code, v.title, v.descr, v.cu, sl.level_id, v.sem
FROM (VALUES
    ('Mechanical Engineering','MAJOR','MEE101','Engineering Drawing','Orthographic projection, isometric views, sectional views, tolerances, and AutoCAD basics.',3,100,'First'),
    ('Mechanical Engineering','MAJOR','MEE102','Introduction to Engineering','Engineering profession, ethics, units, materials overview, and the engineering design process.',2,100,'Second'),
    ('Mechanical Engineering','MAJOR','MEE201','Engineering Mechanics I (Statics)','Forces, moments, equilibrium, trusses, frames, friction, centroids, and moments of inertia.',3,200,'First'),
    ('Mechanical Engineering','MAJOR','MEE202','Engineering Mechanics II (Dynamics)','Kinematics, kinetics, work-energy, impulse-momentum, and vibration fundamentals.',3,200,'Second'),
    ('Mechanical Engineering','MAJOR','MEE301','Thermodynamics I','Laws of thermodynamics, pure substance properties, gas power cycles (Otto, Diesel, Brayton).',3,300,'First'),
    ('Mechanical Engineering','MAJOR','MEE302','Fluid Mechanics','Fluid properties, hydrostatics, continuity, Bernoulli, pipe flow, and boundary layer theory.',3,300,'Second'),
    ('Mechanical Engineering','ELECTIVE','MEE303','Renewable Energy Systems','Solar, wind, hydro, biomass energy fundamentals, storage systems, and grid integration.',3,300,'Second'),
    ('Mechanical Engineering','MAJOR','MEE401','Machine Design','Stress analysis, fatigue, shafts, bearings, gears, belts, and brake design.',3,400,'First'),
    ('Mechanical Engineering','MAJOR','MEE402','Manufacturing Technology','Casting, forming, machining, welding, and quality control techniques.',3,400,'Second')
) v(dept,cat,code,title,descr,cu,lvl,sem)
JOIN department d ON d.department_name=v.dept
JOIN course_category cc ON cc.category_code=v.cat
JOIN student_level sl ON sl.level_number=v.lvl;

-- Biochemistry
INSERT INTO course (department_id, category_id, course_code, course_title, course_description, credit_units, level_id, semester_offered)
SELECT d.department_id, cc.category_id, v.code, v.title, v.descr, v.cu, sl.level_id, v.sem
FROM (VALUES
    ('Biochemistry','MAJOR','BCH101','General Chemistry for Life Sciences','Atomic structure, chemical bonding, organic functional groups, and aqueous solution chemistry.',3,100,'First'),
    ('Biochemistry','MAJOR','BCH102','Introduction to Biochemistry','Carbohydrates, lipids, proteins (amino acids, peptide bonds), and nucleic acid overview.',3,100,'Second'),
    ('Biochemistry','MAJOR','BCH201','Enzymology','Enzyme kinetics, Michaelis-Menten, inhibition types, coenzymes, and clinical assay applications.',3,200,'First'),
    ('Biochemistry','MAJOR','BCH202','Metabolism I','Glycolysis, gluconeogenesis, TCA cycle, oxidative phosphorylation, and metabolic regulation.',3,200,'Second'),
    ('Biochemistry','MAJOR','BCH301','Molecular Biology','DNA replication, transcription, translation, gene regulation, and recombinant DNA technology.',3,300,'First'),
    ('Biochemistry','MAJOR','BCH302','Biochemical Techniques','Spectrophotometry, centrifugation, chromatography (TLC, HPLC), electrophoresis, and PCR.',3,300,'Second'),
    ('Biochemistry','ELECTIVE','BCH303','Nutritional Biochemistry','Vitamins, essential minerals, dietary requirements, metabolic syndrome, and malnutrition.',3,300,'Second'),
    ('Biochemistry','MAJOR','BCH401','Clinical Biochemistry','Liver and kidney function tests, cardiac biomarkers, diabetes diagnostics, and lab interpretation.',3,400,'First')
) v(dept,cat,code,title,descr,cu,lvl,sem)
JOIN department d ON d.department_name=v.dept
JOIN course_category cc ON cc.category_code=v.cat
JOIN student_level sl ON sl.level_number=v.lvl;
GO

-- ============================================================
-- 11. COURSE PREREQUISITES
-- ============================================================
INSERT INTO course_prerequisite (course_id, required_course_id, min_grade)
SELECT c1.course_id, c2.course_id, v.mg
FROM (VALUES
    ('CSC201','CSC102','E'),('CSC202','CSC102','E'),
    ('CSC301','CSC201','E'),('CSC302','CSC201','E'),
    ('CSC401','CSC302','E'),('CSC401','CSC303','E'),
    ('AIT301','AIT202','D'),('AIT302','AIT301','D'),
    ('ECO301','ECO201','C'),('ECO401','ECO301','C'),
    ('LAW201','LAW102','E'),('LAW301','LAW201','E'),
    ('BCH202','BCH201','E'),('BCH301','BCH202','E'),
    ('MEE202','MEE201','E'),
    ('SWE301','SWE201','E'),('CYB301','CYB201','E'),
    ('MAT202','MAT201','E'),('ACC301','ACC201','E')
) v(c,r,mg)
JOIN course c1 ON c1.course_code=v.c
JOIN course c2 ON c2.course_code=v.r;
GO

-- ============================================================
-- 12. PROGRAMME-COURSE MAPPINGS
-- ============================================================

-- SER001 → every programme
INSERT INTO programme_course (programme_id, course_id, course_type, is_compulsory)
SELECT p.programme_id, c.course_id, 'COMPULSORY_SE', 1
FROM programme p CROSS JOIN course c WHERE c.course_code='SER001';
GO

-- B.Sc Computer Science
INSERT INTO programme_course (programme_id, course_id, course_type, is_compulsory)
SELECT p.programme_id, c.course_id, 'MAJOR', 1
FROM programme p JOIN course c ON 1=1
WHERE p.programme_name='B.Sc Computer Science'
  AND c.course_code IN ('CSC101','CSC102','CSC103','CSC201','CSC202','CSC203','CSC204',
                        'CSC301','CSC302','CSC303','CSC304','CSC401','CSC402','CSC403','CSC404');

INSERT INTO programme_course (programme_id, course_id, course_type, is_compulsory)
SELECT p.programme_id, c.course_id, 'ELECTIVE', 0
FROM programme p JOIN course c ON 1=1
WHERE p.programme_name='B.Sc Computer Science'
  AND c.course_code IN ('CSC305','CSC306','CSC405','CSC406','SWE201','AIT201','CYB201');
GO

-- B.Sc Artificial Intelligence
INSERT INTO programme_course (programme_id, course_id, course_type, is_compulsory)
SELECT p.programme_id, c.course_id, 'MAJOR', 1
FROM programme p JOIN course c ON 1=1
WHERE p.programme_name='B.Sc Artificial Intelligence'
  AND c.course_code IN ('AIT101','AIT201','AIT202','AIT301','AIT302','AIT401',
                        'CSC101','CSC102','MAT101','MAT201');

INSERT INTO programme_course (programme_id, course_id, course_type, is_compulsory)
SELECT p.programme_id, c.course_id, 'ELECTIVE', 0
FROM programme p JOIN course c ON 1=1
WHERE p.programme_name='B.Sc Artificial Intelligence'
  AND c.course_code IN ('AIT402','CSC302','CSC303','CYB201','CSC406');
GO

-- B.Sc Economics
INSERT INTO programme_course (programme_id, course_id, course_type, is_compulsory)
SELECT p.programme_id, c.course_id, 'MAJOR', 1
FROM programme p JOIN course c ON 1=1
WHERE p.programme_name='B.Sc Economics'
  AND c.course_code IN ('ECO101','ECO102','ECO201','ECO202','ECO301','ECO302','ECO401',
                        'MAT101','MAT102','MAT201');

INSERT INTO programme_course (programme_id, course_id, course_type, is_compulsory)
SELECT p.programme_id, c.course_id, 'ELECTIVE', 0
FROM programme p JOIN course c ON 1=1
WHERE p.programme_name='B.Sc Economics'
  AND c.course_code IN ('ECO303','ECO402','ACC101','MAT302');
GO

-- B.Sc Accounting
INSERT INTO programme_course (programme_id, course_id, course_type, is_compulsory)
SELECT p.programme_id, c.course_id, 'MAJOR', 1
FROM programme p JOIN course c ON 1=1
WHERE p.programme_name='B.Sc Accounting'
  AND c.course_code IN ('ACC101','ACC102','ACC201','ACC301','ACC302','ACC401','ECO101','ECO102','MAT101');

INSERT INTO programme_course (programme_id, course_id, course_type, is_compulsory)
SELECT p.programme_id, c.course_id, 'ELECTIVE', 0
FROM programme p JOIN course c ON 1=1
WHERE p.programme_name='B.Sc Accounting'
  AND c.course_code IN ('ACC303','ECO201','LAW102');
GO

-- LL.B Law
INSERT INTO programme_course (programme_id, course_id, course_type, is_compulsory)
SELECT p.programme_id, c.course_id, 'MAJOR', 1
FROM programme p JOIN course c ON 1=1
WHERE p.programme_name='LL.B Law'
  AND c.course_code IN ('LAW101','LAW102','LAW201','LAW202','LAW301','LAW302','LAW401','LAW402');

INSERT INTO programme_course (programme_id, course_id, course_type, is_compulsory)
SELECT p.programme_id, c.course_id, 'ELECTIVE', 0
FROM programme p JOIN course c ON 1=1
WHERE p.programme_name='LL.B Law' AND c.course_code IN ('LAW303','ECO101');
GO

-- B.Eng Mechanical Engineering
INSERT INTO programme_course (programme_id, course_id, course_type, is_compulsory)
SELECT p.programme_id, c.course_id, 'MAJOR', 1
FROM programme p JOIN course c ON 1=1
WHERE p.programme_name='B.Eng Mechanical Engineering'
  AND c.course_code IN ('MEE101','MEE102','MEE201','MEE202','MEE301','MEE302',
                        'MEE401','MEE402','MAT101','MAT102','MAT201');

INSERT INTO programme_course (programme_id, course_id, course_type, is_compulsory)
SELECT p.programme_id, c.course_id, 'ELECTIVE', 0
FROM programme p JOIN course c ON 1=1
WHERE p.programme_name='B.Eng Mechanical Engineering'
  AND c.course_code IN ('MEE303','CSC101','MAT302');
GO

-- B.Sc Biochemistry
INSERT INTO programme_course (programme_id, course_id, course_type, is_compulsory)
SELECT p.programme_id, c.course_id, 'MAJOR', 1
FROM programme p JOIN course c ON 1=1
WHERE p.programme_name='B.Sc Biochemistry'
  AND c.course_code IN ('BCH101','BCH102','BCH201','BCH202','BCH301','BCH302','BCH401','MAT101','CSC101');

INSERT INTO programme_course (programme_id, course_id, course_type, is_compulsory)
SELECT p.programme_id, c.course_id, 'ELECTIVE', 0
FROM programme p JOIN course c ON 1=1
WHERE p.programme_name='B.Sc Biochemistry' AND c.course_code IN ('BCH303','AIT201');
GO

-- ============================================================
-- 13. STAFF
-- ============================================================
INSERT INTO staff (staff_no, first_name, last_name, department_id, designation, email)
SELECT v.sno, v.fn, v.ln, d.department_id, v.desig, v.email
FROM (VALUES
    ('CST/STA/001','Adewale',   'Adeyemi',   'Computer Science',            'Professor',          'adeyemi@luxuniv.edu.ng'),
    ('CST/STA/002','Funmilayo', 'Okonkwo',   'Computer Science',            'Senior Lecturer',    'okonkwo@luxuniv.edu.ng'),
    ('CST/STA/003','Emeka',     'Nwachukwu', 'Artificial Intelligence',     'Lecturer I',         'nwachukwu@luxuniv.edu.ng'),
    ('CST/STA/004','Chidinma',  'Eze',       'Cybersecurity',               'Lecturer II',        'eze@luxuniv.edu.ng'),
    ('SOC/STA/001','Bola',      'Adesanya',  'Economics',                   'Professor',          'adesanya@luxuniv.edu.ng'),
    ('SOC/STA/002','Yinka',     'Fashola',   'Economics',                   'Associate Professor','fashola@luxuniv.edu.ng'),
    ('ADMIN/STA/001','Ngozi',   'Okafor',    'Accounting',                  'Senior Lecturer',    'okafor@luxuniv.edu.ng'),
    ('ARTS/STA/001','Tunde',    'Bakare',    'English',                     'Professor',          'bakare@luxuniv.edu.ng'),
    ('LAW/STA/001', 'Amaka',    'Igwe',      'Private and Property Law',    'Professor',          'igwe@luxuniv.edu.ng'),
    ('TECH/STA/001','Segun',    'Afolabi',   'Mechanical Engineering',      'Professor',          'afolabi@luxuniv.edu.ng'),
    ('SCI/STA/001', 'Kemi',     'Adetoye',   'Biochemistry',                'Senior Lecturer',    'adetoye@luxuniv.edu.ng')
) v(sno,fn,ln,dept,desig,email)
JOIN department d ON d.department_name=v.dept;
GO

-- ============================================================
-- 14. STUDENTS
-- ============================================================
INSERT INTO student (student_matric_no,first_name,last_name,middle_name,date_of_birth,
    gender,email,phone,state_of_origin,programme_id,current_level_id,admission_session_id,enrollment_status)
SELECT v.mat,v.fn,v.ln,v.mn,v.dob,v.gen,v.email,v.phone,v.soo,
       p.programme_id, sl.level_id, sess.session_id, v.status
FROM (VALUES
    ('CST/2024/001','Adebayo',  'Ogunleye','Folake',  '2006-03-15','Male',  'adebayo.ogunleye@luxuniv.edu.ng',  '08012345678','Oyo',    'B.Sc Computer Science',           '100L','2024/2025','Active'),
    ('CST/2024/002','Chioma',   'Nwosu',   'Grace',   '2006-07-22','Female','chioma.nwosu@luxuniv.edu.ng',      '08023456789','Anambra','B.Sc Artificial Intelligence',    '100L','2024/2025','Active'),
    ('CST/2022/001','Tunde',    'Adeyinka',NULL,      '2004-01-10','Male',  'tunde.adeyinka@luxuniv.edu.ng',    '08034567890','Osun',   'B.Sc Computer Science',           '300L','2022/2023','Active'),
    ('SOC/2024/001','Fatima',   'Musa',    'Bello',   '2006-05-18','Female','fatima.musa@luxuniv.edu.ng',       '08045678901','Kano',   'B.Sc Economics',                  '100L','2024/2025','Active'),
    ('ADMIN/2024/001','Emeka',  'Obiora',  'Chukwu',  '2006-09-30','Male',  'emeka.obiora@luxuniv.edu.ng',      '08056789012','Enugu',  'B.Sc Accounting',                 '100L','2024/2025','Active'),
    ('LAW/2020/001', 'Seun',    'Adeleke', 'Taiwo',   '2002-11-05','Male',  'seun.adeleke@luxuniv.edu.ng',      '08067890123','Lagos',  'LL.B Law',                        '400L','2021/2022','Active'),
    ('TECH/2023/001','Ibrahim', 'Danladi', NULL,      '2005-04-12','Male',  'ibrahim.danladi@luxuniv.edu.ng',   '08078901234','Plateau','B.Eng Mechanical Engineering',    '200L','2023/2024','Active'),
    ('SCI/2024/001', 'Aisha',   'Lawal',   'Hauwa',   '2006-08-25','Female','aisha.lawal@luxuniv.edu.ng',       '08089012345','Kaduna', 'B.Sc Biochemistry',               '100L','2024/2025','Active'),
    ('CST/2023/001', 'Blessing','Obi',     'Nneka',   '2005-12-14','Female','blessing.obi@luxuniv.edu.ng',      '08090123456','Imo',    'B.Sc Software Engineering',       '200L','2023/2024','Active'),
    ('CST/2021/001', 'Kunle',   'Abiodun', 'Rasheed', '2003-06-20','Male',  'kunle.abiodun@luxuniv.edu.ng',     '08001234567','Ogun',   'B.Sc Cybersecurity',              '400L','2021/2022','Active')
) v(mat,fn,ln,mn,dob,gen,email,phone,soo,prog,lvl,sess,status)
JOIN programme p ON p.programme_name=v.prog
JOIN student_level sl ON sl.level_name=v.lvl
JOIN academic_session sess ON sess.session_name=v.sess;
GO

-- ============================================================
-- 15. COURSE REGISTRATIONS
-- Semester IDs: 1=21/22 Fst, 2=21/22 Snd, 3=22/23 Fst,
--               4=22/23 Snd, 5=23/24 Fst, 6=23/24 Snd,
--               7=24/25 Fst, 8=24/25 Snd
-- ============================================================
INSERT INTO course_registration (student_id, course_id, semester_id, course_type_taken)
SELECT s.student_id, c.course_id, v.sem_id, v.ctype
FROM (VALUES
    ('CST/2024/001','SER001',7,'COMPULSORY_SE'),('CST/2024/001','CSC101',7,'MAJOR'),
    ('CST/2024/001','CSC103',7,'MAJOR'),('CST/2024/001','GST101',7,'MAJOR'),
    ('CST/2024/001','GST111',7,'MAJOR'),
    ('CST/2024/002','SER001',7,'COMPULSORY_SE'),('CST/2024/002','AIT101',7,'MAJOR'),
    ('CST/2024/002','CSC101',7,'MAJOR'),('CST/2024/002','CSC103',7,'MAJOR'),
    ('SOC/2024/001','SER001',7,'COMPULSORY_SE'),('SOC/2024/001','ECO101',7,'MAJOR'),
    ('SOC/2024/001','MAT101',7,'MAJOR'),('SOC/2024/001','GST101',7,'MAJOR'),
    ('ADMIN/2024/001','SER001',7,'COMPULSORY_SE'),('ADMIN/2024/001','ACC101',7,'MAJOR'),
    ('ADMIN/2024/001','ECO101',7,'MAJOR'),('ADMIN/2024/001','MAT101',7,'MAJOR'),
    ('SCI/2024/001','SER001',7,'COMPULSORY_SE'),('SCI/2024/001','BCH101',7,'MAJOR'),
    ('SCI/2024/001','MAT101',7,'MAJOR'),('SCI/2024/001','GST101',7,'MAJOR'),
    ('CST/2022/001','CSC301',5,'MAJOR'),('CST/2022/001','CSC302',5,'MAJOR'),
    ('CST/2022/001','CSC304',5,'MAJOR'),('CST/2022/001','CSC306',5,'MAJOR'),
    ('CST/2022/001','CSC305',5,'ELECTIVE')
) v(mat,ccode,sem_id,ctype)
JOIN student s ON s.student_matric_no=v.mat
JOIN course c ON c.course_code=v.ccode;
GO

-- ============================================================
-- 16. COURSE RESULTS (completed semester 5)
-- ============================================================
INSERT INTO course_result (registration_id, ca_score, exam_score, grade, grade_point, credit_units_earned, remark)
SELECT cr.registration_id, v.ca, v.ex, v.gr, v.gp, c.credit_units, 'Pass'
FROM (VALUES
    ('CST/2022/001','CSC301',35,45,'B',4.0),
    ('CST/2022/001','CSC302',38,40,'A',5.0),
    ('CST/2022/001','CSC304',30,32,'C',3.0),
    ('CST/2022/001','CSC306',28,30,'D',2.0),
    ('CST/2022/001','CSC305',20,22,'E',1.0)
) v(mat,ccode,ca,ex,gr,gp)
JOIN student s ON s.student_matric_no=v.mat
JOIN course c ON c.course_code=v.ccode
JOIN course_registration cr ON cr.student_id=s.student_id
    AND cr.course_id=c.course_id AND cr.semester_id=5;
GO

-- ============================================================
-- 17. COURSE ASSIGNMENTS
-- ============================================================
INSERT INTO course_assignment (course_id, semester_id, staff_id)
SELECT c.course_id, 7, st.staff_id
FROM (VALUES
    ('CSC101','CST/STA/001'),('CSC102','CST/STA/002'),
    ('AIT101','CST/STA/003'),('CYB101','CST/STA/004'),
    ('SER001','ARTS/STA/001'),('ECO101','SOC/STA/001'),
    ('ACC101','ADMIN/STA/001'),('BCH101','SCI/STA/001')
) v(ccode,sno)
JOIN course c ON c.course_code=v.ccode
JOIN staff st ON st.staff_no=v.sno;
GO

-- ============================================================
-- END OF 03_insert_sample_data.sql
-- ============================================================
