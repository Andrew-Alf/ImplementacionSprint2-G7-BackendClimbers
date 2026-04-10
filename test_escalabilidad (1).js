import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

const errorRate = new Rate('error_rate');
const durTrend  = new Trend('registro_duration_ms', true);

// Ejecutar: k6 run -e BASE_URL=http://<ALB_DNS> test_escalabilidad.js
export const options = {
  stages: [
    { duration: '2m',  target: 5000  },   // Ramp-up suave
    { duration: '3m',  target: 12000 },   // Subir al pico
    { duration: '10m', target: 12000 },   // Sostener — aquí se valida el ASR-2
    { duration: '2m',  target: 0     },   // Ramp-down
  ],
  thresholds: {
    'http_req_duration': ['p(95)<3000'],  // ASR-2: p95 < 3 segundos
    'error_rate':        ['rate<0.01'],   // Tasa de error < 1%
  },
};

export default function () {
  const BASE_URL = __ENV.BASE_URL || 'http://localhost:8000';

  const email = `vu${__VU}.it${__ITER}.t${Date.now()}@biteco-test.com`;

  const res = http.post(
    `${BASE_URL}/usuarios`,
    JSON.stringify({
      nombre:     `Usuario VU-${__VU}`,
      email:      email,
      empresa_id: (__VU % 100) + 1,
    }),
    { headers: { 'Content-Type': 'application/json' }, timeout: '10s' }
  );

  const ok = check(res, {
    'status 201':    (r) => r.status === 201,
    'respuesta < 3s': (r) => r.timings.duration < 3000,
  });

  errorRate.add(!ok);
  durTrend.add(res.timings.duration);

  sleep(0.1);
}

export function handleSummary(data) {
  const p95 = data.metrics['http_req_duration']?.values['p(95)'] ?? 0;
  const err  = data.metrics['error_rate']?.values?.rate ?? 0;

  console.log('\n========= RESULTADO ASR-2 =========');
  console.log(`p95 latencia : ${p95.toFixed(0)} ms  → ${p95 < 3000 ? '✅ CUMPLE' : '❌ NO CUMPLE'}`);
  console.log(`Tasa de error: ${(err * 100).toFixed(2)}%     → ${err < 0.01 ? '✅ CUMPLE' : '❌ NO CUMPLE'}`);
  console.log('====================================\n');
  return { stdout: JSON.stringify(data, null, 2) };
}
