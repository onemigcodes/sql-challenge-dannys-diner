-- Recreating the schema in MySQL
CREATE DATABASE dannys_diner;
USE dannys_diner;

CREATE TABLE sales (
  customer_id VARCHAR(1),
  order_date DATE,
  product_id INTEGER
);

INSERT INTO sales
  (customer_id, order_date, product_id)
VALUES
  ('A', '2021-01-01', 1),
  ('A', '2021-01-01', 2),
  ('A', '2021-01-07', 2),
  ('A', '2021-01-10', 3),
  ('A', '2021-01-11', 3),
  ('A', '2021-01-11', 3),
  ('B', '2021-01-01', 2),
  ('B', '2021-01-02', 2),
  ('B', '2021-01-04', 1),
  ('B', '2021-01-11', 1),
  ('B', '2021-01-16', 3),
  ('B', '2021-02-01', 3),
  ('C', '2021-01-01', 3),
  ('C', '2021-01-01', 3),
  ('C', '2021-01-07', 3);

CREATE TABLE menu (
  product_id VARCHAR(1),
  product_name VARCHAR(5),
  price INTEGER
);

INSERT INTO menu
  (product_id, product_name, price)
VALUES
  ('1', 'sushi', 10),
  ('2', 'curry', 15),
  ('3', 'ramen', 12);

CREATE TABLE members (
  customer_id VARCHAR(1),
  join_date DATE
);

INSERT INTO members
  (customer_id, join_date)
VALUES
  ('A', '2021-01-07'),
  ('B', '2021-01-09');

-- 1. What is the total amount each customer spent at the restaurant?
SELECT
	s.customer_id,
    SUM(m.price) AS total_price
FROM dannys_diner.sales s
	JOIN dannys_diner.menu m ON s.product_id = m.product_id
GROUP BY s.customer_id
ORDER BY s.customer_id;
-- 2. How many days has each customer visited the restaurant?
SELECT
	customer_id,
    COUNT(DISTINCT order_date) AS visits
FROM dannys_diner.sales
GROUP BY customer_id
ORDER BY customer_id;
-- 3. What was the first item from the menu purchased by each customer?
WITH CTE AS (
	SELECT
		ROW_NUMBER() OVER (
			PARTITION BY (s.customer_id) 
		) AS row_menu,
		s.customer_id,
		s.order_date,
		m.product_name
	FROM dannys_diner.sales s
		JOIN dannys_diner.menu m ON s.product_id = m.product_id
)

SELECT
	customer_id,
    product_name
FROM CTE
WHERE row_menu = 1
ORDER BY customer_id;
-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
SELECT
	m.product_name AS most_purchased_product,
    COUNT(s.product_id) AS purchase_count
FROM dannys_diner.sales s
	JOIN dannys_diner.menu m ON s.product_id = m.product_id
GROUP BY m.product_name
ORDER BY purchase_count DESC
LIMIT 1;
-- 5. Which item was the most popular for each customer?
WITH CTE AS (
	SELECT
		s.customer_id,
		m.product_name,
		COUNT(m.product_name) AS order_count,
		DENSE_RANK() OVER (
		PARTITION BY s.customer_id
		ORDER BY COUNT(m.product_name) DESC
		) AS order_ranking
	FROM dannys_diner.sales s
		JOIN dannys_diner.menu m ON s.product_id = m.product_id
	GROUP BY s.customer_id, m.product_name
)

SELECT
	customer_id,
    product_name AS most_popular_product,
    order_count
FROM CTE
WHERE order_ranking = 1
ORDER BY customer_id;
-- 6. Which item was purchased first by the customer after they became a member?
WITH CTE AS (
	SELECT
		s.customer_id,
		s.order_date,
		m.product_name,
		mb.join_date,
		DENSE_RANK() OVER (
		PARTITION BY s.customer_id
		ORDER BY s.order_date ASC
		) AS purchase_after_member
	FROM dannys_diner.sales s
		JOIN dannys_diner.menu m ON s.product_id = m.product_id
		JOIN dannys_diner.members mb ON s.customer_id = mb.customer_id
	WHERE s.order_date > mb.join_date
)

SELECT
	customer_id,
    product_name,
    join_date,
    order_date
FROM CTE
WHERE purchase_after_member = 1;

-- 7. Which item was purchased just before the customer became a member?
WITH CTE AS (
	SELECT
		s.customer_id,
		s.order_date,
		m.product_name,
		mb.join_date,
		DENSE_RANK() OVER (
		PARTITION BY s.customer_id
		ORDER BY s.order_date DESC
		) AS purchase_prior_member
	FROM dannys_diner.sales s
		JOIN dannys_diner.menu m ON s.product_id = m.product_id
		JOIN dannys_diner.members mb ON s.customer_id = mb.customer_id
	WHERE s.order_date < mb.join_date
)
SELECT
	customer_id,
    product_name
FROM CTE
WHERE purchase_prior_member = 1;
-- 8. What is the total items and amount spent for each member before they became a member?
	SELECT
		s.customer_id,
		COUNT(s.product_id) AS total_items,
        SUM(m.price) AS total_sales
	FROM dannys_diner.sales s
		JOIN dannys_diner.members mb ON s.customer_id = mb.customer_id
			AND s.order_date < mb.join_date
        JOIN dannys_diner.menu m ON s.product_id = m.product_id
    GROUP BY s.customer_id
    ORDER BY s.customer_id;
-- 9. If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
WITH CTE AS (
	SELECT
		s.customer_id,
		s.product_id,
		m.price,
		CASE
			WHEN s.product_id = 1 THEN FLOOR(m.price) * 20
			ELSE FLOOR(m.price) * 10
		END AS points 
	FROM dannys_diner.sales s
		JOIN dannys_diner.menu m ON s.product_id = m.product_id
)
SELECT
	customer_id,
    SUM(points) AS total_points
FROM CTE
GROUP BY customer_id
ORDER BY customer_id;

-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?
WITH promo_period_CTE AS (
	SELECT
		s.customer_id,
		mb.join_date,
		MIN(DATE_ADD(mb.join_date, INTERVAL 6 DAY)) as promo_end_date
	FROM dannys_diner.sales s
		JOIN dannys_diner.members mb ON s.customer_id = mb.customer_id
	GROUP BY s.customer_id, mb.join_date
)
SELECT
	s.customer_id,
	SUM(CASE
		WHEN s.order_date BETWEEN promo.join_date AND promo.promo_end_date THEN FLOOR(m.price) * 10 * 2
		WHEN m.product_id = 1 THEN FLOOR(m.price) * 10 * 2
		ELSE FLOOR(m.price) * 10
	END) AS total_points 
FROM dannys_diner.sales s
	JOIN promo_period_CTE promo ON promo.customer_id = s.customer_id
	JOIN dannys_diner.menu m ON s.product_id = m.product_id
WHERE MONTH(s.order_date) = 1
GROUP BY s.customer_id;

-- Join All The Things
-- Recreate the table with: customer_id, order_date, product_name, price, member (Y/N)
SELECT
	s.customer_id,
    s.order_date,
    m.product_name,
    m.price,
    CASE
        WHEN mb.join_date > s.order_date THEN 'Not a Member'
        WHEN mb.join_date <= s.order_date THEN 'Member'
        ELSE 'Not A Member'
    END AS membership_status
FROM dannys_diner.sales s
	LEFT JOIN dannys_diner.members mb ON s.customer_id = mb.customer_id
    JOIN dannys_diner.menu m ON s.product_id = m.product_id
ORDER BY customer_id;

-- Ranking All The Things
-- Danny also requires further information about the ranking of customer products, but he purposely does not need the ranking for non-member purchases so he expects null ranking values for the records when customers are not yet part of the loyalty program.
WITH customer_data AS (
SELECT
	s.customer_id,
    s.order_date,
    m.product_name,
    m.price,
    CASE
        WHEN mb.join_date > s.order_date THEN 'Not a Member'
        WHEN mb.join_date <= s.order_date THEN 'Member'
        ELSE 'Not A Member'
    END AS membership_status
FROM dannys_diner.sales s
	LEFT JOIN dannys_diner.members mb ON s.customer_id = mb.customer_id
    JOIN dannys_diner.menu m ON s.product_id = m.product_id
ORDER BY customer_id
)

SELECT
	*,
    CASE
		WHEN membership_status = 'Not a Member' THEN NULL
        ELSE RANK() OVER (
			PARTITION BY customer_id, membership_status
            ORDER BY order_date) 
		END AS product_ranking
FROM customer_data;
	