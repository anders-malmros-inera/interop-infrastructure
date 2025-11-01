const express = require('express');
const path = require('path');
const { runTests, runTestsWithOutput } = require('./test-runner');
const fs = require('fs');
const marked = require('marked');

const app = express();
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

app.get('/api/run-tests', async (req, res) => {
  try {
    // If ?junit=1 is provided, write a JUnit XML to disk and return the path
    const wantJUnit = req.query.junit === '1' || req.query.junit === 'true';
    if (wantJUnit) {
      const junitPath = path.join(__dirname, 'test-results.xml');
      const out = await runTestsWithOutput({ junitPath });
      return res.json({ ok: true, results: out.results, summary: out.summary, junitPath: out.junitPath, junitError: out.junitError });
    }
    // Always return summarized results to the GUI
    const out = await runTestsWithOutput();
    res.json({ ok: true, results: out.results, summary: out.summary });
  } catch (e) {
    res.status(500).json({ ok: false, error: e.message });
  }
});

app.get('/api/status', (req, res) => {
  res.json({ ok: true, now: new Date().toISOString() });
});

// Serve README.md rendered as HTML
// Return a JSON list of available README sources (base + sibling folders that contain README.md)
app.get('/api/readmes', (req, res) => {
  try {
    const baseDir = path.join(__dirname);
    const repoRoot = path.join(__dirname, '..');
    const items = [];
  // prefer repository root README as the base/root README
  const repoRootReadme = path.join(repoRoot, 'README.md');
  if (fs.existsSync(repoRootReadme)) items.push({ id: 'root', name: 'Repository (interop-infrastructure)', path: repoRootReadme, filename: 'README.md' });

    // scan sibling folders under repo root for README-like files (README*.md)
    const entries = fs.readdirSync(repoRoot, { withFileTypes: true });
    for (const e of entries) {
      if (!e.isDirectory()) continue;
      try {
        const files = fs.readdirSync(path.join(repoRoot, e.name));
        const readmeFile = files.find(f => /^README.*\.md$/i.test(f));
        if (readmeFile) {
          items.push({ id: e.name, name: e.name, path: path.join(repoRoot, e.name, readmeFile), filename: readmeFile });
        }
      } catch (ex) {
        // ignore unreadable directories
      }
    }
  // sort with repo root first then alphabetical
  items.sort((a, b) => (a.id === 'root' ? -1 : b.id === 'root' ? 1 : a.name.localeCompare(b.name)));
  res.json({ ok: true, items: items.map(it => ({ id: it.id, name: it.name, file: it.filename || 'README.md' })) });
  } catch (err) {
    res.status(500).json({ ok: false, error: err.message });
  }
});

// Serve README.md rendered as HTML. Use ?container=<id> where id is 'base' or a sibling folder name.
app.get('/readme', (req, res) => {
  try {
    const container = req.query.container || 'root';
    const repoRoot = path.join(__dirname, '..');
    let target = null;
    if (container === 'root') {
      const p = path.join(repoRoot, 'README.md');
      if (fs.existsSync(p)) target = p;
    } else {
      // find any README*.md in the target folder
      try {
        const dir = path.join(repoRoot, container);
        const files = fs.readdirSync(dir);
        const readmeFile = files.find(f => /^README.*\.md$/i.test(f));
        if (readmeFile) target = path.join(dir, readmeFile);
      } catch (ex) {
        // ignore
      }
    }
    if (!target) return res.status(404).send('README.md not found for container: ' + container);
    const md = fs.readFileSync(target, 'utf8');
    let html = marked.parse(md || '');

  // discover other README items so we can rewrite links to point at the container endpoint
  const items = [];
    try {
      const repoRootReadme = path.join(repoRoot, 'README.md');
      if (fs.existsSync(repoRootReadme)) items.push({ id: 'root', name: 'root', path: repoRootReadme, filename: 'README.md' });
      const entries = fs.readdirSync(repoRoot, { withFileTypes: true });
      for (const e of entries) {
        if (!e.isDirectory()) continue;
        try {
          const files = fs.readdirSync(path.join(repoRoot, e.name));
          const readmeFile = files.find(f => /^README.*\.md$/i.test(f));
          if (readmeFile) items.push({ id: e.name, name: e.name, path: path.join(repoRoot, e.name, readmeFile), filename: readmeFile });
        } catch (ex) {}
      }
    } catch (ex) {}

    // create quick lookup by filename (case-insensitive) and by folder
    const filenameMap = new Map();
    const folderMap = new Map();
    for (const it of items) {
      filenameMap.set(it.filename.toLowerCase(), it);
      folderMap.set(it.id.toLowerCase(), it);
    }

    // Rewrite anchor hrefs that point to README files so they open the admin-web /readme?container=... endpoint
    // Preserve fragments (anchors) and query parts
    html = html.replace(/<a\s+([^>]*?)href=("|')([^"']+)("|')([^>]*)>/gi, (m, before, q1, href, q2, after) => {
      try {
        // leave external and anchor-only links unchanged
        if (href.startsWith('http://') || href.startsWith('https://') || href.startsWith('mailto:') || href.startsWith('#')) return m;
        // separate fragment and query
        const fragIndex = href.indexOf('#');
        const frag = fragIndex >= 0 ? href.substring(fragIndex) : '';
        const hrefNoFrag = fragIndex >= 0 ? href.substring(0, fragIndex) : href;
        const cleanHref = hrefNoFrag.split('?')[0];
        const base = path.basename(cleanHref).toLowerCase();
        if (/^readme.*\.md$/i.test(base)) {
          // prefer folder-based resolution when the href contains a folder path
          const parts = cleanHref.split('/').filter(Boolean);
          if (parts.length > 1) {
            const folder = parts[0].toLowerCase();
            const matchByFolder = folderMap.get(folder);
            if (matchByFolder) return `<a ${before}href="/readme?container=${encodeURIComponent(matchByFolder.id)}${frag}" ${after}>`;
          }
          // fallback to filename match (common README.md)
          const matchByFile = filenameMap.get(base);
          if (matchByFile) {
            return `<a ${before}href="/readme?container=${encodeURIComponent(matchByFile.id)}${frag}" ${after}>`;
          }
        }
      } catch (e) {
        // fallthrough: return original
      }
      return m;
    });

    // lightweight markdown styling (github-like) with stronger color/background defaults
    const mdStyles = `
      :root{--bg:#fff;--muted:#6c757d}
      .markdown-body{font-family: Inter,Segoe UI,Helvetica,Arial,sans-serif;line-height:1.6;color:#24292e;background:var(--bg);padding:1rem;max-width:980px;margin:auto}
      /* enforce readable text color for arbitrary embedded HTML */
      .markdown-body :not(pre):not(code) { color: #24292e !important; background: transparent !important }
      .markdown-body h1{font-size:1.6rem;margin:1rem 0}
      .markdown-body h2{font-size:1.35rem;margin:.85rem 0}
      .markdown-body h3{font-size:1.15rem;margin:.75rem 0}
      .markdown-body p{margin:.5rem 0}
      .markdown-body a{color:#0366d6}
      .markdown-body pre{background:#0f1720;color:#e6eef8;padding:.75rem;border-radius:6px;overflow:auto}
      .markdown-body code{background:#f6f8fa;padding:.15rem .3rem;border-radius:6px;color:#111}
      .markdown-body blockquote{color:var(--muted);border-left:4px solid #e6eef8;padding-left:1rem;margin:0.5rem 0}
      .markdown-body ul, .markdown-body ol{margin:0.5rem 0 0.5rem 1.25rem}
      .markdown-body table{border-collapse:collapse;width:100%;margin:0.5rem 0}
      .markdown-body table th, .markdown-body table td{border:1px solid #e1e4e8;padding:.35rem .5rem}
      `;
    return res.send(`<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>README - ${container}</title><style>${mdStyles}</style></head><body><a class="back" href="/">← Back</a><hr/><div class="markdown-body">${html}</div></body></html>`);
  } catch (e) {
    res.status(500).send('Failed to render README: ' + e.message);
  }
});

const port = process.env.PORT || 3000;
app.listen(port, () => console.log(`Admin web listening on :${port}`));
