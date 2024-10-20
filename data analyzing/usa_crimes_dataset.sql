-- 1. Identify the top 5 cities with the highest average number of victims per crime.
SELECT DISTINCT
    city,
    SUM(victims)
    OVER(PARTITION BY city) AS total_victims,
    concat(round((SUM(victims)
                  OVER(PARTITION BY city) * 100.0) / SUM(victims)
                                                     OVER(),
                 2),
           '%')             percentage_victims
FROM
    "public"."usa_crimes"
ORDER BY
    total_victims DESC
FETCH FIRST 5 ROWS ONLY;




-- 2. Find the police districts where the number of crimes increased every year.
WITH yearly_crime_counts AS (
    SELECT
        police_district_name,
        EXTRACT(YEAR FROM dispatch_date::date) AS YEAR,
        COUNT(id)                        AS total_crimes
    FROM
        "public"."usa_crimes"
    GROUP BY
        police_district_name,
        EXTRACT(YEAR FROM dispatch_date::date)
)
SELECT
    police_district_name
FROM
    yearly_crime_counts y1
WHERE
    NOT EXISTS (
        SELECT
            1
        FROM
            yearly_crime_counts y2
        WHERE
                y1.police_district_name = y2.police_district_name
            AND y2.year = y1.year + 1
            AND y2.total_crimes <= y1.total_crimes
    )
GROUP BY
    police_district_name;





-- 3. Finding the city and street where the highest number of crimes of any type occurred, and determine what percentage of total crimes in that city this represents.
WITH city_street_crimes AS (
    SELECT
        city,
        street_name,
        COUNT(id) AS crime_count
    FROM
        "public"."usa_crimes"
    GROUP BY
        city,
        street_name
)
SELECT
    city_street_crimes.city,
    city_street_crimes.street_name,
    city_street_crimes.crime_count,
    round(((city_street_crimes.crime_count * 100.0) / total_city_crimes.total_crimes)) AS percentage_of_city_crimes
FROM
         city_street_crimes
    JOIN (
        SELECT
            city,
            COUNT(id) AS total_crimes
        FROM
            "public"."usa_crimes"
        GROUP BY
            city
    ) total_city_crimes ON city_street_crimes.city = total_city_crimes.city
ORDER BY
    crime_count DESC
FETCH FIRST 1 ROWS ONLY;





-- 4. Determine the total number of crimes and the average number of victims for crimes committed during weekends (Saturday and Sunday).
WITH total_crimes AS (
    SELECT
        COUNT(id) AS total_crimes
    FROM
        public.usa_crimes
)
SELECT
    'Weekend' AS period,
    COUNT(id) AS total_crime,
    ROUND(AVG(victims), 2) AS avg_victims,
    ROUND(100.0 * COUNT(id) / (
        SELECT total_crimes FROM total_crimes
    ), 2) AS percentage
FROM
    public.usa_crimes
WHERE
    start_day_of_week IN ('Saturday', 'Sunday')
GROUP BY
    period

UNION ALL

SELECT
    'Weekday' AS period,
    COUNT(id) AS total_crime,
    ROUND(AVG(victims), 2) AS avg_victims,
    ROUND(100.0 * COUNT(id) / (
        SELECT total_crimes FROM total_crimes
    ), 2) AS percentage
FROM
    public.usa_crimes
WHERE
    start_day_of_week NOT IN ('Saturday', 'Sunday')
GROUP BY
    period;
    
    
    

-- 5. Identify sectors where the total number of crimes has decreased by more than 20% in the last year compared to the previous year.
WITH crime_trends AS (
    SELECT
        city,
        EXTRACT(YEAR FROM dispatch_date::date) AS YEAR,
        COUNT(id)                        AS total_crimes
    FROM
        "public"."usa_crimes"
    GROUP BY
        city,
        EXTRACT(YEAR FROM dispatch_date::date)
)
SELECT DISTINCT
    cur.city
FROM
         crime_trends cur
    JOIN crime_trends prev ON cur.city = prev.city
                                  AND ( cur.year = prev.year + 1 )
WHERE
    ( ( ( prev.total_crimes - cur.total_crimes ) * 100.0 ) / prev.total_crimes ) > 20;
    
    
    


-- 6. Find the cities with the highest number of crimes involving more than 3 victims in the last 1 years.
SELECT DISTINCT
    city,
    COUNT(id)
    OVER(PARTITION BY city) crime_count
FROM
    "public"."usa_crimes"
WHERE
        victims > 0
    AND start_date::date >= TO_DATE('31-DEC-2022', 'DD-MON-YYYY') - INTERVAL '1' YEAR
ORDER BY
    crime_count DESC;




-- 7. Crimes Frequency by Time of Day with Percentages.  
WITH time_of_day_counts AS (
    SELECT
        start_part_of_day,
        COUNT(*) AS crime_count
    FROM
        "public"."usa_crimes"
    GROUP BY
        start_part_of_day
), sum_of_all_crimes AS (
    SELECT
        SUM(crime_count) AS total_crimes
    FROM
        time_of_day_counts
)
SELECT
    todc.start_part_of_day,
    todc.crime_count,
    round((todc.crime_count * 100.0) / soac.total_crimes, 2) AS percentage
FROM
    time_of_day_counts todc,
    sum_of_all_crimes  soac
ORDER BY
    CASE todc.start_part_of_day
        WHEN 'Morning'   THEN
            1
        WHEN 'Afternoon' THEN
            2
        WHEN 'Evening'   THEN
            3
        WHEN 'Night'     THEN
            4
    END;





-- 8. Analyzing the trend of total crimes recorded each year, including the percentage change from the previous year
WITH YearlyCrime AS (
    SELECT 
        EXTRACT(YEAR FROM start_date::date) AS YEAR,
        COUNT(*) AS total_crimes
    FROM "public"."usa_crimes"
    GROUP BY YEAR
),
YearlyChange AS (
    SELECT 
        YEAR,
        total_crimes,
        LAG(total_crimes) OVER (ORDER BY YEAR) AS prev_year_crimes
    FROM YearlyCrime
)
SELECT 
    YEAR,
    total_crimes,
    ROUND((total_crimes - prev_year_crimes) * 100.0 / NULLIF(prev_year_crimes, 0), 2) AS percentage_change
FROM YearlyChange
ORDER BY YEAR;




-- 9. Total number of victims and average number of victims for each crime type, including only those crime types with more than one incident
WITH VictimStats AS (
    SELECT 
        crime_type,
        SUM(victims) AS total_victims,
        ROUND(AVG(victims), 4) AS average_victims,
        COUNT(*) AS incident_count
    FROM "public"."usa_crimes"
    GROUP BY crime_type
)
SELECT 
    crime_type,
    total_victims,
    average_victims
FROM VictimStats
WHERE incident_count > 1
ORDER BY average_victims DESC;



-- 10. Comparing the total counts of crimes for each month
WITH MonthlyCrimeCount AS (
    SELECT 
        DATE_TRUNC('month', start_date::date) AS MONTH,
        crime_type,
        COUNT(*) AS crime_count
    FROM "public"."usa_crimes"
    GROUP BY MONTH, crime_type
)
SELECT 
    TO_CHAR(MONTH, 'FMMonth YYYY') AS month_year,
    SUM(crime_count) AS total_crimes
FROM MonthlyCrimeCount
GROUP BY month_year
ORDER BY month_year, total_crimes DESC;




-- 11. Analyzing how crimes are distributed across different locations
SELECT 
    place,
    crime_type,
    COUNT(*) AS total_crimes
FROM "public"."usa_crimes"
GROUP BY place, crime_type
ORDER BY place, total_crimes DESC;




-- 12. Analyzing the distribution of crime severity
WITH MonthlySeverity AS (
    SELECT
        CASE 
            WHEN AVG(victims) = 0 THEN 'Low'
            WHEN AVG(victims) BETWEEN 1 AND 2 THEN 'Medium'
            ELSE 'High'
        END AS severity,
        COUNT(*) AS total_crimes
    FROM "public"."usa_crimes"
)
SELECT
    severity,
    SUM(total_crimes) AS total_crimes
FROM MonthlySeverity
GROUP BY severity
ORDER BY severity DESC;




-- 13. Determining the seasonal trends of crimes by analyzing the total number of crimes for each season of the year
WITH SeasonalCrimeCounts AS (
    SELECT 
        CASE 
            WHEN EXTRACT(MONTH FROM start_date::date) IN (12, 1, 2) THEN 'Winter'
            WHEN EXTRACT(MONTH FROM start_date::date) IN (3, 4, 5) THEN 'Spring'
            WHEN EXTRACT(MONTH FROM start_date::date) IN (6, 7, 8) THEN 'Summer'
            ELSE 'Fall'
        END AS season,
        COUNT(*) AS total_crimes
    FROM "public"."usa_crimes"
    GROUP BY season
)
SELECT 
    season,
    total_crimes
FROM SeasonalCrimeCounts
ORDER BY 
    CASE season
        WHEN 'Winter' THEN 1
        WHEN 'Spring' THEN 2
        WHEN 'Summer' THEN 3
        WHEN 'Fall' THEN 4
    END DESC;



-- 14. Retrieving the top 5 street types with the highest number of victims in crime incidents
SELECT 
    st.abbreviation_meaning AS full_street_type,
    SUM(c.victims) AS total_victims
FROM 
    "public"."usa_crimes" c
JOIN 
    "public"."street_types" st
ON 
    c.street_type = st.street_abbreviation
GROUP BY st.abbreviation_meaning
ORDER BY total_victims DESC
LIMIT 5;




-- 15. Identifing if certain locations are repeat offenders of specific crime types
WITH CrimeLocationFrequency AS (
    SELECT 
        latitude, 
        longitude, 
        crime_type, 
        COUNT(id) AS crime_count
    FROM 
        "public"."usa_crimes"
    GROUP BY 
        latitude, longitude, crime_type
)
SELECT 
    latitude, 
    longitude, 
    crime_type, 
    crime_count
FROM 
    CrimeLocationFrequency
WHERE 
    crime_count > 1
ORDER BY 
    crime_count DESC
LIMIT 10;



-- 16. Identifing crime types that tend to occur in specific police districts more frequently, showing the top two districts for each crime type.
WITH CrimeDistrictCounts AS (
    SELECT 
        crime_type,
        police_district_name,
        COUNT(*) AS incident_count,
        RANK() OVER (PARTITION BY crime_type ORDER BY COUNT(*) DESC) AS rank
    FROM "public"."usa_crimes"
    GROUP BY crime_type, police_district_name
)
SELECT 
    crime_type,
    police_district_name,
    incident_count
FROM CrimeDistrictCounts
WHERE rank <= 2
ORDER BY crime_type, incident_count DESC;




-- 17. The count of crimes per district were dispatched before they officially started
WITH CrimesDispatchedBeforeStart AS (
    SELECT 
        police_district_number,
        COUNT(*) AS crimes_dispatched_before_start
    FROM 
        "public"."usa_crimes"
    WHERE 
        (dispatch_date::DATE + dispatch_time::TIME) > (start_date::DATE + start_time::TIME)
    GROUP BY 
        police_district_number
)
SELECT 
    police_district_number,
    crimes_dispatched_before_start
FROM 
    CrimesDispatchedBeforeStart
ORDER BY 
    crimes_dispatched_before_start DESC;





-- 18. Finding changing of crimes counts over season of each year
WITH season_data AS (
    SELECT
        EXTRACT(YEAR FROM start_date::DATE) AS YEAR,
        CASE
            WHEN EXTRACT(MONTH FROM start_date::DATE) IN (12, 1, 2) THEN 'Winter'
            WHEN EXTRACT(MONTH FROM start_date::DATE) IN (3, 4, 5) THEN 'Spring'
            WHEN EXTRACT(MONTH FROM start_date::DATE) IN (6, 7, 8) THEN 'Summer'
            WHEN EXTRACT(MONTH FROM start_date::DATE) IN (9, 10, 11) THEN 'Fall'
        END AS season,
        COUNT(*) AS total_crimes
    FROM "public"."usa_crimes"
    GROUP BY YEAR, season
),
seasonal_trends AS (
    SELECT
        YEAR,
        season,
        total_crimes,
        LAG(total_crimes) OVER (PARTITION BY season ORDER BY YEAR) AS previous_year_crimes
    FROM season_data
)
SELECT
    YEAR,
    season,
    total_crimes,
    previous_year_crimes,
    CASE
        WHEN previous_year_crimes IS NOT NULL THEN 
            ROUND((total_crimes - previous_year_crimes) * 100.0 / previous_year_crimes, 2) 
        ELSE 
            NULL 
    END AS percentage_change
FROM seasonal_trends
ORDER BY season, YEAR;




