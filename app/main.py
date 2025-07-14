from flask import Flask, jsonify
app = Flask(__name__)
@app.route('/')
def home(): return "Hello from your containerized app!"
@app.route('/api/health')
def health_check(): return jsonify({"status": "ok"}), 200
if __name__ == '__main__': app.run(host='0.0.0.0', port=8080)