import http from 'k6/http';
import { check, sleep } from 'k6';
import { SharedArray } from 'k6/data';
import { Trend, Rate } from 'k6/metrics';

const BASE_URL = (__ENV.BASE_URL || 'http://127.0.0.1:8888').replace(/\/+$/, '');
const ACCOUNTS_FILE = __ENV.ACCOUNTS_FILE || './data/accounts.json';
const THINK_TIME_MS = Number(__ENV.THINK_TIME_MS || 0);

const accounts = new SharedArray('accounts', function () {
  return JSON.parse(open(ACCOUNTS_FILE));
});

const loginDuration = new Trend('login_duration', true);
const loginFailures = new Rate('login_failures');

export const options = {
  scenarios: {
    login: {
      executor: 'constant-arrival-rate',
      rate: Number(__ENV.LOGIN_RATE || 1),
      timeUnit: '1s',
      duration: __ENV.LOGIN_DURATION || '1m',
      preAllocatedVUs: Number(__ENV.LOGIN_VUS || 5),
      maxVUs: Number(__ENV.LOGIN_MAX_VUS || 10),
      exec: 'loginFlow',
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.01'],
    login_duration: ['p(95)<5000', 'p(99)<10000'],
    login_failures: ['rate<0.01'],
  },
};

export function loginFlow() {
  const account = accounts[(__VU + __ITER) % accounts.length];
  const res = http.post(BASE_URL + '/api/v1/jwxt/session', JSON.stringify({
    username: account.username,
    password: account.password,
  }), {
    headers: { 'Content-Type': 'application/json' },
    tags: { name: 'login' },
  });
  const ok = res.status === 200 && res.json('code') === 0;

  check(res, {
    'login status is 200': (r) => r.status === 200,
    'login business code is 0': (r) => r.json('code') === 0,
  });

  loginDuration.add(res.timings.duration);
  loginFailures.add(!ok);

  if (THINK_TIME_MS > 0) {
    sleep(THINK_TIME_MS / 1000);
  }
}
