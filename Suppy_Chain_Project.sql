CREATE DATABASE Supply_Chain;

use supply_chain;

-- 1. DIM_SUPPLIER

CREATE TABLE Dim_Supplier (
    Supplier_ID VARCHAR(10) NOT NULL,
    Supplier_Name VARCHAR(50) NOT NULL,
    Supplier_Country VARCHAR(30) NOT NULL,
    Supplier_City VARCHAR(30) NOT NULL,
    Supplier_Tier CHAR(1) NOT NULL,   -- A, B, C
    Reliability_Score DECIMAL(5,2) NOT NULL,   -- 0-100
    PRIMARY KEY (Supplier_ID)
);

SELECT * FROM DIM_SUPPLIER;



-- 2. DIM_PRODUCT

CREATE TABLE Dim_Product (
    Product_ID VARCHAR(10) NOT NULL,
    Product_Name VARCHAR(50) NOT NULL,
    Category VARCHAR(30) NOT NULL,
    Sub_Category VARCHAR(30)  NOT NULL,
    Unit_Cost DECIMAL(10,2) NOT NULL,
    Unit_Price DECIMAL(10,2) NOT NULL,
    Primary_Supplier_ID  VARCHAR(10)  NOT NULL,
    PRIMARY KEY (Product_ID),
    FOREIGN KEY (Primary_Supplier_ID) REFERENCES Dim_Supplier(Supplier_ID)
);

-- 3. DIM_WAREHOUSE

CREATE TABLE Dim_Warehouse (
    Warehouse_ID VARCHAR(10) NOT NULL,
    Warehouse_City VARCHAR(30) NOT NULL,
    Warehouse_Country VARCHAR(30) NOT NULL,
    Warehouse_Region VARCHAR(20) NOT NULL,
    Capacity_Units INT NOT NULL,
    PRIMARY KEY (Warehouse_ID)
);

-- 4. DIM_CUSTOMER

CREATE TABLE Dim_Customer (
    Customer_ID VARCHAR(12)   NOT NULL,
    Customer_Region VARCHAR(20)  NOT NULL,
    Customer_Country VARCHAR(20)  NOT NULL,
    Customer_City VARCHAR(20)  NOT NULL,
    Customer_Segment VARCHAR(15)  NOT NULL,   
    PRIMARY KEY (Customer_ID)
);




-- 5. FACT_ORDERS

CREATE TABLE Fact_Orders (
    Order_ID VARCHAR(12) NOT NULL,
    Customer_ID VARCHAR(12) NOT NULL,
    Product_ID VARCHAR(10) NOT NULL,
    Supplier_ID VARCHAR(10) NOT NULL,
    Warehouse_ID VARCHAR(10) NOT NULL,
    Order_Date DATE NOT NULL,
    Ship_Date DATE NOT NULL,
    Promised_Delivery_Date DATE NOT NULL,
    Actual_Delivery_Date DATE NOT NULL,
    Ship_Mode VARCHAR(15) NOT NULL,  -- Air, Sea, Road, Rail, Same-day
    Carrier VARCHAR(30) NOT NULL,
    Order_Quantity INT NOT NULL,
    Shipped_Quantity INT NOT NULL,
    Unit_Price DECIMAL(10,2) NOT NULL,
    Unit_Cost DECIMAL(10,2) NOT NULL,
    Revenue DECIMAL(12,2) NOT NULL,
    COGS DECIMAL(12,2) NOT NULL,
    Shipping_Cost DECIMAL(10,2) NOT NULL,
    Processing_Days INT NOT NULL,
    Transit_Days INT NOT NULL,
    Delay_Days INT NOT NULL,
    Delivery_Status VARCHAR(20) NOT NULL, -- On-Time / Slightly Delayed / Delayed
    Fill_Rate_Pct DECIMAL(5,2) NOT NULL,
    PRIMARY KEY (Order_ID),
    FOREIGN KEY (Customer_ID) REFERENCES Dim_Customer(Customer_ID),
    FOREIGN KEY (Product_ID) REFERENCES Dim_Product(Product_ID),
    FOREIGN KEY (Supplier_ID) REFERENCES Dim_Supplier(Supplier_ID),
    FOREIGN KEY (Warehouse_ID) REFERENCES Dim_Warehouse(Warehouse_ID)
);

-- 6. FACT_INVENTORY

CREATE TABLE Fact_Inventory (
    Inventory_ID INT NOT NULL AUTO_INCREMENT,  -- surrogate key
    Product_ID VARCHAR(10) NOT NULL,
    Warehouse_ID VARCHAR(10) NOT NULL,
    Snapshot_Date DATE NOT NULL,
    Stock_On_Hand INT NOT NULL,
    Reorder_Level INT NOT NULL,
    Safety_Stock INT NOT NULL,
    Units_Received INT NOT NULL,
    Units_Shipped INT NOT NULL,
    Days_Of_Supply DECIMAL(8,2)  NOT NULL,
    Stockout_Flag TINYINT(1) NOT NULL,   
    Inventory_Value DECIMAL(14,2) NOT NULL,
    Reorder_Status VARCHAR(15)  NOT NULL,  
    Stock_Health VARCHAR(20)  NOT NULL,
    COGS_for_Product DECIMAL(14,2) NOT NULL,
    Inventory_Turnover DECIMAL(12,4) NOT NULL,
    Days_Inventory_On_Hand DECIMAL(10,4) NOT NULL,
    PRIMARY KEY (Inventory_ID),
    UNIQUE KEY uq_product_wh_date (Product_ID, Warehouse_ID, Snapshot_Date),
    FOREIGN KEY (Product_ID) REFERENCES Dim_Product(Product_ID),
    FOREIGN KEY (Warehouse_ID) REFERENCES Dim_Warehouse(Warehouse_ID)
);


SELECT * FROM FACT_ORDERS;
SELECT * FROM FACT_INVENTORY;
SELECT * FROM DIM_WAREHOUSE ;
SELECT * FROM DIM_PRODUCT;
SELECT * FROM DIM_SUPPLIER;
SELECT * FROM DIM_CUSTOMER;


-- 1. Order & Sales KPIs

SELECT DISTINCT
    COUNT(ORDER_ID) AS TOTAL_ORDERS
FROM
    FACT_ORDERS;

-- 3) Total Sales Revenue 

SELECT 
    CONCAT(ROUND(SUM(unit_price * order_quantity) / 100000,
                    2),
            'M') AS Total_Revenue
FROM
    fact_orders;

-- 4) Average Order Value (AOV) 

SELECT 
    ROUND(SUM(unit_price * order_quantity) / COUNT(DISTINCT order_id),
            2) AS AVG_AOV
FROM
    fact_orders;

-- 3) Orders by Region/Country/City 

SELECT 
    IFNULL(dw.warehouse_region, 'Grand Total') AS Warehouse_Region,
    IFNULL(dw.warehouse_country, 'Grand Total') AS Warehouse_Country,
    IFNULL(dw.warehouse_city, 'Grand Total') AS Warehouse_City,
    COUNT(fo.order_id) AS Total_Orders
FROM
    Dim_Warehouse dw
        LEFT JOIN
    Fact_Orders fo ON dw.Warehouse_ID = fo.Warehouse_ID
GROUP BY dw.warehouse_region , dw.warehouse_country , dw.warehouse_city WITH ROLLUP;


-- 2. Inventory & Stock KPIs
-- 1) Stock on Hand 

SELECT 
    CONCAT(ROUND(SUM(stock_On_hand) / 1000000, 2),
            'M') AS Total_Stock
FROM
    fact_inventory;

-- 2) Reorder Status 

SELECT 
    CONCAT(ROUND(SUM(CASE
                        WHEN stock_on_hand >= reorder_level THEN 1
                        ELSE 0
                    END) * 100.0 / COUNT(*),
                    2),
            '%') AS sufficient_stock_percentage
FROM
    fact_inventory;

-- 3) Average Lead Time 

SELECT 
    ROUND(AVG(processing_days), 2) AS avg_lead_time
FROM
    fact_orders;

-- 4) Inventory Value
SELECT 
    CONCAT(ROUND(SUM(INVENTORY_VALUE) / 1000000, 2),
            'M') AS TOTAL_INVENTORY_VALUE
FROM
    FACT_INVENTORY;

-- 5) Inventory Turnover Ratio 

SELECT 
    ROUND((SELECT 
                    SUM(COGS)
                FROM
                    Fact_Orders) / (SELECT 
                    AVG(Stock_On_Hand)
                FROM
                    Fact_Inventory),
            0) AS Inventory_Turnover_Ratio;


-- 3. Procurement & Cost KPIs

-- 1) Procurement Cost 
SELECT 
    CONCAT(ROUND(SUM(COGS)/1000000,2),"M") AS procurement_cost
FROM
    fact_orders;

-- Transportation Cost 
SELECT 
   CONCAT( ROUND(SUM(shipping_cost)/100000,2),"M")AS procurement_cost
FROM
    fact_orders;
    

-- Total Supply Chain Cost 
SELECT 
    CONCAT(ROUND((SUM(COGS) + SUM(Shipping_Cost)) / 1000000, 0), "M") AS Total_Supply_Chain_Cost
FROM
    fact_orders;

-- Cost per Unit 

SELECT 
    ROUND(SUM(cogs) / SUM(order_quantity), 2) AS cost_per_unit
FROM
    fact_orders;


-- 4. Logistics & Delivery KPIs
-- 1) On-Time Delivery % 

SELECT 
    Delivery_Status,
    COUNT(*) AS Order_Count,
    CONCAT(ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM fact_orders), 2), '%') AS Percentage
FROM
    fact_orders
GROUP BY Delivery_Status
ORDER BY CONCAT(ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM fact_orders), 2), '%') DESC;


-- 2) Orders by Ship Mode 

SELECT 
    ship_mode,
    COUNT(order_id) AS Orders_by_shipmode,
    CONCAT(ROUND(COUNT(order_id) * 100.0 /(SELECT COUNT(order_id) FROM fact_orders),2),
        '%') AS Perc_by_shipmode
FROM fact_orders
GROUP BY ship_mode
ORDER BY Orders_by_shipmode DESC;
 

-- 5. Demand & Fulfillment KPIs
-- 1) Forecasr Accuracy

SELECT
    MONTH(order_date) AS month_number,
    MONTHNAME(order_date) AS month_,
    SUM(order_quantity) AS total_order_quantity,
    SUM(shipped_quantity) AS total_shipped_quantity,
   concat(ROUND(
        SUM(shipped_quantity) * 100.0
        / NULLIF(SUM(order_quantity), 0),
        2
    ),"%") AS forecast_accuracy
FROM fact_orders
GROUP BY
    MONTH(order_date),
    MONTHNAME(order_date)
ORDER BY month_number;


-- 2) Fill Rate 

SELECT 
    MONTHNAME(order_date) AS month_,
    SUM(order_quantity) AS total_order_quantity,
    SUM(shipped_quantity) AS total_shipped_quantity,
    CONCAT(ROUND(
        SUM(shipped_quantity) * 100.0
        / NULLIF(SUM(order_quantity), 0),
        2
    ),"%")AS fill_rate_percentage
FROM fact_orders
GROUP BY MONTHNAME(order_date)
WITH ROLLUP;



SELECT * FROM FACT_ORDERS;
SELECT * FROM FACT_INVENTORY;
SELECT * FROM DIM_WAREHOUSE ;
SELECT * FROM DIM_PRODUCT;
SELECT * FROM DIM_SUPPLIER;
SELECT * FROM DIM_CUSTOMER;


