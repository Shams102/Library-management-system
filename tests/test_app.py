"""
Automated Tests for the Library Management System.

Uses an isolated temporary database so the real application data is never affected.
Run with:  pytest tests/ -v
"""

import os
import sys
import tempfile
import pytest

# Ensure the project root is on the Python path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from app import create_app


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def app():
    """Create the application with a temporary test database."""
    db_fd, db_path = tempfile.mkstemp(suffix=".db")
    test_app = create_app({
        "TESTING": True,
        "DATABASE": db_path,
        "SECRET_KEY": "test-secret",
    })

    yield test_app

    # Cleanup – close the file descriptor and remove the temp DB
    os.close(db_fd)
    os.unlink(db_path)


@pytest.fixture
def client(app):
    """Flask test client."""
    return app.test_client()


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

class TestHomePage:
    """Tests for the home page (GET /)."""

    def test_home_page_loads(self, client):
        """The home page should return HTTP 200."""
        response = client.get("/")
        assert response.status_code == 200

    def test_home_page_contains_title(self, client):
        """The page should contain the application title."""
        response = client.get("/")
        assert b"Library Management System" in response.data

    def test_home_page_shows_seeded_books(self, client):
        """Sample books should appear after the first run."""
        response = client.get("/")
        assert b"The Pragmatic Programmer" in response.data
        assert b"Clean Code" in response.data


class TestAddBook:
    """Tests for adding books (POST /add)."""

    def test_add_book_success(self, client):
        """Adding a valid book should redirect and show a success flash."""
        response = client.post("/add", data={
            "title": "Test Book",
            "author": "Test Author",
            "isbn": "111-1111111111",
        }, follow_redirects=True)
        assert response.status_code == 200
        assert b"Test Book" in response.data
        assert b"has been added" in response.data

    def test_add_book_displays_in_list(self, client):
        """A newly added book should appear in the book list."""
        client.post("/add", data={
            "title": "New Book",
            "author": "New Author",
            "isbn": "222-2222222222",
        })
        response = client.get("/")
        assert b"New Book" in response.data
        assert b"New Author" in response.data


class TestValidation:
    """Tests for form validation."""

    def test_missing_title(self, client):
        """Submitting without a title should show an error."""
        response = client.post("/add", data={
            "title": "",
            "author": "Author",
            "isbn": "333-3333333333",
        }, follow_redirects=True)
        assert b"required" in response.data

    def test_missing_author(self, client):
        """Submitting without an author should show an error."""
        response = client.post("/add", data={
            "title": "Title",
            "author": "",
            "isbn": "444-4444444444",
        }, follow_redirects=True)
        assert b"required" in response.data

    def test_missing_isbn(self, client):
        """Submitting without an ISBN should show an error."""
        response = client.post("/add", data={
            "title": "Title",
            "author": "Author",
            "isbn": "",
        }, follow_redirects=True)
        assert b"required" in response.data

    def test_duplicate_isbn_rejected(self, client):
        """Adding two books with the same ISBN should fail."""
        client.post("/add", data={
            "title": "First",
            "author": "Author",
            "isbn": "555-5555555555",
        })
        response = client.post("/add", data={
            "title": "Second",
            "author": "Author",
            "isbn": "555-5555555555",
        }, follow_redirects=True)
        assert b"already exists" in response.data


class TestDeleteBook:
    """Tests for deleting books (POST /delete/<id>)."""

    def test_delete_book(self, client):
        """Deleting a book should remove it from the list."""
        # The seeded books start at id 1
        response = client.post("/delete/1", follow_redirects=True)
        assert response.status_code == 200
        assert b"has been removed" in response.data

    def test_delete_nonexistent_book(self, client):
        """Deleting a non-existent book should show an error."""
        response = client.post("/delete/9999", follow_redirects=True)
        assert b"not found" in response.data


class TestHealthEndpoint:
    """Tests for the /health endpoint."""

    def test_health_returns_200(self, client):
        """The health endpoint should return HTTP 200."""
        response = client.get("/health")
        assert response.status_code == 200

    def test_health_returns_json(self, client):
        """The health response should contain a status field."""
        response = client.get("/health")
        data = response.get_json()
        assert data["status"] == "healthy"
        assert data["service"] == "library-management"
