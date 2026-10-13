// 从仓库原版 TypeScript 直接生成跨语言对照样例；生产应用不依赖 Node。
const fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'../..');
const ts=require(path.join(root,'apps/web/node_modules/typescript'));
const cache=new Map();
function load(file) {
  file=path.resolve(file);
  if(!path.extname(file))file+='.ts';
  if(cache.has(file))return cache.get(file);
  if(file.endsWith('.json'))return JSON.parse(fs.readFileSync(file,'utf8'));
  const module={exports:{}};cache.set(file,module.exports);
  const code=ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022,esModuleInterop:true}}).outputText;
  new Function('require','module','exports',code)(id=>load(id.startsWith('@/')?path.join(root,'apps/web/src',id.slice(2)):path.resolve(path.dirname(file),id)),module,module.exports);
  return module.exports;
}
const source=path.join(root,'apps/web/src/features/schedule/model');
const {buildCourseBlocks,buildScheduleCourseEntries}=load(path.join(source,'calendar.ts'));
const {createScheduleCalendarExport}=load(path.join(source,'calendarExport.ts'));
const fixtures=load(path.join(root,'apps/web/src/mock/fixtures.ts'));
const examples=[];
function add(name,courses,week,manual=[],overrides=[],colors=[]) {
  const values=new Set(['','地点待定','未命名课程']);
  for(const c of courses) {
    values.add([c.Code,c.LessonID].filter(Boolean).join('\0')||c.Name);values.add(c.Name);
    for(const a of c.Activities||[]) {values.add(a.RoomName||'地点待定');values.add([...new Set((a.Teachers||[]).map(s=>s.trim()).filter(Boolean))].join('\0'));}
  }
  for(const c of [...manual,...overrides]) {values.add(c.id||c.targetID);values.add(c.name);values.add(c.room);}
  for(const v of [...values])values.add(v.trim());
  const order={chinese:[...values].sort((a,b)=>a.localeCompare(b,'zh-CN')),standard:[...values].sort((a,b)=>a.localeCompare(b,'en-US'))};
  examples.push({name,courses,week,manual,overrides,colors,order,
    entries:buildScheduleCourseEntries(courses,week,manual,overrides,colors),
    blocks:buildCourseBlocks(courses,week,manual,overrides,colors)});
}
function activity(start,end,weeks,extra={}) {return {Weekday:1,StartSection:start,EndSection:end,Weeks:weeks,RoomName:'H101',Teachers:['张老师'],...extra};}
function course(id,activities,extra={}) {return {LessonID:id,Code:id,Name:id,Credits:'3',TeachingClass:'一班',Teachers:[],Activities:activities,...extra};}
const mock=fixtures.mockCourseTable(fixtures.currentSemesterID);
for(let w=0;w<=20;w++)add(`原版演示第${w}周`,mock.Courses,w);
add('每周空周次与地点合并',[course('A',[activity(1,2,[]),activity(1,2,[1,3])])],4);
add('连续完整安排',[course('A',[activity(1,2,[1,2]),activity(3,4,[1,2]),activity(4,5,[1,2])])],1);
add('连续部分周次',[course('A',[activity(1,2,[1,2]),activity(3,4,[2,3])])],2);
add('连续其他周不合并',[course('A',[activity(1,2,[1,2]),activity(3,4,[2,3])])],1);
add('理论课忽略精确时间',[course('A',[activity(1,2,[1,2],{StartTime:'08:20',EndTime:'10:00'}),activity(3,4,[1],{StartTime:'10:20',EndTime:'12:00'})])],1);
add('实验课保留独立时间',[course('A',[activity(1,2,[1,2],{StartTime:'08:20',EndTime:'10:00',ActivityType:'实验'}),activity(3,4,[1],{StartTime:'10:20',EndTime:'12:00',ActivityType:'实验'})])],1);
const overlap=[course('A',[activity(1,2,[1])]),course('B',[activity(2,3,[1])]),course('C',[activity(3,4,[1])]),course('D',[activity(1,4,[2])])];
for(let w=0;w<4;w++)add(`重叠链第${w}周`,overlap,w);
add('最近的非本周短课',[course('A',[activity(1,4,[9])]),course('B',[activity(2,2,[3])]),course('C',[activity(3,4,[3])])],2);
add('活动课保留长替代课详情',[course('A',[activity(3,4,[2])]),course('B',[activity(1,6,[1])])],2);
add('同课不同教室',[course('A',[activity(1,2,[1,3],{RoomName:'H102'}),activity(1,2,[2,4],{RoomName:'H101'})])],2);
add('非法安排与超出12节',[course('A',[activity(0,2,[1]),activity(3,2,[1]),activity(1,2,[1],{Weekday:8}),activity(13,14,[])])],1);
add('中文排序默认色',['物理','高等数学','大学英语','操作系统','软件工程','数据结构'].map(n=>course('',[activity(1,2,[1])],{Code:'',Name:n})),1);
const manual=[{id:'manual-example',semesterID:mock.SemesterID,name:'自习',room:'',weekday:7,startSection:3,endSection:4,weeks:[1,3,5]}];
const overrides=[{targetID:'demo-lesson-001-1-1-2',semesterID:mock.SemesterID,name:'本机改名',room:'H9999',weekday:6,startSection:2,endSection:3,weeks:[2,4]}];
add('手动课程与覆盖与颜色',mock.Courses,2,manual,overrides,[{semesterID:mock.SemesterID,courseKey:'DEMO101\0demo-lesson-001',tone:'pine'}]);
// 固定种子的组合安排，覆盖不同输入顺序、非本周避让与跨课连接。
let seed=17;function random(max){seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed%max;}
for(let i=0;i<80;i++) {
  const courses=Array.from({length:6},(_,j)=>course(`C${j}`,Array.from({length:3},()=>{
    const start=1+random(10);return activity(start,start+random(4),[1+random(4),1+random(4)],{Weekday:1+random(3),RoomName:`H${random(3)}`});})));
  add(`组合安排${i}`,courses,1+random(4));
}
const calendar=createScheduleCalendarExport({semester:fixtures.mockSemesters[0],table:mock,manualCourses:manual,courseOverrides:overrides,generatedAt:new Date('2026-09-30T01:02:03Z')});
const dest=path.join(root,'flutter/test/fixtures');fs.mkdirSync(dest,{recursive:true});
const strings=[...new Set(examples.flatMap(e=>e.order.chinese))];
const order={chinese:[...strings].sort((a,b)=>a.localeCompare(b,'zh-CN')),standard:[...strings].sort((a,b)=>a.localeCompare(b,'en-US'))};
fs.writeFileSync(path.join(dest,'schedule_reference.json'),JSON.stringify({order,examples,export:{semester:fixtures.mockSemesters[0],table:mock,manual,overrides,order:examples.find(e=>e.name==='手动课程与覆盖与颜色').order,...calendar}},null,2)+'\n');
const assets=path.join(root,'flutter/assets/data');
fs.writeFileSync(path.join(assets,'demo_schedule.json'),JSON.stringify({semesters:fixtures.mockSemesters,table:mock},null,2)+'\n');
console.log(`Generated ${examples.length} original Vue reference cases and ICS export`);
