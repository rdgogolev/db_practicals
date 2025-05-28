-- Authors
INSERT INTO author(name) VALUES
 ('George Orwell'),
 ('Harper Lee'),
 ('Jane Austen'),
 ('Francesc Miralles and Hector Garcia');

-- Publishers
INSERT INTO publisher(name) VALUES
 ('Penguin Books'),
 ('J.B. Lippincott & Co.'),
 ('T. Egerton'),
 ('Secker and Warburg'),
 ('Penguin Life');

-- Genres
INSERT INTO genre(name) VALUES
 ('Fiction'),
 ('Non-Fiction'),
 ('Romance'),
 ('Satire'),
 ('Self Help');

-- Books
INSERT INTO book(title, author_id, publisher_id, genre_id, state) VALUES
 ('1984', 1, 1, 1, 'Present'),
 ('To Kill a Mockingbird', 2, 2, 1, 'Present'),
 ('Pride and Prejudice', 3, 3, 3, 'Present'),
 ('Animal Farm', 1, 4, 4, 'Present'),
 ('Ikigai', 4, 5, 5, 'Present');

-- Users & Members
INSERT INTO "user"(username, password_hash, role) VALUES
 ('alice', '…hash…','member'),
 ('bob',   '…hash…','member');
INSERT INTO member(user_id, name, email) VALUES
 (1, 'Alice', 'alice@example.com'),
 (2, 'Bob',   'bob@example.com');
