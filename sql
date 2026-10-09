
-- 1. Additional services provided by the operator TELE2 (name, price)

SELECT
    a.additionalServiceName,
    oas.price
FROM OperatorAdditionalService oas
JOIN AdditionalService a        ON a.additionalServiceID = oas.additionalServiceID
JOIN MobileNetworkOperator mno  ON mno.operatorID = oas.operatorID
WHERE mno.operatorName = 'TELE2';



-- 2. Additional services offered by all operators
--    (operator name, additional service name, price)

SELECT
    RTRIM(mno.operatorName) AS operatorName,
    a.additionalServiceName,
    oas.price
FROM OperatorAdditionalService oas
JOIN AdditionalService a        ON a.additionalServiceID = oas.additionalServiceID
JOIN MobileNetworkOperator mno  ON mno.operatorID = oas.operatorID
ORDER BY mno.operatorName, a.additionalServiceName;



-- 3. Number of countries in each zone

SELECT
    z.zoneName,
    COUNT(c.countryCode) AS countryCount
FROM [Zone] z
LEFT JOIN Country c ON c.zoneID = z.zoneID
GROUP BY z.zoneID, z.zoneName
ORDER BY z.zoneName;



-- 4. Operator offering the most expensive calls to Mexico
--    (price comes from ServicePriceInZone, zone from Mexico's Country row;
--     WITH TIES returns every operator sharing the highest price)

SELECT TOP (1) WITH TIES
    RTRIM(mno.operatorName) AS operatorName
FROM ServicePriceInZone spz
JOIN Country c                  ON c.zoneID = spz.zoneID
JOIN MobileNetworkOperator mno  ON mno.operatorID = spz.operatorID
WHERE c.countryName = 'Meksika'     -- Mexico (country names are stored in Lithuanian)
  AND spz.serviceID = 4             -- 'Skambuciai i uzsienio tinklus, Lt/min.' (calls to foreign networks)
ORDER BY spz.price DESC;



-- 5. Internet data plan NOT included in any mobile plan with the lowest
--    price per 1 MB (operator name, plan name, price per MB)

SELECT TOP (1) WITH TIES
    RTRIM(mno.operatorName) AS operatorName,
    idp.internetDataPlanName,
    CAST(CAST(idp.price AS DECIMAL(18,10)) / idp.dataAllowanceMB AS DECIMAL(18,10)) AS pricePerMB
FROM InternetDataPlan idp
JOIN MobileNetworkOperator mno ON mno.operatorID = idp.operatorID
WHERE NOT EXISTS (
    SELECT 1
    FROM [Plan] p
    WHERE p.internetDataPlanID = idp.internetDataPlanID
)
ORDER BY pricePerMB ASC;



-- 6. Percentage distribution of subscribers among operators
--    (a subscriber belongs to the operator of the plan they subscribed to)

SELECT
    RTRIM(mno.operatorName)         AS operatorName,
    COUNT(s.subscriberID)           AS subscriberCount,
    CAST(100.0 * COUNT(s.subscriberID) / SUM(COUNT(s.subscriberID)) OVER () AS DECIMAL(5,2)) AS percentage
FROM MobileNetworkOperator mno
LEFT JOIN [Plan] p      ON p.operatorID = mno.operatorID
LEFT JOIN Subscriber s  ON s.planID = p.planID
GROUP BY mno.operatorID, mno.operatorName
ORDER BY percentage DESC;


-- 7. Three most popular plans (ties at the cut-off are all returned)

SELECT TOP (3) WITH TIES
    p.planName,
    COUNT(s.subscriberID) AS subscriberCount
FROM [Plan] p
JOIN Subscriber s ON s.planID = p.planID
GROUP BY p.planID, p.planName
ORDER BY COUNT(s.subscriberID) DESC;



-- 8. Ten randomly selected subscribers

SELECT TOP (10)
    pe.firstName + ' ' + pe.lastName    AS fullName,
    c.cityName,
    s.phoneNumber,
    s.contractStartDate,
    s.contractEndDate,
    RTRIM(mno.operatorName)             AS operatorName,
    p.planName,
    CASE WHEN EXISTS (
            SELECT 1 FROM OrderedInternetDataPlan oidp
            WHERE oidp.subscriberID = s.subscriberID)
         THEN 'Yes' ELSE 'No' END       AS internetDataPlanOrdered,
    CASE WHEN EXISTS (
            SELECT 1 FROM OrderedAdditionalService oas
            WHERE oas.subscriberID = s.subscriberID)
         THEN 'Yes' ELSE 'No' END       AS additionalServiceOrdered
FROM Subscriber s
JOIN Person pe                  ON pe.personID = s.personID
JOIN City c                     ON c.cityID = pe.cityID
JOIN [Plan] p                   ON p.planID = s.planID
JOIN MobileNetworkOperator mno  ON mno.operatorID = p.operatorID
ORDER BY NEWID();



-- 9. Top five subscribers by number of calls made within Lithuania
--    during October 2013
--    serviceID 1 = 'Skambuciai i Lietuvos tinklus' (calls to Lithuanian
--    networks); SMS and video calls are other services, so they are excluded.
--    A NULL initialization place means the call was made inside Lithuania.

SELECT TOP (5)
    s.subscriberID,
    pe.firstName + ' ' + pe.lastName AS fullName,
    s.phoneNumber,
    COUNT(*) AS callCount
FROM P2PConnection pc
JOIN Subscriber s   ON s.subscriberID = pc.subscriberID
JOIN Person pe      ON pe.personID = s.personID
WHERE pc.serviceID = 1
  AND pc.connectionInitializationPlace IS NULL
  AND pc.connectionStart >= '20131001'
  AND pc.connectionStart <  '20131101'
GROUP BY s.subscriberID, pe.firstName, pe.lastName, s.phoneNumber
ORDER BY callCount DESC;



-- 10. Most popular foreign country by number of calls made to it
--     serviceID 4 = 'Skambuciai i uzsienio tinklus' (calls to foreign
--     networks), so SMS to foreign networks (serviceID 5) are not counted.
--     Ties are all returned.

WITH CountryCalls AS (
    SELECT
        c.countryCode,
        c.countryName,
        COUNT(*) AS callCount
    FROM P2PConnection pc
    JOIN Country c ON c.countryCode = pc.recipientCountry
    WHERE pc.serviceID = 4
    GROUP BY c.countryCode, c.countryName
)
SELECT countryName, callCount
FROM CountryCalls
WHERE callCount = (SELECT MAX(callCount) FROM CountryCalls);
