-- Inspecting the Data
SELECT * FROM sales_data_sample;

-- Checking unique values
SELECT DISTINCT status FROM sales_data_sample;
SELECT DISTINCT year_id FROM sales_data_sample;
SELECT DISTINCT productline FROM sales_data_sample; 
SELECT DISTINCT country FROM sales_data_sample;
SELECT DISTINCT dealsize FROM sales_data_sample;
SELECT DISTINCT territory FROM sales_data_sample;

-- My analysis will begin here 
-- I'm going to start by grouping the sales by productline using an aggregate function. 
SELECT 
	productline,
    	sum(sales) AS Revenue
FROM
	sales_data_sample
GROUP BY productline
ORDER BY 2 DESC;
-- It appears Classic Cars and Vintage Cars have the most revenue 

-- I want to see what years the most sales were made. 
SELECT 
	year_id,
    	sum(sales) AS Revenue
FROM
	sales_data_sample
GROUP BY year_id
orDER BY 2 DESC;
-- It looks like 2004 had the most revenue. 2005 has the lowest revenue. 

-- Since 2005 had the lowest revenue, I want to check if they operated the entire year in 2005. 
SELECT DISTINCT 
	month_id
FROM
	sales_data_sample
WHERE
	year_id = 2005
ORDER BY month_id ASC;
-- It looks like the business only operating 5 months out of the year in 2005. This explains why the revenue was so low. 

-- I'm going to take a look at the different deal sizes offered (small, medium, large) in order to see which one brought in the most revenue
SELECT 
	dealsize,
    	sum(sales) AS Revenue
FROM
	sales_data_sample
GROUP BY dealsize
ORDER BY 2 DESC;
-- It looks like the Medium dealsize brought in the most revenue.

-- I want to check the best month for sales in 2003 and how much was earned that month and the amount of orders placed. 
SELECT
	month_id,
    	sum(sales) AS Revenue,
    	COUNT(ordernumber) AS Frequency
FROM
	sales_data_sample
WHERE
	year_id = 2003
GROUP BY month_id
ORDER BY 2 DESC;
-- It looks like the month of November in 2003 brought in the highest number of orders and revenue
-- Changing the year to 2004 will show the month of November in 2004 also brought in the highest number of orders and revenue.
-- I excluded year 2005 since the sales stopped in May for that year. 

-- Since November seems to be the best month for sales, I want to find out what product they're selling the most of in that month.
SELECT
	month_id,
   	productline,
    	sum(sales) AS Revenue,
    	counT(ordernumber)
FROM
	sales_data_sample
WHERE
	year_id = 2003 AND month_id = 11
GROUP BY month_id, productline
ORDER BY 3 DESC;
-- It looks like Classic Cars sold the most in November, followed by Vintage Cars. 
-- Changing the year to 2004 will have the same results. 

-- I want to check who the best customer is. This can be done using RFM(recency, frequency, monetary) Analysis. 
-- I'm going to select the customer name, and then with aggregate functions I will find the sum of sales, average sales, number of orders, and the last order date
-- Then I will calculate the difference between a customer's last purchase date and the most recent purchase date in the entire data set (Recency)
-- I'm going to group these into 4 equal buckets using a window function and NTILE. 
DROP TABLE IF EXISTS #rfm -- #rfm is going to be a temp table created further down.
;with rfm AS
(
	SELECT
		customername,
    		sum(sales) AS MonetaryValue,
    		avg(sales) AS AvgMonetaryValue,
    		COUNT(ordernumber) AS Frequency,
    		max(orderdate) AS last_order_date,
    		(SELECT max(orderdate) FROM sales_data_sample) AS max_order_date,
    		DATEDIFF(DD, max(orderdate), (SELECT max(orderdate) FROM sales_data_sample)) AS Recency
	FROM
		sales_data_sample
	GROUP BY customername
	ORDER BY Frequency DESC;
), -- Adding up all of the RFM values
rfm_calc AS
(
	SELECT 
		r.*,
		NTILE(4) OVER (order BY Recency) AS rfm_recency,
    		NTILE(4) OVER (order BY Frequency) AS rfm_frequency,
    		NTILE(4) OVER (order BY MonetaryValue) AS rfm_monetary
	FROM rfm r 
)
SELECT 
	c.*, 
   	 -- Adding the numeric RFM values
   	 rfm_recency+ rfm_frequency+ rfm_monetary AS rfm_cell,
   	 -- Adding the RFM values as strings to create a triple digit number. I'm going to pass all of this into a temp table. 
   	 CAST(rfm_recency as VARCHAR) + cast(rfm_frequency AS VARCHAR) + CAST(rfm_monetary As VARCHAR) AS rfm_cell_string
INTO #rfm 
FROM 
	rfm_calc c;
-- The closer the last_order_date to the max date, the higher the rfm numbers. 
-- Customer Daedalus Designs Imports last made a purchase 465 days ago. 
-- The business should reach out to them to try and get some repeat business from them and see if their needs were met last time. 

-- Using a CASE statement for segmentation using the rfm cell string I created above.
SELECT 
	 customername,
   	 rfm_recency,
   	 rfm_frequency, 
   	 rfm_monetary
   	 CASE
    		WHEN rfm_cell_string IN (111,112,121,122,123,132,211,212,114,141) THEN 'lost_customers'
        	WHEN rfm_cell_string IN (133,134,143,244,334,343,344,144) THEN 'slipping_away_cannot_lose'
        	WHEN rfm_cell_string IN (311,411,331) THEN 'new_customers'
       	 	WHEN rfm_cell_string IN (222,223,233,322) THEN 'potential_repeat_business'
       		WHEN rfm_cell_string IN (323,333,321,422,332,432) THEN 'active_customers'
       	 	WHEN rfm_cell_string IN (433,434,443,444) THEN 'loyal_customers'
    	 END rfm_segment
FROM #rfm;

-- Checking what products are most often sold together. 
-- Checking the product codes for the orders where 2 items are often sold together. 
-- I will also append the column with 2 order codes so they're in the same column
-- Using stuff to convert from xml to string and getting the order number for the product codes
SELECT DISTINCT ordernumber, STUFF(
        (SELECT ',' + productcode
        FROM sales_data_sample AS p
        WHERE ordernumber IN 
            (
                SELECT ordernumber,
                from (
                    SELECT ordernumber,
                    COUNT(*) AS rn
                    FROM sales_data_sample
                    WHERE status = 'Shipped'
                    GROUP BY ordernumber;
                ) as m 
                WHERE rn = 2 -- Checking which 2 products are normally sold together. 
            )
         	AND p.ordernumber = s.ordernumber
            for xml path (''))
  
  			, 1, 1, '') AS ProductCodes
            
FROM sales_data_sample AS s
ORDER BY 2;
-- This gets all of the orders with only 2 product codes so I can see which 2 items sell together a lot. 

