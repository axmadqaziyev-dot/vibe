const fs=require('fs');
const p='firestore.rules';let s=fs.readFileSync(p,'utf8').replace(/^\uFEFF/,'');
s=s.replace('allow create: if isChatMember(chatId)', `allow create: if signedIn()
                      && request.auth.uid in getAfter(/databases/$(database)/documents/chats/$(chatId)).data.members`);
const extra=`
    match /moments/{momentId} {
      allow read: if signedIn();
      allow create: if signedIn()
        && request.resource.data.owner == request.auth.uid
        && request.resource.data.name is string
        && request.resource.data.text is string
        && request.resource.data.text.size() > 0
        && request.resource.data.text.size() <= 500
        && request.resource.data.createdAt == request.time
        && request.resource.data.keys().hasOnly(['owner', 'name', 'text', 'createdAt']);
      allow delete: if signedIn() && resource.data.owner == request.auth.uid;
    }
    match /socialRooms/{roomId} {
      allow read: if signedIn();
      allow create: if signedIn()
        && request.resource.data.owner == request.auth.uid
        && request.resource.data.name is string
        && request.resource.data.text is string
        && request.resource.data.text.size() > 0
        && request.resource.data.text.size() <= 80
        && request.resource.data.createdAt == request.time
        && request.resource.data.keys().hasOnly(['owner', 'name', 'text', 'createdAt']);
      match /messages/{messageId} {
        allow read: if signedIn();
        allow create: if signedIn()
          && exists(/databases/$(database)/documents/socialRooms/$(roomId))
          && request.resource.data.senderId == request.auth.uid
          && request.resource.data.name is string
          && request.resource.data.text is string
          && request.resource.data.text.size() > 0
          && request.resource.data.text.size() <= 1000
          && request.resource.data.createdAt == request.time
          && request.resource.data.keys().hasOnly(['senderId','name','text','createdAt']);
      }
    }
`;
const i=s.lastIndexOf('  }');s=s.slice(0,i)+extra+s.slice(i);fs.writeFileSync(p,s);
const f=JSON.parse(fs.readFileSync('firebase.json','utf8'));
f.hosting.headers=[{source:'**',headers:[{key:'Cache-Control',value:'no-cache'}]}];
fs.writeFileSync('firebase.json',JSON.stringify(f,null,2));
let html=fs.readFileSync('web/index.html','utf8');html=html.replaceAll('flutter_application_1','VIBE').replace('A new Flutter project.','VIBE — dostlarınla mesajlaş, anlarını paylaş, səsli və video danış.');fs.writeFileSync('web/index.html',html);
const manifest=JSON.parse(fs.readFileSync('web/manifest.json','utf8'));Object.assign(manifest,{name:'VIBE',short_name:'VIBE',background_color:'#fafafa',theme_color:'#e7dfff',description:'Bir salamla başlasın. Mesajlar, anlar və zənglər.'});fs.writeFileSync('web/manifest.json',JSON.stringify(manifest,null,2));
