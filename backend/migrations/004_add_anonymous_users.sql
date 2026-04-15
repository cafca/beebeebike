ALTER TABLE users
    ADD COLUMN account_type TEXT NOT NULL DEFAULT 'registered';

ALTER TABLE users
    ALTER COLUMN email DROP NOT NULL,
    ALTER COLUMN password_hash DROP NOT NULL;

ALTER TABLE users
    ADD CONSTRAINT users_account_type_check
    CHECK (account_type IN ('anonymous', 'registered'));

ALTER TABLE users
    ADD CONSTRAINT users_registered_credentials_check
    CHECK (
        account_type = 'anonymous'
        OR (email IS NOT NULL AND password_hash IS NOT NULL)
    );
