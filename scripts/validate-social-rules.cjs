const fs=require('fs');
const base='C:/Users/user/AppData/Roaming/npm/node_modules/firebase-tools/lib/';
const auth=require(base+'auth');const rules=require(base+'gcp/rules');
(async()=>{
 const account=auth.getGlobalDefaultAccount();if(!account)throw Error('Login required');
 await require(base+'requireAuth').requireAuth({project:'vibe-f9d13',...account});
 const release=(await rules.listAllReleases('vibe-f9d13')).find(r=>r.name==='projects/vibe-f9d13/releases/cloud.firestore');
 const expected=JSON.parse(fs.readFileSync('firestore.deployment.json','utf8')).release;
 if(release?.rulesetName!==expected.rulesetName)throw Error('Remote rules changed');
 const old=await rules.getRulesetContent(release.rulesetName);
 fs.writeFileSync('firestore.social.backup.json',JSON.stringify({release,files:old},null,2));
 const files=[{name:'firestore.rules',content:fs.readFileSync('firestore.rules','utf8').replace(/^\uFEFF/,'')}];
 const validation=await rules.testRuleset('vibe-f9d13',files);
 console.log('Validation:',JSON.stringify(validation.body));
 if((validation.body.issues||[]).some(i=>i.severity==='ERROR'))throw Error('Validation failed');
})().catch(e=>{console.error(e.message);process.exitCode=1;});
