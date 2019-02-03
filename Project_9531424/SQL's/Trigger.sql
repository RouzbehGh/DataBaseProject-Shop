DELIMITER //
CREATE TRIGGER log_update_on_new_customer_orders
AFTER UPDATE ON newcustomerorders
FOR EACH ROW
  BEGIN
    INSERT INTO updatenewcustomerorderlog (purchase_time, customerEmail, shopId, productId, pre_status, new_status)
    VALUES (NEW.purchase_time, NEW.customerEmail, NEW.shopId, NEW.productId, OLD.status, NEW.status);
   END //
 DELIMITER ;
--------------------------------------------------------------------------
DELIMITER //
CREATE TRIGGER log_update_on_customer_orders
AFTER UPDATE ON customerorders
FOR EACH ROW
  BEGIN
    INSERT INTO updatecustomerorderlog (purchase_time, customerUsername, shopId, productId, pre_status, new_status)
    VALUES (NEW.purchase_time, NEW.customerUsername, NEW.shopId, NEW.productId, OLD.status, NEW.status);
   END //
 DELIMITER ;
--------------------------------------------------------------------------
DELIMITER //
CREATE TRIGGER log_update_on_postmans
AFTER UPDATE ON postman
FOR EACH ROW
  BEGIN
    INSERT INTO updatepostmanlog (postmanid, pre_status, new_status)
    VALUES (NEW.id, OLD.status, NEW.status);
   END //
 DELIMITER ;
--------------------------------------------------------------------------
DELIMITER //
CREATE TRIGGER log_update_on_customers
AFTER UPDATE ON customers
FOR EACH ROW
  BEGIN
    INSERT INTO updatecustomerlog (username, pre_email, new_email, pre_password, new_password, pre_credit, new_credit)
    VALUES (NEW.username, OLD.email, NEW.email, OLD.password, NEW.password, OLD.credit, NEW.credit);
   END //
 DELIMITER ;
--------------------------------------------------------------------------
DELIMITER // 
 CREATE TRIGGER hash_password
BEFORE UPDATE ON customers
FOR EACH ROW
  BEGIN
    SET NEW.password = sha1(NEW.password);
   END //
 DELIMITER ;
--------------------------------------------------------------------------
 DELIMITER //
CREATE TRIGGER deliver_new_customer_order_to_postman
AFTER INSERT ON newcustomerorders
FOR EACH ROW
  BEGIN

    DECLARE pm INT UNSIGNED;

    IF NEW.status != 'rejected'
    THEN

      SELECT T.id
      INTO pm
      FROM postman AS T
      WHERE T.status = 'free' AND T.shopId = NEW.shopId
      LIMIT 1;

      IF pm
      THEN
        UPDATE postman AS T
        SET status = 'sending'
        WHERE T.id = pm;
        INSERT INTO newcustomersshipping (postmanid, purchase_time, customerEmail, shopId, productId)
        VALUES (pm, NEW.purchase_time, NEW.customerEmail, NEW.shopId, NEW.productId);

      END IF;
    END IF;
   END //
 DELIMITER ;
--------------------------------------------------------------------------
DELIMITER //
CREATE TRIGGER add_order_by_new_customer
BEFORE INSERT ON newcustomerorders
FOR EACH ROW
  BEGIN

    DECLARE pm INT UNSIGNED;

    SELECT P.value
    INTO @supply_of_product
    FROM product AS P
    WHERE P.shopId = NEW.shopId AND P.id = NEW.productId;

    SELECT S.start_time
    INTO @shop_start_time
    FROM shop AS S
    WHERE S.id = NEW.shopId;

    SELECT S.end_time
    INTO @shop_end_time
    FROM shop AS S
    WHERE S.id = NEW.shopId;

    IF @supply_of_product < NEW.value OR
       @shop_start_time > current_time OR
       current_time > @shop_end_time
    THEN
      SET NEW.status = 'rejected';
    ELSE

      UPDATE product AS P
      SET P.value = P.value - NEW.value
      WHERE P.id = NEW.productId AND P.shopId = NEW.shopId;

      SELECT T.id
      INTO pm
      FROM postman AS T
      WHERE T.status = 'free' AND T.shopId = NEW.shopId
      LIMIT 1;

      IF pm
      THEN
        SET NEW.status = 'sending';
      END IF;

    END IF;
   END //
 DELIMITER ;
---------------------------------------------------------------
DELIMITER //
CREATE TRIGGER deliver_to_postman
AFTER INSERT ON customerorders
FOR EACH ROW
  BEGIN

    DECLARE pm INT UNSIGNED;

    IF NEW.status != 'rejected'
    THEN

      SELECT T.id
      INTO pm
      FROM postman AS T
      WHERE T.status = 'free' AND T.shopId = NEW.shopId
      LIMIT 1;

      IF pm
      THEN
        UPDATE postman AS T
        SET status = 'sending'
        WHERE T.id = pm;
        INSERT INTO shipment (postmanid, purchase_time, customerUsername, shopId, productId)
        VALUES (pm, NEW.purchase_time, NEW.customerUsername, NEW.shopId, NEW.productId);

      END IF;
    END IF;
   END //
 DELIMITER ;
---------------------------------------------------------------
DELIMITER //
CREATE TRIGGER add_order_by_customer
BEFORE INSERT ON customerorders
FOR EACH ROW
  BEGIN

    DECLARE pm INT UNSIGNED;

    SELECT P.price
    INTO @price_of_product
    FROM product AS P
    WHERE P.shopId = NEW.shopId AND P.id = NEW.productId;

    SELECT P.offer
    INTO @offer_of_product
    FROM product AS P
    WHERE P.shopId = NEW.shopId AND P.id = NEW.productId;

    SELECT P.value
    INTO @supply_of_product
    FROM product AS P
    WHERE P.shopId = NEW.shopId AND P.id = NEW.productId;

    SELECT C.credit
    INTO @cu_cred
    FROM customers AS C
    WHERE C.username = NEW.customerUsername;

    SELECT S.start_time
    INTO @shop_start_time
    FROM shop AS S
    WHERE S.id = NEW.shopId;

    SELECT S.end_time
    INTO @shop_end_time
    FROM shop AS S
    WHERE S.id = NEW.shopId;

    IF @supply_of_product < NEW.value OR @cu_cred < ((1.0 - @offer_of_product) * @price_of_product * NEW.value) OR
       @shop_start_time > current_time OR
       current_time > @shop_end_time
    THEN
      SET NEW.status = 'rejected';
    ELSE

      UPDATE customers AS C
      SET C.credit = C.credit - (1.0 - @offer_of_product) * @price_of_product * NEW.value
      WHERE C.username = NEW.customerUsername AND NEW.payment_type = 'online';

      UPDATE product AS P
      SET P.value = P.value - NEW.value
      WHERE P.id = NEW.productId AND P.shopId = NEW.shopId;

      SELECT T.id
      INTO pm
      FROM postman AS T
      WHERE T.status = 'free' AND T.shopId = NEW.shopId
      LIMIT 1;

      IF pm
      THEN
        SET NEW.status = 'sending';
      END IF;

    END IF;
   END //
 DELIMITER ;