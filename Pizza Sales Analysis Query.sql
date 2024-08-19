CREATE DATABASE IF NOT EXISTS pizza_sales;

USE pizza_sales;

CREATE TABLE orders (
	order_id INT AUTO_INCREMENT PRIMARY KEY,
	`date` DATE,
    `time` TIME
);

CREATE TABLE pizza_types (
    pizza_type_id VARCHAR(50) PRIMARY KEY,
    `name` VARCHAR(50) NOT NULL,
    category VARCHAR(50) NOT NULL,
    ingredients VARCHAR(200) NOT NULL,
    UNIQUE INDEX (pizza_type_id)
); 

CREATE TABLE pizzas (
    pizza_id VARCHAR(50) PRIMARY KEY,
    pizza_type_id VARCHAR(50),
    size VARCHAR(1) NOT NULL,
    price DECIMAL(6,2),
    FOREIGN KEY (pizza_type_id) REFERENCES pizza_types(pizza_type_id)
);

CREATE TABLE order_details (
    order_details_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    pizza_id VARCHAR(50) NOT NULL,
    quantity INT NOT NULL,
    FOREIGN KEY (order_id) REFERENCES orders (order_id),
    FOREIGN KEY (pizza_id) REFERENCES pizzas (pizza_id)
);

-- Basics
-- Retrieve the total number of orders placed.
SELECT COUNT(order_id) AS Total_Orders_Count
FROM orders;

-- Calculate the total revenue generated from pizza sales.
SELECT SUM(od.quantity * p.price) AS Total_Revenue
FROM order_details od
JOIN pizzas p 
ON od.pizza_id = p.pizza_id;

-- Identify the highest-priced pizza.
SELECT pt.`name` AS Highest_Priced_Pizza, p.price AS Price
FROM pizzas AS p
JOIN pizza_types AS pt
ON p.pizza_type_id = pt.pizza_type_id
WHERE p.price = (SELECT MAX(price) FROM pizzas);

-- Identify the most common pizza size ordered.
SELECT p.size AS Most_Ordered_Size, COUNT(*) AS Order_Count
FROM order_details AS od
JOIN pizzas AS p
ON p.pizza_id = od.pizza_id
GROUP BY p.size
ORDER BY COUNT(*) DESC
LIMIT 1;

-- List the top 5 most ordered pizza types along with their quantities.
SELECT p.pizza_type_id AS Most_Ordered_Pizza_Types, SUM(quantity) AS Total_Quantity
FROM order_details AS OD
JOIN pizzas AS p
ON OD.pizza_id = p.pizza_id
GROUP BY OD.pizza_id
ORDER BY Total_Quantity DESC
LIMIT 5;

-- Intermediate:
-- Join the necessary tables to find the total quantity of each pizza category ordered.
SELECT PT.category, SUM(quantity) AS total_quantity
FROM pizza_types AS PT
JOIN pizzas AS p
ON p.pizza_type_id = PT.pizza_type_id
JOIN order_details AS OD
ON OD.pizza_id = p.pizza_id
GROUP BY PT.category
ORDER BY total_quantity DESC;

-- Determine the distribution of orders by hour of the day.
SELECT DAY(date) AS `day`, HOUR(time) `hour`, COUNT(*) AS Order_Count
FROM orders
GROUP BY day, hour;

-- Join relevant tables to find the category-wise distribution of pizzas.
SELECT PT.category, COUNT(*) pizza_count
FROM pizza_types AS PT
JOIN pizzas AS p
ON p.pizza_type_id = PT.pizza_type_id
GROUP BY PT.category
ORDER BY pizza_count DESC;

-- Group the orders by date and calculate the average number of pizzas ordered per day.
SELECT ROUND(AVG(daily_total), 0) AS average_pizzas_ordered_per_day
FROM (
    SELECT SUM(quantity) AS daily_total
    FROM order_details AS od
    JOIN orders AS o
    ON o.order_id = od.order_id
    GROUP BY date
) AS daily_totals;

-- Determine the top 3 most ordered pizza types based on revenue. 
SELECT p.pizza_type_id, pt.name, ROUND(SUM(quantity*price), 2) AS revenue
FROM order_details AS od
JOIN pizzas AS p
ON od.pizza_id = p.pizza_id
JOIN pizza_types AS pt
ON pt.pizza_type_id = p.pizza_type_id
GROUP BY p.pizza_type_id
ORDER BY revenue DESC
LIMIT 3;
 
-- Advanced: 
-- Calculate the percentage contribution of each pizza type to total revenue.
SET @total_revenue = (
	SELECT ROUND(SUM(od.quantity*p.price), 2) AS revenue
	FROM order_details AS od
	JOIN pizzas AS p
	ON od.pizza_id = p.pizza_id
);

SELECT p.pizza_type_id, 
	   pt.`name`, 
       CONCAT(ROUND((SUM(od.quantity * p.price) / @total_revenue) * 100, 1), "%") AS revenue_percentage
FROM order_details AS od
JOIN pizzas AS p
ON od.pizza_id = p.pizza_id
JOIN pizza_types AS pt
ON pt.pizza_type_id = p.pizza_type_id
GROUP BY p.pizza_type_id
ORDER BY revenue_percentage DESC;

-- Analyze the cumulative revenue generated over time.
WITH CTE_revenue AS (
	SELECT MONTHNAME(date) AS month,
	   ROUND(SUM(od.quantity*p.price), 2) AS revenue,
	   ROW_NUMBER() OVER (ORDER BY FIELD(month, 
					     'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'
					     )
			     ) AS month_order
FROM orders AS o
JOIN order_details AS od
ON od.order_id = o.order_id
JOIN pizzas AS p
ON od.pizza_id = p.pizza_id
GROUP BY MONTHNAME(date)
)

SELECT month,
	   revenue,
	   (
		 SELECT SUM(revenue) 
		 FROM CTE_revenue 
		 WHERE CTE_revenue.month_order <= CTE.month_order
	    ) AS cumulative_revenue
FROM CTE_revenue AS CTE
ORDER BY month_order;

-- Determine the top 3 most ordered pizza types based on revenue for each pizza category. 
WITH temp_table AS (
	SELECT category,
		   p.pizza_type_id, 
		   pt.name, 
		   ROUND(SUM(od.quantity * p.price), 2) AS revenue,
		   ROW_NUMBER() OVER (PARTITION BY pt.category ORDER BY SUM(od.quantity * p.price) DESC) AS `rank`
	FROM order_details AS od
	JOIN pizzas AS p
	ON od.pizza_id = p.pizza_id
	JOIN pizza_types AS pt
	ON pt.pizza_type_id = p.pizza_type_id
	GROUP BY category, p.pizza_type_id
	ORDER BY category ASC, revenue DESC
)

SELECT category,
	   pizza_type_id,
       name, 
       revenue
FROM temp_table
WHERE `rank` < 4
ORDER BY FIELD(category, 'Classic', 'Veggie', 'Chicken', 'Supreme');
