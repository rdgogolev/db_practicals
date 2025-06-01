// Book: To Kill a Mockingbird
// Book: To Kill a Mockingbird
CREATE (b:Book {id:1,title: 'To Kill a Mockingbird', state: 'Present'}),
       (b)-[:WRITTEN_BY]->(:Author {name: 'Harper Lee'}),
       (b)-[:PUBLISHED_BY]->(:Publisher {name: 'J.B. Lippincott & Co.'}),
       (b)-[:HAS_GENRE]->(:Genre {name: 'Fiction'});


// Book: 1984
CREATE (b:Book {id:2,title: '1984', state: 'Present'}),
       (b)-[:WRITTEN_BY]->(:Author {name: 'George Orwell'}),
       (b)-[:PUBLISHED_BY]->(:Publisher {name: 'Penguin Books'}),
       (b)-[:HAS_GENRE]->(:Genre {name: 'Fiction'});

// Book: Pride and Prejudice
CREATE (b:Book {id:3,title: 'Pride and Prejudice', state: 'Present'}),
       (b)-[:WRITTEN_BY]->(:Author {name: 'Jane Austen'}),
       (b)-[:PUBLISHED_BY]->(:Publisher {name: 'T. Egerton'}),
       (b)-[:HAS_GENRE]->(:Genre {name: 'Romance'});

// Book: Animal Farm
CREATE (b:Book {id:4,title: 'Animal Farm', state: 'Present'}),
       (b)-[:WRITTEN_BY]->(:Author {name: 'George Orwell'}),
       (b)-[:PUBLISHED_BY]->(:Publisher {name: 'Secker and Warburg'}),
       (b)-[:HAS_GENRE]->(:Genre {name: 'Satire'});

// Book: Ikigai
CREATE (b:Book {id:5,title: 'Ikigai', state: 'Present'}),
       (b)-[:WRITTEN_BY]->(:Author {name: 'Francesc Miralles and Hector Garcia'}),
       (b)-[:PUBLISHED_BY]->(:Publisher {name: 'Penguin Life'}),
       (b)-[:HAS_GENRE]->(:Genre {name: 'Self Help'});

CREATE (:User {id: 1, username: 'alice', password_hash: '…hash…', role: 'member'}),
       (:User {id: 2, username: 'bob',   password_hash: '…hash…', role: 'member'});

CREATE (:Member {id: 1, name: 'Alice', email: 'alice@example.com'}),
       (:Member {id: 2, name: 'Bob',   email: 'bob@example.com'});

MATCH (m:Member {id: 1}), (u:User {id: 1}) CREATE (m)-[:IS_USER]->(u);
MATCH (m:Member {id: 2}), (u:User {id: 2}) CREATE (m)-[:IS_USER]->(u);

MATCH (b:Book {id: 1})
MATCH (m:Member {id: 1})
CREATE (m)-[:BORROWED {borrow_date: date('2025-06-01'), return_date: null}]->(b)
SET b.state = 'Borrowed';

