"""
Library Management System - Flask Web Application
A simple CRUD application for managing books in a library.
Uses SQLite for persistent storage.
"""

import os
import sqlite3
from flask import Flask, render_template, request, redirect, url_for, flash, jsonify

# ---------------------------------------------------------------------------
# Application Factory & Configuration
# ---------------------------------------------------------------------------

def create_app(test_config=None):
    """Application factory pattern for Flask."""
    app = Flask(__name__)

    # Default configuration
    app.config["SECRET_KEY"] = os.environ.get("SECRET_KEY", "dev-secret-key")
    app.config["DATABASE"] = os.environ.get("DATABASE_PATH", os.path.join(app.instance_path, "library.db"))

    # Override with test configuration if provided
    if test_config:
        app.config.update(test_config)

    # Ensure the directory for the database exists
    db_dir = os.path.dirname(app.config["DATABASE"])
    if db_dir:
        os.makedirs(db_dir, exist_ok=True)

    # Initialise the database on first request
    init_db(app)

    # -----------------------------------------------------------------------
    # Routes
    # -----------------------------------------------------------------------

    @app.route("/")
    def index():
        """Home page – display all books."""
        books = query_db(app, "SELECT * FROM books ORDER BY id DESC")
        return render_template("index.html", books=books)

    @app.route("/add", methods=["POST"])
    def add_book():
        """Add a new book to the library."""
        title = request.form.get("title", "").strip()
        author = request.form.get("author", "").strip()
        isbn = request.form.get("isbn", "").strip()

        # --- Validation ---
        if not title or not author or not isbn:
            flash("All fields (Title, Author, ISBN) are required.", "error")
            return redirect(url_for("index"))

        # Check for duplicate ISBN
        existing = query_db(app, "SELECT id FROM books WHERE isbn = ?", (isbn,), one=True)
        if existing:
            flash(f"A book with ISBN '{isbn}' already exists.", "error")
            return redirect(url_for("index"))

        # Insert the book
        execute_db(app, "INSERT INTO books (title, author, isbn) VALUES (?, ?, ?)",
                   (title, author, isbn))
        flash(f"'{title}' has been added to the library.", "success")
        return redirect(url_for("index"))

    @app.route("/delete/<int:book_id>", methods=["POST"])
    def delete_book(book_id):
        """Delete a book by its ID."""
        book = query_db(app, "SELECT * FROM books WHERE id = ?", (book_id,), one=True)
        if book is None:
            flash("Book not found.", "error")
        else:
            execute_db(app, "DELETE FROM books WHERE id = ?", (book_id,))
            flash(f"'{book['title']}' has been removed from the library.", "success")
        return redirect(url_for("index"))

    @app.route("/health")
    def health():
        """Health-check endpoint – returns HTTP 200 with JSON body."""
        return jsonify({"status": "healthy", "service": "library-management"}), 200

    return app


# ---------------------------------------------------------------------------
# Database Helpers
# ---------------------------------------------------------------------------

def get_db(app):
    """Open a new database connection."""
    conn = sqlite3.connect(app.config["DATABASE"])
    conn.row_factory = sqlite3.Row  # Access columns by name
    return conn


def query_db(app, query, args=(), one=False):
    """Execute a SELECT query and return results."""
    conn = get_db(app)
    try:
        cur = conn.execute(query, args)
        rows = cur.fetchall()
        return (rows[0] if rows else None) if one else rows
    finally:
        conn.close()


def execute_db(app, query, args=()):
    """Execute an INSERT / UPDATE / DELETE query."""
    conn = get_db(app)
    try:
        conn.execute(query, args)
        conn.commit()
    finally:
        conn.close()


def init_db(app):
    """Create the books table and seed sample data (only on the first run)."""
    conn = get_db(app)
    try:
        conn.execute("""
            CREATE TABLE IF NOT EXISTS books (
                id    INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT    NOT NULL,
                author TEXT   NOT NULL,
                isbn  TEXT    NOT NULL UNIQUE
            )
        """)
        conn.commit()

        # Seed sample books only if the table is empty
        count = conn.execute("SELECT COUNT(*) FROM books").fetchone()[0]
        if count == 0:
            sample_books = [
                ("The Pragmatic Programmer", "David Thomas & Andrew Hunt", "978-0135957059"),
                ("Clean Code", "Robert C. Martin", "978-0132350884"),
                ("Design Patterns", "Gang of Four", "978-0201633610"),
            ]
            conn.executemany(
                "INSERT INTO books (title, author, isbn) VALUES (?, ?, ?)",
                sample_books,
            )
            conn.commit()
    finally:
        conn.close()


# ---------------------------------------------------------------------------
# Entry Point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    application = create_app()
    application.run(host="0.0.0.0", port=5000, debug=False)
