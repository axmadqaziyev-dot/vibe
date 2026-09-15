// Read-only inspection; never prints access tokens or user records.
const fs = require('fs');
const base = 'C:/Users/user/AppData/Roaming/npm/node_modules/firebase-tools/lib/';
(async () => {
  const account = require(base + 'auth').getGlobalDefaultAccount();
  if (!account) throw Error('Firebase login required');
  await require(base + 'requireAuth').requireAuth({project: 'vibe-f9d13', ...account});
  const {Client} = require(base + 'apiv2');
  const client = new Client({urlPrefix: 'https://storage.googleapis.com'});
  try {
    const result = await client.get('/storage/v1/b/vibe-f9d13.firebasestorage.app');
    console.log('Bucket:', JSON.stringify({name: result.body.name, cors: result.body.cors}));
  } catch (e) { console.log('Bucket check:', e.message); }
  const rules = require(base + 'gcp/rules');
  const releases = await rules.listAllReleases('vibe-f9d13');
  const saved = [];
  for (const release of releases.filter(r => /cloud.firestore$|firebase.storage/.test(r.name))) {
    const files = await rules.getRulesetContent(release.rulesetName);
    saved.push({release, files});
    console.log('Release:', release.name);
    for (const file of files) console.log(file.name + '\n' + file.content);
  }
  fs.writeFileSync('voice.rules.backup.json', JSON.stringify(saved, null, 2));
})().catch(e => { console.error(e.message); process.exitCode = 1; });

