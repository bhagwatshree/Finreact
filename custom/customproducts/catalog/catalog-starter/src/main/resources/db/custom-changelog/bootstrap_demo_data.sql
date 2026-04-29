-- =============================================================================
-- Custom Products Demo Bootstrap (Postgres)
-- =============================================================================
-- Mirrors the Liquibase changesets in this directory so the demo data can be
-- loaded directly against a running Fineract database without going through
-- the custom_changelog context. Idempotent: every insert is guarded by an
-- existence check or ON CONFLICT clause.
--
-- Caveat: per user spec, office is in Kenya but currency is ZAR (Rand). Real
-- Kenyan deployments would use KES.
-- =============================================================================

BEGIN;

-- 1) Catalog tables --------------------------------------------------------
CREATE TABLE IF NOT EXISTS c_custom_product_catalog (
    id                       BIGSERIAL PRIMARY KEY,
    code                     VARCHAR(50)  NOT NULL UNIQUE,
    display_name             VARCHAR(200) NOT NULL,
    family                   VARCHAR(50)  NOT NULL,
    core_savings_product_id  BIGINT REFERENCES m_savings_product(id),
    marketing_tagline        VARCHAR(500),
    icon_url                 VARCHAR(500),
    enabled                  BOOLEAN      NOT NULL DEFAULT TRUE,
    created_date             TIMESTAMP WITH TIME ZONE,
    last_modified_date       TIMESTAMP WITH TIME ZONE,
    created_by               BIGINT,
    last_modified_by         BIGINT
);

CREATE TABLE IF NOT EXISTS c_custom_product_account_link (
    id                  BIGSERIAL PRIMARY KEY,
    custom_product_id   BIGINT NOT NULL REFERENCES c_custom_product_catalog(id),
    savings_account_id  BIGINT NOT NULL,
    link_type           VARCHAR(20) NOT NULL,
    created_date        TIMESTAMP WITH TIME ZONE
);
CREATE INDEX IF NOT EXISTS idx_c_custom_product_account_link_account
    ON c_custom_product_account_link(savings_account_id);

-- 2) Catalog rows (10 products) -------------------------------------------
INSERT INTO c_custom_product_catalog (code, display_name, family, marketing_tagline, enabled) VALUES
    ('SAV', 'Savings with Interest',         'SAVINGS',                  NULL,                                                              TRUE),
    ('FD',  'Fixed Deposit',                 'FIXED_DEPOSIT',            NULL,                                                              TRUE),
    ('LTS', 'Long term Savings',             'RECURRING_DEPOSIT',        NULL,                                                              TRUE),
    ('GS',  'Group Savings with Interest',   'GROUP_SAVINGS',            NULL,                                                              TRUE),
    ('GSL', 'Group Savings with Loans',      'GROUP_SAVINGS_WITH_LOANS', NULL,                                                              TRUE),
    ('GSP', 'Group Savings',                 'GROUP_SAVINGS',            'Plain group savings without interest accrual',                    TRUE),
    ('TGT', 'Target Savings',                'SAVINGS',                  'Goal-based savings; backed by core SAVINGS engine',               TRUE),
    ('GAM', 'Gamified Savings',              'SAVINGS',                  'Rewards layer over SAVINGS',                                      TRUE),
    ('CRF', 'Crowdfunding',                  'SAVINGS',                  'Pooled-contribution SAVINGS',                                     TRUE),
    ('PEN', 'Pensions (Long term savings)',  'RECURRING_DEPOSIT',        'Long-horizon RD with vesting metadata managed by wrapper',        TRUE)
ON CONFLICT (code) DO NOTHING;

-- 3) Office: VZA (Kenya) ---------------------------------------------------
INSERT INTO m_office (parent_id, hierarchy, external_id, name, opening_date)
SELECT 1, '.1.', 'VZA-EXT-001', 'VZA', DATE '2024-01-01'
WHERE NOT EXISTS (SELECT 1 FROM m_office WHERE name = 'VZA');

-- 4) Activate ZAR for the org (currency row already in m_currency) --------
INSERT INTO m_organisation_currency (code, decimal_places, name, display_symbol, internationalized_name_code)
SELECT 'ZAR', 2, 'South African Rand', 'R', 'currency.ZAR'
WHERE NOT EXISTS (SELECT 1 FROM m_organisation_currency WHERE code = 'ZAR');

-- 5) Ten savings products (one per catalog row) ---------------------------
-- All are deposit_type_enum=100 (Savings) for demo simplicity. The catalog
-- row's family field tells the wrapper which logical product family this is.
-- accounting_type=1 (NONE) avoids GL setup. Other enums are sane defaults.
DO $$
DECLARE
    p RECORD;
    rate NUMERIC;
    sname VARCHAR(4);
BEGIN
    FOR p IN
        SELECT * FROM (VALUES
            ('SAV', 'CP Savings with Interest',       'CPSV', 5.00),
            ('FD',  'CP Fixed Deposit',               'CPFD', 8.00),
            ('LTS', 'CP Long term Savings',           'CPLT', 7.00),
            ('GS',  'CP Group Savings with Interest', 'CPGS', 4.00),
            ('GSL', 'CP Group Savings with Loans',    'CPGL', 4.50),
            ('GSP', 'CP Group Savings',               'CPGP', 0.00),
            ('TGT', 'CP Target Savings',              'CPTG', 5.50),
            ('GAM', 'CP Gamified Savings',            'CPGM', 5.25),
            ('CRF', 'CP Crowdfunding',                'CPCF', 0.00),
            ('PEN', 'CP Pensions',                    'CPPN', 6.00)
        ) AS t(code, pname, sname, rate)
    LOOP
        IF NOT EXISTS (SELECT 1 FROM m_savings_product WHERE name = p.pname) THEN
            INSERT INTO m_savings_product (
                name, short_name, description, deposit_type_enum, currency_code,
                currency_digits, currency_multiplesof, nominal_annual_interest_rate,
                interest_compounding_period_enum, interest_posting_period_enum,
                interest_calculation_type_enum, interest_calculation_days_in_year_type_enum,
                accounting_type, allow_overdraft, enforce_min_required_balance, withhold_tax
            ) VALUES (
                p.pname, p.sname, p.pname || ' (custom-products demo)', 100, 'ZAR',
                2, 1, p.rate,
                2, 4,
                1, 365,
                1, FALSE, FALSE, FALSE
            );

            UPDATE c_custom_product_catalog
               SET core_savings_product_id = (SELECT id FROM m_savings_product WHERE name = p.pname),
                   last_modified_date      = NOW()
             WHERE code = p.code;
        END IF;
    END LOOP;
END $$;

-- 6) Two groups under VZA --------------------------------------------------
DO $$
DECLARE
    vza_id BIGINT := (SELECT id FROM m_office WHERE name = 'VZA');
BEGIN
    IF NOT EXISTS (SELECT 1 FROM m_group WHERE display_name = 'VZA Group A') THEN
        INSERT INTO m_group (status_enum, activation_date, office_id, level_id, display_name, hierarchy, account_no, external_id,
                             submittedon_date, submittedon_userid, activatedon_userid)
        VALUES (300, DATE '2024-02-01', vza_id, 2, 'VZA Group A', '.1.GA.', 'GRP000000A', 'VZA-GRP-A',
                DATE '2024-01-15', 1, 1);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM m_group WHERE display_name = 'VZA Group B') THEN
        INSERT INTO m_group (status_enum, activation_date, office_id, level_id, display_name, hierarchy, account_no, external_id,
                             submittedon_date, submittedon_userid, activatedon_userid)
        VALUES (300, DATE '2024-02-15', vza_id, 2, 'VZA Group B', '.1.GB.', 'GRP000000B', 'VZA-GRP-B',
                DATE '2024-01-20', 1, 1);
    END IF;
END $$;

-- 7) Three clients under VZA ----------------------------------------------
DO $$
DECLARE
    vza_id BIGINT := (SELECT id FROM m_office WHERE name = 'VZA');
BEGIN
    IF NOT EXISTS (SELECT 1 FROM m_client WHERE account_no = 'CLI0000001') THEN
        INSERT INTO m_client (account_no, external_id, status_enum, activation_date, office_id,
                              firstname, lastname, display_name, mobile_no,
                              office_joining_date, submittedon_date, activatedon_userid, legal_form_enum,
                              created_by, last_modified_by, created_on_utc, last_modified_on_utc)
        VALUES ('CLI0000001', 'VZA-CLI-001', 300, DATE '2024-03-01', vza_id,
                'Amani',  'Otieno',  'Amani Otieno',  '+254700000001',
                DATE '2024-03-01', DATE '2024-02-25', 1, 1,
                1, 1, NOW(), NOW());
    END IF;
    IF NOT EXISTS (SELECT 1 FROM m_client WHERE account_no = 'CLI0000002') THEN
        INSERT INTO m_client (account_no, external_id, status_enum, activation_date, office_id,
                              firstname, lastname, display_name, mobile_no,
                              office_joining_date, submittedon_date, activatedon_userid, legal_form_enum,
                              created_by, last_modified_by, created_on_utc, last_modified_on_utc)
        VALUES ('CLI0000002', 'VZA-CLI-002', 300, DATE '2024-03-05', vza_id,
                'Brenda', 'Wanjiku', 'Brenda Wanjiku', '+254700000002',
                DATE '2024-03-05', DATE '2024-03-01', 1, 1,
                1, 1, NOW(), NOW());
    END IF;
    IF NOT EXISTS (SELECT 1 FROM m_client WHERE account_no = 'CLI0000003') THEN
        INSERT INTO m_client (account_no, external_id, status_enum, activation_date, office_id,
                              firstname, lastname, display_name, mobile_no,
                              office_joining_date, submittedon_date, activatedon_userid, legal_form_enum,
                              created_by, last_modified_by, created_on_utc, last_modified_on_utc)
        VALUES ('CLI0000003', 'VZA-CLI-003', 300, DATE '2024-03-10', vza_id,
                'Chiku',  'Kamau',   'Chiku Kamau',   '+254700000003',
                DATE '2024-03-10', DATE '2024-03-08', 1, 1,
                1, 1, NOW(), NOW());
    END IF;
END $$;

-- 8) Group memberships: every client is in both groups --------------------
INSERT INTO m_group_client (group_id, client_id)
SELECT g.id, c.id
  FROM m_group   g
  JOIN m_client  c ON c.account_no IN ('CLI0000001','CLI0000002','CLI0000003')
 WHERE g.display_name IN ('VZA Group A','VZA Group B')
ON CONFLICT (group_id, client_id) DO NOTHING;

-- 9) Savings accounts (purchases) -----------------------------------------
-- Individual products: SAV, FD, LTS, TGT, GAM, CRF, PEN  -> 7 per client
-- Group products:      GS, GSL, GSP                       -> per group
-- Account number convention: ACC-<CLI/GRP>-<CODE>
DO $$
DECLARE
    indiv TEXT[] := ARRAY['SAV','FD','LTS','TGT','GAM','CRF','PEN'];
    grp   TEXT[] := ARRAY['GS','GSL','GSP'];
    cli   RECORD;
    grpr  RECORD;
    pcode TEXT;
    prod  RECORD;
BEGIN
    -- Individual purchases
    FOR cli IN SELECT id, account_no FROM m_client WHERE account_no IN ('CLI0000001','CLI0000002','CLI0000003') LOOP
        FOREACH pcode IN ARRAY indiv LOOP
            SELECT id, nominal_annual_interest_rate, interest_compounding_period_enum,
                   interest_calculation_type_enum, interest_calculation_days_in_year_type_enum,
                   deposit_type_enum
              INTO prod
              FROM m_savings_product
             WHERE id = (SELECT core_savings_product_id FROM c_custom_product_catalog WHERE code = pcode);

            IF prod.id IS NOT NULL AND NOT EXISTS (
                SELECT 1 FROM m_savings_account WHERE account_no = 'ACC-'||cli.account_no||'-'||pcode
            ) THEN
                INSERT INTO m_savings_account (
                    account_no, client_id, product_id, status_enum, sub_status_enum,
                    account_type_enum, deposit_type_enum,
                    submittedon_date, approvedon_date, activatedon_date,
                    submittedon_userid, approvedon_userid, activatedon_userid,
                    currency_code, currency_digits, currency_multiplesof,
                    nominal_annual_interest_rate, interest_compounding_period_enum,
                    interest_posting_period_enum, interest_calculation_type_enum,
                    interest_calculation_days_in_year_type_enum,
                    allow_overdraft, enforce_min_required_balance, withhold_tax,
                    account_balance_derived, version,
                    created_by, last_modified_by, created_on_utc, last_modified_on_utc
                ) VALUES (
                    'ACC-'||cli.account_no||'-'||pcode, cli.id, prod.id, 300, 0,
                    1, prod.deposit_type_enum,
                    DATE '2024-04-01', DATE '2024-04-02', DATE '2024-04-03',
                    1, 1, 1,
                    'ZAR', 2, 1,
                    prod.nominal_annual_interest_rate, prod.interest_compounding_period_enum,
                    4, prod.interest_calculation_type_enum,
                    prod.interest_calculation_days_in_year_type_enum,
                    FALSE, FALSE, FALSE,
                    0, 1,
                    1, 1, NOW(), NOW()
                );
            END IF;
        END LOOP;
    END LOOP;

    -- Group purchases
    FOR grpr IN SELECT id, account_no FROM m_group WHERE display_name IN ('VZA Group A','VZA Group B') LOOP
        FOREACH pcode IN ARRAY grp LOOP
            SELECT id, nominal_annual_interest_rate, interest_compounding_period_enum,
                   interest_calculation_type_enum, interest_calculation_days_in_year_type_enum,
                   deposit_type_enum
              INTO prod
              FROM m_savings_product
             WHERE id = (SELECT core_savings_product_id FROM c_custom_product_catalog WHERE code = pcode);

            IF prod.id IS NOT NULL AND NOT EXISTS (
                SELECT 1 FROM m_savings_account WHERE account_no = 'ACC-'||grpr.account_no||'-'||pcode
            ) THEN
                INSERT INTO m_savings_account (
                    account_no, group_id, product_id, status_enum, sub_status_enum,
                    account_type_enum, deposit_type_enum,
                    submittedon_date, approvedon_date, activatedon_date,
                    currency_code, currency_digits, currency_multiplesof,
                    nominal_annual_interest_rate, interest_compounding_period_enum,
                    interest_posting_period_enum, interest_calculation_type_enum,
                    interest_calculation_days_in_year_type_enum,
                    allow_overdraft, enforce_min_required_balance, withhold_tax,
                    account_balance_derived, version,
                    created_by, last_modified_by, created_on_utc, last_modified_on_utc
                ) VALUES (
                    'ACC-'||grpr.account_no||'-'||pcode, grpr.id, prod.id, 300, 0,
                    2, prod.deposit_type_enum,
                    DATE '2024-04-05', DATE '2024-04-06', DATE '2024-04-07',
                    1, 1, 1,
                    'ZAR', 2, 1,
                    prod.nominal_annual_interest_rate, prod.interest_compounding_period_enum,
                    4, prod.interest_calculation_type_enum,
                    prod.interest_calculation_days_in_year_type_enum,
                    FALSE, FALSE, FALSE,
                    0, 1,
                    1, 1, NOW(), NOW()
                );
            END IF;
        END LOOP;
    END LOOP;
END $$;

-- 10) Catalog -> account links --------------------------------------------
INSERT INTO c_custom_product_account_link (custom_product_id, savings_account_id, link_type, created_date)
SELECT cat.id, sa.id,
       CASE WHEN sa.client_id IS NOT NULL THEN 'INDIVIDUAL' ELSE 'GROUP' END,
       NOW()
  FROM m_savings_account sa
  JOIN c_custom_product_catalog cat ON cat.core_savings_product_id = sa.product_id
 WHERE NOT EXISTS (
    SELECT 1 FROM c_custom_product_account_link l
     WHERE l.custom_product_id = cat.id AND l.savings_account_id = sa.id
 );

COMMIT;
