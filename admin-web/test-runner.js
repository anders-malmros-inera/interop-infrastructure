const fetch = require('node-fetch');
const fs = require('fs');

function defaultHeaders() { return { 'Content-Type': 'application/json', Accept: 'application/json' }; }

async function fetchJson(url, opts = {}) {
  try {
    const r = await fetch(url, Object.assign({ timeout: 8000 }, opts));
    const text = await r.text();
    let json = null;
    try { json = text ? JSON.parse(text) : null } catch (e) { json = null }
    return { ok: r.ok, status: r.status, bodyText: text, body: json };
  } catch (e) { return { ok: false, error: e.message }; }
}

async function createApi(base, payload) {
  const url = `${base}/apis`;
  const r = await fetchJson(url, { method: 'POST', headers: defaultHeaders(), body: JSON.stringify(payload) });
  if (!r.ok) return r;
  // Perl returns { id: '...' }, Java returns id string
  let id = null;
  if (r.body && r.body.id) id = r.body.id;
  else if (r.bodyText) id = r.bodyText.replace(/^"|"$/g, '').trim();
  return { ok: true, status: r.status, id: id, raw: r };
}

async function getApi(base, id) { return await fetchJson(`${base}/apis/${id}`, { method: 'GET', headers: defaultHeaders() }); }
async function updateApi(base, id, payload) { return await fetchJson(`${base}/apis/${id}`, { method: 'PUT', headers: defaultHeaders(), body: JSON.stringify(payload) }); }
async function deleteApi(base, id) { return await fetchJson(`${base}/apis/${id}`, { method: 'DELETE', headers: defaultHeaders() }); }

function makePayload(template) {
  const p = JSON.parse(JSON.stringify(template));
  const suffix = Math.random().toString(36).slice(2, 8);
  if (p.url) p.url = p.url.replace(/\bTEST\b/, suffix);
  if (p.signature) p.signature = `${p.signature}-${suffix}`;
  if (p.organization && p.organization.id) p.organization.id = `${p.organization.id}-${suffix}`;
  return p;
}

async function runCrudForService(name, base, isPerl) {
  const results = [];
  const templatePerl = {
    logicalAddress: 'TEST-ADDR', interoperabilitySpecificationId: 'testSpec', apiStandard: 'testStandard',
    url: 'https://example.com/TEST', status: 'active', organization: { id: 'org1', name: 'Org One' },
    accessModel: { type: 'open', metadataUrl: 'https://example.com/meta' }, signature: 'sig-1'
  };
  const templateJava = {
    logicalAddress: 'TEST-ADDR', interoperabilitySpecificationId: 'testSpec', apiStandard: 'testStandard',
    url: 'https://example.com/TEST', status: 'active', organizationId: 'org1', organizationName: 'Org One',
    accessModelType: 'open', accessModelMetadataUrl: 'https://example.com/meta', signature: 'sig-1'
  };
  const payload = isPerl ? makePayload(templatePerl) : makePayload(templateJava);

  const createRes = await createApi(base, payload);
  results.push({ name: `${name}_create`, target: `${base}/apis`, result: createRes, request: payload });
  if (!createRes.ok) return results;

  const id = createRes.id;
  results.push({ name: `${name}_created_id`, result: id });

  const get1 = await getApi(base, id);
  results.push({ name: `${name}_get_after_create`, target: `${base}/apis/${id}`, result: get1 });

  if (isPerl) { payload.status = 'updated'; payload.organization.name = 'Org One Updated'; } else { payload.status = 'updated'; payload.organizationName = 'Org One Updated'; }
  const upd = await updateApi(base, id, payload);
  results.push({ name: `${name}_update`, target: `${base}/apis/${id}`, result: upd, request: payload });

  const get2 = await getApi(base, id);
  results.push({ name: `${name}_get_after_update`, target: `${base}/apis/${id}`, result: get2 });

  const del = await deleteApi(base, id);
  results.push({ name: `${name}_delete`, target: `${base}/apis/${id}`, result: del });

  const get3 = await getApi(base, id);
  results.push({ name: `${name}_get_after_delete`, target: `${base}/apis/${id}`, result: get3 });

  return results;
}

async function runTests() {
  const perlBase = process.env.PERL_API_BASE || 'http://api:5000';
  const javaBase = process.env.JAVA_API_BASE || 'http://java-api:8080';
  const results = [];
  const pingPerl = await fetchJson(`${perlBase}/_ping`, { method: 'GET' }); results.push({ name: 'perl_ping', target: `${perlBase}/_ping`, result: pingPerl });
  const pingJava = await fetchJson(`${javaBase}/_ping`, { method: 'GET' }); results.push({ name: 'java_ping', target: `${javaBase}/_ping`, result: pingJava });
  const perlList = await fetchJson(`${perlBase}/apis?logicalAddress=SE1611&interoperabilitySpecificationId=remissV1`, { method: 'GET' }); results.push({ name: 'perl_list', target: `${perlBase}/apis?logicalAddress=SE1611&interoperabilitySpecificationId=remissV1`, result: perlList });
  const javaList = await fetchJson(`${javaBase}/apis?logicalAddress=SE1611&interoperabilitySpecificationId=remissV1`, { method: 'GET' }); results.push({ name: 'java_list', target: `${javaBase}/apis?logicalAddress=SE1611&interoperabilitySpecificationId=remissV1`, result: javaList });
  const perlCrud = await runCrudForService('perl', perlBase, true); results.push(...perlCrud);
  const javaCrud = await runCrudForService('java', javaBase, false); results.push(...javaCrud);
  return results;
}

function _escapeXml(s) { if (s === null || s === undefined) return ''; return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&apos;'); }

function summarizeResults(results) {
  const summary = { total: 0, passed: 0, failed: 0, details: [] };
  for (const r of results) {
    summary.total += 1;
    const name = r.name || '(unnamed)';
    const res = r.result;
    let pass = false;
    if (!res) pass = false;
    else if (typeof res === 'string') pass = !!res;
    else if (res.error) pass = false;
    else if (name.endsWith('_ping') || name.endsWith('_list')) pass = res.ok && res.status === 200;
    else if (name.endsWith('_create')) pass = res.ok && (res.status === 201 || res.status === 200);
    else if (name.endsWith('_created_id')) pass = !!res;
    else if (name.endsWith('_get_after_delete')) {
      // after delete, a GET should usually return 404 (not found) or 410 (gone).
      // treat 404/410 as success; also accept an OK with empty body.
      if (!res) pass = false;
      else if (res.status === 404 || res.status === 410) pass = true;
      else if (res.ok && (res.status === 200 || res.status === 204)) {
        // consider empty body a success
        if (!res.body && (!res.bodyText || res.bodyText.trim() === '')) pass = true;
        else if (Array.isArray(res.body) && res.body.length === 0) pass = true;
        else pass = false;
      } else pass = false;
    }
    else if (name.includes('_get_') || name.match(/_get_after_?/)) pass = res.ok && res.status === 200;
    else if (name.endsWith('_update')) pass = res.ok && (res.status === 200 || res.status === 204);
    else if (name.endsWith('_delete')) pass = res.ok && (res.status === 204 || res.status === 200);
    else pass = !!res.ok;
    if (pass) summary.passed += 1; else summary.failed += 1;
    summary.details.push({ name, pass, status: res && res.status, bodyText: res && res.bodyText, error: res && res.error });
  }
  return summary;
}

function buildJUnitXml(results, suiteName = 'interop-admin-tests') {
  const summary = summarizeResults(results);
  const tests = summary.total;
  const failures = summary.failed;
  let xml = `<?xml version="1.0" encoding="UTF-8"?>\n<testsuite name="${_escapeXml(suiteName)}" tests="${tests}" failures="${failures}">\n`;
  for (const d of summary.details) {
    xml += `  <testcase classname="${_escapeXml(suiteName)}" name="${_escapeXml(d.name)}">\n`;
    if (!d.pass) {
      const msg = d.error || d.bodyText || `status=${d.status}`;
      xml += `    <failure message="${_escapeXml(msg)}">${_escapeXml(msg)}</failure>\n`;
    }
    const so = (d.bodyText && d.bodyText.length > 0) ? d.bodyText : '';
    if (so) xml += `    <system-out>${_escapeXml(so)}</system-out>\n`;
    xml += `  </testcase>\n`;
  }
  xml += `</testsuite>\n`;
  return xml;
}

async function runTestsWithOutput(options = {}) {
  const results = await runTests();
  const summary = summarizeResults(results);
  if (options && options.junitPath) {
    try {
      const xml = buildJUnitXml(results);
      fs.writeFileSync(options.junitPath, xml, 'utf8');
      return { results, summary, junitPath: options.junitPath };
    } catch (e) {
      return { results, summary, junitError: String(e) };
    }
  }
  return { results, summary };
}

module.exports = { runTests, runTestsWithOutput };

if (require.main === module) {
  runTests().then(r => {
    console.log(JSON.stringify(r, null, 2));
    process.exit(0);
  }).catch(e => {
    console.error(e);
    process.exit(2);
  });
}
