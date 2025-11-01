const express = require('express');
const path = require('path');
const { runTests, runTestsWithOutput } = require('./test-runner');

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
    const results = await runTests();
    const summary = null;
    res.json({ ok: true, results, summary });
  } catch (e) {
    res.status(500).json({ ok: false, error: e.message });
  }
});

app.get('/api/status', (req, res) => {
  res.json({ ok: true, now: new Date().toISOString() });
});

const port = process.env.PORT || 3000;
app.listen(port, () => console.log(`Admin web listening on :${port}`));
