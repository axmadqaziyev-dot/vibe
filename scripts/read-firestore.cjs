const fs = require('fs');
const base = 'C:/Users/user/AppData/Roaming/npm/node_modules/firebase-tools/lib/';
const auth = require(base + 'auth');
const rules = require(base + 'gcp/rules');
(async () => {
 const account = auth.getGlobalDefaultAccount();
 if (!account) throw new Error('Firebase login required');
 await require(base + 'requireAuth').requireAuth({project:'vibe-f9d13', ...account});
 const releases = await rules.listAllReleases('vibe-f9d13');
 const release = releases.find(r => r.name === 'projects/vibe-f9d13/releases/cloud.firestore');
 if (!release) throw new Error('Default Firestore release not found');
 const files = await rules.getRulesetContent(release.rulesetName);
 fs.writeFileSync('firestore.remote.backup.json', JSON.stringify({release,files},null,2));
 for (const file of files) console.log(file.name + '\n' + file.content);
})().catch(e => { console.error(e.message); process.exitCode=1; });
