# MySQL 調優檢查清單

**建表規範**

- ✅ 必須有主鍵，且用自增整數（BIGINT UNSIGNED AUTO_INCREMENT）
- ✅ 禁止使用 TEXT/BLOB（放在額外表中）
- ✅ NOT NULL 欄位設定預設值
- ✅ 時間欄位用 DATETIME，不用 TIMESTAMP（2038 問題）
- ✅ 金額欄位用 DECIMAL，不用 FLOAT（精度問題）

**索引規範**

- ✅ JOIN 欄位必須建索引
- ✅ WHERE 常用欄位建索引
- ✅ 聯合索引：選擇性高的欄位放前面
- ✅ 禁止在索引欄位上做函數操作
- ✅ 單表索引不超過 5 個

**SQL 規範**

- ✅ 禁止 SELECT \*
- ✅ 禁止深度分頁（OFFSET > 10000）
- ✅ WHERE 條件必須有索引欄位
- ✅ 分頁用遊標方式（WHERE id > lastId）
- ✅ 大批量操作分批執行（每批 1000 條）
- ✅ 禁止在事務中做遠程調用
