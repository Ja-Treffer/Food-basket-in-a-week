// 从 review.html 抽出题库，写成 data/quiz.json（单一事实来源仍是 review.html）
const fs=require('fs'), path=require('path');
const file=path.join(__dirname,'..','review.html');
const html=fs.readFileSync(file,'utf8');
const m=html.match(/var Q = (\[[\s\S]*?\n  \]);/);
if(!m){console.error('Q not found');process.exit(1);}
const Q=new Function('return '+m[1])();
const out=Q.map((q,i)=>({n:i+1,g:q.g,ref:q.ref,t:q.t,o:q.o,a:q.a,why:q.why,x:q.x}));
const dst=path.join(__dirname,'..','data','quiz.json');
fs.writeFileSync(dst,JSON.stringify({v:1,perQuestionSeconds:20,items:out},null,2),'utf8');
console.log('wrote '+dst+' items='+out.length);
