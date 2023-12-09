USE Bike_Sales_Project;

/**** IMPORTING DATA, CHECKING VALUES, DATA INTEGRITY AND CONSISTENCY ****/

-- Creating Table Bike_Sales to store the RAW data
IF OBJECT_ID('Bike_Sales') IS NOT NULL DROP TABLE Bike_Sales;

CREATE TABLE Bike_Sales(
	Date Date NULL
	,Day TINYINT NULL
	,Month NVARCHAR(255) NULL
	,Year SMALLINT NULL
	,Customer_Age SMALLINT NULL
	,Customer_Group NVARCHAR(255) NULL
	,Gender NVARCHAR(255) NULL
	,Country NVARCHAR(255) NULL
	,State NVARCHAR(255) NULL
	,Product_Category NVARCHAR(255) NULL
	,Sub_Category NVARCHAR(255)
	,Product NVARCHAR(255)
	,Order_Quantity SMALLINT
	,Unit_Cost DECIMAL(10,2) NULL
	,Unit_Price DECIMAL(10,2) NULL
	,Profit DECIMAL(10,2) NULL
	,Cost DECIMAL(10,2) NULL
	,Revenue DECIMAL(10,2) NULL
	);



/*----- ##### ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### ----- */



-- Importing the data from the CSV file into the Bike_Sales table
BULK INSERT Bike_Sales
FROM 
	'C:\Users\Acer\Documents\`_Projects\Project 1 - Bicycles\Excel Source Fike\Bicycle Data(world)_CSV.csv'
WITH (
	FORMAT = 'CSV'
	,FIRSTROW = 2
	,FIELDTERMINATOR = ','
	,ROWTERMINATOR = '\n'
);

-- Checking for null values in each columns
DECLARE @TableName NVARCHAR(50) = '[Bike_Sales]';
DECLARE @SQLQuery NVARCHAR(MAX) = 'SELECT TOP 1000 * FROM ' + @TableName + ' WHERE 1 = 0';

SELECT
	@SQLQuery += ' OR ' + QUOTENAME(name) + ' IS NULL'
FROM
	sys.columns 
WHERE
	[object_id] = OBJECT_ID(@TableName) AND is_nullable = 1;



/*----- ##### ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### ----- */



EXEC sp_executesql @SQLQuery;
/* ( did not find any null values ) */

-- Checking total distinct count for each column
DECLARE @TableName2 NVARCHAR(50) = '[Bike_Sales]';
DECLARE @SQLQuery2 NVARCHAR(MAX) = 'SELECT ';

SELECT 
    @SQLQuery2 += 'COUNT(DISTINCT ' + QUOTENAME(name) + ') AS Distinct_' + name + ', '
FROM 
    sys.columns
WHERE 
    [object_id] = OBJECT_ID(@TableName2) AND is_nullable = 1;

SET @SQLQuery2 = LEFT(@SQLQuery2, LEN(@SQLQuery2) - 1) + ' FROM ' + @TableName2;

EXEC sp_executesql @SQLQuery2;



/*----- ##### ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### ----- */



-- Adding a 'Reg_ID' column as a unique value to the Bike_Sales table (to help with manipulating data on the later stage)
ALTER TABLE Bike_Sales
ADD Reg_ID INT IDENTITY(1,1);

-- Cross Checking Cost, Profit and Revenue if they present the right values
WITH Cross_Checking AS
(
	SELECT
		TOP 500 Reg_ID
		,Order_Quantity
		,Unit_Cost
		,Unit_Price
		,Cost
		,Revenue
		,Profit
		,Order_Quantity * Unit_Cost AS NewCost
		,Order_Quantity * Unit_Price AS NewRevenue
		,(Order_Quantity * Unit_Price)-(Order_Quantity * Unit_Cost) AS NewProfit
		,CASE
			WHEN Cost = Order_Quantity * Unit_Cost THEN 'True'
			ELSE 'False'
		END AS Cost_Checking
		,CASE
			WHEN Revenue = Order_Quantity * Unit_Price THEN 'True'
			ELSE 'False'
		END AS Revenue_Checking
		,CASE
			WHEN Profit = (Order_Quantity * Unit_Price)-(Order_Quantity * Unit_Cost) THEN 'True'
			ELSE 'False'
		END AS Profit_Checking
	FROM
		Bike_Sales
)
SELECT
	*
FROM
	Cross_Checking
--WHERE
--	Cost_Checking = 'True' AND Revenue_Checking = 'True' AND Profit_Checking = 'True';



/*----- ##### ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### ----- */



/* (since the majority result for Profit and Revenue column is incorrect they will be drop in the creationg of Fact Table later) 
	Cost column will also be removed since it wouldn't make sense to leave it */

-- Checking for Country and States (Hierarchy) arrangement and row counts 
SELECT
	COUNT(DISTINCT State) AS Distinct_State_Count
FROM
	Bike_Sales;
/* (53 Rows the base total Row count,Since State is the bottom part of this hierarchy) */

WITH State_Country AS
(
	SELECT
		DISTINCT State AS Distinct_State
		,Country
	FROM
		Bike_Sales
)
SELECT
	COUNT(Distinct_State) Total_States
	,COUNT(Country) AS Total_Countries
FROM
	State_Country;
/* (no errors were found, Since both queries provide the same total row count) */

-- Checking for Product_Category,Sub_Category and Product (Hierarchy) structure and row counts 
SELECT
	COUNT(DISTINCT Product) AS Distinct_Product
FROM
	Bike_Sales;
/* (130 Rows the base total Row count,Since Product is the bottom part of this hierarchy) */

WITH Prod_Prod_Categ_Sub_Categ AS
(
	SELECT
		DISTINCT Product AS Distinct_Product
		,Product_Category
		,Sub_Category
	FROM
		Bike_Sales
)
SELECT
	COUNT(Distinct_Product) AS Total_Product
	,COUNT(Product_Category) AS Total_Product_Category
	,COUNT(Sub_Category) AS Total_Sub_Category
FROM
	Prod_Prod_Categ_Sub_Categ;
/* (Showing 138 Rows (when infact it should show only 130) there's a clear data inconsistency here) */



/*----- ##### ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### ----- */



/**** DATA INVESTIGATION ****/

-- Investigating the data inconsistency error when doing Product Hierarchy
WITH Reference AS
(
	SELECT
		Product
		,Sub_Category
		,Product_Category
	FROM
		Bike_Sales
	GROUP BY
		Product
		,Sub_Category
		,Product_Category 
	),
	Extraction AS
	(
	SELECT 
		Product
		,COUNT(Product) AS Register_Count
	FROM
		Reference
	GROUP BY
		Product
	HAVING
		COUNT(Product) > 1
	)
SELECT
	BS.Product
	,BS.Sub_Category
	,BS.Product_Category
	,COUNT(BS.Reg_ID) AS Reg_Count
INTO  #Suspected_Product
FROM
	Bike_Sales AS BS
		RIGHT JOIN
	Extraction AS EXT
	ON BS.Product = EXT.Product
WHERE
	BS.Product = EXT.Product
GROUP BY
	BS.Product
	,BS.Sub_Category
	,BS.Product_Category
ORDER BY
	BS.Product;



/*----- ##### ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### ----- */



/* Using the Reg_ID which is unique as count to determine, how many times a product appears in the table
	we can Average it in accordance to the products Sub_Category and Product_Category to return inconsistent products. */

-- Extracting the 8 Excessive row count
WITH Reg_Count AS 
(
	SELECT
		Product
		,Sub_Category
		,Product_Category
		,COUNT(Reg_ID) AS Reg_Count
	FROM
		Bike_Sales
	GROUP BY
		Product
		,Sub_Category
		,Product_Category
	),
	Reg_Avg AS (
	SELECT
		Sub_Category
		,Product_Category
		,AVG(Reg_Count) AS Avg_Reg
	FROM
		Reg_Count
	GROUP BY
		Sub_Category
		,Product_Category
)
SELECT
	SP.Product
	,SP.Sub_Category
	,SP.Product_Category
	,SP.Reg_Count
	,RA.Avg_Reg
INTO #Inconsistent_Product
FROM
	#Suspected_Product AS SP
		LEFT JOIN
	Reg_Avg AS RA
	ON SP.Product_Category = RA.Product_Category AND SP.Sub_Category = RA.Sub_Category
WHERE
	SP.Reg_Count < RA.Avg_Reg
ORDER BY
	1;



/*----- ##### ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### ----- */



-- Adding the correct Sub_Category and Product_Category for reference when updating the dataset
SELECT
	IPT.*
	,CASE
		WHEN IPT.Product IN(SP.Product) AND IPT.Sub_Category != SP.Sub_Category THEN SP.Sub_Category
	END AS Correct_Sub_Category
	,CASE
		WHEN IPT.Product IN(SP.Product) AND IPT.Product_Category != SP.Product_Category OR IPT.Product_Category = SP.Product_Category  THEN SP.Product_Category
	END AS Correct_Product_Category
INTO #Final_Inconsistent_Product
FROM
	#Inconsistent_Product AS IPT
		LEFT JOIN
	#Suspected_Product AS SP
	ON IPT.Product = SP.Product AND IPT.Sub_Category != SP.Sub_Category
ORDER BY
1;



/*----- ##### ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### ----- */



-- Applying the gathered evidence in the dataset
SELECT 
	SUM(Reg_Count) AS Total_Inconsistent_Reg
FROM
	#Final_Inconsistent_Product;
/* (24 is the total registered times for products who have incorrect Sub_Category and Product_Category) */

SELECT
	TOP 1000 -- For safeguard, incase we generate duplication due to incorrect join method
	BS.Product_Category
	,BS.Sub_Category
	,BS.Product
	,BS.Reg_ID
INTO #To_Change
FROM
	Bike_Sales AS BS
		LEFT JOIN
	#Final_Inconsistent_Product AS FIP
	ON BS.Product = FIP.Product AND BS.Sub_Category = FIP.Sub_Category AND BS.Product_Category = FIP.Product_Category
WHERE
	BS.Product_Category = FIP.Product_Category AND BS.Sub_Category = FIP.Sub_Category
ORDER BY
	BS.Product;

-- Cross-checking if the produced result matches with the base total registered times
SELECT
	COUNT(DISTINCT Reg_ID) AS Total_Unique_Reg
FROM 
	#To_Change
/* (Returns a total of 24. This confirms the baseline "Total_Inconsistent_Reg" that findings is matched) */



/*----- ##### ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### ----- */



/**** DATA CLEANING ****/

/* Using the SELECT statement to test if the appropriate rows are being affected by using CASE statement to ensure that 
	later on in the UPDATE statement only the intended part will be replaced with the right values.*/
SELECT
	BS.Product_Category
	,BS.Sub_Category
	,BS.Product
	,BS.Reg_ID
	,CASE
		WHEN BS.Reg_ID IN(TC.Reg_ID) AND BS.Sub_Category IN(TC.Sub_Category) THEN FIP.Correct_Sub_Category
	END AS Sub_Category_Test
	,CASE
		WHEN BS.Reg_ID IN(TC.Reg_ID) AND BS.Product_Category IN(TC.Product_Category) THEN FIP.Correct_Product_Category
	END AS Product_Category_Test
FROM
	Bike_Sales AS BS
		LEFT JOIN
	#To_Change AS TC
	ON TC.Reg_ID = BS.Reg_ID
		LEFT JOIN
	#Final_Inconsistent_Product AS FIP
	ON BS.Product = FIP.Product AND BS.Sub_Category = FIP.Sub_Category AND BS.Product_Category = FIP.Product_Category
WHERE
	BS.Reg_ID = TC.Reg_ID
ORDER BY
	BS.Product;

-- Updating the dataset with the right values to correct the Product Hiearachy Structure

BEGIN TRAN

UPDATE
	Bike_Sales
	SET
		Sub_Category =
		CASE
			WHEN BS.Reg_ID IN(TC.Reg_ID) AND BS.Sub_Category IN(TC.Sub_Category) THEN FIP.Correct_Sub_Category
		END,
		Product_Category =
		CASE
			WHEN BS.Reg_ID IN(TC.Reg_ID) AND BS.Product_Category IN(TC.Product_Category) THEN FIP.Correct_Product_Category
		END
	FROM
		Bike_Sales AS BS
			LEFT JOIN
		#To_Change AS TC
		ON TC.Reg_ID = BS.Reg_ID
			LEFT JOIN
		#Final_Inconsistent_Product AS FIP
		ON BS.Product = FIP.Product AND BS.Sub_Category = FIP.Sub_Category AND BS.Product_Category = FIP.Product_Category
	WHERE
		BS.Reg_ID = TC.Reg_ID;

 --COMMIT;
 --ROLLBACK;

-- confirming Product Hierarchy structure if it's already in correct row count
SELECT
	DISTINCT Product_Category
	,Sub_Category
	,Product 
FROM
	Bike_Sales;
/* (Shows total of 130 Rows, shows that the data is already corrected) */



/*----- ##### ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### ----- */



-- Trimming invisible trailing spaces from columns that stores string values
SELECT
	Column_Name
	,Data_Type
FROM
	INFORMATION_SCHEMA.COLUMNS
WHERE
	TABLE_NAME = 'Bike_Sales';

-- Selecting columns that stores strings values to be trimmed
SELECT
	TOP 1000 TRIM(Month) AS Month
	,TRIM(Age_Group) AS Age_Group
	,TRIM(Gender) AS Customer_Gender
	,TRIM(Country) AS Country
	,TRIM(State) AS State
	,TRIM(Product_Category) AS Product_Category
	,TRIM(Sub_Category) AS Sub_Category
	,TRIM(Product) AS Product
FROM
	Bike_Sales;

-- Updating string columns in the Bike_Sales table to remove leading and trailing spaces
BEGIN TRAN

UPDATE
	Bike_Sales
	SET 
		Month = TRIM(Month)
		,Age_Group = TRIM(Age_Group)
		,Gender = TRIM(Gender)
		,Country = TRIM(Country)
		,State = TRIM(State)
		,Product_Category = TRIM(Product_Category)
		,Sub_Category = TRIM(Sub_Category)
		,Product = TRIM(Product);

--COMMIT;
--ROLLBACK;



/*----- ##### ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### ----- */



/**** DATA MODELING ****/

-- Selecting columns that store string values
SELECT
	COLUMN_NAME
	,DATA_TYPE
FROM
	INFORMATION_SCHEMA.COLUMNS
WHERE
	TABLE_NAME = 'Bike_Sales'AND DATA_TYPE LIKE'%VAR%';

-- Determining the maximum character length for each column to set appropriate storage limits.
SELECT
	MAX(DISTINCT(LEN(Month))) AS Max_char_Month
	,MAX(DISTINCT(LEN(Age_Group))) AS Max_char_Age_Group
	,MAX(DISTINCT(LEN(Gender))) AS Max_char_Gender
	,MAX(DISTINCT(LEN(Country))) AS Max_char_Country
	,MAX(DISTINCT(LEN(State))) AS Max_char_Sate
	,MAX(DISTINCT(LEN(Product_Category))) AS Max_char_Product_Category
	,MAX(DISTINCT(LEN(Sub_Category))) AS Max_char_Sub_Category
	,MAX(DISTINCT(LEN(Product))) AS Max_char_Product
FROM
	Bike_Sales;



/*----- ##### ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### ----- */



/* Creating DIM_Product_Category, DIM_Sub_Category, DIM_Product with auto-incrementing primary keys
	to ensure data integrity. The primary keys in these tables will be used as foreign keys in other tables,
	providing a reliable way to link related data. By enforcing referential integrity through these keys,
	to maintain consistency and accuracy of the data throughout the database, even as new data is added in the future. */

CREATE TABLE DIM_Product_Category
(
	ProductCategoryKey SMALLINT IDENTITY(1,1) PRIMARY KEY
	,Product_Category NVARCHAR(50) UNIQUE  NOT NULL
);

-- Inserting Values to DIM_Product_Category Column Product_Category
INSERT INTO DIM_Product_Category (Product_Category)
SELECT
	 Product_Category
From
	Bike_Sales
GROUP BY
	Product_Category
ORDER BY
	CASE
		WHEN Product_Category = 'Accessories' THEN 1
		WHEN Product_Category = 'Bikes' THEN 2
		ELSE 3
	END

-- Checking DIM_Product_Category if Structure is correct
SELECT
	* 
FROM 
	DIM_Product_Category;



/*----- ##### ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### ----- */



-- Creating Table DIM_Sub_Category
CREATE TABLE DIM_Sub_Category
(
	SubcategoryKey SMALLINT IDENTITY(1,1) PRIMARY KEY
	,Sub_Category NVARCHAR(50) UNIQUE  NOT NULL
	,ProductCategoryKey SMALLINT NOT NULL
	,CONSTRAINT FK_DIM_Sub_Category_ProductCategoryKey FOREIGN KEY (ProductCategoryKey)
	REFERENCES DIM_Product_Category(ProductCategoryKey)
);

-- CTE to manipulate data to be combined and extracted from different table
WITH Ref AS
(
SELECT
	BS.Product_Category
	,BS.Sub_Category
	,PC.ProductCategoryKey
FROM
	Bike_Sales AS BS
		LEFT JOIN
	DIM_Product_Category AS PC
	ON BS.Product_Category = PC.Product_Category
GROUP BY
	BS.Product_Category
	,BS.Sub_Category
	,PC.ProductCategoryKey
)
-- Inserting Values to DIM_Sub_Category Columns Sub_Category,ProductCategoryKey
INSERT INTO DIM_Sub_Category (Sub_Category,ProductCategoryKey)
SELECT
	Sub_Category
	,ProductCategoryKey
FROM
	Ref
ORDER BY
	CASE
		WHEN Product_Category = 'Accessories' THEN 1
		WHEN Product_Category = 'Bikes' THEN 2
		ELSE 3
	END;

-- Checking DIM_Product_Category if Structure is correct
SELECT
	*
FROM
	DIM_Sub_Category;

-- Looking into what other columns are assocaited with Product
SELECT
	COLUMN_NAME
	,DATA_TYPE
FROM
	INFORMATION_SCHEMA.COLUMNS
WHERE
	TABLE_NAME = 'Bike_Sales'AND DATA_TYPE NOT LIKE'%VAR%';

-- Changing DECIMAL data types since, these columns doesn't store values with decimals
ALTER TABLE Bike_Sales
ALTER COLUMN Order_Quantity SMALLINT;

ALTER TABLE Bike_Sales
ALTER COLUMN Unit_Cost SMALLINT;

ALTER TABLE Bike_Sales
ALTER COLUMN Unit_Price SMALLINT;



/*----- ##### ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### ----- */



-- Creating Table DIM_Product (using 200 as base count on Productkey to be ensure to not encounter conflict with other autoincrement fields in the future)
CREATE TABLE DIM_Product
(
	ProductKey SMALLINT IDENTITY(200,1) PRIMARY KEY
	,Product NVARCHAR(50) UNIQUE  NOT NULL
	,SubcategoryKey SMALLINT NOT NULL
	,Unit_Cost SMALLINT NOT NULL
	,Unit_Price SMALLINT NOT NULL
	,CONSTRAINT FK_DIM_Product_SubcategoryKey FOREIGN KEY (SubcategoryKey)
	REFERENCES DIM_Sub_Category(SubcategoryKey)
);

-- CTE to manipulate data to be combined and extracted from different table
WITH Ref AS
(
SELECT
	DISTINCT BS.Product
	,SC.SubcategoryKey
	,Unit_Cost
	,Unit_Price
	,SC.Sub_Category
FROM
	Bike_Sales AS BS
	 RIGHT JOIN
	DIM_Sub_Category AS SC
	ON BS.Sub_Category = SC.Sub_Category
)
-- Inserting Values to DIM_Product Columns Product,SubcategoryKey,Unit_Cost,Unit_Price
INSERT INTO DIM_Product (Product,SubcategoryKey,Unit_Cost,Unit_Price)
SELECT
	Product, SubcategoryKey
	,Unit_Cost
	,Unit_Price
FROM
	Ref
ORDER BY
	2;



/*----- ##### ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### ----- */



-- Checking DIM_Product if Structure is correct
SELECT
	*
FROM
	DIM_Product;

/* Creating DIM_Country, DIM_States tables with auto-incrementing primary keys to ensure data integrity.
	The primary keys in these tables will be used as foreign keys in other tables, providing a reliable way
	to link related data. By enforcing referential integrity through these keys, to maintain consistency and 
	accuracy of the data throughout the database, even as new data is added in the future. */

CREATE TABLE DIM_Country
(
	Country_ID SMALLINT IDENTITY(1,1) PRIMARY KEY
	,Country NVARCHAR(50) UNIQUE  NOT NULL
	,Alpha_Code VARCHAR(20) NOT NULL
);

-- Inserting Values to DIM_Country Column Country
INSERT INTO DIM_Country (Country)
SELECT
	DISTINCT Country
	, CASE
        WHEN Country = 'Australia' THEN 'AUS'
        WHEN Country = 'Canada' THEN 'CAN'
        WHEN Country = 'France' THEN 'FRA'
        WHEN Country = 'Germany' THEN 'DEU'
        WHEN Country = 'United Kingdom' THEN 'GBR'
        WHEN Country = 'United States' THEN 'USA'
    END AS 'Alpha Code'
FROM
	Bike_Sales
GROUP BY
	Country
ORDER BY
	1;



/*----- ##### ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### ----- */



-- Checking DIM_Country if Structure is correct
SELECT
	*
FROM
	DIM_Country;

-- Creating Table DIM_States (using 101 as base count on State_ID to be ensure to not encounter conflict with other autoincrement fields in the future)
CREATE TABLE DIM_States 
(
   Country_ID SMALLINT NOT NULL
	,State VARCHAR(50) NOT NULL
	,State_ID INT IDENTITY(101, 1) NOT NULL
	,CONSTRAINT FK_DIM_Country FOREIGN KEY (Country_ID)
	REFERENCES DIM_Country(Country_ID)
);


-- CTE to manipulate data to be combined and extracted from different table sources
WITH Ref1 AS
(
	SELECT
		DC.Country_ID
		,BS.Country
	FROM
		Bike_Sales AS BS
			LEFT JOIN
		DIM_Country AS DC
		ON BS.Country = DC.Country
	GROUP BY
		DC.Country_ID
		,BS.Country
),
Ref2 AS
(
	SELECT
		DISTINCT R1.Country_ID
		,R1.Country
		,BS.State
	FROM
		Bike_Sales BS 
			JOIN
		Ref1 AS R1
		ON BS.Country = R1.Country
)
-- Inserting Values to DIM_States Columns Country_ID,State
INSERT INTO DIM_States (Country_ID,State)
SELECT
	rf1.Country_ID
	,rf2.State
FROM
	Ref1 AS rf1
	JOIN
	Ref2 AS rf2
	ON rf1.Country_ID = rf2.Country_ID
ORDER BY
	1;



/*----- ##### ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### ----- */



-- Checking DIM_Country if Structure is correct
SELECT 
	* 
FROM 
	DIM_States;

-- Creating Table DIM_Dates with autoincrement date, to see sales gap (dates with no sales), and would be use in analyzing the data
CREATE TABLE DIM_Date
(
	Date DATE PRIMARY KEY
	,Day TINYINT NOT NULL
	,Month NVARCHAR(50) NOT NULL
	,Month_No TINYINT NOT NULL
	,YEAR SMALLINT NOT NULL
);

-- Inserting Values to DIM_Date Columns Date,Day,Month, Month_No,Year
DECLARE @StartDate DATE = '2011-01-01'
DECLARE @EndDate DATE = '2016-12-31'
DECLARE @Counter INT = 1

WHILE 
	@StartDate <= @EndDate
	BEGIN
		INSERT INTO DIM_Date (Date, Day, Month, Month_No, Year)
			VALUES 
				(
				@StartDate
				,DAY(@StartDate)
				,DATENAME(MONTH, @StartDate)
				,DATEPART(MM, @StartDate)
				,YEAR(@StartDate)
				)
		SET @Counter += 1
		SET @StartDate = DATEADD(DAY, 1, @StartDate)
	END;

-- Checking DIM_Date if Structure is correct
SELECT 
	 *
FROM 
	DIM_Date;

--Looking into columns that are related FACT table
SELECT
	COLUMN_NAME
	,DATA_TYPE
FROM
	INFORMATION_SCHEMA.COLUMNS
WHERE
	TABLE_NAME = 'Bike_Sales'



/*----- ##### ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### ----- */



-- Creating Table FACT_Bike_Sales
CREATE TABLE FACT_Bike_Sales
(
	Date DATE NOT NULL
	,Customer_Age TINYINT NOT NULL
	,Customer_Gender NVARCHAR(15) NOT NULL
	,Country_ID SMALLINT NOT NULL
	,State_ID INT NOT NULL
	,Product_Key SMALLINT NOT NULL
	,Order_Quantity SMALLINT NOT NULL

	,CONSTRAINT FK_DIM_Date_Connection FOREIGN KEY (Date)
	REFERENCES DIM_Date (Date)
	,CONSTRAINT FK_DIM_Country_Connection FOREIGN KEY (Country_ID)
	REFERENCES DIM_Country (Country_ID)
	,CONSTRAINT FK_DIM_States_Connection FOREIGN KEY (State_ID)
	REFERENCES DIM_States (State_ID)
	,CONSTRAINT FK_DIM_Product_Connection FOREIGN KEY (Product_Key)
	REFERENCES DIM_Product (ProductKey)
);

-- Inserting Values to FACT_Bike_Sales Columns Date,Customer_Age,Customer_Gender,Country_ID,State_ID,Product_Key,Order_Quantity,Cost,Profit,Revenue
INSERT INTO FACT_Bike_Sales (Date,Customer_Age,Customer_Gender,Country_ID,State_ID,Product_Key,Order_Quantity)
SELECT
 --	Reg_ID, Used to verify if everything is correct
	Date
	,Customer_Age
	,CASE
		WHEN Gender = 'M' THEN 'Male'
		ELSE 'Female'
	END AS Customer_Gender
	,CASE
		WHEN BS.Country IS NOT NULL THEN DC.Country_ID
	END AS Country_ID
	,CASE
		WHEN BS.State IS NOT NULL THEN DS.State_ID
	END AS State_ID
	,CASE
		WHEN BS.Product IS NOT NULL THEN DP.ProductKey
	END AS Product_Key
	,Order_Quantity
FROM 
	Bike_Sales AS BS
		LEFT JOIN
	DIM_Country AS DC
	ON BS.Country = DC.Country
		LEFT JOIN
	DIM_States AS DS
	ON BS.State = DS.State
		LEFT JOIN
	DIM_Product AS DP
	ON BS.Product = DP.Product;
-- Order by
-- 1



/*----- ##### ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### ----- */



/* Data Analysis */

-- Extracting all data that were needed in the analysis stage then store in a temporary table for fast processing.

SELECT
	FBS.Date
	,DD.Month
	,DD.Month_No
	,DD.YEAR
	,DPC.Product_Category
	,DSC.Sub_Category
	,DP.Product
	,DC.Country
	,DS.State
	,FBS.Customer_Age
	,FBS.Customer_Gender
	,FBS.Order_Quantity
	,DP.Unit_Price * FBS.Order_Quantity AS Product_Revenue
INTO #Data_To_Use
FROM
	FACT_Bike_Sales AS FBS
		LEFT JOIN
	DIM_Date AS DD
	ON FBS.Date = DD.Date
		LEFT JOIN
	DIM_Product AS DP
	ON FBS.Product_Key = DP.ProductKey
		LEFT JOIN
	DIM_Sub_Category AS DSC
	ON DP.SubcategoryKey= DSC.SubcategoryKey
		LEFT JOIN
	DIM_Product_Category AS DPC
	ON DSC.ProductCategoryKey = DPC.ProductCategoryKey
		LEFT JOIN
	DIM_Country AS DC
	ON FBS.Country_ID = DC.Country_ID
		LEFT JOIN
	DIM_States AS DS
	ON FBS.State_ID = DS.State_ID;



/*----- ##### ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### ----- */



WITH Product_Sales_Year AS (
-- Analyzing the sales perfomarnce where 3 product categories are present.
	SELECT
		DISTINCT Month
		,Month_No
		,YEAR
		,Product_Category
		,SUM(Order_Quantity) AS Total_Order_Quantity
		,SUM(Product_Revenue) AS Total_Revenue
	FROM
		#Data_To_Use
	GROUP BY
		YEAR
		,Month
		,Month_No
		,Product_Category
	--ORDER BY
	--	YEAR
	--	,Month_No
)
/*( After seeing the result, The full operation took in July of 2013 on wards, where each categories do have sales records. That's because
	From 2011 until June of 2013 the company is only selling Bike Products.
	
	This information would narrow down the scope and focusing on months which have complete product category data (August to December) 
	that would help in analyzing the re-stocking of products in the upcoming months for year 2016)*/
SELECT
	Month
	,Month_No
	,YEAR
	,Product_Category
	,Total_Order_Quantity
	,Total_Revenue
FROM
	Product_Sales_Year
WHERE
	Month_No IN (8,9,10,11,12) AND Year NOT IN (2011, 2012) AND Product_Category IS NOT NULL
ORDER BY
	YEAR ASC
	,Month_No ASC
	,Product_Category ASC;
/*( Extracting data which the satifies the date range interest. )*/



/*----- ##### ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### ----- */



-- Getting products whose sales performance are great, based on combined total revenue for year 2013 and 2015.
WITH Product_Year_Reference AS
(
	SELECT
		Date
		,Month
		,Month_No
		,YEAR
		,Product_Category
		,Sub_Category
		,Product
		,SUM(Product_Revenue) AS Product_Revenue
		,CAST(AVG(Product_Revenue) AS INT) AS Product_Average_Revenue
		,SUM(Order_Quantity) AS Product_Total_Sold
		,AVG(Order_Quantity) AS Average_Product_Sold
	FROM
		#Data_To_Use
	WHERE
		Month_No IN (8, 9 ,10 ,11 ,12) AND Year NOT IN (2011, 2012) AND Product_Category IS NOT NULL
	GROUP BY
		Date
		,Month
		,Month_No
		,YEAR
		,Product_Category
		,Sub_Category
		,Product
/* (Extracted relevant columns that would help in analyzing 'Recommended products' during the specifid date condition,
	Since the 'Date' values used came from the FACT table that records the actual date of purchase,
	The averaging calculation for designated metrics would be accurate) */
)
, Ranked_Products AS
(
	SELECT
		Product_Category
		,Sub_Category
		,Product
		,SUM(Product_Revenue) AS Total_Revenue_2013_2015
		,SUM(Product_Average_Revenue) AS Average_Revenue_2013_2015
		,SUM(Product_Total_Sold) AS Total_Sold_2013_2015
		,SUM(Average_Product_Sold) AS Average_Sold_2013_2015
		,RANK() OVER(PARTITION BY Product_Category, Sub_Category ORDER BY SUM(Product_Revenue) DESC) AS Product_Tota_Revenue_Rank
	FROM
		Product_Year_Reference
	GROUP BY
		Product_Category
		,Product
		,Sub_Category
/* (After getting the data, and summing up the metrics values that came from year 2013 and 2015 specified months. Each products
	where rank based on their total revenue. To know which products performs Sub Category wise.) */
)
SELECT
	Product_Category
	,Product
	,Sub_Category
	,Product_Tota_Revenue_Rank
	,Total_Revenue_2013_2015
	,Average_Revenue_2013_2015
	,Total_Sold_2013_2015
	,Average_Sold_2013_2015
INTO #Product_Ranked
FROM
	Ranked_Products;



/*----- ##### ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### ----- */



-- Creating a benchmark to help in extracting notable products from their respective Sub categories by making a 'Sub Category average revenue'.
WITH Sub_Category_Year_Reference AS
(
	SELECT
		Date
		,Sub_Category
		,CAST(AVG(Product_Revenue) AS INT) AS Sub_C_Average_Revenue
		,AVG(Order_Quantity) AS Average_Product_Sold
	FROM
		#Data_To_Use
	WHERE
		Month_No IN (8, 9 ,10 ,11 ,12) AND Year NOT IN (2011, 2012) AND Product_Category IS NOT NULL
	GROUP BY
		Date
		,Sub_Category
)
/* (Grouping the data to get a combined 2013 and 2015 average records that would become the benchmark in extracting products.) */
SELECT
	Sub_Category
	,SUM(Sub_C_Average_Revenue) AS Sub_C_Average_Revenue_2013_2015
	,SUM(Average_Product_Sold) AS Sub_C_Average_Sold_2013_2015
INTO #Sub_Category_Average_Revenue
FROM
	Sub_Category_Year_Reference
GROUP BY
	Sub_Category
ORDER BY
	1;



/*----- ##### ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### ----- */



-- Extracting Notable Products whose Total Revenue (August-December) is greater or equal to their Sub categories Average Revenue (August-December)
SELECT
	PR.Sub_Category
	,PR.Product_Tota_Revenue_Rank
	,PR.Product
	,PR.Total_Revenue_2013_2015 AS Product_Total_Sales
	,SAR.Sub_C_Average_Revenue_2013_2015 AS Sub_Category_Average_Sales
	,ROUND((CAST(PR.Total_Revenue_2013_2015 AS FLOAT) - CAST(SAR.Sub_C_Average_Revenue_2013_2015 AS FLOAT)) 
	/ CAST(SAR.Sub_C_Average_Revenue_2013_2015 AS FLOAT) * 100,2) AS Diffrence_in_Percentage
	,CASE
		WHEN Product IS NOT NULL THEN 'High Potential'
	END AS 'Product_Performance'
	,PR.Total_Sold_2013_2015 AS Product_Total_Sold
INTO  #High_Performing_Products
FROM
	#Product_Ranked AS PR
		LEFT JOIN
	#Sub_Category_Average_Revenue AS SAR
	ON PR.Sub_Category = SAR.Sub_Category
WHERE
	 PR.Total_Revenue_2013_2015 > SAR.Sub_C_Average_Revenue_2013_2015;
/* (There are only 38 notable products which satisfies the conditon, these products would be priority for re-stocking) */



/*----- ##### ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### ----- */



-- Extracting products which falls into top 10 in terms total sales under their respective Sub Categories but falls short when compared to Sub Categories Average sales.
WITH Condition_Set AS
(
	SELECT
		PR.Sub_Category
		,PR.Product_Tota_Revenue_Rank
		,PR.Product
		,PR.Total_Revenue_2013_2015 AS Product_Total_Sales
		,PR.Total_Sold_2013_2015 AS Product_Total_Sold
		,ROUND((CAST(PR.Total_Revenue_2013_2015 AS FLOAT) - CAST(SAR.Sub_C_Average_Revenue_2013_2015 AS FLOAT)) 
		/ CAST(SAR.Sub_C_Average_Revenue_2013_2015 AS FLOAT) * 100,2) AS Diffrence_in_Percentage
		,SAR.Sub_C_Average_Revenue_2013_2015
	FROM
		#Product_Ranked AS PR
			LEFT JOIN
		#High_Performing_Products AS HPP
		ON PR.Sub_Category = HPP.Sub_Category AND PR.Product = HPP.Product
			LEFT JOIN
		#Sub_Category_Average_Revenue AS SAR
		ON PR.Sub_Category = SAR.Sub_Category
	WHERE
		PR.Product_Tota_Revenue_Rank <= 10 AND HPP.Product IS NULL
)
SELECT
	Sub_Category
	,Product_Tota_Revenue_Rank
	,Product
	,Product_Total_Sales
	,Sub_C_Average_Revenue_2013_2015
	,Diffrence_in_Percentage
	,CASE
		WHEN Product IS NOT NULL AND Diffrence_in_Percentage > -25 THEN 'Minimum Potential'
		WHEN Diffrence_in_Percentage > -50.00  THEN 'Less Potential'
	END AS 'Product_Performance'
	,Product_Total_Sold
INTO #Products_with_Potential
FROM
	Condition_Set
WHERE
	Diffrence_in_Percentage >= -50
ORDER BY
	6;



/*----- ##### ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### ----- */



-- Combining High Performing and Potential Products
WITH Combining_High_Performing_Producs_Potential_Products AS
(
	SELECT
		*
	FROM
		#High_Performing_Products
	UNION ALL
	SELECT
		*
	FROM
		#Products_with_Potential
)
SELECT
	*
INTO #Products_to_be_ReStock
FROM
	Combining_High_Performing_Producs_Potential_Products
ORDER BY
	1 DESC;

-- Products which are not included in the 'Potential products'
SELECT
	DP.Product
FROM
	DIM_Product AS DP
		LEFT JOIN
	#Products_to_be_ReStock AS PTBR
	ON DP.Product = PTBR.Product
WHERE
	PTBR.Product IS NULL;



/*----- ##### ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### ----- */



-- Preparing data to be used in the creation of prediction model and storing in View to be pulled in python, 

IF OBJECT_ID('Data_For_Prediction') IS NOT NULL DROP VIEW Data_For_Prediction;

CREATE VIEW Data_For_Prediction AS
SELECT
	FBS.Date
	,DD.Month_No
	,DP.Product
	,DP.Unit_Price * FBS.Order_Quantity AS Product_Revenue
	,FBS.Order_Quantity
	FROM
	FACT_Bike_Sales AS FBS
		LEFT JOIN
	DIM_Date AS DD
	ON FBS.Date = DD.Date
		LEFT JOIN
	DIM_Product AS DP
	ON FBS.Product_Key = DP.ProductKey
WHERE
	YEAR(FBS.Date) NOT IN(2011, 2012) AND DD.Month_No IN (8, 9 ,10 ,11 ,12);
/*(Data to used in training model)*/

IF OBJECT_ID('Data_2016') IS NOT NULL DROP VIEW Data_2016;

CREATE VIEW Data_2016 AS
SELECT
	FBS.Date
	,DD.Month_No
	,DP.Product
	,DP.Unit_Price * FBS.Order_Quantity AS Product_Revenue
	,FBS.Order_Quantity
	FROM
	FACT_Bike_Sales AS FBS
		LEFT JOIN
	DIM_Date AS DD
	ON FBS.Date = DD.Date
		LEFT JOIN
	DIM_Product AS DP
	ON FBS.Product_Key = DP.ProductKey
WHERE
	YEAR(FBS.Date) = 2016;
/*(Data used to attach the projected value)*/

-- Extracting customers and related data to be used in analyzing potential sales sources based on the recommended products.
SELECT
	DTU.Date
	,DTU.Month
	,DTU.Month_No
	,DTU.Customer_Age
	,DTU.Customer_Gender
	,DTU.Country
	,DTU.State
	,PTRB.Product
	,DTU.Product_Revenue
	,DTU.Order_Quantity
INTO #Customer_Data
FROM
	#Data_To_Use AS DTU
		RIGHT JOIN
	#Products_to_be_ReStock AS PTRB
	ON DTU.Product = PTRB.Product
WHERE
	YEAR(Date) NOT IN(2011, 2012) AND Month_No IN (8, 9 ,10 ,11 ,12);



/*----- ##### ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### ----- */



-- Looking into which countries to expect the most revenue would come from based on the selected recommended products.

SELECT
	Country
	,COUNT(DISTINCT state) AS Total_Distinct_States
	,SUM(Product_Revenue) AS Total_Revenue
	,SUM(Order_Quantity) AS Total_Order
FROM
	#Customer_Data
GROUP BY
	Country
ORDER BY
	3 DESC;

-- Looking into states percentage generated total revenue
WITH States_Revenue AS
(
	SELECT
		Country
		,State
		,SUM(Product_Revenue) AS Total_Revenue
		,ROUND(CAST(SUM(Product_Revenue) * 100  / SUM(SUM(Product_Revenue)) OVER(PARTITION BY Country) AS FLOAT),2) AS Revenue_Percentage
		,SUM(Order_Quantity) AS Total_Order
	FROM
		#Customer_Data
	GROUP BY
		Country,
		state
	--ORDER BY
	--	Country ASC,
	--	Total_Revenue DESC
)
/*(After seeing the revenue percentage by countries states, some states don't contribute "below 0% revenue" that much therefore they would be excluded)*/

SELECT
	*
FROM
	States_Revenue
WHERE
	Revenue_Percentage >= 1
ORDER BY
	Country ASC,
	Total_Revenue DESC;
/*(Base on the result, there are only few states within Australia, Canada and United States that contribute the most in terms of revenue generated,
	France and Germany revenue are distributed across its states. while United Kingdom only has 1 registered state, results in having 100% revenue percentage)*/



/*----- ##### ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### --- #####  ----- // ----- ##### ----- */



-- Looking into which age groups to expect the most revenue would come from based on the selected recommended products.
WITH Customer_Age_Group AS
(
	SELECT
		Country
		,Customer_Age
		,CASE
			WHEN Customer_Age <= 24 THEN 'Youth < 24'
			WHEN Customer_Age >= 25 AND Customer_Age <= 59 THEN 'Adult < 59' 
			ELSE 'Senior 60+'
		END AS Age_Group
		,SUM(Product_Revenue) AS Total_Revenue
		,SUM(Order_Quantity) AS Total_Order
	FROM
		#Customer_Data
	GROUP BY
		Country
		,Customer_Age
)
SELECT
	Country
	,Age_Group
	,SUM(Total_Revenue) AS Group_Total_Revenue
	,ROUND(CAST(SUM(Total_Revenue) * 100  / SUM(SUM(Total_Revenue)) OVER(PARTITION BY Country) AS FLOAT),2) AS Revenue_Percentage
	,SUM(Total_Order) AS Group_Total_Order
FROM
	Customer_Age_Group
GROUP BY
	Country
	,Age_Group
ORDER BY
	1 ASC
	,CASE
		WHEN Age_Group = 'Youth < 24' THEN 1
		WHEN Age_Group = 'Adult < 59' THEN 2
		ELSE 3
	END;
/*(Base on the result, the revenue is expected to come from; 1st - Adults which is dominant across all countries
	then 2nd - Youths and lastly 3rd - Seniors)*/