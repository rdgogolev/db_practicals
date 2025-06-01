from flask import Flask, jsonify, render_template, request
from datetime import date
from flask_cors import CORS
from neo4j import GraphDatabase

app = Flask(__name__, static_url_path='/static', static_folder='static')
CORS(app)

# Neo4j connection setup
NEO4J_URI = "bolt://localhost:7687"
NEO4J_USER = "neo4j"
NEO4J_PASSWORD = "qwerty123"

driver = GraphDatabase.driver(NEO4J_URI, auth=(NEO4J_USER, NEO4J_PASSWORD))

# ========== ROUTES ==========

@app.route('/')
def home():
    return render_template('index.html')

@app.route('/viewer.html')
def viewer():
    return render_template('viewer.html')


@app.route('/api/list')
def list_books():
    print('ok...')
    query = """
       MATCH (b:Book)
OPTIONAL MATCH (b)-[:WRITTEN_BY]->(a:Author)
OPTIONAL MATCH (b)-[:PUBLISHED_BY]->(p:Publisher)
OPTIONAL MATCH (b)-[:HAS_GENRE]->(g:Genre)
OPTIONAL MATCH (m:Member)-[r:BORROWED]->(b)
RETURN 
  b.id AS `Book ID`,
  b.title AS Title,
  a.name AS Author,
  p.name AS Publisher,
  g.name AS Genre,
  m.name AS Borrower,
  r.borrow_date AS `Borrow Date`,
  r.return_date AS `Return Date`,
  b.state AS State
    """

    with driver.session() as session:
        result = session.run(query)
        books = []
        for record in result:
            book = dict(record)
            # Safely convert Date to string
            for key in ["Borrow Date", "Return Date"]:
                if book.get(key) is not None:
                    book[key] = str(book[key])
            # Derive state
            book["State"] = "Borrowed" if book.get("Borrow Date") else "Present"
            books.append(book)
        return jsonify(books)


@app.route('/api/borrow', methods=['POST'])
def borrow_book():
    book_id = request.args.get('book_id', type=int)
    borrower_name = request.args.get('borrower_name', type=str)

    if not book_id or not borrower_name:
        return jsonify({'error': 'Missing parameters'}), 400

    query = """
    MATCH (b:Book {id: $book_id})
    MATCH (m:Member {name: $borrower_name})
    CREATE (m)-[:BORROWED {borrow_date: date()}]->(b)
    SET b.state = 'Borrowed'
    RETURN b.title AS book_title
    """

    print("broo2")
    with driver.session() as session:
        print("broo3")
        result = session.run(query, book_id=book_id, borrower_name=borrower_name)
        record = result.single()

        if not record:
            return jsonify({
                'error': 'Book or member not found, or book already borrowed'
            }), 404

    return jsonify({'status': 'ok'})



@app.route('/api/return', methods=['POST'])
def return_book():
    book_id = request.args.get('book_id', type=int)

    if not book_id:
        return jsonify({'error': 'Missing parameters'}), 400

    query = """
    MATCH (m:Member)-[r:BORROWED]->(b:Book {id: $book_id})
    WHERE r.return_date IS NULL
    SET r.return_date = date(),
        b.state = 'Present'
    RETURN b.title AS book_title
    """

    print("broo2")
    with driver.session() as session:
        print("broo3")
        result = session.run(query, book_id=book_id)
        record = result.single()

        if not record:
            return jsonify({
                'error': 'Book not found or not currently borrowed'
            }), 404

        # Now delete the relationship separately
        delete_query = """
        MATCH (m:Member)-[r:BORROWED]->(b:Book {id: $book_id})
        WHERE r.return_date IS NOT NULL
        DELETE r
        """
        session.run(delete_query, book_id=book_id)

    return jsonify({'status': 'ok'})

@app.route('/api/totalreset', methods=['POST'])
def total_reset():
    query = "MATCH ()-[r:BORROWED]->() DELETE r"
    with driver.session() as session:
        session.run(query)
    return jsonify({'message': 'All borrow records deleted'})


if __name__ == '__main__':
    app.run(debug=True)
