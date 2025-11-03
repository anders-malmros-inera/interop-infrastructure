const path = require('path');
const t = require('../admin-web/test-runner');

async function main() {
  // Default to ports that refuse quickly when local services are not running
  process.env.PERL_API_BASE = process.env.PERL_API_BASE || 'http://127.0.0.1:1';
  process.env.JAVA_API_BASE = process.env.JAVA_API_BASE || 'http://127.0.0.1:1';
  process.env.FED_API_BASE = process.env.FED_API_BASE || 'http://127.0.0.1:1';
  const junitPath = path.join(__dirname, 'test-results', 'junit-admin-runner.xml');
  try {
    const res = await t.runTestsWithOutput({ junitPath });
    console.log('SUMMARY:');
    console.log(JSON.stringify(res.summary, null, 2));
    if (res.junitPath) console.log('JUnit written to', res.junitPath);
    process.exit(0);
  } catch (e) {
    console.error('Test run failed:', e);
    process.exit(2);
  }
}

main();
