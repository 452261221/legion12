import express from "express";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const port = Number(process.env.PORT || 80);
const assetsRoot = path.resolve(__dirname, "public");

// Serve card assets under the same /cards path used by the mini-app.
app.use("/cards", express.static(path.join(assetsRoot, "cards"), {
  fallthrough: false,
  maxAge: "30d"
}));

app.get("/healthz", (_req, res) => {
  res.json({
    ok: true,
    service: "legion-card-assets-server"
  });
});

app.get("/", (_req, res) => {
  res.type("text/plain; charset=utf-8").send("legion-card-assets-server is running");
});

app.use((err, _req, res, _next) => {
  if (err?.status === 404) {
    res.status(404).json({ ok: false, message: "Not found" });
    return;
  }
  res.status(500).json({ ok: false, message: "Internal server error" });
});

app.listen(port, "0.0.0.0", () => {
  console.log(`legion-card-assets-server listening on ${port}`);
});
