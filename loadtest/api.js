import http from 'k6/http';
import { check, sleep } from 'k6';
import { SharedArray } from 'k6/data';
import { Trend, Rate } from 'k6/metrics';

const BASE_URL = (__ENV.BASE_URL || 'http://127.0.0.1:8888').replace(/\/+$/, '');
const MODE = (__ENV.MODE || 'smoke').toLowerCase();
const ACCOUNTS_FILE = __ENV.ACCOUNTS_FILE || './data/accounts.json';
const SEMESTER_ID = __ENV.SEMESTER_ID || '1106';
const WARM_CACHE = (__ENV.WARM_CACHE || 'true').toLowerCase() === 'true';
const THINK_TIME_MS = Number(__ENV.THINK_TIME_MS || 0);
const TARGET_RPS = Number(__ENV.TARGET_RPS || 20);
const SOAK_RPS = Number(__ENV.SOAK_RPS || 10);

const accounts = new SharedArray('accounts', function () {
  return JSON.parse(open(ACCOUNTS_FILE));
});

const endpointDuration = new Trend('endpoint_duration', true);
const endpointFailures = new Rate('endpoint_failures');

const endpoints = [
  { name: 'session', path: '/api/v1/jwxt/session', weight: 1 },
  { name: 'semesters', path: '/api/v1/jwxt/semesters', weight: 2 },
  { name: 'profile', path: '/api/v1/jwxt/profile', weight: 1 },
  { name: 'grades', path: '/api/v1/jwxt/grades?semester_id=' + SEMESTER_ID, weight: 3 },
  { name: 'course-table', path: '/api/v1/jwxt/course-table?semester_id=' + SEMESTER_ID, weight: 2 },
  { name: 'current-week', path: '/api/v1/schedule/current-week', weight: 1, public: true },
];

function createSession(username, password) {
  return http.post(BASE_URL + '/api/v1/jwxt/session', JSON.stringify({
    username: username,
    password: password,
  }), {
    headers: { 'Content-Type': 'application/json' },
    tags: { name: 'login' },
  });
}

export function setup() {
  const sessions = [];
  const failures = [];

  for (let i = 0; i < accounts.length; i++) {
    const account = accounts[i];
    const res = createSession(account.username, account.password);
    const cookies = res.cookies['campus_session'];
    const cookie = cookies && cookies.length > 0 ? cookies[0].value : '';
    if (res.status !== 200 || cookie === '') {
      failures.push(account.username + ': HTTP ' + res.status);
      continue;
    }
    sessions.push({ username: account.username, cookie: cookie });
  }

  if (sessions.length === 0) {
    throw new Error('no usable sessions: ' + failures.join(', '));
  }

  if (WARM_CACHE) {
    warmCaches(sessions);
  }

  return { sessions: sessions };
}

function warmCaches(sessions) {
  const globalPaths = [
    '/api/v1/jwxt/semesters',
  ];
  const userPaths = [
    '/api/v1/jwxt/profile',
    '/api/v1/jwxt/grades?semester_id=' + SEMESTER_ID,
    '/api/v1/jwxt/course-table?semester_id=' + SEMESTER_ID,
  ];
  const firstHeaders = { Cookie: 'campus_session=' + sessions[0].cookie };

  for (let i = 0; i < globalPaths.length; i++) {
    const res = http.get(BASE_URL + globalPaths[i], { headers: firstHeaders });
    if (res.status !== 200) {
      console.warn('cache warmup failed for global path ' + globalPaths[i] + ': HTTP ' + res.status);
    }
  }

  for (let i = 0; i < sessions.length; i++) {
    const headers = { Cookie: 'campus_session=' + sessions[i].cookie };
    for (let j = 0; j < userPaths.length; j++) {
      const res = http.get(BASE_URL + userPaths[j], { headers: headers });
      if (res.status !== 200) {
        console.warn(
          'cache warmup failed for ' + sessions[i].username +
          ' at ' + userPaths[j] + ': HTTP ' + res.status,
        );
      }
    }
  }
}

export function mainFlow(data) {
  const session = data.sessions[(__VU - 1) % data.sessions.length];
  const endpoint = pickEndpoint();
  const headers = {};

  if (!endpoint.public) {
    headers.Cookie = 'campus_session=' + session.cookie;
  }

  const res = http.get(BASE_URL + endpoint.path, {
    headers: headers,
    tags: { endpoint: endpoint.name },
  });
  const ok = res.status === 200 && res.json('code') === 0;

  check(res, {
    'status is 200': (r) => r.status === 200,
    'business code is 0': (r) => r.json('code') === 0,
  });

  endpointDuration.add(res.timings.duration, { endpoint: endpoint.name });
  endpointFailures.add(!ok, { endpoint: endpoint.name });

  if (THINK_TIME_MS > 0) {
    sleep(THINK_TIME_MS / 1000);
  }
}

function pickEndpoint() {
  const total = endpoints.reduce(function (sum, endpoint) {
    return sum + endpoint.weight;
  }, 0);
  let roll = Math.random() * total;

  for (let i = 0; i < endpoints.length; i++) {
    roll -= endpoints[i].weight;
    if (roll <= 0) {
      return endpoints[i];
    }
  }
  return endpoints[endpoints.length - 1];
}

function buildScenarios() {
  const scenarios = {};
  const main = {
    exec: 'mainFlow',
    startTime: '0s',
  };

  if (MODE === 'smoke') {
    main.executor = 'shared-iterations';
    main.vus = 5;
    main.iterations = 100;
    main.maxDuration = '3m';
  } else if (MODE === 'load') {
    main.executor = 'ramping-vus';
    main.stages = [
      { duration: '1m', target: 10 },
      { duration: '2m', target: 50 },
      { duration: '3m', target: 100 },
      { duration: '2m', target: 100 },
      { duration: '1m', target: 0 },
    ];
    main.gracefulRampDown = '30s';
  } else if (MODE === '1c1g') {
    main.executor = 'ramping-arrival-rate';
    main.startRate = 1;
    main.timeUnit = '1s';
    main.stages = [
      { duration: '1m', target: Math.max(1, Math.round(TARGET_RPS * 0.25)) },
      { duration: '2m', target: Math.max(1, Math.round(TARGET_RPS * 0.5)) },
      { duration: '2m', target: TARGET_RPS },
      { duration: '2m', target: TARGET_RPS },
      { duration: '1m', target: 0 },
    ];
    main.preAllocatedVUs = 10;
    main.maxVUs = 50;
    main.gracefulStop = '30s';
  } else if (MODE === 'stress') {
    main.executor = 'ramping-vus';
    main.stages = [
      { duration: '1m', target: 50 },
      { duration: '2m', target: 200 },
      { duration: '3m', target: 400 },
      { duration: '2m', target: 400 },
      { duration: '1m', target: 0 },
    ];
    main.gracefulRampDown = '30s';
  } else if (MODE === 'soak-1c1g') {
    main.executor = 'constant-arrival-rate';
    main.rate = SOAK_RPS;
    main.timeUnit = '1s';
    main.duration = __ENV.SOAK_DURATION || '15m';
    main.preAllocatedVUs = 10;
    main.maxVUs = 50;
  } else if (MODE === 'soak') {
    main.executor = 'constant-vus';
    main.vus = 50;
    main.duration = '30m';
  } else {
    throw new Error('unknown MODE: ' + MODE);
  }

  scenarios.main = main;
  return scenarios;
}

export const options = {
  scenarios: buildScenarios(),
  thresholds: {
    endpoint_duration: ['p(95)<800', 'p(99)<1500'],
    endpoint_failures: ['rate<0.01'],
  },
  setupTimeout: WARM_CACHE ? '20m' : '10m',
};
