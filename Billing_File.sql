---------------------------------------------------------------
--- Total Billing Per Client
with combineall as 
(
	select * from AvoxiBillingFile..Jan where Customer is not null
	union all
	select * from AvoxiBillingFile..Feb where Customer is not null
	union all
	select * from AvoxiBillingFile..March where Customer is not null
)

select com.Customer,
	   round(sum(case when com.Called_From = 'Mobile' then CEILING(com.Duration_Seconds / 60.0) * cli.Mobile_Rate
            ELSE CEILING(com.Duration_Seconds / 60.0) * cli.Landline_Rate  end),2) as total_billing
from combineall com
join AvoxiBillingFile..Rates_Clients cli
	on com.AccountID = cli.AccountID
group by com.customer
order by com.Customer



---------------------------------------------------------------
---- Gross Margin Calculation by Country

-- create a tempoeray table for all combined data from Jan-March and can be use it later.
DROP TABLE #combineall; 

create table #combineall
(
	Customer varchar(255),
	AccountID bigint,                
    Duration_Seconds bigint,         
    Called_From VARCHAR(50)
);

insert into #combineall
	select * from AvoxiBillingFile..Jan where Customer is not null
	union all
	select * from AvoxiBillingFile..Feb where Customer is not null
	union all
	select * from AvoxiBillingFile..March where Customer is not null;

select * from #combineall;




WITH totalbill AS (
    SELECT 
        com.Customer, 
        com.AccountID, 
        cli.Country, 
        ROUND(
            SUM(
                CASE 
                    WHEN com.Called_From = 'Mobile' THEN CEILING(com.Duration_Seconds / 60.0) * cli.Mobile_Rate
                    ELSE CEILING(com.Duration_Seconds / 60.0) * cli.Landline_Rate 
                END
            ), 2
        ) AS total_billing
    FROM #combineall com
    JOIN AvoxiBillingFile..Rates_Clients cli
        ON com.AccountID = cli.AccountID
    GROUP BY com.Customer, com.AccountID, cli.Country
),

vendorcost AS (
    SELECT 
        com.Customer, 
        com.AccountID, 
        com.Duration_Seconds, 
        com.Called_From, 
        car.Vendor, 
        car.Country, 
        car.Landline_rate, 
        car.mobile_rate,
        ROUND(
            SUM(
                CASE 
                    WHEN car.vendor = 'Vendor 1' THEN CEILING(com.Duration_Seconds / 6.0) * 6 * 
                        CASE WHEN com.Called_From = 'Mobile' THEN car.mobile_rate ELSE car.Landline_rate END
                    WHEN car.vendor = 'Vendor 2' THEN com.Duration_Seconds * 
                        CASE WHEN com.Called_From = 'Mobile' THEN car.mobile_rate ELSE car.Landline_rate END
                    WHEN car.vendor = 'Vendor 3' THEN CEILING(com.Duration_Seconds / 60.0) * 60 * 
                        CASE WHEN com.Called_From = 'Mobile' THEN car.mobile_rate ELSE car.Landline_rate END
                    WHEN car.vendor = 'Vendor 4' THEN
                        CASE 
                            WHEN com.Duration_Seconds <= 30 THEN 30 * 
                                CASE WHEN com.Called_From = 'Mobile' THEN car.mobile_rate ELSE car.Landline_rate END
                            ELSE (30 + CEILING((com.Duration_Seconds - 30)/6.0) * 6) * 
                                CASE WHEN com.Called_From = 'Mobile' THEN car.mobile_rate ELSE car.Landline_rate END
                        END
                    WHEN car.vendor = 'Vendor 5' THEN CEILING(com.Duration_Seconds / 30) * 30 * 
                        CASE WHEN com.Called_From = 'Mobile' THEN car.mobile_rate ELSE car.Landline_rate END
                END
            ), 2
        ) AS vendor_cost
    FROM #combineall com
    JOIN AvoxiBillingFile..Rates_Carrier car 
        ON com.AccountID = car.AccountID
    GROUP BY com.Customer, com.AccountID, com.Duration_Seconds, com.Called_From, car.Vendor, car.Country, car.Landline_rate, car.mobile_rate
)

---- Getting Gross Margin by Country
SELECT 
    tb.Country,  -- Group by Country
    ROUND(SUM(tb.total_billing), 2) AS total_billing,
    ROUND(SUM(vc.vendor_cost), 2) AS total_cost,
    ROUND(
        ((SUM(tb.total_billing) - SUM(vc.vendor_cost)) / SUM(tb.total_billing)) * 100, 2
    ) AS gross_margin_percentage
FROM totalbill tb
JOIN vendorcost vc 
    ON tb.Customer = vc.Customer 
GROUP BY tb.Country
ORDER BY tb.Country;






---------------------------------------------------------------
-- Total Cost Per Vendor

-- Getting Total Billing per Client
with totalbill AS (
    SELECT 
        com.Customer, 
        com.AccountID, 
        cli.Country, 
        com.Called_From,
        ROUND(
            SUM(
                CASE 
                    WHEN com.Called_From = 'Mobile' THEN CEILING(com.Duration_Seconds / 60.0) * cli.Mobile_Rate
                    ELSE CEILING(com.Duration_Seconds / 60.0) * cli.Landline_Rate
                END
            ), 2
        ) AS total_billing
    FROM #combineall com
    JOIN AvoxiBillingFile..Rates_Clients cli
        ON com.AccountID = cli.AccountID
    GROUP BY com.Customer, com.AccountID, cli.Country, com.Called_From
),

-- Vendor Cost Calculation
vendorcost AS (
    SELECT 
        com.Customer, 
        com.AccountID, 
        com.Duration_Seconds, 
        com.Called_From, 
        car.Vendor, 
        car.Country, 
        car.Landline_rate, 
        car.mobile_rate,
        ROUND(
            SUM(
                CASE 
                    WHEN car.vendor = 'Vendor 1' THEN CEILING(com.Duration_Seconds / 6.0) * 6 * 
                        CASE WHEN com.Called_From = 'Mobile' THEN car.mobile_rate ELSE car.Landline_rate END
                    WHEN car.vendor = 'Vendor 2' THEN com.Duration_Seconds * 
                        CASE WHEN com.Called_From = 'Mobile' THEN car.mobile_rate ELSE car.Landline_rate END
                    WHEN car.vendor = 'Vendor 3' THEN CEILING(com.Duration_Seconds / 60.0) * 60 * 
                        CASE WHEN com.Called_From = 'Mobile' THEN car.mobile_rate ELSE car.Landline_rate END
                    WHEN car.vendor = 'Vendor 4' THEN
                        CASE 
                            WHEN com.Duration_Seconds <= 30 THEN 30 * 
                                CASE WHEN com.Called_From = 'Mobile' THEN car.mobile_rate ELSE car.Landline_rate END
                            ELSE (30 + CEILING((com.Duration_Seconds - 30)/6.0) * 6) * 
                                CASE WHEN com.Called_From = 'Mobile' THEN car.mobile_rate ELSE car.Landline_rate END
                        END
                    WHEN car.vendor = 'Vendor 5' THEN CEILING(com.Duration_Seconds / 30) * 30 * 
                        CASE WHEN com.Called_From = 'Mobile' THEN car.mobile_rate ELSE car.Landline_rate END
                END
            ), 2
        ) AS vendor_cost
    FROM #combineall com
    JOIN AvoxiBillingFile..Rates_Carrier car 
        ON com.AccountID = car.AccountID
    GROUP BY com.Customer, com.AccountID, com.Duration_Seconds, com.Called_From, car.Vendor, car.Country, car.Landline_rate, car.mobile_rate
)

--  Getting Total Cost per Vendor
SELECT 
    vc.Vendor, 
    ROUND(SUM(vc.vendor_cost), 2) AS total_cost
FROM vendorcost vc
GROUP BY vc.Vendor
ORDER BY vc.Vendor;





---------------------------------------------------------------
-- Gross Margin by Carrier (Vendor) in a % form

WITH totalbill AS (
    SELECT 
        com.Customer, 
        com.AccountID, 
        cli.Country, 
        ROUND(
            SUM(
                CASE 
                    WHEN com.Called_From = 'Mobile' THEN CEILING(com.Duration_Seconds / 60.0) * cli.Mobile_Rate
                    ELSE CEILING(com.Duration_Seconds / 60.0) * cli.Landline_Rate 
                END
            ), 2
        ) AS total_billing
    FROM #combineall com
    JOIN AvoxiBillingFile..Rates_Clients cli
        ON com.AccountID = cli.AccountID
    GROUP BY com.Customer, com.AccountID, cli.Country
),

vendorcost AS (
    SELECT 
        com.Customer, 
        com.AccountID, 
        com.Duration_Seconds, 
        com.Called_From, 
        car.Vendor, 
        car.Country, 
        car.Landline_rate, 
        car.mobile_rate,
        ROUND(
            SUM(
                CASE 
                    WHEN car.vendor = 'Vendor 1' THEN CEILING(com.Duration_Seconds / 6.0) * 6 * 
                        CASE WHEN com.Called_From = 'Mobile' THEN car.mobile_rate ELSE car.Landline_rate END
                    WHEN car.vendor = 'Vendor 2' THEN com.Duration_Seconds * 
                        CASE WHEN com.Called_From = 'Mobile' THEN car.mobile_rate ELSE car.Landline_rate END
                    WHEN car.vendor = 'Vendor 3' THEN CEILING(com.Duration_Seconds / 60.0) * 60 * 
                        CASE WHEN com.Called_From = 'Mobile' THEN car.mobile_rate ELSE car.Landline_rate END
                    WHEN car.vendor = 'Vendor 4' THEN
                        CASE 
                            WHEN com.Duration_Seconds <= 30 THEN 30 * 
                                CASE WHEN com.Called_From = 'Mobile' THEN car.mobile_rate ELSE car.Landline_rate END
                            ELSE (30 + CEILING((com.Duration_Seconds - 30)/6.0) * 6) * 
                                CASE WHEN com.Called_From = 'Mobile' THEN car.mobile_rate ELSE car.Landline_rate END
                        END
                    WHEN car.vendor = 'Vendor 5' THEN CEILING(com.Duration_Seconds / 30) * 30 * 
                        CASE WHEN com.Called_From = 'Mobile' THEN car.mobile_rate ELSE car.Landline_rate END
                END
            ), 2
        ) AS vendor_cost
    FROM #combineall com
    JOIN AvoxiBillingFile..Rates_Carrier car 
        ON com.AccountID = car.AccountID
    GROUP BY com.Customer, com.AccountID, com.Duration_Seconds, com.Called_From, car.Vendor, car.Country, car.Landline_rate, car.mobile_rate
)



-- Getting Gross Margin by Carrier (Vendor) in a % form
SELECT 
    car.Vendor,
    ROUND(SUM(tb.total_billing), 2) AS total_billing,
    ROUND(SUM(vc.vendor_cost), 2) AS total_cost,
    ROUND(
        ((SUM(tb.total_billing) - SUM(vc.vendor_cost)) / SUM(tb.total_billing)) * 100, 2
    ) AS gross_margin_percentage
FROM totalbill tb
JOIN vendorcost vc ON tb.Customer = vc.Customer
JOIN AvoxiBillingFile..Rates_Carrier car ON tb.AccountID = car.AccountID
GROUP BY car.Vendor
ORDER BY car.Vendor;






---------------------------------------------------------------
-- Gross Margin by Number type in a % form

-- Calculate Total Billing per Client
with totalbill AS (
    SELECT 
        com.Customer, 
        com.AccountID, 
        cli.Country, 
        com.Called_From,
        ROUND(
            SUM(
                CASE 
                    WHEN com.Called_From = 'Mobile' THEN CEILING(com.Duration_Seconds / 60.0) * cli.Mobile_Rate
                    ELSE CEILING(com.Duration_Seconds / 60.0) * cli.Landline_Rate
                END
            ), 2
        ) AS total_billing
    FROM #combineall com
    JOIN AvoxiBillingFile..Rates_Clients cli
        ON com.AccountID = cli.AccountID
    GROUP BY com.Customer, com.AccountID, cli.Country, com.Called_From
),

-- Calculate Vendor Costs per Client
vendorcost AS (
    SELECT 
        com.Customer, 
        com.AccountID, 
        com.Duration_Seconds, 
        com.Called_From, 
        car.Vendor, 
        car.Country, 
        car.Landline_rate, 
        car.mobile_rate, 
        car.Number_Type,
        ROUND(
            SUM(
                CASE 
                    WHEN car.vendor = 'Vendor 1' THEN CEILING(com.Duration_Seconds / 6.0) * 6 * 
                        CASE WHEN com.Called_From = 'Mobile' THEN car.mobile_rate ELSE car.Landline_rate END
                    WHEN car.vendor = 'Vendor 2' THEN com.Duration_Seconds * 
                        CASE WHEN com.Called_From = 'Mobile' THEN car.mobile_rate ELSE car.Landline_rate END
                    WHEN car.vendor = 'Vendor 3' THEN CEILING(com.Duration_Seconds / 60.0) * 60 * 
                        CASE WHEN com.Called_From = 'Mobile' THEN car.mobile_rate ELSE car.Landline_rate END
                    WHEN car.vendor = 'Vendor 4' THEN
                        CASE 
                            WHEN com.Duration_Seconds <= 30 THEN 30 * 
                                CASE WHEN com.Called_From = 'Mobile' THEN car.mobile_rate ELSE car.Landline_rate END
                            ELSE (30 + CEILING((com.Duration_Seconds - 30)/6.0) * 6) * 
                                CASE WHEN com.Called_From = 'Mobile' THEN car.mobile_rate ELSE car.Landline_rate END
                        END
                    WHEN car.vendor = 'Vendor 5' THEN CEILING(com.Duration_Seconds / 30) * 30 * 
                        CASE WHEN com.Called_From = 'Mobile' THEN car.mobile_rate ELSE car.Landline_rate END
                END
            ), 2
        ) AS vendor_cost
    FROM #combineall com
    JOIN AvoxiBillingFile..Rates_Carrier car 
        ON com.AccountID = car.AccountID
    GROUP BY com.Customer, com.AccountID, com.Duration_Seconds, com.Called_From, car.Vendor, car.Country, car.Landline_rate, car.mobile_rate, car.Number_Type
)

-- Getting Gross Margin by Number type in a % form
SELECT 
    vc.Number_Type,  -- Based on the Number Type (DID, ITFS, etc.)
    ROUND(SUM(tb.total_billing), 2) AS total_billing,
    ROUND(SUM(vc.vendor_cost), 2) AS total_cost,
    ROUND(
        CASE 
            WHEN SUM(tb.total_billing) = 0 THEN 0  -- Prevent division by zero
            ELSE ((SUM(tb.total_billing) - SUM(vc.vendor_cost)) / SUM(tb.total_billing)) * 100 
        END, 2
    ) AS gross_margin_percentage
FROM totalbill tb
JOIN vendorcost vc ON tb.Customer = vc.Customer
GROUP BY vc.Number_Type
ORDER BY vc.Number_Type;






---------------------------------------------------------------
-- Gross Margin by Country/Carrier/Client


WITH totalbill AS (
    SELECT 
        com.Customer, 
        com.AccountID, 
        cli.Country, 
        ROUND(
            SUM(
                CASE 
                    WHEN com.Called_From = 'Mobile' THEN CEILING(com.Duration_Seconds / 60.0) * cli.Mobile_Rate
                    ELSE CEILING(com.Duration_Seconds / 60.0) * cli.Landline_Rate 
                END
            ), 2
        ) AS total_billing
    FROM #combineall com
    JOIN AvoxiBillingFile..Rates_Clients cli
        ON com.AccountID = cli.AccountID
    GROUP BY com.Customer, com.AccountID, cli.Country
),

vendorcost AS (
    SELECT 
        com.Customer, 
        com.AccountID, 
        com.Duration_Seconds, 
        com.Called_From, 
        car.Vendor, 
        car.Country, 
        car.Landline_rate, 
        car.mobile_rate,
        ROUND(
            SUM(
                CASE 
                    WHEN car.vendor = 'Vendor 1' THEN CEILING(com.Duration_Seconds / 6.0) * 6 * 
                        CASE WHEN com.Called_From = 'Mobile' THEN car.mobile_rate ELSE car.Landline_rate END
                    WHEN car.vendor = 'Vendor 2' THEN com.Duration_Seconds * 
                        CASE WHEN com.Called_From = 'Mobile' THEN car.mobile_rate ELSE car.Landline_rate END
                    WHEN car.vendor = 'Vendor 3' THEN CEILING(com.Duration_Seconds / 60.0) * 60 * 
                        CASE WHEN com.Called_From = 'Mobile' THEN car.mobile_rate ELSE car.Landline_rate END
                    WHEN car.vendor = 'Vendor 4' THEN
                        CASE 
                            WHEN com.Duration_Seconds <= 30 THEN 30 * 
                                CASE WHEN com.Called_From = 'Mobile' THEN car.mobile_rate ELSE car.Landline_rate END
                            ELSE (30 + CEILING((com.Duration_Seconds - 30)/6.0) * 6) * 
                                CASE WHEN com.Called_From = 'Mobile' THEN car.mobile_rate ELSE car.Landline_rate END
                        END
                    WHEN car.vendor = 'Vendor 5' THEN CEILING(com.Duration_Seconds / 30) * 30 * 
                        CASE WHEN com.Called_From = 'Mobile' THEN car.mobile_rate ELSE car.Landline_rate END
                END
            ), 2
        ) AS vendor_cost
    FROM #combineall com
    JOIN AvoxiBillingFile..Rates_Carrier car 
        ON com.AccountID = car.AccountID
    GROUP BY com.Customer, com.AccountID, com.Duration_Seconds, com.Called_From, car.Vendor, car.Country, car.Landline_rate, car.mobile_rate
)



-- Getting Gross Margin by Country/Carrier/Client
SELECT 
    cli.Country,
    car.Vendor,
    tb.Customer,
    ROUND(SUM(tb.total_billing), 2) AS total_billing,
    ROUND(SUM(vc.vendor_cost), 2) AS total_cost,
    ROUND(
        CASE 
            WHEN SUM(tb.total_billing) = 0 THEN 0  -- Check if total_billing is 0
            ELSE ((SUM(tb.total_billing) - SUM(vc.vendor_cost)) / SUM(tb.total_billing)) * 100 
        END, 2
    ) AS gross_margin_percentage
FROM totalbill tb
JOIN vendorcost vc ON tb.Customer = vc.Customer
JOIN AvoxiBillingFile..Rates_Clients cli ON tb.AccountID = cli.AccountID
JOIN AvoxiBillingFile..Rates_Carrier car ON tb.AccountID = car.AccountID
GROUP BY cli.Country, car.Vendor, tb.Customer
ORDER BY cli.Country, car.Vendor, tb.Customer;
