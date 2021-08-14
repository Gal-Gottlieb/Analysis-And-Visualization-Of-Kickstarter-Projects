
-- 1) Creating database for the project

Create database kickstar;

-- 2) Creating a backup for the database

BACKUP DATABASE kickstar
TO DISK = 'filepath';

-- 3) Exporting the Excel file by using SQL server 2017 export and import data

-- 4) Run the database

use kickstar;

-- 5) Making a copy of the original table and insert the data in it

SELECT * INTO kickstarter_project
FROM kickstarter_projects$;

-- 6) Get a glimpse of the data by selecting the first five rows with all the columns

select *
from kickstarter_project
order by ID
offset 0 rows
fetch next 5 rows only;


-- Data Cleaning and data management and integration (DMI)

-- 1) Finding outliers in the Name column

select name, count(*)
from kickstarter_project
group by Name
having count(*)>1
order by count(*) desc;

-- 2) Changing NULL values in the Name column to 'Unknown'

update kickstarter_project
set name =  replace(name,'#NAME?','Unkwown')
from kickstarter_project
where name like '#NAME?';

-- 3) Giving a single value instead of three to projects whose name indicates that they were canceled

update kickstarter_project
set name = replace(name,'N/A (Canceled)','canceled')
from kickstarter_project
where name like 'N/A (Canceled)';

update kickstarter_project
set name = replace(name,'cancelled (Canceled)','canceled')
from kickstarter_project
where name like 'cancelled (Canceled)';

update kickstarter_project
set name = replace(name,'canceled (Canceled)','canceled')
from kickstarter_project
where name like 'canceled (Canceled)';


-- 4) Update State column name to Projectstate so wouldn't be confusing as similar to state as a country

sp_rename 'kickstarter_project.State', 'Projectstate', 'COLUMN';


-- 5) Verifying whether any column's NULL values exist in the database

select *
from kickstarter_project
where name is null or Category is null or Projectstate is null or country is null or Subcategory is null or Launched is null
or Deadline is null or Pledged is null or Backers is null or Projectstate is null;

-- 6) Looking for outliers in the columns Goal, Pledged, and Backers

select *
from kickstarter_project
where goal<=0 or Pledged<0 or Backers<0;

-- 7) Deleting outliers where Goal is equal to zero

delete from kickstarter_project
where goal=0;

-- 8) Checking for duplication of categories and subcategories

select distinct Category,Subcategory
from kickstarter_project
order by Category, Subcategory;

-- 9) Checking that there are no duplicate countries

select distinct(Country)
from kickstarter_project
order by Country;

-- 10) Making sure the primary key values (ID) do not repeat

select count(*)
from kickstarter_project
group by id
having count(id)>1;

-- 11) Adding constraints to the table's columns

-- a) To ensure new values will not be 0 or less, add a constraint to the goal column

alter table kickstarter_project
add CONSTRAINT goal_constraint check (goal>0);

-- b) Adding a constraint to pledged column to make sure values aren't less than 0

alter table kickstarter_project
add CONSTRAINT pledged_constraint check (pledged>=0);

-- c) Adding a constraint to backers column to make sure values aren't less than 0

alter table kickstarter_project
add CONSTRAINT backers_constraint check (backers>=0);

-- d) To make sure that the deadline is not earlier than the launch time, add a constraint to the deadline column

alter table kickstarter_project
add CONSTRAINT deadline_date_constraint check (deadline>=launched);

-- Data exploration

-- 1) Identifying possible project states

select distinct(Projectstate)
from kickstarter_project
order by Projectstate;

-- 2) Checking outliers in launched and deadline columns

-- a) Checking the minimum and maximum data of project launch and deadline

select min(Launched) as 'Min Launched Date' ,max(Launched) as 'Max Launched Date'
from kickstarter_project;

select min(Deadline) as 'Min Deadline Date' ,max(Deadline) as 'Max Deadline Date'
from kickstarter_project;

-- b) Project numbers by year to identify outliers

select year(Launched) [Year],count(*) 'Number of Projects'
from kickstarter_project
group by year(Launched);

-- 3) look at the Max launched date in 2018

select max(Launched) as 'Max Launched Date'
from kickstarter_project
where year(Launched)='2018'
group by year(Launched);

-- * As the last project for 2018 was launched in January, the data is not reliable for trend analysis by year

-- 4) A look at the Min launched date in 2009

select min(Launched) as 'Min Launched Date' ,max(Launched) as 'Max Launched Date'
from kickstarter_project
where year(Launched)='2009'
group by year(Launched);

-- * Due to the fact that the first project in 2009 was launched in April, the data cannot be used to calculate trending by year

-- 5) Checking the hours project distribution in different countries

select Country, datepart(hour, Launched) [time], count(*)
from kickstarter_project
group by country, datepart(hour, Launched)
order by country, count(*) desc;

-- * As the time is probably monitored by United States time, Australia and Japan launch during the evening, as well as New Zealand

/* 6) Annual goal completion by category and project 
Where project's goal greater than 1,000
Table used in figures 1 and 3
*/

select category,Subcategory,year(launched) [year] ,month(Launched) [Month],country,Goal,pledged,
pledged/goal  as 'Goal completion'
from kickstarter_project
where goal>1000 
order by [Goal completion] desc, Pledged desc;

/* 7) Top 20,000 projects in terms of goal completion rate
Where project's goal greater than 1,000
*/

select
category,Subcategory,year(launched) [year],country,Goal,pledged, case when pledged=0 then 0 
else round(pledged/goal,0) end as 'Goal completion'
from kickstarter_project
where goal>1000
order by [Goal completion] desc
offset 0 rows
fetch next 20000 rows only;


/* 8) Top 20 projects in terms of goal completion rate
Where project's goal greater than 1,000
*/

select name,category, subcategory, year(launched) [year],country,goal,pledged, round(Pledged/goal,0) as 'Goal completion' 
from kickstarter_project
where goal>1000
order by [Goal completion] desc
offset 0 rows
fetch next 20 rows only;

-- 9) Median vs. AVG of pledged and goal of projects 

select round(PERCENTILE_CONT(0.5) within group (order by pledged) over (),0) as 'Median Pledged', round(avg(pledged) over(),0)
as 'AVG Pledged',round(STDEV(pledged) over(),0) as 'STDEV Pledged',  
round(PERCENTILE_CONT(0.5) within group (order by goal) over (),0) as 'Median Goal', round(avg(goal) over(),0)
as 'AVG Goal',round(STDEV(goal) over(),0) as 'STDEV Goal'
from kickstarter_project
order by [Median Pledged]
offset 0 rows
fetch next 1 rows only;

-- * Average is higher with Median pledged, as extreme values will cause the Average to increase.

-- 10) -- Statistics by year of launch, category, and pledge Between 2010 and 2017

select distinct year(Launched) [Year] ,Category ,count(*) over (partition by year(Launched), category) as 'Number of projects'
,round(avg(pledged) over(partition by year(Launched),category),0) as 'AVG pledged',
round(PERCENTILE_CONT(0.25) within group (order by pledged) over (partition by year(Launched),category),0) 
as 'Pledged - 25thPerc',  round(PERCENTILE_CONT(0.5) within group (order by pledged) over (partition by year(Launched),category),0) 
as 'Median', round(PERCENTILE_CONT(0.75) within group (order by pledged) over (partition by year(Launched),category),0)
as 'Pledged - 75thPerc', max(pledged) over (partition by year(Launched),category)  as 'Max Pledged'
from kickstarter_project
where year(Launched) not in ('2018','2009')
order by year(Launched), Category;

-- 11) Statistics by month of launched, category and pledged Between 2010 and 2017

select distinct month(Launched) [Month] ,Category ,count(*) over (partition by month(Launched), category) as 'Number of projects'
,round(avg(pledged) over(partition by month(Launched),category),0) as 'AVG pledged',
round(PERCENTILE_CONT(0.25) within group (order by pledged) over (partition by month(Launched),category),0) 
as 'Pledged - 25thPerc',  round(PERCENTILE_CONT(0.5) within group (order by pledged) over (partition by month(Launched),category),0) 
as 'Median', round(PERCENTILE_CONT(0.75) within group (order by pledged) over (partition by month(Launched),category),0)
as 'Pledged - 75thPerc', max(pledged) over (partition by month(Launched),category)  as 'Max Pledged'
from kickstarter_project
where year(Launched) not in ('2018','2009')
order by month(Launched), Category;


/* 12) Stats on pledged funds by country and category Between 2010 and 2017
Where project's goal greater than 1,000
*/

with cte2 as(
select distinct Country,Category ,count(*) over (partition by Country, category) as 'Number of projects'
,round(avg(pledged) over(partition by Country,category),0) as 'AVG pledged',
round(PERCENTILE_CONT(0.25) within group (order by pledged) over (partition by Country,category),0) 
as 'Pledged - 25thPerc',  round(PERCENTILE_CONT(0.5) within group (order by pledged) over (partition by Country,category),0) 
as 'Median', round(PERCENTILE_CONT(0.75) within group (order by pledged) over (partition by Country,category),0)
as 'Pledged - 75thPerc', max(pledged) over (partition by Country,category)  as 'Max Pledged'
from kickstarter_project)
select *
from cte2
where [Number of projects]>100
order by Country, Category;

/* 13) Stats on pledged funds by  category and sub category
Where project's goal greater than 1,000
*/

with cte3 as(
select distinct Category,subcategory ,count(*) over (partition by category,subcategory) as 'Number of projects'
,round(avg(pledged) over(partition by category,subcategory),0) as 'AVG pledged', 
round(STDEV(pledged) over(partition by category,subcategory),0) as 'STDEV',
round(PERCENTILE_CONT(0.25) within group (order by pledged) over (partition by category,subcategory),0) 
as 'Pledged - 25thPerc',  round(PERCENTILE_CONT(0.5) within group (order by pledged) over (partition by category,subcategory),0) 
as 'Median', round(PERCENTILE_CONT(0.75) within group (order by pledged) over (partition by category,subcategory),0)
as 'Pledged - 75thPerc', max(pledged) over (partition by category,subcategory)  as 'Max Pledged'
from kickstarter_project)
select *
from cte3
where [Number of projects]>100
order by Category,Subcategory;

-- 14) Duration of campaigns by country, by category, by subcategory, and by successful and unsuccessful projects

select q1.Country,Q1.Category,Q1.Subcategory,Q1.[AVG Succsesful campaign time in days],
Q2.[AVG not successful campaign time in days]
from(
select  distinct 
country,Category,Subcategory,
avg(datediff(day, launched,Deadline)) over(partition by category, subcategory)
as 'AVG Succsesful campaign time in days'
from kickstarter_project
where Projectstate like 'successful'
) as Q1
inner join
(
select  distinct 
country,Category,Subcategory,
avg(datediff(day, launched,Deadline)) over(partition by category, subcategory)
as 'AVG not successful campaign time in days'
from kickstarter_project
where Projectstate not like 'successful'
) as Q2
on q1.Country=q2.Country and Q1.Category=Q2.Category AND Q1.Subcategory=Q2.Subcategory 
order by q1.Country,q1.Category,q1.Subcategory;

-- 15) The number of projects by country

-- a) The number of projects by each country

select Country,category, count(*) as 'Number of Projects'
from kickstarter_project
group by Country,Category
order by country, Category;

-- b) Number of projects by USA vs. not USA

select count(*) as 'Count','USA' as 'USA or not'
from kickstarter_project
where country  like '%states'
union
select count(*) ,'Not USA'
from kickstarter_projects$
where country not like '%states';

-- 16) Success of project in USA by project's launch hour

select distinct Country, datepart(hour, Launched) [time], Projectstate, count(*) over
(partition by country, datepart(hour, Launched),projectstate) as 'Number of Projects'
from kickstarter_project
where country like 'united states' and Projectstate in ('successful','failed')
order by time,Projectstate;

/* 
17) Project's success by Category, subcategory, country and year between 2010 and 2017
Where project's goal greater than 1,000
Table used in Figure 4
*/

select q1.Category,q1.Subcategory,q1.Country,q1.Year,q1.[Number of successful Projects],q2.[Number of failed Projects],
q1.[Number of successful Projects]/(q2.[Number of failed Projects]+q1.[Number of successful Projects]) 
as 'Success ratio'
from(
select distinct country,category,Subcategory,datepart(Year, Launched) [Year], count(*) over
(partition by category,Subcategory,Country, datepart(Year, Launched)) as 'Number of successful Projects'
from kickstarter_project
where  Projectstate like 'successful' and goal>1000 and year(Launched) not in ('2009','2018'))as Q1
inner join
(
select distinct country,category,Subcategory,datepart(Year, Launched) [Year], count(*) over
(partition by category,Subcategory,Country,datepart(Year, Launched)) as 'Number of failed Projects'
from kickstarter_project
where  Projectstate like 'failed' and goal>1000 and year(Launched) not in ('2009','2018'))as Q2
on q1.Year=q2.Year and q1.category=q2.category and q1.Country=q2.Country and q1.Subcategory=q2.Subcategory
order by category,Subcategory,Country,Year;

-- 18) Duration in days, Median Goal, Median Pledge and Average Number of Backers by year and category and by success

select distinct year(Launched) as 'Year', Category, Projectstate ,avg(datediff(dd,Launched,Deadline)) over 
(partition by year(Launched), projectstate, category)
as 'Project AVG Duration',  round(PERCENTILE_CONT(0.5) within group (order by goal) over (partition by year(Launched),
projectstate,category),0) 
as 'Median Goal',
round(PERCENTILE_CONT(0.5) within group (order by pledged) over (partition by year(Launched), projectstate,category),0) 
as 'Median Pledged',round(PERCENTILE_CONT(0.5) within group (order by pledged-goal) over (partition by category, subcategory,
projectstate),0) 
as 'Median Pledged minus Goal',round(PERCENTILE_CONT(0.5) within group (order by pledged/goal*100) over (partition by category,
subcategory, projectstate),0) 
as 'Median Pledged/Goal %',
round(avg(Backers) over(partition by year(Launched), projectstate,category),0) as 'Project AVG Backers'
from kickstarter_project
where Projectstate in ('successful','failed')
order by year, Category, Projectstate;

/* 19) Duration in days, Median Project's Goal, Median Pledge and average number of backers 
by category and subcategory and by success
*/

select distinct Category,Subcategory, Projectstate ,avg(datediff(dd,Launched,Deadline)) over 
(partition by category, subcategory, projectstate)
as 'Project AVG Duration',  round(PERCENTILE_CONT(0.5) within group (order by goal) over (partition by category, subcategory,
projectstate),0) 
as 'Median Goal',
round(PERCENTILE_CONT(0.5) within group (order by pledged) over (partition by category, subcategory, projectstate),0) 
as 'Median Pledged',round(PERCENTILE_CONT(0.5) within group (order by pledged-goal) over (partition by category, subcategory,
projectstate),0) 
as 'Median Pledged-Goal', round(PERCENTILE_CONT(0.5) within group (order by pledged/goal*100) over
(partition by category, subcategory, projectstate),2) 
as 'Median Pledged/Goal',
round(avg(Backers) over(partition by category, subcategory, projectstate),0) as 'Project AVG Backers'
from kickstarter_project
where Projectstate in ('successful','failed')
order by Category,Subcategory ,Projectstate;

-- 20) Duration in days, Median Project's Goal, Median Pledge and average number of backers by state and category and by success

select distinct country, Category, Projectstate ,avg(datediff(dd,Launched,Deadline)) over 
(partition by country, Category, Projectstate)
as 'Project AVG Duration',  round(PERCENTILE_CONT(0.5) within group (order by goal) over (partition by country, Category,
Projectstate),0) 
as 'Median Goal',
round(PERCENTILE_CONT(0.5) within group (order by pledged) over (partition by country, Category, Projectstate),0) 
as 'Median Pledged',round(PERCENTILE_CONT(0.5) within group (order by pledged-goal) over (partition by country, Category,
Projectstate),0) 
as 'Median Pledged-Goal', round(PERCENTILE_CONT(0.5) within group (order by pledged/goal) over
(partition by country, Category, Projectstate),2) 
as 'Median Pledged/Goal',
round(avg(Backers) over(partition by country, Category, Projectstate),0) as 'Project AVG Backers'
from kickstarter_project
where Projectstate in ('successful','failed')
order by country,Category ,Projectstate;

/* 
21) Project goal levels by percentiles based on year, category and subcategory for the years between 2010 and 2017 -
Table used in Figure 2
*/

select year(Launched)[Year],Name,Category,Subcategory,Goal,round(PERCENTILE_CONT(0.5) within group (order by goal) 
over (partition by year(Launched), Category, Subcategory),0) as 'Median Goal',
round(PERCENTILE_CONT(0.5) within group (order by goal) over (partition by year(Launched), Category),0)
as 'Median Goal by Year & Category',
case when goal > PERCENTILE_CONT(0.2) within group (order by goal) over (partition by year(Launched), Category, Subcategory) 
and Goal <= PERCENTILE_CONT(0.4) within group (order by goal) over (partition by year(Launched), Category, Subcategory) 
then 'Low'
when goal > PERCENTILE_CONT(0.4) within group (order by goal) over (partition by year(Launched), Category, Subcategory) 
and Goal <= PERCENTILE_CONT(0.6) within group (order by goal) over (partition by year(Launched), Category, Subcategory) 
then 'Regular'
when goal > PERCENTILE_CONT(0.6) within group (order by goal) over (partition by year(Launched), Category, Subcategory) 
and Goal <= PERCENTILE_CONT(0.8) within group (order by goal) over (partition by year(Launched), Category, Subcategory) 
then 'High'
When goal > PERCENTILE_CONT(0.8) within group (order by goal) over (partition by year(Launched), Category, Subcategory) 
then 'Very High'
else 'Very Low' end as 'Goal Level',
Projectstate, round(Pledged/Goal,2) as 'Goal Completion'
from kickstarter_project
where year(Launched) not in ('2009','2018')
order by year(Launched), Category, Subcategory, [Goal level];

/* 22) In addition to categories and subcategories by year and countries, the following metrics are used:
success ratio, average amount pledged, and average goal completion
*/

select q1.Category,q1.Subcategory,q1.Country,q1.Year,q1.[Successful Projects],
q2.[Unsuccessful Projects], 
q1.[Successful Projects]/(q2.[Unsuccessful Projects]+q1.[Successful Projects]) as 'Success Ratio %',
q1.[Successful Projects Rank],
rank() over (order by q1.[Successful Projects]/(q2.[Unsuccessful Projects]+q1.[Successful Projects]) desc) as
'Success Ratio %Rank', 
q1.[AVG Money Pledged], q1.[Ranking AVG Money Pldged], q1.[AVG Goal Completion], q1.[Ranking AVG goal completion%]
from(
select Category, Subcategory,country,year(Launched) [Year],count(*) as 'Successful Projects', 
rank() over (order by count(*) desc) as 'Successful Projects Rank', 
round(avg(pledged),0) as 'AVG Money Pledged',
rank() over (order by avg(pledged) desc) as 'Ranking AVG Money Pldged',
round(avg(pledged/goal),0) as 'AVG Goal Completion',
rank() over (order by avg(pledged/goal) desc) as 'Ranking AVG Goal Completion%'
from kickstarter_project
where Projectstate='successful' and year(Launched) not in ('2009','2018')
group by Category, Subcategory,country,year(Launched)) as q1
inner join
(
select Category, Subcategory,country,year(Launched) [Year],count(*) as 'Unsuccessful Projects'
from kickstarter_project
where Projectstate not like 'successful' and year(Launched) not in ('2009','2018')
group by Category, Subcategory,country,year(Launched)) as q2
on q1.Category=q2.Category and q1.Subcategory=q2.Subcategory and q1.Country=q2.Country and q1.Year=q2.Year
order by Category,Subcategory,Country,Year;

/* 23) Checking the percent of successful projects whithin projects that their state is successful or failed
Where their goal was above 1,000$ and they launced between 2010 and 2017
Result is used in Figure 4
*/

select count(*)*100 /((select count(*)
from kickstarter_project
where Projectstate='failed' and year(Launched) not in ('2009','2018') and goal>1000
)+count(*)) as 'successful projects %'
from kickstarter_project
where Projectstate='successful' and year(Launched) not in ('2009','2018') and goal>1000;
