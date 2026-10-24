"""Minimal single-page grammar admin workspace.

It is intentionally dependency-free (no Node/Vite) and talks to the protected
``/api/v1/admin/grammar`` endpoints with a JWT stored in sessionStorage.
"""
from fastapi import APIRouter
from fastapi.responses import HTMLResponse

router = APIRouter()

_ADMIN_HTML = r"""<!doctype html>
<html lang="vi">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1"/>
<title>EnglishAI Grammar Admin</title>
<style>
:root{color-scheme:dark;--bg:#0f1220;--panel:#181c2e;--line:#2b3150;--text:#eef1ff;--muted:#9aa3c7;--primary:#6c5ce7;--green:#2ed573;--red:#ff4757;--amber:#ffa502}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--text);font:14px/1.45 system-ui,Segoe UI,Roboto,sans-serif}
header{padding:14px 22px;border-bottom:1px solid var(--line);display:flex;gap:14px;align-items:center;justify-content:space-between;background:#14182a}
h1{font-size:18px;margin:0}.muted{color:var(--muted)}button{background:var(--panel);color:var(--text);border:1px solid var(--line);border-radius:9px;padding:8px 12px;cursor:pointer;font-weight:600}
button.primary{background:var(--primary);border-color:var(--primary)}button.green{background:#153a2a;border-color:#1f6b49;color:#76f0ad}button.red{background:#3a1620;border-color:#722334;color:#ff9ba8}button:disabled{opacity:.5;cursor:not-allowed}
input,textarea{width:100%;background:#0b0e19;color:var(--text);border:1px solid var(--line);border-radius:9px;padding:10px}textarea{min-height:58vh;font:12px/1.5 ui-monospace,SFMono-Regular,Consolas,monospace;resize:vertical}
main{display:grid;grid-template-columns:330px 1fr;gap:16px;padding:16px;height:calc(100vh - 67px)}aside{overflow:auto;border:1px solid var(--line);border-radius:14px;background:var(--panel)}
.row{padding:11px 13px;border-bottom:1px solid var(--line);cursor:pointer}.row:hover,.row.active{background:#242b48}.row b{display:block;font-size:13px}.row small{color:var(--muted)}.pill{display:inline-block;padding:1px 6px;border-radius:5px;font-size:10px;font-weight:700;margin-right:4px}
.published{background:#153a2a;color:#76f0ad}.draft,.in_review{background:#3a3016;color:#ffd166}.archived{background:#3a1620;color:#ff9ba8}.beta{background:#3a2a16;color:#ffc078}
.panel{border:1px solid var(--line);border-radius:14px;background:var(--panel);padding:14px;overflow:auto}#editor{display:grid;grid-template-rows:auto auto 1fr;gap:10px;min-height:0}
.toolbar{display:flex;flex-wrap:wrap;gap:8px}.status{min-height:20px;color:var(--muted);white-space:pre-wrap}.error{color:#ff9ba8}.ok{color:#76f0ad}
#login{display:flex;align-items:center;justify-content:center;min-height:70vh}#login .panel{width:min(420px,92vw)}#login input{margin:7px 0}
pre{white-space:pre-wrap;background:#0b0e19;border:1px solid var(--line);border-radius:8px;padding:9px;margin:6px 0;max-height:220px;overflow:auto}
@media(max-width:800px){main{grid-template-columns:1fr;height:auto}aside{max-height:35vh}}
</style>
</head>
<body>
<header>
  <div><h1>Grammar Admin</h1><div class="muted" id="who">C1/C2 beta · versioned content</div></div>
  <div class="toolbar">
    <button id="btnNew">+ Bài mới</button>
    <button id="btnImport">Import 96 bài</button>
    <button id="btnExport">Export JSON</button>
    <button id="btnLogout">Đăng xuất</button>
  </div>
</header>
<main id="app" style="display:none">
  <aside id="list"></aside>
  <section class="panel" id="editor">
    <div class="toolbar">
      <button class="primary" id="btnSave">Lưu</button>
      <button id="btnValidate">Validate</button>
      <button id="btnReview">Gửi duyệt</button>
      <button class="green" id="btnPublish">Publish</button>
      <button id="btnVersions">Versions</button>
    </div>
    <div class="status" id="status"></div>
    <textarea id="json" spellcheck="false"></textarea>
    <div id="versions"></div>
  </section>
</main>
<section id="login">
  <div class="panel">
    <h2 style="margin-top:0">Đăng nhập admin</h2>
    <p class="muted">Dùng tài khoản có role <b>admin</b> hoặc <b>reviewer</b>. Token chỉ lưu trong sessionStorage.</p>
    <input id="email" placeholder="Email" autocomplete="username"/>
    <input id="password" type="password" placeholder="Mật khẩu" autocomplete="current-password"/>
    <button class="primary" id="btnLogin" style="width:100%;margin-top:8px">Đăng nhập</button>
    <div class="status" id="loginStatus"></div>
  </div>
</section>
<script>
const state={token:sessionStorage.getItem('grammar_admin_token')||'',lessons:[],current:null,isNew:false};
const $=id=>document.getElementById(id);
const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
function setStatus(msg,isError=false){const el=$('status');el.textContent=msg;el.className='status '+(isError?'error':'ok');}
function setLoginStatus(msg,isError=false){const el=$('loginStatus');el.textContent=msg;el.className='status '+(isError?'error':'ok');}
async function api(path,options={}){
  const headers=Object.assign({'Content-Type':'application/json'},options.headers||{});
  if(state.token)headers.Authorization='Bearer '+state.token;
  const res=await fetch(path,Object.assign({},options,{headers}));
  if(res.status===401){logout();throw new Error('Phiên đăng nhập hết hạn');}
  const text=await res.text();
  let data=null;try{data=text?JSON.parse(text):null}catch(e){data=text}
  if(!res.ok){const detail=data&&data.detail!==undefined?data.detail:data;throw new Error(typeof detail==='string'?detail:JSON.stringify(detail));}
  return data;
}
async function login(){
  const email=$('email').value.trim(),password=$('password').value;
  if(!email||!password)return setLoginStatus('Nhập email và mật khẩu',true);
  try{
    const data=await api('/api/v1/auth/login',{method:'POST',body:JSON.stringify({email,password})});
    if(!['admin','reviewer'].includes(data.user&&data.user.role))throw new Error('Tài khoản không có quyền admin/reviewer');
    state.token=data.access_token;sessionStorage.setItem('grammar_admin_token',state.token);
    $('who').textContent=`${data.user.name} · ${data.user.role}`;
    $('login').style.display='none';$('app').style.display='grid';await loadLessons();
  }catch(e){setLoginStatus(e.message,true)}
}
function logout(){state.token='';sessionStorage.removeItem('grammar_admin_token');$('app').style.display='none';$('login').style.display='flex';setLoginStatus('')}
async function loadLessons(){
  try{
    state.lessons=await api('/api/v1/admin/grammar/lessons');
    const list=$('list');list.innerHTML='';
    state.lessons.forEach(l=>{
      const div=document.createElement('div');div.className='row';div.dataset.slug=l.slug;
      div.innerHTML=`<b>${esc(l.title)}</b><small>${esc(l.id)} · ${esc(l.level)}</small><div style="margin-top:4px"><span class="pill ${esc(l.status)}">${esc(l.status)}</span>${l.is_beta?'<span class="pill beta">BETA</span>':''}<span class="muted">v${l.version}</span></div>`;
      div.onclick=()=>selectLesson(l.slug);list.appendChild(div);
    });
  }catch(e){setStatus(e.message,true)}
}
async function selectLesson(slug){
  state.isNew=false;
  document.querySelectorAll('.row').forEach(r=>r.classList.toggle('active',r.dataset.slug===slug));
  try{state.current=await api('/api/v1/admin/grammar/lessons/'+encodeURIComponent(slug));$('json').value=JSON.stringify(state.current,null,2);$('versions').innerHTML='';setStatus('Đã tải '+slug)}catch(e){setStatus(e.message,true)}
}
function newLesson(){
  state.isNew=true;state.current=null;
  document.querySelectorAll('.row').forEach(r=>r.classList.remove('active'));
  $('json').value=JSON.stringify({id:'new_lesson_id',title:'New Grammar Lesson',title_vi:'Bài ngữ pháp mới',level:'A1',category:'Cơ bản',description:'Mô tả bài học.',formula_affirmative:'S + V',formula_negative:'S + do not + V',formula_question:'Do + S + V?',time_markers:['always','every day','now'],usage_rules:['Quy tắc 1','Quy tắc 2','Quy tắc 3'],examples:[{english:'I study English.',vietnamese:'Tôi học tiếng Anh.',note:''},{english:'She works here.',vietnamese:'Cô ấy làm việc ở đây.',note:''},{english:'They are happy.',vietnamese:'Họ vui vẻ.',note:''}],common_mistakes:['Lỗi 1','Lỗi 2','Lỗi 3'],quiz:[{question:'She ___ a student.',options:['am','is','are','be'],correct_index:1,explanation:'She dùng is.'},{question:'They ___ happy.',options:['am','is','are','be'],correct_index:2,explanation:'They dùng are.'},{question:'I ___ ready.',options:['am','is','are','be'],correct_index:0,explanation:'I dùng am.'},{question:'___ you tired?',options:['Am','Is','Are','Do'],correct_index:2,explanation:'you dùng are.'},{question:'He ___ here.',options:['am','is','are','be'],correct_index:1,explanation:'He dùng is.'}],is_beta:false,status:'draft',tags:[],estimated_minutes:10},null,2);
  $('versions').innerHTML='';setStatus('Bài mới: sửa JSON rồi bấm Lưu');
}
async function saveLesson(){
  let payload;try{payload=JSON.parse($('json').value)}catch(e){return setStatus('JSON lỗi: '+e.message,true)}
  try{
    const result=state.isNew
      ? await api('/api/v1/admin/grammar/lessons',{method:'POST',body:JSON.stringify(payload)})
      : await api('/api/v1/admin/grammar/lessons/'+encodeURIComponent(state.current.slug),{method:'PUT',body:JSON.stringify(payload)});
    state.current=result;state.isNew=false;$('json').value=JSON.stringify(result,null,2);setStatus('Đã lưu v'+result.version);await loadLessons();
  }catch(e){setStatus(e.message,true)}
}
async function validateLesson(){if(!state.current&&!state.isNew)return setStatus('Chọn bài trước',true);if(state.isNew)return setStatus('Lưu bài mới trước khi validate',true);try{const r=await api('/api/v1/admin/grammar/lessons/'+encodeURIComponent(state.current.slug)+'/validate',{method:'POST'});setStatus(r.valid?'Hợp lệ':'Lỗi:\n'+r.errors.join('\n'),!r.valid)}catch(e){setStatus(e.message,true)}}
async function reviewLesson(){if(!state.current)return setStatus('Chọn bài trước',true);try{state.current=await api('/api/v1/admin/grammar/lessons/'+encodeURIComponent(state.current.slug)+'/submit-review',{method:'POST'});$('json').value=JSON.stringify(state.current,null,2);setStatus('Đã gửi duyệt');await loadLessons()}catch(e){setStatus(e.message,true)}}
async function publishLesson(){if(!state.current)return setStatus('Chọn bài trước',true);try{state.current=await api('/api/v1/admin/grammar/lessons/'+encodeURIComponent(state.current.slug)+'/publish',{method:'POST'});$('json').value=JSON.stringify(state.current,null,2);setStatus('Đã publish v'+state.current.version);await loadLessons()}catch(e){setStatus(e.message,true)}}
async function showVersions(){if(!state.current)return setStatus('Chọn bài trước',true);try{const rows=await api('/api/v1/admin/grammar/lessons/'+encodeURIComponent(state.current.slug)+'/versions');$('versions').innerHTML=rows.map(v=>`<div class="panel" style="padding:8px;margin-top:6px"><b>v${v.version}</b> <span class="muted">${esc(v.changelog||'')}</span><pre>${esc(v.content_hash)}</pre><button class="red" onclick="rollback(${v.version})">Rollback</button></div>`).join('')}catch(e){setStatus(e.message,true)}}
async function rollback(version){if(!state.current)return;if(!confirm('Rollback về v'+version+'?'))return;try{state.current=await api(`/api/v1/admin/grammar/lessons/${encodeURIComponent(state.current.slug)}/rollback/${version}`,{method:'POST'});$('json').value=JSON.stringify(state.current,null,2);setStatus('Đã rollback, tạo v'+state.current.version);await loadLessons()}catch(e){setStatus(e.message,true)}}
async function importCurriculum(){if(!confirm('Import 96 bài từ asset? Bài trùng slug sẽ được cập nhật.'))return;try{await api('/api/v1/admin/grammar/import',{method:'POST'});setStatus('Import xong');await loadLessons()}catch(e){setStatus(e.message,true)}}
async function exportCurriculum(){try{const rows=await api('/api/v1/admin/grammar/export');const blob=new Blob([JSON.stringify(rows,null,2)],{type:'application/json'});const a=document.createElement('a');a.href=URL.createObjectURL(blob);a.download='grammar-export.json';a.click();URL.revokeObjectURL(a.href)}catch(e){setStatus(e.message,true)}}
$('btnLogin').onclick=login;$('password').addEventListener('keydown',e=>{if(e.key==='Enter')login()});
$('btnLogout').onclick=logout;$('btnNew').onclick=newLesson;$('btnSave').onclick=saveLesson;$('btnValidate').onclick=validateLesson;$('btnReview').onclick=reviewLesson;$('btnPublish').onclick=publishLesson;$('btnVersions').onclick=showVersions;$('btnImport').onclick=importCurriculum;$('btnExport').onclick=exportCurriculum;
if(state.token){$('login').style.display='none';$('app').style.display='grid';$('who').textContent='Đang tải...';loadLessons().catch(()=>logout());}
</script>
</body>
</html>"""


@router.get("/grammar", response_class=HTMLResponse)
async def grammar_admin_page():
    return HTMLResponse(_ADMIN_HTML)
