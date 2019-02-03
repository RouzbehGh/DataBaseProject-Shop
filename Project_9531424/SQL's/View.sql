*********************** View of Query One ***************************
CREATE VIEW S(shopId, productId, total) AS
  (SELECT
     C.shopId,
     C.productId,
     sum(C.value)
   FROM customerorders AS C
   GROUP BY C.shopId, C.productId
  )
  UNION ALL (
    SELECT
      T.shopId,
      T.productId,
      sum(T.value)
    FROM newcustomerorders AS T
    GROUP BY T.shopId, T.productId
  );

CREATE VIEW M0 (shopId, productId, total) AS (
  SELECT
    shopId,
    productId,
    sum(total)
  FROM S
  GROUP BY shopId, productId
);

CREATE VIEW H1 (shopId, productId, total) AS (
  SELECT *
  FROM M0
  WHERE M0.total >= ALL (SELECT U.total
                         FROM M0 AS U
                         WHERE M0.shopId = U.shopId)
);

CREATE VIEW M1 (shopId, productId, total) AS (
  SELECT *
  FROM M0
  WHERE (M0.shopId, M0.productId, M0.total) NOT IN (SELECT *
                                                    FROM H1)
);

CREATE VIEW H2 (shopId, productId, total) AS (
  SELECT *
  FROM M1
  WHERE M1.total >= ALL (SELECT U.total
                         FROM M1 AS U
                         WHERE M1.shopId = U.shopId)
);

CREATE VIEW M2 (shopId, productId, total) AS (
  SELECT *
  FROM M1
  WHERE (M1.shopId, M1.productId, M1.total) NOT IN (SELECT *
                                                    FROM H2)
);

CREATE VIEW H3 (shopId, productId, total) AS (
  SELECT *
  FROM M2
  WHERE M2.total >= ALL (SELECT U.total
                         FROM M2 AS U
                         WHERE M2.shopId = U.shopId)
);

CREATE VIEW M3 (shopId, productId, total) AS (
  SELECT *
  FROM M2
  WHERE (M2.shopId, M2.productId, M2.total) NOT IN (SELECT *
                                                    FROM H3)
);

CREATE VIEW H4 (shopId, productId, total) AS (
  SELECT *
  FROM M3
  WHERE M3.total >= ALL (SELECT U.total
                         FROM M3 AS U
                         WHERE M3.shopId = U.shopId)
);

CREATE VIEW M4 (shopId, productId, total) AS (
  SELECT *
  FROM M3
  WHERE (M3.shopId, M3.productId, M3.total) NOT IN (SELECT *
                                                    FROM H4)
);

CREATE VIEW H5 (shopId, productId, total) AS (
  SELECT *
  FROM M4
  WHERE M4.total >= ALL (SELECT U.total
                         FROM M4 AS U
                         WHERE M4.shopId = U.shopId)
);
*********************** View of Query Two ***************************
CREATE VIEW Rej1(customerUsername, phone_number) AS (
  SELECT
    C.customerUsername,
    C.phone_number
  FROM customerorders AS C
  WHERE C.status = 'rejected'
);

CREATE VIEW Rej2(customerEmail, phone_number) AS (
  SELECT
    C.customerEmail,
    T.phone_number
  FROM newcustomerorders AS C
    JOIN newcustomers AS T ON C.customerEmail = T.email
  WHERE C.status = 'rejected'
);
*********************** View of Query Three ***************************
CREATE VIEW NewCustomerAvgerage(average) AS (
  SELECT avg(T.value * P.price)
  FROM newcustomerorders AS T
    JOIN product AS P ON T.productId = P.id AND T.shopId = P.shopId
  WHERE status != 'rejected'
);

CREATE VIEW CustomersAverage(average) AS (
  SELECT avg(T.value * P.price)
  FROM Customerorders AS T
    JOIN product AS P ON T.productId = P.id AND T.shopId = P.shopId
  WHERE status != 'rejected'
);
*********************** View of Query Four ***************************
CREATE VIEW PostmanAverageAll(id, average) AS (
  SELECT
    R.id,
    avg(R.pr)
  FROM
    (SELECT ALL
       S.postmanid   AS id,
       C.value * P.price AS pr
     FROM (shipping AS S
       JOIN customerorders AS C
         ON S.purchase_time = C.purchase_time AND S.customerUsername = C.customerUsername AND S.shopId = C.shopId AND
            S.productId = C.productId) JOIN product AS P ON C.productId = P.id
     UNION ALL
     SELECT
       S.postmanid   AS id,
       C.value * P.price AS pr
     FROM (newcustomersshipping AS S
       JOIN newcustomerorders AS C
         ON S.purchase_time = C.purchase_time AND S.customerEmail = C.customerEmail AND S.shopId = C.shopId AND
            S.productId = C.productId) JOIN product AS P ON C.productId = P.id
    ) AS R
  GROUP BY R.id
);
