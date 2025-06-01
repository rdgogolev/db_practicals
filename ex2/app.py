from flask import Flask, jsonify, render_template, request
from datetime import date
import logging
from flask_sqlalchemy import SQLAlchemy
from flask_cors import CORS

app = Flask(__name__, static_url_path='/static', static_folder='static')
CORS(app)
logging.basicConfig(level=logging.DEBUG)

app.config['SQLALCHEMY_DATABASE_URI'] = 'postgresql://postgres:qwerty@localhost:5432/library_db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

db = SQLAlchemy(app)

class Author(db.Model):
    __tablename__ = 'author'
    author_id = db.Column(db.Integer, primary_key=True)
    name      = db.Column(db.String, nullable=False, unique=True)
    books     = db.relationship('Book', back_populates='author')

class Publisher(db.Model):
    __tablename__ = 'publisher'
    publisher_id = db.Column(db.Integer, primary_key=True)
    name         = db.Column(db.String, nullable=False, unique=True)
    books        = db.relationship('Book', back_populates='publisher')

class Genre(db.Model):
    __tablename__ = 'genre'
    genre_id = db.Column(db.Integer, primary_key=True)
    name     = db.Column(db.String, nullable=False, unique=True)
    books    = db.relationship('Book', back_populates='genre')

class Book(db.Model):
    __tablename__ = 'book'
    book_id      = db.Column(db.Integer, primary_key=True)
    title        = db.Column(db.String, nullable=False)
    author_id    = db.Column(db.Integer, db.ForeignKey('author.author_id'),   nullable=False)
    publisher_id = db.Column(db.Integer, db.ForeignKey('publisher.publisher_id'), nullable=False)
    genre_id     = db.Column(db.Integer, db.ForeignKey('genre.genre_id'),     nullable=False)
    state        = db.Column(db.String, nullable=False, default='Present')

    author    = db.relationship('Author',    back_populates='books',    lazy='joined')
    publisher = db.relationship('Publisher', back_populates='books',    lazy='joined')
    genre     = db.relationship('Genre',     back_populates='books',    lazy='joined')


class Borrow(db.Model):
    __tablename__ = 'borrow'
    borrow_id     = db.Column(db.Integer, primary_key=True)
    book_id       = db.Column(db.Integer, db.ForeignKey('book.book_id'), nullable=False)
    borrower_name = db.Column(db.String,  nullable=False)
    borrow_date   = db.Column(db.Date,    nullable=False)
    return_date   = db.Column(db.Date)

    book = db.relationship('Book', lazy='joined')

@app.route('/')
def home():
    return render_template('index.html')

@app.route('/viewer.html')
def viewer():
    return render_template('viewer.html')

@app.route('/api/list')
def list_books():
    """
    Returns a list of all books with their author/publisher/genre names
    and any active borrow record.
    """
    rows = (
        db.session.query(
            Book.book_id        .label('Book ID'),
            Book.title          .label('Title'),
            Author.name         .label('Author'),
            Publisher.name      .label('Publisher'),
            Genre.name          .label('Genre'),
            Borrow.borrower_name.label('Borrower'),
            Borrow.borrow_date  .label('Borrow Date'),
            Borrow.return_date  .label('Return Date'),
            Book.state          .label('State')
        )
        .outerjoin(Author,    Book.author_id    == Author.author_id)
        .outerjoin(Publisher, Book.publisher_id == Publisher.publisher_id)
        .outerjoin(Genre,     Book.genre_id     == Genre.genre_id)
        .outerjoin(Borrow,    (Book.book_id      == Borrow.book_id) & (Borrow.return_date == None))
        .all()
    )

    result = []
    for r in rows:
        d = r._asdict()
        d['State'] = 'Borrowed' if d['Borrow Date'] else 'Present'
        result.append(d)
    return jsonify(result)

@app.route('/api/borrow', methods=['POST'])
def borrow_book():
    book_id       = request.args.get('book_id',       type=int)
    borrower_name = request.args.get('borrower_name', type=str)

    if not book_id or not borrower_name:
        return jsonify({'error': 'missing parameters'}), 400

    borrow = Borrow(
        book_id       = book_id,
        borrower_name = borrower_name,
        borrow_date   = date.today(),
        return_date   = None
    )
    db.session.add(borrow)
    db.session.commit()
    return jsonify({'status': 'ok'})

@app.route('/api/return', methods=['POST'])
def return_book():
    book_id = request.args.get('book_id', type=int)
    if not book_id:
        return jsonify({'error': 'missing book_id'}), 400

    record = Borrow.query.filter_by(book_id=book_id, return_date=None).first()
    if record:
        record.return_date = date.today()
        db.session.commit()
    return jsonify({'status': 'ok'})

@app.route('/api/totalreset', methods=['POST'])
def total_reset():
    Borrow.query.delete()
    db.session.commit()
    return jsonify({'message': 'All borrowing data cleared.'})

if __name__ == '__main__':
    app.run(debug=True)
