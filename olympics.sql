create database olympics;

CREATE TABLE athlete_events (
    id          INT,
    name        VARCHAR(100),
    sex         VARCHAR(100),
    age         VARCHAR(100),
    height      VARCHAR(100),
    weight      VARCHAR(100),
    team        VARCHAR(100),
    noc         VARCHAR(100),
    games       VARCHAR(100),
    year        INT,
    season      VARCHAR(100),
    city        VARCHAR(100),
    sport       VARCHAR(100),
    event       VARCHAR(100),
    medal       VARCHAR(100)
);

select * from athlete_events;

show variables like 'local_infile';

set global local_infile = 1;

LOAD DATA local INFILE 'C:/Users/bittu/Downloads/archive/athlete_events.csv'
INTO TABLE athlete_events
FIELDS TERMINATED BY ','
enclosed by '"'
lines terminated by '\n'
IGNORE 1 ROWS;

select @@secure_file_priv;

select * from athlete_events;

select * from noc_regions;

-- 1. How many olympics games have been held? 
select count(distinct games) from athlete_events;

-- 2. List down all Olympics games held so far.
select distinct(year), season,city 
from athlete_events
order by year;

-- 3. Mention the total no of nations who participated in each olympics game?
select games, count(distinct region) as total_country
from athlete_events ae 
join noc_regions nc on ae.noc = nc.noc
group by games order by games;

-- 4. Which year saw the highest and lowest no of countries participating in olympics
(select year, count(distinct region) as total_participating
from athlete_events ae
inner join noc_regions nr on ae.noc = nr.noc
group by year
order by total_participating desc
limit 1)
union 
(select year, count(distinct region) as total_participating
from athlete_events ae
inner join noc_regions nr on ae.noc = nr.noc
group by year
order by total_participating asc
limit 1);

-- 5. Which nation has participated in all of the olympic games
with cte as 
	(select region, count(distinct(games)) as total_olympics_played 
	from athlete_events ae
	join noc_regions nr on ae.noc = nr.noc 
	group by region
	order by total_olympics_played
	)
select * from cte
where total_olympics_played = (select max(total_olympics_played) from cte);

-- 6. Identify the sport which was played in all summer olympics.

SELECT sport
FROM athlete_events
WHERE season = 'Summer'
GROUP BY sport
HAVING COUNT(DISTINCT games) = (
SELECT COUNT(DISTINCT games)
FROM
athlete_events
WHERE
season = 'Summer');



-- 7. Which Sports were just played only in one olympics season.
with cte as 
	(select sport, count(distinct games) as no_of_season_played
	from athlete_events
	group by sport
	order by sport,no_of_season_played
	)
select * from cte where no_of_season_played =1;

-- 8. Fetch the total no of sports played in each olympic games.
select games, count(distinct sport) as total_sports_played
from athlete_events
group by games
order by games;

-- 9. Fetch oldest athletes to win a gold medal
select name, age from athlete_events
where medal = 'Gold'
order by age desc
limit 1;

WITH ranked_athletes AS (
    SELECT name, age,
	dense_rank() OVER (ORDER BY age DESC) AS dr
    FROM athlete_events
    WHERE medal = 'Gold' AND age != 'NA'
)
SELECT name, age
FROM ranked_athletes
WHERE dr = 1;



-- 10. Find the Ratio of male and female athletes participated in all olympic games.
SELECT 
    
    (SUM(CASE WHEN sex = 'M' THEN 1 ELSE 0 END) * 100 / COUNT(*)) AS male_percentage,
    (SUM(CASE WHEN sex = 'F' THEN 1 ELSE 0 END) * 100 / COUNT(*)) AS female_percentage
FROM athlete_events;

-- 11. Fetch the top 5 athletes who have won the most gold medals.
with cte as 
	(select name,count(medal) as total_gold_medal,
    dense_rank() over(order by count(medal) desc) as rnk 
	from athlete_events
	where medal = 'Gold'
	group by name)
select * from cte where rnk<6;

-- 12. Fetch the top 5 athletes who have won the most medals (gold/silver/bronze).

with cte as 
	(select name,count(medal) as total_medal,
    dense_rank() over(order by count(medal) desc) as rnk 
	from athlete_events
    where medal !="Na"
	group by name)
select * from cte where rnk<6;

-- 13. Fetch the top 5 most successful countries in olympics. Success is defined by no of medals won.
with cte as 
	(select region, count(medal) as total_medal,
    dense_rank() over(order by count(medal) desc) as rnk 
	from athlete_events ae
    inner join noc_regions nr on ae.noc = nr.noc
    where medal !="Na"
	group by region)
select * from cte where rnk<6;

-- 14. List down total gold, silver and bronze medals won by each country.
select region,
	count(case when medal = 'Gold' then 1 end) as gold,
	count(case when medal = 'Silver' then 1 end) as silver,
	count(case when medal = 'Bronze' then 1 end) as bronze
from athlete_events ae
JOIN noc_regions nr ON ae.noc = nr.noc
group by region
order by gold desc,silver desc,bronze desc;

-- 15. List down total gold, silver and bronze medals won by each country corresponding to each olympic games.
select region, games,
	count(case when medal = 'Gold' then 1 end) as gold,
	count(case when medal = 'Silver' then 1 end) as silver,
	count(case when medal = 'Bronze' then 1 end) as bronze
from athlete_events ae
JOIN noc_regions nr ON ae.noc = nr.noc
group by region, games
order by games asc, gold desc,silver desc,bronze desc;



-- 17. Identify which country won the most gold, most silver, most bronze medals and the most medals in each olympic games.
WITH cte AS (
    SELECT ae.games, nr.region, ae.medal,
        COUNT(*) AS medal_count,
        DENSE_RANK() OVER (PARTITION BY games, medal ORDER BY COUNT(*) DESC) AS rn
    FROM athlete_events ae
    JOIN noc_regions nr ON ae.noc = nr.noc
    WHERE ae.medal IN ('Gold', 'Silver', 'Bronze')
    GROUP BY ae.games, nr.region, ae.medal
)
SELECT games,
    MAX(CASE WHEN medal = 'Gold' AND rn = 1 THEN CONCAT(region, ' ', CAST(medal_count AS CHAR)) END) AS max_gold,
    MAX(CASE WHEN medal = 'Silver' AND rn = 1 THEN CONCAT(region, ' ', CAST(medal_count AS CHAR)) END) AS max_silver,
    MAX(CASE WHEN medal = 'Bronze' AND rn = 1 THEN CONCAT(region, ' ', CAST(medal_count AS CHAR)) END) AS max_bronze,
    (SELECT CONCAT(region, ' ', CAST(SUM(medal_count) AS CHAR))
 FROM cte AS c
 WHERE c.games = cte.games
 GROUP BY games, region
 ORDER BY SUM(medal_count) DESC
 LIMIT 1) AS season_max_medal
FROM cte
GROUP BY games
ORDER BY games;

    
-- 18. Which countries have never won gold medal but have won silver/bronze medals?
with cte as(
select region,
count(case when medal = 'Gold' then 1 end) as gold,
count(case when medal = 'Silver' then 1 end) as silver,
count(case when medal = 'Bronze' then 1 end) as bronze
from athlete_events ae
JOIN noc_regions nr ON ae.noc = nr.noc
group by region
)
select * from cte where gold = 0 and (silver>0 or bronze >0);

-- 19. In which Sport/event, India has won highest medals.
with cte as(
	select sport,
	count(medal) as medal_won,
	dense_rank() over(order by count(medal) desc) as rnk
	from athlete_events ae
	join noc_regions nr ON ae.noc = nr.noc
	where team = 'India' and medal<>'NA'
	group by sport
)
select sport,medal_won
from cte 
where rnk = 1 ;

-- 20. Break down all olympic games where India won medal for Hockey and how many medals in each olympic games
select games,count(medal) as hockey_medal
from athlete_events
where sport = 'Hockey' and team = 'India' and medal<>'NA'
group by games
order by games;




































