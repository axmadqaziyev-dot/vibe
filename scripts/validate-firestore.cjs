const fs = require('fs');
const base = 'C:/Users/user/AppData/Roaming/npm/node_modules/firebase-tools/lib/';
const auth = require(base+'auth');
const rules = require(base+'gcp/rules');
(async () => {
 const account = auth.getGlobalDefaultAccount();
 if (!account) throw Error('Firebase login required');
 await require(base+'requireAuth').requireAuth({project:'vibe-f9d13',...account});
 const backup = JSON.parse(fs.readFileSync('firestore.remote.backup.json','utf8').replace(/^\uFEFF/,''));
 const releases = await rules.listAllReleases('vibe-f9d13');
 const current = releases.find(r=>r.name==='projects/vibe-f9d13/releases/cloud.firestore');
 if (!current || current.rulesetName!==backup.release.rulesetName) throw Error('Remote rules changed; merge must be reviewed again');
 const content = fs.readFileSync('firestore.rules','utf8').replace(/^\uFEFF/,'');
 const files = [{name:'firestore.rules',content}];
 const result = await rules.testRuleset('vibe-f9d13',files);
 console.log('Validation:',JSON.stringify(result.body));
 if ((result.body.issues||[]).some(i=>i.severity==='ERROR')) throw Error('Rules validation failed');
 fs.writeFileSync('firestore.validation.json',JSON.stringify(result.body,null,2));
})().catch(e=>{console.error(e.message);process.exitCode=1;});
