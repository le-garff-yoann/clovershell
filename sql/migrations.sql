-- 1 up

CREATE EXTENSION zombodb;

CREATE TABLE clovers (
    id BIGSERIAL NOT NULL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    template TEXT,
    score BIGINT DEFAULT 0 CHECK (score >= 0)
);

CREATE UNIQUE INDEX idx_unique_clovers_name ON clovers(name);
CREATE INDEX idx_zdb_clovers 
    ON clovers
    USING zombodb(zdb('clovers', clovers.ctid), zdb(clovers))
    WITH (url='default');

CREATE TABLE tags (
    id SERIAL NOT NULL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT
);

CREATE UNIQUE INDEX idx_unique_tags_name ON tags(name);
CREATE INDEX idx_zdb_tags
    ON tags
    USING zombodb(zdb('tags', tags.ctid), zdb(tags))
    WITH (url='default');

CREATE TABLE plays (
    id BIGSERIAL NOT NULL PRIMARY KEY,
    return_code BIGINT NOT NULL,
    started_at TIMESTAMP NOT NULL,
    -- ended_at TIMESTAMP,
    -- stderr TEXT[],
    -- stdout TEXT[],
    stderr TEXT,
    stdout TEXT,
    clover_id BIGSERIAL NOT NULL REFERENCES clovers(id) ON DELETE CASCADE
);

CREATE INDEX idx_zdb_plays
    ON plays
    USING zombodb(zdb('plays', plays.ctid), zdb(plays))
    WITH (url='default');

CREATE TABLE users (
    id BIGSERIAL NOT NULL PRIMARY KEY,
    username VARCHAR(255) NOT NULL,
    password VARCHAR(255) NOT NULL
);

CREATE UNIQUE INDEX idx_unique_users_name ON users(username);

CREATE TABLE clovers_tags (
    clover_id BIGINT NOT NULL REFERENCES clovers(id) ON DELETE CASCADE,
    tag_id BIGINT NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
    PRIMARY KEY (clover_id, tag_id)
);

CREATE TABLE plays_users (
    play_id BIGINT NOT NULL REFERENCES plays(id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    PRIMARY KEY (play_id, user_id)
);

CREATE FUNCTION compute_clover_score_on_plays_change() RETURNS TRIGGER AS $compute_clover_score_on_plays_change$
    DECLARE
        r RECORD;
        ok INT := 0;
        ko INT := 0;
    BEGIN
        FOR r IN SELECT return_code, count(*) AS count FROM plays WHERE clover_id = NEW.clover_id GROUP BY return_code LOOP
            IF (r.return_code = 0) THEN
                ok := r.count;
            ELSE
                ko := ko + r.count;
            END IF;
        END LOOP;

        UPDATE clovers SET score = ((1 + ok) / (1 + ko)) * 10 WHERE id = NEW.clover_id;

        RETURN NULL;
    END;
$compute_clover_score_on_plays_change$ LANGUAGE plpgsql;

CREATE TRIGGER compute_clover_score_on_plays_change
AFTER INSERT ON plays
    FOR EACH ROW EXECUTE PROCEDURE compute_clover_score_on_plays_change();
