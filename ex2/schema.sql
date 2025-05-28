DROP TABLE IF EXISTS borrow, book, author, publisher, genre, member, "user" CASCADE;

-- USERS
CREATE TABLE "user" (
  user_id       SERIAL PRIMARY KEY,
  username      VARCHAR NOT NULL UNIQUE,
  password_hash VARCHAR NOT NULL,
  role          VARCHAR NOT NULL
    CHECK(role IN ('admin','librarian','member'))
);

CREATE TABLE member (
  member_id SERIAL      PRIMARY KEY,
  user_id   INTEGER     NOT NULL UNIQUE
    REFERENCES "user"(user_id) ON DELETE CASCADE,
  name      VARCHAR     NOT NULL,
  email     VARCHAR     NOT NULL UNIQUE,
  address   TEXT
);

CREATE TABLE author (
  author_id SERIAL PRIMARY KEY,
  name      VARCHAR NOT NULL UNIQUE
);

CREATE TABLE publisher (
  publisher_id SERIAL PRIMARY KEY,
  name         VARCHAR NOT NULL UNIQUE
);

CREATE TABLE genre (
  genre_id SERIAL PRIMARY KEY,
  name     VARCHAR NOT NULL UNIQUE
);

CREATE TABLE book (
  book_id      SERIAL PRIMARY KEY,
  title        VARCHAR NOT NULL,
  author_id    INTEGER NOT NULL
    REFERENCES author(author_id),
  publisher_id INTEGER NOT NULL
    REFERENCES publisher(publisher_id),
  genre_id     INTEGER NOT NULL
    REFERENCES genre(genre_id),
  state        VARCHAR NOT NULL DEFAULT 'Present'
);

CREATE TABLE borrow (
  borrow_id   SERIAL    PRIMARY KEY,
  book_id     INTEGER   NOT NULL REFERENCES book(book_id),
  member_id   INTEGER   NOT NULL REFERENCES member(member_id),
  borrow_date DATE      NOT NULL,
  return_date DATE
);
