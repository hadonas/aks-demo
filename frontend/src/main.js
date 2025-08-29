import Vue from 'vue'
import App from './App.vue'

// OpenTelemetry imports
import { WebTracerProvider } from '@opentelemetry/sdk-trace-web'
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http'
import { OTLPMetricExporter } from '@opentelemetry/exporter-metrics-otlp-http'
import { Resource } from '@opentelemetry/resources'
import { SemanticResourceAttributes } from '@opentelemetry/semantic-conventions'
import { BatchSpanProcessor } from '@opentelemetry/sdk-trace-base'
import { FetchInstrumentation } from '@opentelemetry/instrumentation-fetch'
import { XMLHttpRequestInstrumentation } from '@opentelemetry/instrumentation-xml-http-request'
import { registerInstrumentations } from '@opentelemetry/instrumentation'
import { MeterProvider, PeriodicExportingMetricReader } from '@opentelemetry/sdk-metrics'

// OpenTelemetry 설정
function setupOpenTelemetry() {
  try {
    // 외부 Collector 엔드포인트
    const otlpEndpoint = process.env.VUE_APP_OTEL_EXPORTER_OTLP_ENDPOINT || 'http://collector.lgtm.20.249.154.255.nip.io'
    
    // 리소스 설정
    const resource = new Resource({
      [SemanticResourceAttributes.SERVICE_NAME]: 'aks-demo-frontend',
      [SemanticResourceAttributes.SERVICE_VERSION]: '1.0.0',
      [SemanticResourceAttributes.DEPLOYMENT_ENVIRONMENT]: 'production',
      [SemanticResourceAttributes.SERVICE_INSTANCE_ID]: 'frontend-1'
    })

    // TracerProvider 설정
    const tracerProvider = new WebTracerProvider({
      resource: resource
    })

    // OTLP Trace Exporter 설정
    const traceExporter = new OTLPTraceExporter({
      url: otlpEndpoint
    })

    // Span Processor 설정
    tracerProvider.addSpanProcessor(new BatchSpanProcessor(traceExporter))

    // TracerProvider 등록
    tracerProvider.register()

    // Metrics 설정
    const metricExporter = new OTLPMetricExporter({
      url: otlpEndpoint
    })

    const metricReader = new PeriodicExportingMetricReader({
      exporter: metricExporter,
      exportIntervalMillis: 5000 // 5초마다 메트릭 전송
    })

    const meterProvider = new MeterProvider({
      resource: resource,
      readers: [metricReader]
    })

    // 자동 계측 설정
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

    console.log('OpenTelemetry initialized successfully with external collector')
    return { tracerProvider, meterProvider }
  } catch (error) {
    console.error('Failed to initialize OpenTelemetry:', error)
    return null
  }
}

// OpenTelemetry 초기화
setupOpenTelemetry()

Vue.config.productionTip = false

new Vue({
  render: h => h(App)
}).$mount('#app') 