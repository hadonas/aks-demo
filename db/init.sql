-- 데이터베이스 초기화 스크립트
CREATE DATABASE IF NOT EXISTS testdb;
USE testdb;

-- 사용자 테이블 생성
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(255) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 메시지 테이블 생성 (user_id 컬럼 포함)
CREATE TABLE IF NOT EXISTS messages (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    message TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- 기존 messages 테이블에 user_id 컬럼이 없다면 추가
ALTER TABLE messages ADD COLUMN IF NOT EXISTS user_id INT; 