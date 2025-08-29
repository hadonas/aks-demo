import Vue from 'vue'
import App from './App.vue'

// OpenTelemetry imports
import { WebTracerProvider } from '@opentelemetry/sdk-trace-web'
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http'
import { Resource } from '@opentelemetry/resources'
import { BatchSpanProcessor } from '@opentelemetry/sdk-trace-base'
import { FetchInstrumentation } from '@opentelemetry/instrumentation-fetch'
import { XMLHttpRequestInstrumentation } from '@opentelemetry/instrumentation-xml-http-request'
import { registerInstrumentations } from '@opentelemetry/instrumentation'

// OpenTelemetry 설정
function setupOpenTelemetry() {
  try {
    // OpenTelemetry Collector 엔드포인트
    let otlpEndpoint = process.env.VUE_APP_OTEL_EXPORTER_OTLP_ENDPOINT || 'http://collector.lgtm.20.249.154.255.nip.io'

    // 리소스 설정
    const resource = new Resource({
      'service.name': 'aks-demo-frontend',
      'service.version': '1.0.0',
      'deployment.environment': 'production',
      'service.instance.id': `frontend-${Date.now()}`,
      'service.namespace': 'aks-demo',
      'telemetry.sdk.name': 'opentelemetry',
      'telemetry.sdk.language': 'webjs'
    })

    // TracerProvider 설정
    const tracerProvider = new WebTracerProvider({
      resource: resource
    })

    // OTLP Trace Exporter 설정 (기본 헤더 사용)
    const traceExporter = new OTLPTraceExporter({
      url: `${otlpEndpoint}/v1/traces`,
      timeoutMillis: 10000
    })

    // Span Processor 설정 (배치 최적화)
    tracerProvider.addSpanProcessor(new BatchSpanProcessor(traceExporter, {
      maxQueueSize: 1000,
      maxExportBatchSize: 100,
      exportTimeoutMillis: 10000,
      scheduledDelayMillis: 2000
    }))

    // TracerProvider 등록
    tracerProvider.register()

    // 자동 계측 설정 (트레이싱)
    registerInstrumentations({
      instrumentations: [
        new FetchInstrumentation({
          ignoreIncomingRequestHook: (url) => {
            // 메트릭 엔드포인트는 제외
            return url.includes('/metrics')
          }
        }),
        new XMLHttpRequestInstrumentation({
          ignoreIncomingRequestHook: (url) => {
            return url.includes('/metrics')
          }
        })
      ]
    })

    return { tracerProvider }
  } catch (error) {
    return null
  }
}

// OpenTelemetry 초기화
setupOpenTelemetry()

Vue.config.productionTip = false

new Vue({
  render: h => h(App)
}).$mount('#app') 