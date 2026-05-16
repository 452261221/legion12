import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { execFileSync } from "node:child_process";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const projectRoot = path.resolve(__dirname, "..");
const zipPath = path.join(projectRoot, "cloud-hosting-deploy.zip");
const sourceRoot = __dirname;
const includeItems = ["Dockerfile", "package.json", "server.js", "README.md", "public"];

if (fs.existsSync(zipPath)) {
  fs.rmSync(zipPath, { force: true });
}

const pythonScript = `
import os, zipfile
src = r"""${sourceRoot}"""
zip_path = r"""${zipPath}"""
items = ${JSON.stringify(includeItems)}
with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_STORED, allowZip64=True) as zf:
    for item in items:
        full = os.path.join(src, item)
        if os.path.isdir(full):
            for root, _, files in os.walk(full):
                for name in sorted(files):
                    fpath = os.path.join(root, name)
                    arc = os.path.relpath(fpath, src).replace("\\\\", "/")
                    zf.write(fpath, arc)
        else:
            zf.write(full, item)
with zipfile.ZipFile(zip_path) as zf:
    thumbs = [n for n in zf.namelist() if n.startswith("public/cards/thumbs/") and n.endswith(".webp")]
    print("ZIP_COUNT", len(thumbs))
    print("ZIP_TEST", zf.testzip())
`.trim();

execFileSync("python", ["-c", pythonScript], {
  stdio: "inherit",
  cwd: projectRoot
});

const stat = fs.statSync(zipPath);
console.log(`Created ${zipPath}`);
console.log(`Size: ${(stat.size / 1024 / 1024).toFixed(2)} MB`);
