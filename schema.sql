CREATE TABLE lists (
  id serial PRIMARY KEY,
  name text UNIQUE NOT NULL
);

CREATE TABLE todos (
  id serial PRIMARY KEY,
  name text NOT NULL,
  complete boolean NOT NULL DEFAULT false,
  list_id int NOT NULL REFERENCES lists (id) ON DELETE CASCADE
);

-- createdb todos
-- psql -d todos < schema.sql

