import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const sourceRoot = path.resolve(__dirname, "../cloud-assets/cards/thumbs");
const cardsJsonPath = path.resolve(__dirname, "../src/static/data/cards.json");
const targetRoot = path.resolve(__dirname, "./public/cards/thumbs");

if (!fs.existsSync(sourceRoot)) {
  throw new Error(`Source assets not found: ${sourceRoot}`);
}

if (!fs.existsSync(cardsJsonPath)) {
  throw new Error(`Cards data not found: ${cardsJsonPath}`);
}

fs.rmSync(path.resolve(__dirname, "./public/cards"), { recursive: true, force: true });
fs.mkdirSync(targetRoot, { recursive: true });

const cards = JSON.parse(fs.readFileSync(cardsJsonPath, "utf8"));
let copiedCount = 0;

for (const card of cards) {
  if (!card?.id || !card?.image) {
    continue;
  }

  const relativeThumbPath = card.image
    .replace(/^\/cards\/faces\//, "")
    .replace(/\.png$/i, ".webp");
  const sourceFile = path.join(sourceRoot, relativeThumbPath);
  if (!fs.existsSync(sourceFile)) {
    continue;
  }

  const targetFile = path.join(targetRoot, `${card.id}.webp`);
  fs.copyFileSync(sourceFile, targetFile);
  copiedCount += 1;
}

console.log(`Thumb assets synced to ${targetRoot}`);
console.log(`Copied files: ${copiedCount}`);
