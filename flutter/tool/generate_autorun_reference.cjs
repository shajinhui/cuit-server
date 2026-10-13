// 直接运行仓库中的 Vue 业务函数，生成 Flutter 的跨语言对照数据。
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../..');
const ts = require(path.join(root, 'apps/web/node_modules/typescript'));
const cache = new Map();
function load(filename) {
  filename = path.resolve(filename);
  if (!path.extname(filename)) filename += '.ts';
  if (cache.has(filename)) return cache.get(filename);
  if (filename.endsWith('.json')) return JSON.parse(fs.readFileSync(filename, 'utf8'));
  const module = { exports: {} };
  cache.set(filename, module.exports);
  const code = ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022, esModuleInterop: true },
  }).outputText;
  new Function('require', 'module', 'exports', code)(
    id => load(path.resolve(path.dirname(filename), id)), module, module.exports,
  );
  return module.exports;
}
const source = path.join(root, 'apps/web/src/features/autorun');
const run = load(path.join(source, 'run.ts'));
const track = load(path.join(source, 'track.ts'));
const model = load(path.join(source, 'model.ts'));
const completion = load(path.join(root, 'apps/web/src/features/plan-completion/model.ts'));
const campusInputs = [
  { bounds: [], standard: {} },
  { bounds: [], standard: { campusName: '龙泉校区' } },
  { bounds: [], standard: { campus: '航空港', campusName: 'longquan' } },
  { bounds: [], standard: { campusID: 2 } },
  { bounds: [{ siteBound: '104.308,30.607' }], standard: {} },
  { bounds: [{ siteBound: '30.606--104.305' }], standard: {} },
];
const progressInputs = [
  { runInfo: {}, runStandard: {} },
  { runInfo: { runValidCount: 4, runCount: 9, runValidDistance: 12500 }, runStandard: { boyAllRunTime: 20, girlAllRunTime: 16, boyAllRunDistance: 60000 } },
  { runInfo: { runValidCount: '', runCount: 3, runDistance: '12.4' }, runStandard: { allRunTime: -1, allRunDistance: 0 } },
  { runInfo: { runCount: 35, runDistance: 76 }, runStandard: { allRunTime: '30', allRunDistance: 60 } },
];
const activities = [
  { clubActivityId: 1, optionStatus: '1', signInStudent: 30, maxStudent: 30 },
  { clubActivityId: 2, optionStatus: '3', signInStudent: 2, maxStudent: 30 },
  { clubActivityId: 3, fullActivity: '1', signInStudent: 2, maxStudent: 30 },
  { clubActivityId: 4, optionStatus: '0', signInStudent: 2, maxStudent: 30 },
];
const signTasks = [null];
for (const status of ['0', '1', '2']) {
  for (const signIn of ['0', '1']) {
    for (const signBack of ['0', '1']) {
      signTasks.push({ activityId: 9, signStatus: status, signInStatus: signIn, signBackStatus: signBack });
    }
  }
}
const preparation = { userId: 42, schoolId: 1, runStandard: { semesterYear: '2026-2027-1' }, bounds: [{ siteBound: '104.00,30.50' }] };
const now = '2026-10-06T17:02:03Z';
const records = ['airport', 'longquan'].map(campus => ({
  campus, preparation, now, random: 0.25, distance: 500, duration: 32,
  expected: run.buildAutoRunRecordBody({
    identity: preparation, standard: preparation.runStandard, bounds: preparation.bounds,
    now: new Date(now), random: () => 0.25, locations: track.loadTrackMap(campus), runDistance: 500, runTime: 32,
  }),
}));
const creditInputs = [['160', '80'], ['0', '80'], ['160学分', '180学分'], ['—', '80'], ['160', '-1']];
const fixture = {
  campuses: campusInputs.map(input => ({ ...input, expected: run.detectAutoRunCampus(input.bounds, input.standard) })),
  progress: progressInputs.map(input => ({ input, expected: model.buildAutoRunProgressCards(input).map(v => ({ current: v.current, target: v.target, unit: v.unit })) })),
  activities: activities.map(input => ({ input, expected: model.normalizeAutoRunClubActivities([input])[0] })),
  signs: signTasks.map(input => {
    const normalized = model.normalizeAutoRunClubSignTask(input);
    return { input, action: model.resolveAutoRunClubSignAction(normalized), description: model.describeAutoRunClubSignTask(normalized) };
  }),
  records,
  credits: creditInputs.map(([required, earned]) => ({ required, earned, expected: completion.creditProgress(required, earned) })),
};
fs.writeFileSync(path.join(root, 'flutter/test/fixtures/autorun_reference.json'), JSON.stringify(fixture, null, 2) + '\n');
console.log('已生成校园跑与学分完成度的原版对照数据');
