--FUNCTIONS:
--Calculate how big of a part something is of something else
CREATE OR REPLACE FUNCTION calculate_percentage(part numeric,whole numeric)
RETURNS NUMERIC
language plpgsql
AS $$
BEGIN
RETURN ROUND((part / whole)* 100.0,2);
END;
$$;
--1. What are the top 100 selling products in the dataset, what percentage of overall sales do they cover?
/* QUERY */
--Create a CTE with the products ranked to avoid using LIMIT
WITH ranking AS
(
SELECT "Description",
SUM("Quantity") AS product_sales,
RANK() 
OVER(ORDER BY SUM("Quantity") DESC)
AS product_rank 
FROM sales_data
WHERE "Description" IS NOT NULL 
GROUP BY "Description"    
)
--Select the top 100 products
SELECT *,
calculate_percentage(product_sales
,
(SELECT SUM(product_sales) FROM ranking))
AS
percent_of_overall_sales
FROM
ranking WHERE product_rank <= 100;

--2. Where were the products shipped to?
/* QUERY */
--Create a CTE similar to the previous one but this time for countries
WITH ranking AS
(SELECT 
RANK() 
OVER (ORDER BY SUM("Quantity") DESC) AS product_rank,
"Country",
SUM("Quantity") AS product_sales
FROM sales_data
WHERE "Country" IS NOT NULL
GROUP BY "Country")
--Select everything and calculate it's percentage
SELECT *,
calculate_percentage(product_sales,
(SELECT SUM(product_sales) FROM ranking))
AS
percent_of_overall_sales FROM ranking;
--3.What is the distribution of sales across different product categories?
/* QUERY */
--Select necessary columns to avoid group by in next query
--avoid null values

WITH ranking AS
(
SELECT "Description","StockCode",
"Quantity","UnitPrice"
FROM sales_data
WHERE "StockCode" IS NOT NULL AND "Description" IS NOT NULL    
)
--Aggregate descriptions, calculate the overall percentage of sales
SELECT string_agg(DISTINCT "Description", ' | ')
AS list_of_products,
"StockCode",
calculate_percentage(
SUM("Quantity" * "UnitPrice")::numeric
,
(SELECT SUM("Quantity" * "UnitPrice") FROM ranking)::numeric
)
AS
percent_of_overall_sales
FROM
ranking GROUP BY "StockCode"
ORDER BY percent_of_overall_sales DESC;
--4.How do sales vary by month?
/* QUERY */
--Really simple query, just group by month and then calculate everything as before
SELECT 
to_char(
to_date(
SUBSTR("InvoiceDate"::varchar,6,2),'mm')
,'Month') AS month,
ROUND(
SUM("Quantity" * "UnitPrice")::numeric,2) AS monthly_sales
,
calculate_percentage(SUM("Quantity" * "UnitPrice")::numeric,
(SELECT ROUND(SUM("Quantity" * "UnitPrice")::numeric,2) FROM sales_data))
FROM sales_data GROUP BY 1 ORDER BY 2 DESC;
--5. What is the trend of sales over time?
--Create a CTE grouping by quarter
WITH sales_totals AS (
SELECT
SUM("Quantity" * "UnitPrice")::numeric AS total_sales,
SUM(CASE
    WHEN EXTRACT(MONTH FROM "InvoiceDate") BETWEEN 1 AND 3
    THEN ("Quantity" * "UnitPrice")::numeric
    ELSE 0
END) AS Q1,
SUM(CASE
    WHEN EXTRACT(MONTH FROM "InvoiceDate") BETWEEN 4 AND 6
    THEN ("Quantity" * "UnitPrice")::numeric
    ELSE 0
END) AS Q2,
SUM(CASE
    WHEN EXTRACT(MONTH FROM "InvoiceDate") BETWEEN 7 AND 9
    THEN ("Quantity" * "UnitPrice")::numeric
    ELSE 0
END) AS Q3,
SUM(CASE
    WHEN EXTRACT(MONTH FROM "InvoiceDate") BETWEEN 10 AND 12
    THEN ("Quantity" * "UnitPrice")::numeric
    ELSE 0
END) AS Q4
FROM sales_data
),
--create a CTE showing what percentage of yearly sales each season is
percentage_calculations AS (
SELECT
calculate_percentage(Q1, total_sales) AS spring,
calculate_percentage(Q2, total_sales) AS summer,
calculate_percentage(Q3, total_sales) AS fall,
calculate_percentage(Q4, total_sales) AS winter
FROM sales_totals
)
--Select everything
SELECT *
FROM percentage_calculations;
--6. Compare the christmas season sales to the yearly sales
--Calculate the sales over christmas and year-round
WITH sums AS
(
SELECT ROUND(SUM("Quantity" * "UnitPrice")::numeric,2)
AS christmas_season_spending,
(SELECT ROUND(SUM("Quantity" * "UnitPrice")::numeric,2) FROM sales_data)
AS yearly_spending
FROM sales_data
WHERE EXTRACT(Month FROM"InvoiceDate") IN(11,12) 
)
--Select everything and see how much of overall sales christmas covers
SELECT *,
calculate_percentage(christmas_season_spending,yearly_spending)
AS christmas_to_year_percentage FROM sums;