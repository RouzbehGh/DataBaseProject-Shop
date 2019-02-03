-- phpMyAdmin SQL Dump
-- version 4.6.4
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: Jan 19, 2019 at 12:19 PM
-- Server version: 5.7.14
-- PHP Version: 5.6.25

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `final_9531424_9531027`
--

DELIMITER $$
--
-- Procedures
--
CREATE DEFINER=`root`@`localhost` PROCEDURE `add_customer` (IN `us` VARCHAR(100), IN `pa` VARCHAR(100), IN `em` VARCHAR(125), IN `fi` VARCHAR(100), IN `la` VARCHAR(100), IN `po` CHAR(15), IN `ge` ENUM('man','woman'), IN `cr` INT UNSIGNED)  BEGIN
    INSERT INTO customers (username, password, email, first_name, last_name, postcode, gender, credit)
    VALUES (us, sha1(pa), em, fi, la, po, ge, cr);
   END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `add_order_by_customer` (IN `cu` VARCHAR(100), IN `sh` INT UNSIGNED, IN `pr` INT UNSIGNED, IN `va` INTEGER, IN `pa` ENUM('online','offline'), IN `ad` VARCHAR(225), IN `ph` VARCHAR(12))  BEGIN

    SELECT @price_of_product := P.price
    FROM product AS P
    WHERE P.shopId = sh AND P.id = pr;

    SELECT @offer_of_product := P.offer
    FROM product AS P
    WHERE P.shopId = sh AND P.id = pr;

    SELECT @supply_of_product := P.value
    FROM product AS P
    WHERE P.shopId = sh AND P.id = pr;

    SELECT @cu_cred := C.credit
    FROM customers AS C
    WHERE C.username = cu;

    SELECT @shop_start_time := S.start_time
    FROM shop AS S
    WHERE S.id = sh;

    SELECT @shop_end_time := S.end_time
    FROM shop AS S
    WHERE S.id = sh;

    IF @supply_of_product < va OR @cu_cred < ((1.0 - @offer_of_product) * @price_of_product * va) OR
       @shop_start_time > current_time OR
       current_time > @shop_end_time
    THEN

      INSERT INTO customerorders (customerUsername, shopId, productId, value, status, payment_type, address, phone_number)
        VALUE (cu, sh, pr, va, 'rejected', pa, ad, ph);

    ELSE

      UPDATE customers AS C
      SET C.credit = C.credit - (1.0 - @offer_of_product) * @price_of_product * va
      WHERE C.username = cu AND pa = 'online';

      UPDATE product AS P
      SET P.value = P.value - va
      WHERE P.id = pr AND P.shopId = sh;

      INSERT INTO customerorders (customerUsername, shopId, productId, value, payment_type, address, phone_number)
        VALUE (cu, sh, pr, va, pa, ad, ph);

    END IF;

   END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `add_order_by_new_customer` (IN `cu` VARCHAR(125), IN `sh` INT UNSIGNED, IN `pr` INT UNSIGNED, IN `va` INTEGER)  BEGIN
    DECLARE `_rollback` BOOL DEFAULT 0;
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET `_rollback` = 1;
    START TRANSACTION;

    SELECT @supply_of_product := P.value
    FROM product AS P
    WHERE P.shopId = sh AND P.id = pr;

    SELECT @shop_start_time := S.start_time
    FROM shop AS S
    WHERE S.id = sh;

    SELECT @shop_end_time := S.end_time
    FROM shop AS S
    WHERE S.id = sh;

    IF @shop_start_time <= current_time AND current_time <= @shop_end_time AND @supply_of_product >= va
    THEN

      INSERT INTO newcustomerorders (customerEmail, shopId, productId, value)
        VALUE (cu, sh, pr, va);

      UPDATE product AS P
      SET P.value = P.value - va
      WHERE P.id = pr AND P.shopId = sh;

    ELSE
      INSERT INTO newcustomerorders (customerEmail, shopId, productId, value, status)
        VALUE (cu, sh, pr, va, 'rejected');
    END IF;

    IF `_rollback`
    THEN
      ROLLBACK;
    ELSE
      COMMIT;
    END IF;
   END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `charge_account` (IN `us` VARCHAR(100), IN `cr` INT UNSIGNED)  BEGIN
    IF cr > 0
    THEN
      UPDATE customers
      SET credit = credit + cr
      WHERE username = us;
    END IF;
     END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `deliver_to_customer` (IN `pid` INT UNSIGNED, IN `pt` TIMESTAMP, IN `cu` VARCHAR(100), IN `sh` INT UNSIGNED, IN `pr` INT UNSIGNED)  BEGIN
    DECLARE state ENUM ('accepted', 'rejected', 'sending', 'done');

    SELECT status
    INTO state
    FROM customerorders AS C
    WHERE C.purchase_time = pt AND C.customerUsername = cu AND C.shopId = sh AND C.productId = pr;

    IF state != 'done'
    THEN
      UPDATE customerorders AS C
      SET C.status = 'done'
      WHERE C.purchase_time = pt AND C.customerUsername = cu AND C.shopId = sh AND C.productId = pr;
            UPDATE postman AS T
      SET T.status = 'free', T.credit = T.credit + 0.05 * (SELECT P.price
                                                           FROM product AS P
                                                           WHERE P.id = pr AND P.shopId = sh)
      WHERE T.id = tid AND T.shopId = sh;

    END IF;
     END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `deliver_to_new_customer` (IN `pid` INT UNSIGNED, IN `pt` TIMESTAMP, IN `ce` VARCHAR(100), IN `sh` INT UNSIGNED, IN `pr` INT UNSIGNED)  BEGIN
    DECLARE state ENUM ('accepted', 'rejected', 'sending', 'done');

    SELECT status
    INTO state
    FROM newcustomerorders AS C
    WHERE C.purchase_time = pt AND C.customerEmail = ce AND C.shopId = sh AND C.productId = pr;

    IF state != 'done'
    THEN
      UPDATE newcustomerorders AS C
      SET C.status = 'done'
      WHERE C.purchase_time = pt AND C.customerEmail = ce AND C.shopId = sh AND C.productId = pr;
      
            UPDATE postman AS T
      SET T.status = 'free', T.credit = T.credit + 0.05 * (SELECT P.price
                                                           FROM product AS P
                                                           WHERE P.id = pr AND P.shopId = sh)
      WHERE T.id = tid AND T.shopId = sh;

    END IF;
     END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `customeraddresses`
--

CREATE TABLE `customeraddresses` (
  `address` varchar(225) NOT NULL,
  `CustomerUsername` varchar(100) NOT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Dumping data for table `customeraddresses`
--

INSERT INTO `customeraddresses` (`address`, `CustomerUsername`) VALUES
('Bahar St. - Tehran', 'BehzadDara'),
('Enghlab St. - Tehran', 'AliMorty'),
('Hafez St. - Tehran', 'AliMorty'),
('Mirdamad St. - Tehran', 'RoozbehGh'),
('Rasht St. - Tehran', 'RoozbehGh'),
('Shiraz St. - Tehran', 'BehzadDara');

-- --------------------------------------------------------

--
-- Table structure for table `customerorders`
--

CREATE TABLE `customerorders` (
  `purchase_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `customerUsername` varchar(100) NOT NULL,
  `shopId` int(10) UNSIGNED NOT NULL,
  `productId` int(10) UNSIGNED NOT NULL,
  `value` int(10) UNSIGNED NOT NULL DEFAULT '1',
  `status` enum('accepted','rejected','sending','done') NOT NULL DEFAULT 'accepted',
  `payment_type` enum('online','offline') NOT NULL DEFAULT 'online',
  `address` varchar(225) NOT NULL,
  `phone_number` varchar(12) NOT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Dumping data for table `customerorders`
--

INSERT INTO `customerorders` (`purchase_time`, `customerUsername`, `shopId`, `productId`, `value`, `status`, `payment_type`, `address`, `phone_number`) VALUES
('2018-11-20 19:25:59', 'AliMorty', 2, 2, 6, 'sending', 'online', 'Hafez St.-Tehran', '123456'),
('2018-05-24 22:36:29', 'RoozbehGh', 1, 7, 5, 'rejected', 'online', 'Rasht St.-Tehran', '234567'),
('1970-03-19 11:49:42', 'RoozbehGh', 1, 10, 7, 'accepted', 'online', 'Rasht St. - Tehran', '234567'),
('1970-07-07 12:27:58', 'BehzadDara', 3, 3, 6, 'rejected', 'online', 'Shiraz St. - Tehran', '345678'),
('1970-11-10 19:06:35', 'AliMorty', 2, 17, 8, 'accepted', 'online', 'Hafez St. - Tehran', '123456'),
('1971-07-14 17:25:15', 'RoozbehGh', 1, 10, 4, 'rejected', 'online', 'Rasht St. - Tehran', '234567'),
('1972-06-28 07:02:00', 'BehzadDara', 3, 9, 8, 'sending', 'online', 'Shiraz St. - Tehran', '345678'),
('1972-07-13 23:05:35', 'BehzadDara', 3, 21, 2, 'rejected', 'online', 'Shiraz St. - Tehran', '345678'),
('1972-11-11 17:32:03', 'BehzadDara', 3, 21, 2, 'rejected', 'online', 'Shiraz St. - Tehran', '345678'),
('1972-12-27 20:07:29', 'RoozbehGh', 1, 7, 9, 'sending', 'online', 'Rasht St. - Tehran', '234567'),
('1973-07-05 22:34:11', 'BehzadDara', 3, 21, 4, 'rejected', 'online', 'Shiraz St. - Tehran', '345678'),
('1973-07-19 22:56:17', 'RoozbehGh', 1, 10, 8, 'rejected', 'online', 'Rasht St. - Tehran', '234567'),
('1973-10-05 15:31:47', 'AliMorty', 2, 20, 3, 'accepted', 'online', 'Hafez St. - Tehran', '123456'),
('1974-01-27 07:00:25', 'RoozbehGh', 1, 7, 8, 'accepted', 'online', 'Rasht St. - Tehran', '234567'),
('1976-02-20 10:01:26', 'AliMorty', 2, 2, 4, 'sending', 'online', 'Hafez St. - Tehran', '123456'),
('1976-07-27 00:09:44', 'RoozbehGh', 1, 10, 6, 'done', 'online', 'Rasht St. - Tehran', '234567'),
('1976-09-26 17:36:00', 'AliMorty', 2, 2, 3, 'rejected', 'online', 'Hafez St. - Tehran', '123456'),
('1976-11-06 07:34:55', 'RoozbehGh', 1, 7, 6, 'accepted', 'online', 'Rasht St. - Tehran', '234567'),
('1976-11-26 16:51:07', 'BehzadDara', 3, 9, 2, 'accepted', 'online', 'Shiraz St. - Tehran', '345678'),
('1976-12-02 21:20:40', 'AliMorty', 2, 17, 6, 'accepted', 'online', 'Hafez St. - Tehran', '123456'),
('1977-02-22 22:34:21', 'BehzadDara', 3, 3, 5, 'accepted', 'online', 'Shiraz St. - Tehran', '345678'),
('1978-03-23 22:15:22', 'RoozbehGh', 1, 10, 5, 'done', 'online', 'Rasht St. - Tehran', '234567'),
('1978-04-04 23:09:51', 'AliMorty', 2, 20, 9, 'accepted', 'online', 'Hafez St. - Tehran', '123456'),
('1978-08-01 14:17:33', 'RoozbehGh', 1, 7, 7, 'done', 'online', 'Rasht St. - Tehran', '234567'),
('1978-08-19 13:59:43', 'AliMorty', 2, 2, 7, 'accepted', 'online', 'Hafez St. - Tehran', '123456'),
('1978-11-13 13:16:53', 'RoozbehGh', 1, 10, 6, 'rejected', 'online', 'Rasht St. - Tehran', '234567'),
('1979-06-12 12:36:41', 'BehzadDara', 3, 21, 7, 'done', 'online', 'Shiraz St. - Tehran', '345678'),
('1979-08-30 16:30:12', 'AliMorty', 2, 17, 10, 'rejected', 'online', 'Hafez St. - Tehran', '123456'),
('1979-11-09 23:53:00', 'RoozbehGh', 1, 7, 9, 'rejected', 'online', 'Rasht St. - Tehran', '234567');

--
-- Triggers `customerorders`
--
DELIMITER $$
CREATE TRIGGER `add_order_by_customer` BEFORE INSERT ON `customerorders` FOR EACH ROW BEGIN

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
   END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `deliver_to_postman` AFTER INSERT ON `customerorders` FOR EACH ROW BEGIN

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
   END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `log_update_on_customer_orders` AFTER UPDATE ON `customerorders` FOR EACH ROW BEGIN
    INSERT INTO updatecustomerorderlog (purchase_time, customerUsername, shopId, productId, pre_status, new_status)
    VALUES (NEW.purchase_time, NEW.customerUsername, NEW.shopId, NEW.productId, OLD.status, NEW.status);
   END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `customerphonenumbers`
--

CREATE TABLE `customerphonenumbers` (
  `phone_number` varchar(12) NOT NULL,
  `CustomerUsername` varchar(100) NOT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Dumping data for table `customerphonenumbers`
--

INSERT INTO `customerphonenumbers` (`phone_number`, `CustomerUsername`) VALUES
('0123456', 'AliMorty'),
('0234567', 'RoozbehGh'),
('0345678', 'BehzadDara'),
('123456', 'AliMorty'),
('234567', 'RoozbehGh'),
('345678', 'BehzadDara');

-- --------------------------------------------------------

--
-- Table structure for table `customers`
--

CREATE TABLE `customers` (
  `username` varchar(100) NOT NULL,
  `password` varchar(100) DEFAULT NULL,
  `email` varchar(125) NOT NULL,
  `first_name` varchar(100) DEFAULT NULL,
  `last_name` varchar(100) DEFAULT NULL,
  `postcode` char(15) NOT NULL,
  `gender` enum('man','woman') DEFAULT NULL,
  `credit` int(10) UNSIGNED NOT NULL DEFAULT '0'
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Dumping data for table `customers`
--

INSERT INTO `customers` (`username`, `password`, `email`, `first_name`, `last_name`, `postcode`, `gender`, `credit`) VALUES
('AliMorty', 'ba8e6bf9bd6cb7559f9693bc84b5dc0bcaddefba', 'AliMorty@example.org', 'Ali', 'Morty', '1978', 'man', 9247837),
('RoozbehGh', '2840bfc290c7200cac7f22a6c3d8c087c10165fc', 'RoozbehGh@example.org', 'Roozbeh', 'Gh', '2978', 'man', 1089251),
('BehzadDara', '6cff7cf8a443c8a2ac962f78171faaad4efdddf3', 'BehzadDara@example.org', 'Behzad', 'Dara', '3978', 'man', 4245387);

--
-- Triggers `customers`
--
DELIMITER $$
CREATE TRIGGER `hash_password` BEFORE UPDATE ON `customers` FOR EACH ROW BEGIN
    SET NEW.password = sha1(NEW.password);
   END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `log_update_on_customers` AFTER UPDATE ON `customers` FOR EACH ROW BEGIN
    INSERT INTO updatecustomerlog (username, pre_email, new_email, pre_password, new_password, pre_credit, new_credit)
    VALUES (NEW.username, OLD.email, NEW.email, OLD.password, NEW.password, OLD.credit, NEW.credit);
   END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Stand-in structure for view `customersaverage`
-- (See below for the actual view)
--
CREATE TABLE `customersaverage` (
`average` decimal(24,4)
);

-- --------------------------------------------------------

--
-- Stand-in structure for view `h1`
-- (See below for the actual view)
--
CREATE TABLE `h1` (
`shopId` int(11) unsigned
,`productId` int(11) unsigned
,`total` decimal(54,0)
);

-- --------------------------------------------------------

--
-- Stand-in structure for view `h2`
-- (See below for the actual view)
--
CREATE TABLE `h2` (
`shopId` int(11) unsigned
,`productId` int(11) unsigned
,`total` decimal(54,0)
);

-- --------------------------------------------------------

--
-- Stand-in structure for view `h3`
-- (See below for the actual view)
--
CREATE TABLE `h3` (
`shopId` int(11) unsigned
,`productId` int(11) unsigned
,`total` decimal(54,0)
);

-- --------------------------------------------------------

--
-- Stand-in structure for view `h4`
-- (See below for the actual view)
--
CREATE TABLE `h4` (
`shopId` int(11) unsigned
,`productId` int(11) unsigned
,`total` decimal(54,0)
);

-- --------------------------------------------------------

--
-- Stand-in structure for view `h5`
-- (See below for the actual view)
--
CREATE TABLE `h5` (
`shopId` int(11) unsigned
,`productId` int(11) unsigned
,`total` decimal(54,0)
);

-- --------------------------------------------------------

--
-- Stand-in structure for view `m0`
-- (See below for the actual view)
--
CREATE TABLE `m0` (
`shopId` int(11) unsigned
,`productId` int(11) unsigned
,`total` decimal(54,0)
);

-- --------------------------------------------------------

--
-- Stand-in structure for view `m1`
-- (See below for the actual view)
--
CREATE TABLE `m1` (
`shopId` int(11) unsigned
,`productId` int(11) unsigned
,`total` decimal(54,0)
);

-- --------------------------------------------------------

--
-- Stand-in structure for view `m2`
-- (See below for the actual view)
--
CREATE TABLE `m2` (
`shopId` int(11) unsigned
,`productId` int(11) unsigned
,`total` decimal(54,0)
);

-- --------------------------------------------------------

--
-- Stand-in structure for view `m3`
-- (See below for the actual view)
--
CREATE TABLE `m3` (
`shopId` int(11) unsigned
,`productId` int(11) unsigned
,`total` decimal(54,0)
);

-- --------------------------------------------------------

--
-- Stand-in structure for view `m4`
-- (See below for the actual view)
--
CREATE TABLE `m4` (
`shopId` int(11) unsigned
,`productId` int(11) unsigned
,`total` decimal(54,0)
);

-- --------------------------------------------------------

--
-- Stand-in structure for view `newcustomeravgerage`
-- (See below for the actual view)
--
CREATE TABLE `newcustomeravgerage` (
`average` decimal(24,4)
);

-- --------------------------------------------------------

--
-- Table structure for table `newcustomerorders`
--

CREATE TABLE `newcustomerorders` (
  `purchase_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `customerEmail` varchar(125) NOT NULL,
  `shopId` int(10) UNSIGNED NOT NULL,
  `productId` int(10) UNSIGNED NOT NULL,
  `value` int(10) UNSIGNED NOT NULL DEFAULT '1',
  `status` enum('accepted','rejected','sending','done') NOT NULL DEFAULT 'accepted'
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Dumping data for table `newcustomerorders`
--

INSERT INTO `newcustomerorders` (`purchase_time`, `customerEmail`, `shopId`, `productId`, `value`, `status`) VALUES
('2018-01-09 15:27:43', 'Saman@example.com', 3, 3, 4, 'accepted'),
('2018-10-26 04:12:00', 'Saman@example.com', 3, 9, 6, 'sending'),
('2018-08-03 19:21:32', 'Saman@example.com', 3, 3, 8, 'rejected'),
('2018-01-22 09:55:35', 'Amir@example.org', 1, 10, 8, 'accepted'),
('2018-11-18 02:51:59', 'Saman@example.com', 3, 9, 5, 'rejected'),
('2018-07-10 15:05:37', 'Javad@example.net', 2, 2, 2, 'rejected'),
('2018-01-08 18:16:36', 'Javad@example.net', 2, 2, 1, 'rejected'),
('2018-12-14 16:13:29', 'Javad@example.net', 2, 2, 9, 'sending'),
('2018-07-03 14:35:20', 'Javad@example.net', 2, 2, 1, 'sending'),
('2018-01-22 11:30:42', 'Saman@example.com', 3, 3, 8, 'rejected'),
('2018-04-15 23:58:14', 'Javad@example.net', 2, 2, 2, 'accepted'),
('2018-01-28 19:51:06', 'Javad@example.net', 2, 20, 8, 'done'),
('2018-08-13 16:50:46', 'Javad@example.net', 2, 2, 6, 'done'),
('2018-02-15 03:59:36', 'Saman@example.com', 3, 3, 10, 'rejected'),
('2018-12-18 22:19:03', 'Javad@example.net', 2, 17, 1, 'rejected'),
('2018-07-25 12:50:44', 'Javad@example.net', 2, 2, 1, 'done'),
('2018-06-29 16:56:44', 'Javad@example.net', 2, 17, 1, 'sending'),
('2018-06-02 22:14:27', 'Amir@example.org', 1, 7, 6, 'accepted');

--
-- Triggers `newcustomerorders`
--
DELIMITER $$
CREATE TRIGGER `add_order_by_new_customer` BEFORE INSERT ON `newcustomerorders` FOR EACH ROW BEGIN

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
   END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `deliver_new_customer_order_to_postman` AFTER INSERT ON `newcustomerorders` FOR EACH ROW BEGIN

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
   END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `log_update_on_new_customer_orders` AFTER UPDATE ON `newcustomerorders` FOR EACH ROW BEGIN
    INSERT INTO updatenewcustomerorderlog (purchase_time, customerEmail, shopId, productId, pre_status, new_status)
    VALUES (NEW.purchase_time, NEW.customerEmail, NEW.shopId, NEW.productId, OLD.status, NEW.status);
   END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `newcustomers`
--

CREATE TABLE `newcustomers` (
  `email` varchar(125) NOT NULL,
  `first_name` varchar(100) DEFAULT NULL,
  `last_name` varchar(100) DEFAULT NULL,
  `postcode` char(15) NOT NULL,
  `gender` enum('man','woman') DEFAULT 'man',
  `address` varchar(225) NOT NULL,
  `phone_number` varchar(12) NOT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Dumping data for table `newcustomers`
--

INSERT INTO `newcustomers` (`email`, `first_name`, `last_name`, `postcode`, `gender`, `address`, `phone_number`) VALUES
('Amir@example.org', 'Amir', 'Amiri', '19917', 'man', 'Molavi St. - Tehran', '987'),
('Javad@example.net', 'Javad', 'Hoseini', '19918', 'woman', 'Niavarn St. - Tehran', '654'),
('Saman@example.com', 'Saman', 'Babaei', '19919', 'woman', 'Baghdad St. - Tehran', '321');

-- --------------------------------------------------------

--
-- Table structure for table `newcustomersshipping`
--

CREATE TABLE `newcustomersshipping` (
  `postmanid` int(10) UNSIGNED DEFAULT NULL,
  `purchase_time` timestamp NOT NULL,
  `customerEmail` varchar(125) NOT NULL,
  `shopId` int(10) UNSIGNED NOT NULL,
  `productId` int(10) UNSIGNED NOT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Dumping data for table `newcustomersshipping`
--

INSERT INTO `newcustomersshipping` (`postmanid`, `purchase_time`, `customerEmail`, `shopId`, `productId`) VALUES
(7, '2018-02-03 21:08:20', 'aaa@example.com', 1, 5),
(2, '2018-04-07 14:27:58', 'aaa@example.com', 3, 3),
(4, '2018-03-28 06:02:00', 'aaa@example.com', 3, 9),
(11, '2018-11-01 01:52:35', 'aaa@example.com', 3, 9),
(10, '2018-01-10 00:31:25', 'aaa@example.com', 3, 3);

-- --------------------------------------------------------

--
-- Table structure for table `operators`
--

CREATE TABLE `operators` (
  `id` int(10) UNSIGNED NOT NULL,
  `shopId` int(10) UNSIGNED NOT NULL,
  `first_name` varchar(100) DEFAULT NULL,
  `last_name` varchar(100) DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Dumping data for table `operators`
--

INSERT INTO `operators` (`id`, `shopId`, `first_name`, `last_name`) VALUES
(1, 3, 'Hamed', 'Zamani'),
(2, 1, 'Ali', 'Teymoori'),
(3, 1, 'Sina', 'Samadi'),
(4, 2, 'Hashem', 'Beyzaei'),
(5, 2, 'Hootan', 'Hashemi'),
(6, 3, 'Arshia', 'Kameli');

-- --------------------------------------------------------

--
-- Table structure for table `postman`
--

CREATE TABLE `postman` (
  `id` int(10) UNSIGNED NOT NULL,
  `shopId` int(10) UNSIGNED NOT NULL,
  `first_name` varchar(100) DEFAULT NULL,
  `last_name` varchar(100) DEFAULT NULL,
  `phone_number` varchar(12) NOT NULL,
  `status` enum('free','sending') NOT NULL DEFAULT 'sending',
  `credit` int(10) UNSIGNED NOT NULL DEFAULT '0'
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Dumping data for table `postman`
--

INSERT INTO `postman` (`id`, `shopId`, `first_name`, `last_name`, `phone_number`, `status`, `credit`) VALUES
(1, 1, 'Akbar', 'Imani', '6625245', 'free', 9202980),
(2, 3, 'Mohammad', 'Hesami', '5933910', 'sending', 9970566),
(3, 2, 'Amirreza', 'Hashemi', '3375166', 'sending', 8146626),
(4, 3, 'Moein', 'Hendizadeh', '23994544', 'sending', 99458),
(5, 1, 'Mojtaba', 'Taghavi', '40574337', 'sending', 8351239),
(6, 2, 'Mostafa', 'Ghaemi', '3964131', 'sending', 7286728),
(7, 1, 'Boyouk', 'Bikaran', '8352005', 'sending', 2120590),
(8, 2, 'Behnam', 'Akbarizadeh', '1078055', 'free', 8257145),
(9, 1, 'Behrad', 'Farmanian', '16662179', 'free', 9695873),
(10, 3, 'Mehrad', 'ShirazMihan', '19595952', 'free', 1798218),
(11, 3, 'Mehrdad', 'Rahimzadeh', '19406246', 'sending', 8213997),
(12, 2, 'Pedram', 'Laknahour', '4696404', 'free', 2859275);

--
-- Triggers `postman`
--
DELIMITER $$
CREATE TRIGGER `log_update_on_postmans` AFTER UPDATE ON `postman` FOR EACH ROW BEGIN
    INSERT INTO updatepostmanlog (postmanid, pre_status, new_status)
    VALUES (NEW.id, OLD.status, NEW.status);
   END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Stand-in structure for view `postmanaverageall`
-- (See below for the actual view)
--
CREATE TABLE `postmanaverageall` (
`id` int(11) unsigned
,`average` decimal(24,4)
);

-- --------------------------------------------------------

--
-- Table structure for table `product`
--

CREATE TABLE `product` (
  `id` int(10) UNSIGNED NOT NULL,
  `shopId` int(10) UNSIGNED NOT NULL,
  `title` varchar(150) NOT NULL,
  `price` int(10) UNSIGNED NOT NULL,
  `value` int(10) UNSIGNED NOT NULL DEFAULT '1',
  `offer` float UNSIGNED DEFAULT '0'
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Dumping data for table `product`
--

INSERT INTO `product` (`id`, `shopId`, `title`, `price`, `value`, `offer`) VALUES
(1, 2, 'a1', 1813, 105, 0.3128),
(2, 2, 'a2', 2109, 150, 0.2),
(3, 3, 'a3', 9542, 241, 0.48),
(4, 3, 'a4', 9190, 289, 0.0401158),
(5, 1, 'a5', 8845, 237, 0.02424),
(6, 2, 'a6', 2880, 202, 0),
(7, 1, 'a7', 8231, 280, 0.25444),
(8, 3, 'a8', 5820, 99, 0),
(9, 3, 'a9', 8453, 34, 0.138868),
(10, 1, 'b1', 5484, 241, 0.01),
(11, 1, 'b2', 4081, 124, 0.173832),
(12, 1, 'b3', 9023, 172, 0.237003),
(13, 2, 'b4', 4878, 32, 0.14701),
(14, 1, 'b5', 3899, 169, 0.1746),
(15, 1, 'b6', 8872, 276, 0.25),
(16, 3, 'b7', 9259, 47, 0.1),
(17, 2, 'b8', 7827, 224, 0.47518),
(18, 2, 'b9', 8572, 89, 0.09477),
(19, 3, 'c1', 4361, 74, 0.227194),
(20, 2, 'c2', 5770, 71, 0.0154),
(21, 3, 'c3', 986, 177, 0.157248);

-- --------------------------------------------------------

--
-- Stand-in structure for view `rej1`
-- (See below for the actual view)
--
CREATE TABLE `rej1` (
`customerUsername` varchar(100)
,`phone_number` varchar(12)
);

-- --------------------------------------------------------

--
-- Stand-in structure for view `rej2`
-- (See below for the actual view)
--
CREATE TABLE `rej2` (
`customerEmail` varchar(125)
,`phone_number` varchar(12)
);

-- --------------------------------------------------------

--
-- Stand-in structure for view `s`
-- (See below for the actual view)
--
CREATE TABLE `s` (
`shopId` int(11) unsigned
,`productId` int(11) unsigned
,`total` decimal(32,0)
);

-- --------------------------------------------------------

--
-- Table structure for table `shipping`
--

CREATE TABLE `shipping` (
  `postmanid` int(10) UNSIGNED DEFAULT NULL,
  `purchase_time` timestamp NOT NULL,
  `customerUsername` varchar(100) NOT NULL,
  `shopId` int(10) UNSIGNED NOT NULL,
  `productId` int(10) UNSIGNED NOT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Dumping data for table `shipping`
--

INSERT INTO `shipping` (`postmanid`, `purchase_time`, `customerUsername`, `shopId`, `productId`) VALUES
(3, '2018-11-20 19:25:59', 'AliMorty', 2, 2),
(1, '2018-05-24 22:36:29', 'RoozbehGh', 1, 7),
(5, '2018-10-10 15:49:39', 'RoozbehGh', 1, 10),
(12, '2018-07-07 12:27:58', 'BehzadDara', 2, 13);

-- --------------------------------------------------------

--
-- Table structure for table `shop`
--

CREATE TABLE `shop` (
  `id` int(10) UNSIGNED NOT NULL,
  `title` varchar(150) NOT NULL,
  `city` varchar(30) DEFAULT NULL,
  `address` varchar(225) NOT NULL,
  `phone_number` varchar(12) NOT NULL,
  `owner` varchar(50) DEFAULT NULL,
  `start_time` time NOT NULL,
  `end_time` time NOT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Dumping data for table `shop`
--

INSERT INTO `shop` (`id`, `title`, `city`, `address`, `phone_number`, `owner`, `start_time`, `end_time`) VALUES
(1, 'Shop1', 'Kerman', 'Abbas Abad St.', '996633', 'Mr.Rashid Beigi', '08:00:00', '21:55:59'),
(2, 'Shop2', 'Tehran', 'Jordan St.', '885522', 'Mr.Naderi', '10:00:00', '23:59:59'),
(3, 'Shop3', 'Ahvaz', 'Sadat Abad St.', '774411', 'Mr.Shahriari', '11:00:00', '17:30:00');

-- --------------------------------------------------------

--
-- Table structure for table `supporter`
--

CREATE TABLE `supporter` (
  `id` int(10) UNSIGNED NOT NULL,
  `shopId` int(10) UNSIGNED NOT NULL,
  `first_name` varchar(100) DEFAULT NULL,
  `last_name` varchar(100) DEFAULT NULL,
  `address` varchar(225) NOT NULL,
  `phone_number` varchar(12) NOT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Dumping data for table `supporter`
--

INSERT INTO `supporter` (`id`, `shopId`, `first_name`, `last_name`, `address`, `phone_number`) VALUES
(1, 2, 'Mitra', 'Kamali', 'mm1 St.', '11111'),
(2, 1, 'Soraya', 'Ahmadi', 'mm2 St.', '22222'),
(3, 2, 'Shahnaz', 'Ghanbari', 'mm3 St.', '33333'),
(4, 3, 'Reyhane', 'Rahmani', 'mm4 St.', '44444'),
(5, 1, 'Mahnaz', 'Mahmoodi', 'mm5 St.', '55555'),
(6, 3, 'Jhale', 'Hemmati', 'mm6 St.', '66666');

-- --------------------------------------------------------

--
-- Table structure for table `updatecustomerlog`
--

CREATE TABLE `updatecustomerlog` (
  `username` varchar(100) NOT NULL,
  `pre_password` varchar(100) DEFAULT NULL,
  `new_password` varchar(100) DEFAULT NULL,
  `pre_email` varchar(125) NOT NULL,
  `new_email` varchar(125) NOT NULL,
  `pre_credit` int(10) UNSIGNED NOT NULL,
  `new_credit` int(10) UNSIGNED NOT NULL,
  `update_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `updatecustomerorderlog`
--

CREATE TABLE `updatecustomerorderlog` (
  `purchase_time` timestamp NOT NULL,
  `customerUsername` varchar(100) NOT NULL,
  `shopId` int(10) UNSIGNED NOT NULL,
  `productId` int(10) UNSIGNED NOT NULL,
  `dat` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `pre_status` enum('accepted','rejected','sending','done') DEFAULT NULL,
  `new_status` enum('accepted','rejected','sending','done') DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Dumping data for table `updatecustomerorderlog`
--

INSERT INTO `updatecustomerorderlog` (`purchase_time`, `customerUsername`, `shopId`, `productId`, `dat`, `pre_status`, `new_status`) VALUES
('2018-05-24 22:36:29', 'RoozbehGh', 1, 7, '2019-01-19 07:47:17', 'rejected', 'rejected');

-- --------------------------------------------------------

--
-- Table structure for table `updatenewcustomerlog`
--

CREATE TABLE `updatenewcustomerlog` (
  `postmanid` int(10) UNSIGNED NOT NULL,
  `dat` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `pre_status` enum('free','sending') NOT NULL,
  `new_status` enum('free','sending') NOT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `updatenewcustomerorderlog`
--

CREATE TABLE `updatenewcustomerorderlog` (
  `purchase_time` timestamp NOT NULL,
  `customerEmail` varchar(150) NOT NULL,
  `shopId` int(10) UNSIGNED NOT NULL,
  `productId` int(10) UNSIGNED NOT NULL,
  `dat` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `pre_status` enum('accepted','rejected','sending','done') DEFAULT NULL,
  `new_status` enum('accepted','rejected','sending','done') DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Dumping data for table `updatenewcustomerorderlog`
--

INSERT INTO `updatenewcustomerorderlog` (`purchase_time`, `customerEmail`, `shopId`, `productId`, `dat`, `pre_status`, `new_status`) VALUES
('2018-06-29 16:56:44', 'Javad@example.net', 2, 17, '2019-01-19 08:21:41', 'sending', 'sending');

-- --------------------------------------------------------

--
-- Structure for view `customersaverage`
--
DROP TABLE IF EXISTS `customersaverage`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `customersaverage`  AS  (select avg((`t`.`value` * `p`.`price`)) AS `average` from (`customerorders` `t` join `product` `p` on(((`t`.`productId` = `p`.`id`) and (`t`.`shopId` = `p`.`shopId`)))) where (`t`.`status` <> 'rejected')) ;

-- --------------------------------------------------------

--
-- Structure for view `h1`
--
DROP TABLE IF EXISTS `h1`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `h1`  AS  (select `m0`.`shopId` AS `shopId`,`m0`.`productId` AS `productId`,`m0`.`total` AS `total` from `m0` where `m0`.`total` >= all (select `u`.`total` from `m0` `u` where (`m0`.`shopId` = `u`.`shopId`))) ;

-- --------------------------------------------------------

--
-- Structure for view `h2`
--
DROP TABLE IF EXISTS `h2`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `h2`  AS  (select `m1`.`shopId` AS `shopId`,`m1`.`productId` AS `productId`,`m1`.`total` AS `total` from `m1` where `m1`.`total` >= all (select `u`.`total` from `m1` `u` where (`m1`.`shopId` = `u`.`shopId`))) ;

-- --------------------------------------------------------

--
-- Structure for view `h3`
--
DROP TABLE IF EXISTS `h3`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `h3`  AS  (select `m2`.`shopId` AS `shopId`,`m2`.`productId` AS `productId`,`m2`.`total` AS `total` from `m2` where `m2`.`total` >= all (select `u`.`total` from `m2` `u` where (`m2`.`shopId` = `u`.`shopId`))) ;

-- --------------------------------------------------------

--
-- Structure for view `h4`
--
DROP TABLE IF EXISTS `h4`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `h4`  AS  (select `m3`.`shopId` AS `shopId`,`m3`.`productId` AS `productId`,`m3`.`total` AS `total` from `m3` where `m3`.`total` >= all (select `u`.`total` from `m3` `u` where (`m3`.`shopId` = `u`.`shopId`))) ;

-- --------------------------------------------------------

--
-- Structure for view `h5`
--
DROP TABLE IF EXISTS `h5`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `h5`  AS  (select `m4`.`shopId` AS `shopId`,`m4`.`productId` AS `productId`,`m4`.`total` AS `total` from `m4` where `m4`.`total` >= all (select `u`.`total` from `m4` `u` where (`m4`.`shopId` = `u`.`shopId`))) ;

-- --------------------------------------------------------

--
-- Structure for view `m0`
--
DROP TABLE IF EXISTS `m0`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `m0`  AS  (select `s`.`shopId` AS `shopId`,`s`.`productId` AS `productId`,sum(`s`.`total`) AS `total` from `s` group by `s`.`shopId`,`s`.`productId`) ;

-- --------------------------------------------------------

--
-- Structure for view `m1`
--
DROP TABLE IF EXISTS `m1`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `m1`  AS  (select `m0`.`shopId` AS `shopId`,`m0`.`productId` AS `productId`,`m0`.`total` AS `total` from `m0` where (not((`m0`.`shopId`,`m0`.`productId`,`m0`.`total`) in (select `h1`.`shopId`,`h1`.`productId`,`h1`.`total` from `h1`)))) ;

-- --------------------------------------------------------

--
-- Structure for view `m2`
--
DROP TABLE IF EXISTS `m2`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `m2`  AS  (select `m1`.`shopId` AS `shopId`,`m1`.`productId` AS `productId`,`m1`.`total` AS `total` from `m1` where (not((`m1`.`shopId`,`m1`.`productId`,`m1`.`total`) in (select `h2`.`shopId`,`h2`.`productId`,`h2`.`total` from `h2`)))) ;

-- --------------------------------------------------------

--
-- Structure for view `m3`
--
DROP TABLE IF EXISTS `m3`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `m3`  AS  (select `m2`.`shopId` AS `shopId`,`m2`.`productId` AS `productId`,`m2`.`total` AS `total` from `m2` where (not((`m2`.`shopId`,`m2`.`productId`,`m2`.`total`) in (select `h3`.`shopId`,`h3`.`productId`,`h3`.`total` from `h3`)))) ;

-- --------------------------------------------------------

--
-- Structure for view `m4`
--
DROP TABLE IF EXISTS `m4`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `m4`  AS  (select `m3`.`shopId` AS `shopId`,`m3`.`productId` AS `productId`,`m3`.`total` AS `total` from `m3` where (not((`m3`.`shopId`,`m3`.`productId`,`m3`.`total`) in (select `h4`.`shopId`,`h4`.`productId`,`h4`.`total` from `h4`)))) ;

-- --------------------------------------------------------

--
-- Structure for view `newcustomeravgerage`
--
DROP TABLE IF EXISTS `newcustomeravgerage`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `newcustomeravgerage`  AS  (select avg((`t`.`value` * `p`.`price`)) AS `average` from (`newcustomerorders` `t` join `product` `p` on(((`t`.`productId` = `p`.`id`) and (`t`.`shopId` = `p`.`shopId`)))) where (`t`.`status` <> 'rejected')) ;

-- --------------------------------------------------------

--
-- Structure for view `postmanaverageall`
--
DROP TABLE IF EXISTS `postmanaverageall`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `postmanaverageall`  AS  (select `r`.`id` AS `id`,avg(`r`.`pr`) AS `average` from (select `s`.`postmanid` AS `id`,(`c`.`value` * `p`.`price`) AS `pr` from ((`shipping` `s` join `customerorders` `c` on(((`s`.`purchase_time` = `c`.`purchase_time`) and (`s`.`customerUsername` = `c`.`customerUsername`) and (`s`.`shopId` = `c`.`shopId`) and (`s`.`productId` = `c`.`productId`)))) join `product` `p` on((`c`.`productId` = `p`.`id`))) union all select `s`.`postmanid` AS `id`,(`c`.`value` * `p`.`price`) AS `pr` from ((`newcustomersshipping` `s` join `newcustomerorders` `c` on(((`s`.`purchase_time` = `c`.`purchase_time`) and (`s`.`customerEmail` = `c`.`customerEmail`) and (`s`.`shopId` = `c`.`shopId`) and (`s`.`productId` = `c`.`productId`)))) join `product` `p` on((`c`.`productId` = `p`.`id`)))) `r` group by `r`.`id`) ;

-- --------------------------------------------------------

--
-- Structure for view `rej1`
--
DROP TABLE IF EXISTS `rej1`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `rej1`  AS  (select `c`.`customerUsername` AS `customerUsername`,`c`.`phone_number` AS `phone_number` from `customerorders` `c` where (`c`.`status` = 'rejected')) ;

-- --------------------------------------------------------

--
-- Structure for view `rej2`
--
DROP TABLE IF EXISTS `rej2`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `rej2`  AS  (select `c`.`customerEmail` AS `customerEmail`,`t`.`phone_number` AS `phone_number` from (`newcustomerorders` `c` join `newcustomers` `t` on((`c`.`customerEmail` = `t`.`email`))) where (`c`.`status` = 'rejected')) ;

-- --------------------------------------------------------

--
-- Structure for view `s`
--
DROP TABLE IF EXISTS `s`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `s`  AS  (select `c`.`shopId` AS `shopId`,`c`.`productId` AS `productId`,sum(`c`.`value`) AS `total` from `customerorders` `c` group by `c`.`shopId`,`c`.`productId`) union all (select `t`.`shopId` AS `shopId`,`t`.`productId` AS `productId`,sum(`t`.`value`) AS `sum(T.value)` from `newcustomerorders` `t` group by `t`.`shopId`,`t`.`productId`) ;

--
-- Indexes for dumped tables
--

--
-- Indexes for table `customeraddresses`
--
ALTER TABLE `customeraddresses`
  ADD PRIMARY KEY (`address`,`CustomerUsername`),
  ADD KEY `CustomerUsername` (`CustomerUsername`);

--
-- Indexes for table `customerorders`
--
ALTER TABLE `customerorders`
  ADD PRIMARY KEY (`purchase_time`,`customerUsername`,`shopId`,`productId`),
  ADD KEY `shopId` (`shopId`),
  ADD KEY `productId` (`productId`,`shopId`),
  ADD KEY `customerUsername` (`customerUsername`,`address`),
  ADD KEY `customerUsername_2` (`customerUsername`,`phone_number`);

--
-- Indexes for table `customerphonenumbers`
--
ALTER TABLE `customerphonenumbers`
  ADD PRIMARY KEY (`phone_number`,`CustomerUsername`),
  ADD KEY `CustomerUsername` (`CustomerUsername`);

--
-- Indexes for table `customers`
--
ALTER TABLE `customers`
  ADD PRIMARY KEY (`username`);

--
-- Indexes for table `newcustomerorders`
--
ALTER TABLE `newcustomerorders`
  ADD PRIMARY KEY (`purchase_time`,`customerEmail`,`shopId`,`productId`),
  ADD KEY `customerEmail` (`customerEmail`),
  ADD KEY `shopId` (`shopId`),
  ADD KEY `productId` (`productId`,`shopId`);

--
-- Indexes for table `newcustomers`
--
ALTER TABLE `newcustomers`
  ADD PRIMARY KEY (`email`);

--
-- Indexes for table `newcustomersshipping`
--
ALTER TABLE `newcustomersshipping`
  ADD PRIMARY KEY (`purchase_time`,`customerEmail`,`shopId`,`productId`),
  ADD KEY `postmanid` (`postmanid`,`shopId`);

--
-- Indexes for table `operators`
--
ALTER TABLE `operators`
  ADD PRIMARY KEY (`id`,`shopId`),
  ADD KEY `shopId` (`shopId`);

--
-- Indexes for table `postman`
--
ALTER TABLE `postman`
  ADD PRIMARY KEY (`id`,`shopId`),
  ADD KEY `shopId` (`shopId`);

--
-- Indexes for table `product`
--
ALTER TABLE `product`
  ADD PRIMARY KEY (`id`,`shopId`),
  ADD KEY `shopId` (`shopId`);

--
-- Indexes for table `shipping`
--
ALTER TABLE `shipping`
  ADD PRIMARY KEY (`purchase_time`,`customerUsername`,`shopId`,`productId`),
  ADD KEY `postmanid` (`postmanid`,`shopId`);

--
-- Indexes for table `shop`
--
ALTER TABLE `shop`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `supporter`
--
ALTER TABLE `supporter`
  ADD PRIMARY KEY (`id`,`shopId`),
  ADD KEY `shopId` (`shopId`);

--
-- Indexes for table `updatecustomerlog`
--
ALTER TABLE `updatecustomerlog`
  ADD PRIMARY KEY (`username`,`update_time`);

--
-- Indexes for table `updatecustomerorderlog`
--
ALTER TABLE `updatecustomerorderlog`
  ADD PRIMARY KEY (`purchase_time`,`customerUsername`,`shopId`,`productId`,`dat`);

--
-- Indexes for table `updatenewcustomerlog`
--
ALTER TABLE `updatenewcustomerlog`
  ADD PRIMARY KEY (`postmanid`,`dat`);

--
-- Indexes for table `updatenewcustomerorderlog`
--
ALTER TABLE `updatenewcustomerorderlog`
  ADD PRIMARY KEY (`purchase_time`,`customerEmail`,`shopId`,`productId`,`dat`);

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
