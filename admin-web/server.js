const express = require('express');
const path = require('path');
const { runTests, runTestsWithOutput } = require('./test-runner');
const fs = require('fs');
const marked = require('marked');
const fetch = require('node-fetch');

const app = express();
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));
// Serve the repository's openapi directory under /openapi so the admin UI can embed API docs
app.use('/openapi', express.static(path.join(__dirname, '..', 'openapi')));

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

// Health-check: verify Kong has the federation route and federation DB/table responds
app.get('/api/health-check', async (req, res) => {
  try {
    const kongAdmin = process.env.KONG_ADMIN_BASE || 'http://kong:8001';
    const fedBase = process.env.FED_API_BASE || 'http://kong:8000/federation';

    const result = { ok: true, checks: {} };

    // Check Kong routes for /federation
    try {
      const r = await fetch(kongAdmin + '/routes');
      const j = await r.json();
      const hasFed = Array.isArray(j.data) && j.data.some(rt => Array.isArray(rt.paths) && rt.paths.includes('/federation'));
      result.checks.kong_route = { ok: !!hasFed, info: hasFed ? 'federation route present' : 'federation route not found' };
      if (!hasFed) result.ok = false;
    } catch (e) {
      result.checks.kong_route = { ok: false, error: e.message };
      result.ok = false;
    }

    // Check federation ping via configured FED_API_BASE
    try {
      const r2 = await fetch(fedBase + '/_ping', { timeout: 5000 });
      const body = await r2.text();
      result.checks.federation_ping = { ok: r2.status === 200, status: r2.status, body: body };
      if (r2.status !== 200) result.ok = false;
    } catch (e) {
      result.checks.federation_ping = { ok: false, error: e.message };
      result.ok = false;
    }

    // Check federation members endpoint (table existance and access)
    try {
      const r3 = await fetch(fedBase + '/members', { timeout: 5000 });
      const txt = await r3.text();
      result.checks.federation_members = { ok: r3.status === 200, status: r3.status, body: txt };
      if (r3.status !== 200) result.ok = false;
    } catch (e) {
      result.checks.federation_members = { ok: false, error: e.message };
      result.ok = false;
    }

    res.json(result);
  } catch (e) {
    res.status(500).json({ ok: false, error: e.message });
  }
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

// List available OpenAPI HTML pages from the repository openapi/ directory
app.get('/api/apis', (req, res) => {
  try {
    // Only expose the curated APIs: Service catalog and Federation
    const items = [
      { id: 'service-catalog', name: 'Service catalog', file: 'service-catalog-api.html', url: '/openapi/service-catalog-api.html' },
      { id: 'federation', name: 'Federation membership', file: 'federation-membership-api.html', url: '/openapi/federation-membership-api.html' }
    ];
    res.json({ ok: true, items });
  } catch (e) {
    res.status(500).json({ ok: false, error: e.message });
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

    // Rewrite image src attributes so images referenced relatively in READMEs are served through
    // the /readme/resource endpoint which will fetch files from the repository for the active container.
    // This handles image links like ./docs/images/info-model.svg or docs/images/...
    html = html.replace(/<img\s+([^>]*?)src=("|')([^"']+)("|')([^>]*)>/gi, (m, before, q1, src, q2, after) => {
      try {
        // leave external/data URIs alone
        if (src.startsWith('http://') || src.startsWith('https://') || src.startsWith('data:') || src.startsWith('//')) return m;
        // normalize relative paths (preserve the raw path for the resource endpoint)
        const clean = src.replace(/^\.\/+/,'').replace(/^\//,'');
        // construct resource URL pointing back to this server
        const resourceUrl = `/readme/resource?container=${encodeURIComponent(container)}&path=${encodeURIComponent(clean)}`;
        return `<img ${before}src="${resourceUrl}" ${after}>`;
      } catch (e) {
        return m;
      }
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

// Serve repository resources referenced from READMEs. Query parameters:
//   container=root|<folder>  and path=<relative/path/inside/container>
app.get('/readme/resource', (req, res) => {
  try {
    const container = req.query.container || 'root';
    const relPath = req.query.path || '';
    if (!relPath) return res.status(400).send('path query parameter required');
    // disallow traversal
    if (relPath.indexOf('..') >= 0) return res.status(400).send('invalid path');
    const repoRoot = path.join(__dirname, '..');
    let fullPath = null;
    if (container === 'root') {
      fullPath = path.join(repoRoot, relPath);
    } else {
      fullPath = path.join(repoRoot, container, relPath);
    }
    // verify the resolved path is inside the repo
    const normRoot = path.resolve(repoRoot) + path.sep;
    const normFull = path.resolve(fullPath);
    if (!normFull.startsWith(normRoot)) return res.status(400).send('invalid path');
    if (!fs.existsSync(normFull)) return res.status(404).send('resource not found');
    return res.sendFile(normFull);
  } catch (e) {
    return res.status(500).send('failed to serve resource: ' + e.message);
  }
});

const port = process.env.PORT || 3000;
app.listen(port, () => console.log(`Admin web listening on :${port}`));
