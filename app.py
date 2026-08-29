import os
from flask import Flask, jsonify

app = Flask(__name__)
app.config["SERVICE_NAME"] = os.getenv("SERVICE_NAME", "simple-app")
app.config["COMMIT"] = os.getenv("COMMIT", None)
app.config["REGION"] = os.getenv("REGION", "eu-west-1")


@app.get("/healthz")
def healthz():
    return jsonify(
        service=app.config["SERVICE_NAME"],
        status="ok",
        commit=app.config["COMMIT"],
        region=app.config["REGION"],
    )


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
