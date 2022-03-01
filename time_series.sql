CREATE table retail_sales(
	sales_month date,
	naics_code varchar,
	kind_of_business varchar,
	reason_for_null varchar,
	sales decimal
);

COPY retail_sales 
FROM 'D:\Projects\sqlfda/us_retail_sales.csv' 
WITH (FORMAT CSV, HEADER);

-- Creating trends
---Trend of yearly total retail and food services sales
SELECT date_part('year', sales_month) AS sales_year,
		sum(sales) AS sales
FROM retail_sales
WHERE kind_of_business = 'Retail and food services sales, total'
GROUP BY 1
ORDER BY 1;

-- Comparing components
---Compare the yearly sales trend for a few categories that are associated with leisure activities
SELECT date_part('year',sales_month) as sales_year,
		kind_of_business,
		sum(sales) as sales
FROM retail_sales
WHERE kind_of_business in ('Book stores','Sporting goods stores','Hobby, toy, and game stores')
GROUP BY 1,2
ORDER BY 1;

---Yearly trend of sales at women’s and men’s clothing stores
SELECT date_part('year',sales_month) as sales_year,
		kind_of_business,
		sum(sales) as sales
FROM retail_sales
WHERE kind_of_business in ('Men''s clothing stores','Women''s clothing stores')
GROUP BY 1,2
ORDER BY 1;

SELECT date_part('year',sales_month) as sales_year,
		sum(case when kind_of_business = 'Women''s clothing stores'
          		then sales
          	end) as womens_sales,
		sum(case when kind_of_business = 'Men''s clothing stores'
          		then sales
          	end) as mens_sales
FROM retail_sales
WHERE kind_of_business in ('Men''s clothing stores','Women''s clothing stores')
GROUP BY 1
ORDER BY 1;

---Yearly ratio of women’s to men’s clothing sales
SELECT sales_year,
	   round(womens_sales / mens_sales,2) as womens_times_of_mens
FROM (

	SELECT date_part('year',sales_month) as sales_year,
		sum(case when kind_of_business = 'Women''s clothing stores'
          		then sales
          	end) as womens_sales,
		sum(case when kind_of_business = 'Men''s clothing stores'
          		then sales
          	end) as mens_sales
	FROM retail_sales
	WHERE kind_of_business in ('Men''s clothing stores','Women''s clothing stores')
	GROUP BY 1
	ORDER BY 1
) a ;

---Men’s and women’s clothing store sales as percent of monthly total
SELECT 	sales_month, 
		kind_of_business, 
		sales,
		sum(sales) over (partition by sales_month) as total_sales,
		round(sales * 100 / sum(sales) over (partition by sales_month),2) as pct_total
FROM retail_sales
WHERE kind_of_business in ('Men''s clothing stores','Women''s clothing stores')
ORDER BY 1;

---Percent of yearly sales for 2019 for women’s and men’s clothing sales
SELECT 	sales_month, 
		kind_of_business,
		sales,
		sum(sales) over (partition by date_part('year',sales_month),kind_of_business) as yearly_sales,
		round(sales * 100 /sum(sales) over (partition by date_part('year',sales_month),kind_of_business), 2) as pct_yearly
FROM retail_sales
WHERE kind_of_business in ('Men''s clothing stores','Women''s clothing stores')
ORDER BY 1,2;

--Indexing time series data
---Men’s and women’s clothing store sales, indexed to 1992 sales
SELECT sales_year, kind_of_business, sales,
		round((sales / first_value(sales) over (partition by kind_of_business order by sales_year) - 1) * 100, 2) as pct_from_index
FROM
(
    SELECT date_part('year',sales_month) as sales_year,
			kind_of_business,
			sum(sales) as sales
    FROM retail_sales
    WHERE kind_of_business in ('Men''s clothing stores','Women''s clothing stores')
    GROUP BY 1,2
	ORDER BY 1
) a
;

-- Calculating Rolling Time Windows
--- 12-month moving average sales for women’s clothing stores
SELECT 	sales_month,
		round(avg(sales) over (order by sales_month rows between 11 preceding and current row), 2) as moving_avg,
		count(sales) over (order by sales_month rows between 11 preceding and current row
                  ) as records_count
FROM retail_sales
WHERE kind_of_business = 'Women''s clothing stores';

--- 12-month moving average sales for Men’s clothing stores
SELECT a.sales_month, round(avg(b.sales),2) as moving_avg,
		count(b.sales) as records_count
FROM
(
    SELECT distinct sales_month
    FROM retail_sales
    WHERE sales_month between '1992-01-01' and '2020-12-01'
) a
JOIN retail_sales b 
ON b.sales_month between a.sales_month - interval '11 months' and a.sales_month
 AND b.kind_of_business = 'Men''s clothing stores'
GROUP BY 1
ORDER BY 1;

--Calculating Cumulative Values
--- Total sales YTD as of each month
SELECT 	sales_month, 
		sales,
		sum(sales) over (partition by date_part('year',sales_month) order by sales_month) as sales_ytd
FROM retail_sales
WHERE kind_of_business = 'Women''s clothing stores';


-- Analyzing with Seasonality, Period-over-Period Comparisons
--- Calculate MoM growth
SELECT 	kind_of_business, 
		sales_month, 
		sales,
		round((sales / lag(sales) over (partition by kind_of_business order by sales_month) - 1) * 100, 2) as pct_growth_from_previous
FROM retail_sales
WHERE kind_of_business = 'Women''s clothing stores';

--- Calculate YoY growth
SELECT 	sales_year, 
		yearly_sales,
		lag(yearly_sales) over (order by sales_year) as prev_year_sales,
		round((yearly_sales / lag(yearly_sales) over (order by sales_year) -1) * 100, 2) as pct_growth_from_previous
FROM
(
    SELECT 	date_part('year',sales_month) as sales_year,
			sum(sales) as yearly_sales
    FROM retail_sales
    WHERE kind_of_business = 'Women''s clothing stores'
    GROUP BY 1
) a
;

--- Same Month Versus Last Year Comparison
SELECT 	sales_month, 
		sales,
		sales - lag(sales) over (partition by date_part('month',sales_month) order by sales_month) as absolute_diff,
		round((sales / lag(sales) over (partition by date_part('month',sales_month) order by sales_month) - 1) * 100,2) as pct_diff
FROM retail_sales
WHERE kind_of_business = 'Women''s clothing stores';


SELECT 	date_part('month',sales_month) as month_number,
		to_char(sales_month,'Month') as month_name,
		max(case when date_part('year',sales_month) = 2018 then sales end) as sales_2018,
		max(case when date_part('year',sales_month) = 2019 then sales end) as sales_2019,
		max(case when date_part('year',sales_month) = 2020 then sales end) as sales_2020
FROM retail_sales
WHERE kind_of_business = 'Women''s clothing stores'
 	and sales_month between '2018-01-01' and '2020-12-01'
GROUP BY 1,2;


--- Comparing to Multiple Prior Periods
SELECT 	sales_month, sales,
		round(sales / avg(sales) over (partition by date_part('month',sales_month) order by sales_month rows between 3 preceding and 1 preceding),2) as pct_of_prev_3
FROM retail_sales
WHERE kind_of_business = 'Women''s clothing stores';

