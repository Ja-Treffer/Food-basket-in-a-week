const B='http://127.0.0.1:8788';
const post=(p,b)=>fetch(B+p,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(b)}).then(r=>r.json());
const room=await post('/api/room',{});
for(const n of ['阿明','小美','阿强','嘉嘉','阿明']){ await post('/api/join',{pin:room.pin,name:n}); }
console.log(JSON.stringify(room));
