import pytest
from app.main import app
@pytest.fixture
def client():
    app.config['TESTING'] = True
    with app.test_client() as client: yield client
def test_home(client):
    rv = client.get('/'); assert rv.status_code == 200; assert b"Hello" in rv.data
def test_health_check(client):
    rv = client.get('/api/health'); assert rv.status_code == 200; assert rv.get_json()['status'] == 'ok'