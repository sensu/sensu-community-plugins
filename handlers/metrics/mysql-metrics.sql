create database sensumetrics;
use sensumetrics;
create table sensu_historic_metrics( 
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `client_id` VARCHAR(150) NOT NULL,
    `check_name` VARCHAR(100) NOT NULL,
    `issue_time` INT(8) UNSIGNED NOT NULL,
    `output` TEXT,
    `status` INT(2) UNSIGNED,
    INDEX `client_id_idx` (`client_id`),
    INDEX `check_name_idx` (`check_name`),
    INDEX `issue_time_idx` (`issue_time`)
);
GRANT SELECT,INSERT on sensumetrics.sensu_historic_metrics TO sensu_user@'localhost' IDENTIFIED BY 'sensu_user_pass';
FLUSH PRIVILEGES;
