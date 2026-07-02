-- ================================================================
-- Smart Laundry POS & Automated Governance System
-- Database Initialization Script
-- Target: MariaDB 11+ / MySQL 8+
-- ================================================================

-- Buat database (jika belum ada)
CREATE DATABASE IF NOT EXISTS laundry_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE laundry_db;

-- Pastikan tidak ada konflik (jika re-run)
-- DROP TABLE IF EXISTS edit_request_items;
-- DROP TABLE IF EXISTS edit_requests;
-- DROP TABLE IF EXISTS order_items;
-- DROP TABLE IF EXISTS orders;
-- DROP TABLE IF EXISTS customers;
-- DROP TABLE IF EXISTS users;

-- ================================================================
-- 1. Tabel Pengguna Internal
-- ================================================================
CREATE TABLE IF NOT EXISTS users (
    user_id         INT             PRIMARY KEY AUTO_INCREMENT,
    username        VARCHAR(50)     UNIQUE NOT NULL,
    password_hash   VARCHAR(255)    NOT NULL,
    role            VARCHAR(10)     NOT NULL,
    created_at      TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT ck_user_role CHECK (role IN ('kasir', 'owner'))
) ENGINE=InnoDB;

-- ================================================================
-- 2. Tabel Entitas Pelanggan
-- ================================================================
CREATE TABLE IF NOT EXISTS customers (
    customer_id     VARCHAR(20)     PRIMARY KEY,
    name            VARCHAR(100)    NOT NULL,
    phone_number    VARCHAR(20)     UNIQUE NOT NULL,
    created_at      TIMESTAMP       DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ================================================================
-- 3. Tabel Header Transaksi (Orders)
-- ================================================================
CREATE TABLE IF NOT EXISTS orders (
    order_id        INT             PRIMARY KEY AUTO_INCREMENT,
    customer_id     VARCHAR(20),
    queue_number    INT             NOT NULL,
    payment_status  VARCHAR(20)     DEFAULT 'Belum Lunas',
    current_status  VARCHAR(20)     DEFAULT 'Antrean',

    -- Struktur Breakdown Finansial
    subtotal        INT             NOT NULL DEFAULT 0,
    discount        INT             NOT NULL DEFAULT 0,
    tax             INT             NOT NULL DEFAULT 0,
    grand_total     INT             NOT NULL DEFAULT 0,

    -- Lapisan Immutability
    is_locked       TINYINT(1)      DEFAULT 0,
    is_cancelled    TINYINT(1)      DEFAULT 0,

    order_date      TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (customer_id) REFERENCES customers(customer_id),

    CONSTRAINT ck_payment_status   CHECK (payment_status IN ('Belum Lunas', 'Lunas')),
    CONSTRAINT ck_current_status   CHECK (current_status IN ('Antrean', 'Dicuci', 'Disetrika', 'Siap Diambil', 'Selesai')),
    CONSTRAINT ck_is_locked        CHECK (is_locked IN (0, 1)),
    CONSTRAINT ck_is_cancelled     CHECK (is_cancelled IN (0, 1))
) ENGINE=InnoDB;

-- ================================================================
-- 4. Tabel Detail Item Transaksi (Multi-Service Support)
-- ================================================================
CREATE TABLE IF NOT EXISTS order_items (
    item_id             INT             PRIMARY KEY AUTO_INCREMENT,
    order_id            INT             NOT NULL,
    service_type        VARCHAR(20)     NOT NULL,
    weight_quantity     DECIMAL(5,2)    NOT NULL,
    price_per_unit      INT             NOT NULL COMMENT 'Harga historis terkunci saat transaksi',
    item_subtotal       INT             NOT NULL,

    FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE,

    CONSTRAINT ck_service_type CHECK (service_type IN ('Kiloan', 'Sepatu', 'Boneka', 'Karpet', 'Jas'))
) ENGINE=InnoDB;

-- ================================================================
-- 5. Tabel Utama Pengajuan Koreksi (Edit Request Header)
-- ================================================================
CREATE TABLE IF NOT EXISTS edit_requests (
    request_id              INT             PRIMARY KEY AUTO_INCREMENT,
    order_id                INT             NOT NULL,
    requested_by            INT             NOT NULL,
    reason                  TEXT            NOT NULL,
    approval_status         VARCHAR(20)     DEFAULT 'Pending',
    approved_by             INT,
    is_cancellation_request TINYINT(1)      DEFAULT 0,
    created_at              TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (order_id)     REFERENCES orders(order_id),
    FOREIGN KEY (requested_by) REFERENCES users(user_id),
    FOREIGN KEY (approved_by)  REFERENCES users(user_id),

    CONSTRAINT ck_approval_status      CHECK (approval_status IN ('Pending', 'Approved', 'Rejected')),
    CONSTRAINT ck_is_cancellation_req  CHECK (is_cancellation_request IN (0, 1))
) ENGINE=InnoDB;

-- ================================================================
-- 6. Tabel Detail Komparasi Audit (Git-Diff Item Log)
-- ================================================================
CREATE TABLE IF NOT EXISTS edit_request_items (
    request_item_id         INT             PRIMARY KEY AUTO_INCREMENT,
    request_id              INT             NOT NULL,
    order_item_id           INT             COMMENT 'NULL jika kasir menambahkan item baru saat revisi',
    service_type            VARCHAR(20)     NOT NULL,

    -- Snapshot Komparasi Nilai Lama vs Nilai Usulan Baru
    old_weight_quantity     DECIMAL(5,2),
    new_weight_quantity     DECIMAL(5,2),
    old_price_per_unit      INT,
    new_price_per_unit      INT,
    old_item_subtotal       INT,
    new_item_subtotal       INT,

    FOREIGN KEY (request_id) REFERENCES edit_requests(request_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ================================================================
-- INDEXES (PRD §5: Performance Optimization)
-- ================================================================
CREATE INDEX idx_orders_customer_id    ON orders(customer_id);
CREATE INDEX idx_orders_order_date     ON orders(order_date);
CREATE INDEX idx_orders_status         ON orders(current_status, is_cancelled);
CREATE INDEX idx_order_items_order_id  ON order_items(order_id);
CREATE INDEX idx_edit_req_order_id     ON edit_requests(order_id);
CREATE INDEX idx_edit_req_status       ON edit_requests(approval_status);

-- ================================================================
-- SEED: Akun Owner Pertama
-- Password: owner123
-- ================================================================
INSERT INTO users (username, password_hash, role) VALUES
    ('owner', '$2b$12$khIv17TrRJTvg73Jdjd8mOEM2sAs/DzrbUS0ZtRHTnxnhH91cBsf2', 'owner')
ON DUPLICATE KEY UPDATE username = username;

-- ================================================================
-- SEED: Akun Kasir Demo
-- Password: kasir123
-- ================================================================
INSERT INTO users (username, password_hash, role) VALUES
    ('kasir1', '$2b$12$C/aivuvezz91vU91Zs7F7eAgkurqgeCOrC.fijcczbWiv7UQ9XZMS', 'kasir')
ON DUPLICATE KEY UPDATE username = username;

-- ================================================================
-- VERIFIKASI
-- ================================================================
SELECT '=== DATABASE READY ===' AS status;
SELECT user_id, username, role, created_at FROM users;

-- Fix: kasir role harus 'kasir'
UPDATE users SET role = 'kasir' WHERE username = 'kasir1';
