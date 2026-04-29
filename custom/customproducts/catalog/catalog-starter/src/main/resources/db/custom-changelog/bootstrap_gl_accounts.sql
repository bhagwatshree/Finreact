-- =============================================================================
-- Custom Products GL Accounting Bootstrap
-- =============================================================================
-- Wires up cash-based accounting for the 10 demo products so deposits,
-- withdrawals, fee charges, and interest postings produce real journal entries
-- in m_journal_entry. Idempotent; safe to re-run.
--
-- Chart of Accounts seeded (minimal):
--   1000 Cash on Hand                  (Asset)     classification_enum=1
--   1100 Overdraft Portfolio Control   (Asset)     classification_enum=1
--   2000 Savings Liability Control     (Liability) classification_enum=2
--   4000 Income from Fees              (Income)    classification_enum=4
--   4001 Income from Penalties         (Income)    classification_enum=4
--   5000 Interest on Savings (Expense) (Expense)   classification_enum=5
--
-- Product mapping enum (acc_product_mapping.financial_account_type):
--   1 = SAVINGS_REFERENCE       -> 1000 Cash on Hand
--   2 = SAVINGS_CONTROL         -> 2000 Savings Liability
--   3 = INTEREST_ON_SAVINGS     -> 5000 Interest on Savings Expense
--   4 = INCOME_FROM_FEES        -> 4000 Income from Fees
--   5 = INCOME_FROM_PENALTIES   -> 4001 Income from Penalties
-- product_type = 2 (PortfolioProductType.SAVING)
-- =============================================================================

BEGIN;

-- 1) Chart of Accounts -----------------------------------------------------
INSERT INTO acc_gl_account (gl_code, name, classification_enum, account_usage, manual_journal_entries_allowed, disabled, description)
SELECT v.gl_code, v.name, v.classification_enum, 1, TRUE, FALSE, v.description
  FROM (VALUES
        ('1000', 'Cash on Hand',                       1, 'Cash held by branch'),
        ('1100', 'Overdraft Portfolio Control',        1, 'Receivable from clients in overdraft'),
        ('2000', 'Savings Liability Control',          2, 'Bank''s obligation to savings depositors'),
        ('4000', 'Income from Fees',                   4, 'Fee income earned on savings products'),
        ('4001', 'Income from Penalties',              4, 'Penalty income earned on savings products'),
        ('5000', 'Interest on Savings (Expense)',      5, 'Interest paid to savings clients')
       ) AS v(gl_code, name, classification_enum, description)
 WHERE NOT EXISTS (SELECT 1 FROM acc_gl_account a WHERE a.gl_code = v.gl_code);

-- 2) Switch all CP products to CASH-based accounting ----------------------
UPDATE m_savings_product SET accounting_type = 2 WHERE name LIKE 'CP %' AND accounting_type <> 2;

-- 3) Map each CP product to the 5 SAVINGS GL accounts ---------------------
DO $$
DECLARE
    p RECORD;
    cash_id     BIGINT := (SELECT id FROM acc_gl_account WHERE gl_code='1000');
    liab_id     BIGINT := (SELECT id FROM acc_gl_account WHERE gl_code='2000');
    int_exp_id  BIGINT := (SELECT id FROM acc_gl_account WHERE gl_code='5000');
    fee_inc_id  BIGINT := (SELECT id FROM acc_gl_account WHERE gl_code='4000');
    pen_inc_id  BIGINT := (SELECT id FROM acc_gl_account WHERE gl_code='4001');
    pairs INT[][] := ARRAY[ ARRAY[1, 0], ARRAY[2, 0], ARRAY[3, 0], ARRAY[4, 0], ARRAY[5, 0] ];
    fa_type INT;
    gl_id BIGINT;
BEGIN
    FOR p IN SELECT id, name FROM m_savings_product WHERE name LIKE 'CP %' LOOP
        FOR fa_type IN 1..5 LOOP
            gl_id := CASE fa_type
                        WHEN 1 THEN cash_id
                        WHEN 2 THEN liab_id
                        WHEN 3 THEN int_exp_id
                        WHEN 4 THEN fee_inc_id
                        WHEN 5 THEN pen_inc_id
                     END;
            IF NOT EXISTS (
                SELECT 1 FROM acc_product_mapping m
                 WHERE m.product_id = p.id AND m.product_type = 2 AND m.financial_account_type = fa_type
            ) THEN
                INSERT INTO acc_product_mapping (gl_account_id, product_id, product_type, financial_account_type)
                VALUES (gl_id, p.id, 2, fa_type);
            END IF;
        END LOOP;
    END LOOP;
END $$;

COMMIT;
