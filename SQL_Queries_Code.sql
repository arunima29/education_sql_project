-- Query 1
CREATE VIEW a1 AS
SELECT scs.student_id, COUNT(*)*10 AS Credits
FROM student_course_sharing scs
INNER JOIN enrollment AS e
ON scs.shared_with_student_id = e.student_id
WHERE scs.course_id = e.course_id
GROUP BY scs.student_id;
CREATE VIEW a2 AS
SELECT student_id, gift_amount AS Credits
FROM gift_card
GROUP BY student_id;
SELECT s.student_id, s.first_name, s.last_name, CONCAT("$ ", SUM(Credits)) AS total_credits
FROM student s INNER JOIN
(
SELECT *
FROM a1
UNION ALL
SELECT *
FROM a2
) a3
ON a3.student_id = s.student_id
GROUP BY s.student_id
ORDER BY SUM(Credits) DESC;


-- Query 2
SELECT
CASE WHEN Student_Age>=0 AND Student_Age<20 THEN "< 20"
WHEN Student_Age>=20 AND Student_Age<30 THEN "20-29"
WHEN Student_Age>=30 AND Student_Age<40 THEN "30-39"
WHEN Student_Age>=40 THEN ">= 40"
END AS Student_Age_Group,
COUNT(*) AS Number_of_Students,
CONCAT("$ ",ROUND(AVG(Average_Price),2)) AS Average_Price
FROM
(
SELECT ROUND(DATEDIFF(date(now()), s.DOB)/365,0) AS Student_Age, Average_Price
FROM student s INNER JOIN
(
SELECT e.student_id, ROUND(AVG(c.price),2) AS Average_Price
FROM enrollment e INNER JOIN course c
ON e.course_id = c.course_id
GROUP BY student_id
) AS ec
ON s.student_id = ec.student_id
) AS a4
GROUP BY Student_Age_Group
ORDER BY ROUND(AVG(Average_Price),2) DESC;


-- Query 3
SELECT
CASE WHEN a5.Video_Length_Per_Course>=0 AND a5.Video_Length_Per_Course<3 THEN "< 3"
WHEN a5.Video_Length_Per_Course>=3 AND a5.Video_Length_Per_Course<9 THEN "3-8"
WHEN a5.Video_Length_Per_Course>=9 AND a5.Video_Length_Per_Course<15 THEN "9-14"
WHEN a5.Video_Length_Per_Course>=15 AND a5.Video_Length_Per_Course<21 THEN "15-20"
WHEN a5.Video_Length_Per_Course>=21 THEN ">= 21"
END AS Video_Length_Interval_Hrs,
SUM(a6.Number_of_Enrollments_Per_Course) AS Number_of_Enrollments
FROM
(
SELECT c.course_id, ROUND(SUM(length_min)/60,0) AS Video_Length_Per_Course
FROM course c INNER JOIN video v
ON c.course_id = v.course_id
GROUP BY c.course_id
) AS a5
INNER JOIN
(
SELECT c.course_id, COUNT(*) AS Number_of_Enrollments_Per_Course
FROM course c INNER JOIN enrollment e
ON c.course_id = e.course_id
GROUP BY c.course_id
) AS a6
ON a5.course_id = a6.course_id
GROUP BY Video_Length_Interval_Hrs
ORDER BY Number_of_Enrollments DESC;


-- Query 4
CREATE VIEW Course_difficulty_number AS
WITH CTE_Quiz_difficulty_level(course_id, quiz_id, Difficulty_score ) AS (
SELECT course_id, quiz_id, CASE
WHEN difficulty_level = 'Easy' THEN 1
WHEN difficulty_level = 'Medium' THEN 2
WHEN difficulty_level = 'Hard' THEN 3
WHEN difficulty_level = 'Very_Hard' THEN 4
END As Difficulty_score
FROM quiz
ORDER BY course_id
)
SELECT course_id, FORMAT(AVG(Difficulty_score),2)AS
Course_Difficulty_Number
FROM CTE_Quiz_difficulty_level
GROUP BY course_id
ORDER BY course_id ASC;
CREATE VIEW Course_Difficulties_AND_Pass_FAIL AS (
WITH CTE_Course_Difficulty (course_id, Course_Difficulty) AS (
SELECT course_id, CASE
WHEN Course_Difficulty_Number >= 3.5 THEN "Very_Hard"
WHEN Course_Difficulty_Number < 3.5 AND Course_Difficulty_Number >= 2.5 THEN "Hard"
WHEN Course_Difficulty_Number < 2.5
AND Course_Difficulty_Number >= 1.5 THEN "Medium"
WHEN Course_Difficulty_Number < 1.5 THEN "Easy"
END AS Course_Difficulty
FROM Course_difficulty_number
)
SELECT COUNT(*) AS Number, Course_Difficulty, CASE
WHEN final_grade >= 50 THEN "Pass"
WHEN final_grade <50 THEN "Fail"
END AS Pass_Fail
FROM CTE_Course_Difficulty INNER JOIN course USING(course_id) INNER JOIN enrollment
USING(course_id)
GROUP BY Course_Difficulty, Pass_Fail
ORDER BY COurse_Difficulty DESC
);
SELECT FORMAT((Temp1.Number/Temp2.Total)*100, 2) AS Passing_Rate_Percent,
Temp1.Course_Difficulty
FROM Course_Difficulties_AND_Pass_FAIL AS Temp1 LEFT JOIN (
SELECT SUM(Number) AS Total
,Course_Difficulty FROM Course_Difficulties_AND_Pass_FAIL GROUP BY Course_Difficulty) AS Temp2
ON Temp1.Course_Difficulty = Temp2.Course_Difficulty
WHERE Pass_Fail = "Pass"
ORDER BY Passing_Rate_Percent DESC;


-- Query 5
-- Attention-needing Customers! An RFM Model (Recency-Frequency-Monetary) for Customer Segmentation
-- Creating a table with all the information we need to segment the customers
CREATE VIEW All_Needed_Data AS (
SELECT student_id, DATEDIFF("2020-11-09", MAX(purchase_date))
AS Days_Since_Last_Purchase, COUNT(*) AS Purchase_Frequency, SUM(Price)
AS Total_Monetary_Value
FROM enrollment INNER JOIN course USING(course_id)
GROUP BY student_id
);
-- Labeling customers using CASE statements. The details of labeling are explained in query assumptions.
CREATE VIEW Labeled_Customers AS (
SELECT student_id, Days_Since_Last_Purchase, Purchase_Frequency, Total_Monetary_Value,
CASE
WHEN Purchase_Frequency > (SELECT AVG(Purchase_Frequency) FROM All_Needed_Data) THEN "Loyal"
WHEN Purchase_Frequency < (SELECT AVG(Purchase_Frequency) FROM All_Needed_Data) THEN "Normal"
END AS Customer_Frequency_Type,
CASE
WHEN Days_Since_Last_Purchase > (SELECT AVG(Days_Since_Last_Purchase)
FROM All_Needed_Data) THEN "IDLE"
WHEN Days_Since_Last_Purchase < (SELECT AVG(Days_Since_Last_Purchase)
FROM All_Needed_Data) THEN "ACTIVE"
END AS Customer_Status,
CASE
WHEN Total_Monetary_Value > (SELECT AVG(Total_Monetary_Value) FROM All_Needed_Data) THEN
"Valuable"
WHEN Total_Monetary_Value < (SELECT AVG(Total_Monetary_Value) FROM All_Needed_Data) THEN
"Typical"
END AS Customer_Value_Type
FROM All_Needed_Data );

-- Finally, we identify the customers who need attention by filtering on those who are 'Loyal', 'Valuable', and 'IDLE'
SELECT student_id, Days_Since_Last_Purchase, Purchase_Frequency, Total_Monetary_Value, Customer
_Frequency_Type, Customer_Value_Type, Customer_Status
FROM Labeled_Customers
WHERE Customer_Frequency_Type = 'Loyal' AND Customer_Value_Type = 'Valuable'
AND Customer_Status = 'IDLE'
ORDER BY Days_Since_Last_Purchase DESC;


-- Query 6
-- create a table with the total number of shares for each course
CREATE VIEW course_num_shares AS
SELECT student_course_sharing.course_id, COUNT(student_course_sharing.course_id)
AS num_shares
FROM student_course_sharing
GROUP BY student_course_sharing.course_id
ORDER BY num_shares DESC;
-- create a table with the maximum number of shares for each category

CREATE VIEW cat_max_shares AS
SELECT category.category_id, MAX(course_num_shares.num_shares) AS max_shares
FROM category INNER JOIN course ON course.category_id = category.category_id
INNER JOIN
course_num_shares ON course.course_id = course_num_shares.course_id
GROUP BY category.category_id;
-- inner join the two views above with the course and category tables to find the course(s) in each
-- category with the maximum number of shares
SELECT category.category, course.course_title, cat_max_shares.max_shares
FROM cat_max_shares INNER JOIN course ON course.category_id = cat_max_shares.category_id
INNER JOIN course_num_shares ON course_num_shares.course_id = course.course_id
INNER JOIN category ON cat_max_shares.category_id = category.category_id
WHERE course_num_shares.num_shares = cat_max_shares.max_shares
AND cat_max_shares.category_id NOT IN (SELECT category.subcategory_id FROM category);


-- Query 7
-- create a table containing info about the number of enrollments in each category in each region
CREATE VIEW region_cat_qty AS
SELECT student.region, category.category_id, COUNT(category.category_id) AS num_enroll
FROM student INNER JOIN enrollment ON student.student_id = enrollment.student_id
INNER JOIN course ON enrollment.course_id = course.course_id
INNER JOIN category ON course.category_id = category.category_id
WHERE category.category_id NOT IN (SELECT category.subcategory_id FROM category)
GROUP BY student.region , category.category_id
ORDER BY student.region ASC , quantity DESC;

-- get the category with max number of enrollments (most popular) in each region
SELECT region_cat_qty.region, category.category AS MostPopularCategory, max_enroll AS NumOfEnroll
FROM
(SELECT region_cat_qty.region, MAX(quantity) AS max_enroll
FROM region_cat_qty
GROUP BY region_cat_qty.region) AS subquery
INNER JOIN region_cat_qty ON subquery.region = region_cat_qty.region
AND subquery.max_enroll = region_cat_qty.quantity
INNER JOIN category ON category.category_id = region_cat_qty.category_id
ORDER BY max_enroll DESC;


-- Query 8
SELECT education_level AS EducationLevel, FORMAT(avg(enrollment.final_grade),2) AS
AverageFinalGrade
FROM student, enrollment, (SELECT enrollment.student_id, enrollment.final_grade FROM enrollment
WHERE course_id = 22) AS t1
WHERE student.student_id = enrollment.student_id
GROUP BY education_level;


-- Query 9
SELECT course.category_id, instructor.education_level,
FORMAT(AVG(enrollment.course_rating),2) AS avg_rating
FROM enrollment INNER JOIN course ON enrollment.course_id = course.course_id
INNER JOIN course_instructor ON course.course_id = course_instructor.course_id
INNER JOIN instructor ON instructor.instructor_id = course_instructor.instructor_id
WHERE course.category_id NOT IN (SELECT category.subcategory_id FROM category)
GROUP BY course.category_id , instructor.education_level
ORDER BY course.category_id;


-- Query 10
CREATE VIEW CourseSharing AS
(SELECT student_id, shared_with_student_id, course_id
FROM student_course_sharing);
SELECT COUNT(DISTINCT enrollment_id) AS TotalEnrollments ,
COUNT(DISTINCT CourseSharing.student_id) AS EnrollmentsAfterRecommendation
FROM enrollment, CourseSharing
WHERE CourseSharing.shared_with_student_id = enrollment.student_id;


-- Query 11
-- Create a table containing the information about the total number of enrollments of each
-- course in each category
CREATE VIEW course_totalEnroll AS
SELECT category, course.course_title, t1.TotalEnrollments
FROM course, category,
(SELECT course_id, COUNT(enrollment.enrollment_id) AS TotalEnrollments
FROM enrollment
GROUP BY course_id
ORDER BY TotalEnrollments DESC) AS t1
WHERE t1.course_id = course.course_id
AND course.category_id = category.category_id
AND course.price != 0
ORDER BY category, TotalEnrollments DESC;
-- Select the course with the highest total number of enrollments (bestseller) in each category
WITH category_enroll_rank AS
(SELECT category, course_title AS BestSeller, TotalEnrollments,
ROW_NUMBER() OVER(PARTITION BY course_totalEnroll.category ORDER BY TotalEnrollments DESC) `rank`
FROM course_totalEnroll)
SELECT category, BestSeller, TotalEnrollments
FROM category_enroll_rank
WHERE `rank` = 1;


-- Query 12
(SELECT course_title AS CourseName, COUNT(enrollment_id) AS TotalEnrollment,
"Bachelor" AS Degree
FROM enrollment, course, student
WHERE enrollment.course_id = course.course_id
AND enrollment.student_id = student.student_id
AND education_level = "Bachelor"
GROUP BY course_title
ORDER BY TotalEnrollment DESC
LIMIT 5)
UNION
(SELECT course_title AS CourseName, COUNT(enrollment_id) AS TotalEnrollment,
"Master" AS Degree
FROM enrollment, course, student
WHERE enrollment.course_id = course.course_id
AND enrollment.student_id = student.student_id
AND education_level = "Master"
GROUP BY course_title
ORDER BY TotalEnrollment DESC
LIMIT 5);


-- Query 13
SELECT DISTINCT student.student_id FROM student
LEFT JOIN gift_card ON student.student_id = gift_card.student_id
WHERE gift_card.gift_card_id IS NOT NULL AND student.student_id IN
(SELECT DISTINCT enrollment.student_id FROM enrollment
INNER JOIN course ON enrollment.course_id = course.course_id
WHERE course.price != 0);


-- Query 14
SELECT (SELECT COUNT(course.course_id) FROM course WHERE course.price = 0)/COUNT(course.course_id) AS free_course_proportion,
(SELECT (SELECT COUNT(DISTINCT enrollment.student_id) FROM enrollment
INNER JOIN course ON enrollment.course_id = course.course_id
WHERE course.price = 0)/COUNT(student.student_id) FROM student) AS free_course_participation
FROM course;


-- Query 15
SELECT B.course_id, FORMAT(advanced_average,2)
AS advanced_average, FORMAT(beginner_average,2) AS beginner_average,
CASE WHEN advanced_average > beginner_average THEN 'True' ELSE 'False' END AS advanced_better
FROM
(SELECT enrollment.course_id, AVG(final_grade) AS advanced_average
FROM enrollment
WHERE prior_proficiency = 'Advanced'
GROUP BY enrollment.course_id) AS A INNER JOIN
(SELECT enrollment.course_id, AVG(final_grade) AS beginner_average
FROM enrollment
WHERE prior_proficiency = 'Beginner'
GROUP BY enrollment.course_id) AS B ON A.course_id = B.course_id
ORDER BY B.course_id;


-- Query 16
SELECT course_id, FORMAT(AVG(complete_period),2) AS Average_period
FROM
(SELECT student_id, course_id, DATEDIFF(completion_date,purchase_date) AS complete_period
FROM enrollment) AS CP
GROUP BY course_id
ORDER BY Average_period DESC;


-- Query 17
SELECT difficulty_level, quiz_type,COUNT(quiz_type) AS quantity, SUM(COUNT(quiz_type)) OVER
(PARTITION BY difficulty_level) AS Total
FROM quiz
GROUP BY difficulty_level, quiz_type
ORDER BY difficulty_level;


-- Query 18
SELECT T1.instructor_id, T1.first_name, T1.last_name, category_diversity, region_diversity FROM
(SELECT course_instructor.instructor_id, instructor.first_name, instructor.last_name,
COUNT(DISTINCT category.category_id) AS category_diversity
FROM category LEFT JOIN course ON category.category_id = course.category_id
INNER JOIN course_instructor ON course.course_id = course_instructor.course_id
INNER JOIN instructor ON course_instructor.instructor_id = instructor.instructor_id
GROUP BY instructor.instructor_id
ORDER BY category_diversity DESC) AS T1 INNER JOIN
(SELECT instructor.instructor_id, instructor.first_name, instructor.last_name, COUNT(DISTINCT student.region) AS region_diversity
FROM instructor,course_instructor,course,enrollment,student
WHERE instructor.instructor_id=course_instructor.instructor_id
AND course_instructor.course_id=course.course_id
AND course.course_id=enrollment.course_id
AND enrollment.student_id=student.student_id
GROUP BY instructor.instructor_id
ORDER BY region_diversity DESC) AS T2 ON T1.instructor_id = T2.instructor_id
LIMIT 10;


-- Query 19
SELECT E.student_id, E.Total_enrollment, S.Total_be_Shared
FROM
(SELECT student_id, COUNT(enrollment_id) AS Total_enrollment
FROM enrollment
GROUP BY student_id
ORDER BY COUNT(enrollment_id) DESC ) AS E,
(SELECT student_id, COUNT(shared_with_student_id) AS Total_be_Shared
FROM student_course_sharing
GROUP BY student_id
ORDER BY COUNT(shared_with_student_id) DESC) AS S
WHERE E.student_id=S.student_id
AND E.Total_enrollment > S.Total_be_Shared;

