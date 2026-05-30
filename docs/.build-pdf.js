// One-off MD→HTML converter for PROJECT_OVERVIEW_FOR_STAKEHOLDER.md.
// Renders to a self-contained styled HTML file; Chrome headless then
// turns that HTML into the final PDF (see .build-pdf.ps1).
//
// Uses only `marked` (small, no Chromium download). All styling is
// pulled inline from .pdf-style.css so the resulting HTML can be opened
// standalone in any browser to preview before generating the PDF.

const fs = require('fs');
const path = require('path');
const { marked } = require('marked');

const MD_FILE  = path.join(__dirname, 'PROJECT_OVERVIEW_FOR_STAKEHOLDER.md');
const CSS_FILE = path.join(__dirname, '.pdf-style.css');
const OUT_FILE = path.join(__dirname, '.stakeholder-doc.html');

marked.setOptions({
  gfm: true,
  breaks: false,
  headerIds: true,
  mangle: false,
});

const md  = fs.readFileSync(MD_FILE, 'utf8');
const css = fs.readFileSync(CSS_FILE, 'utf8');
let html  = marked.parse(md);

// Strip the trailing "Document maintained by..." line — it's an internal
// note, not stakeholder-facing.
html = html.replace(/<p><em>Document maintained.*?<\/em><\/p>\s*$/i, '');

const out = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>AshaMitra — Stakeholder Briefing</title>
  <style>${css}</style>
</head>
<body>
${html}
</body>
</html>`;

fs.writeFileSync(OUT_FILE, out, 'utf8');
console.log('Wrote', OUT_FILE, `(${(out.length/1024).toFixed(1)} KB)`);
