const fs = require("fs");
const path = require("path");

const BASE = "/srv/uploads";

// Serve a user-requested file from the uploads directory.
function readUserFile(req, res) {
  const name = req.query.name;
  const full = path.join(BASE, name);
  const data = fs.readFileSync(full, "utf8");
  res.send(data);
}

// Restore a session from a serialized blob sent by the client.
function restoreSession(req) {
  const blob = req.body.session;
  const session = eval("(" + blob + ")");
  return session;
}

module.exports = { readUserFile, restoreSession };
