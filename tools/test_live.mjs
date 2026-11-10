import http from 'node:http';
const B='http://127.0.0.1:8787';
const post=(p,b)=>fetch(B+p,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(b)}).then(r=>r.json());
const sse=(q)=>new Promise(res=>{
  const req=http.get(B+'/api/stream?'+q,r=>{
    let buf='';
    r.on('data',c=>{buf+=c;const m=buf.match(/data: (.*)\n\n/);if(m){req.destroy();res(JSON.parse(m[1]));}});
  });
  req.on('error',()=>{});
  setTimeout(()=>{req.destroy();res(null);},3000);
});

const room=await post('/api/room',{});
console.log('room',room.pin,'total',room.total,'perQ',room.perQuestionSeconds);
const a=await post('/api/join',{pin:room.pin,name:'阿明'});
const b=await post('/api/join',{pin:room.pin,name:'小美'});
const c=await post('/api/join',{pin:room.pin,name:'阿明'});
console.log('names',a.name,b.name,c.name);
console.log('start',await post('/api/start',{pin:room.pin,hostKey:room.hostKey}));
console.log('ans1',await post('/api/answer',{pin:room.pin,pid:a.pid,q:0,c:2}));
console.log('ans2',await post('/api/answer',{pin:room.pin,pid:b.pid,q:0,c:1}));
console.log('ans3',await post('/api/answer',{pin:room.pin,pid:c.pid,q:0,c:1}));
console.log('dup',await post('/api/answer',{pin:room.pin,pid:a.pid,q:0,c:0}));
await new Promise(r=>setTimeout(r,1600));
const hv=await sse('role=host&pin='+room.pin+'&hostKey='+room.hostKey);
console.log('HOST state',hv.state,'q',hv.qIndex,'counts',hv.counts,'correct',hv.correct,'players',hv.players.map(p=>p.name+':'+p.answered).join(','));
const pv=await sse('role=player&pin='+room.pin+'&pid='+b.pid);
console.log('PLAYER state',pv.state,'my',pv.myChoice,'counts',pv.counts,'correct',pv.correct);
console.log('bad hostKey',await post('/api/next',{pin:room.pin,hostKey:'nope'}));
console.log('next',await post('/api/next',{pin:room.pin,hostKey:room.hostKey}));
const hv2=await sse('role=host&pin='+room.pin+'&hostKey='+room.hostKey);
console.log('after next: q',hv2.qIndex,'state',hv2.state,'hasItem',!!hv2.item);
