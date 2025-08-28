import Vue from 'vue'
import App from './App.vue'

// OpenTelemetry imports
import { WebTracerProvider } from '@opentelemetry/sdk-trace-web'
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http'
import { Resource } from '@opentelemetry/resources'
import { SemanticResourceAttributes } from '@opentelemetry/semantic-conventions'
import { BatchSpanProcessor } from '@opentelemetry/sdk-trace-base'
import { FetchInstrumentation } from '@opentelemetry/instrumentation-fetch'
import { XMLHttpRequestInstrumentation } from '@opentelemetry/instrumentation-xml-http-request'
import { registerInstrumentations } from '@opentelemetry/instrumentation'

// OpenTelemetry 설정
function setupOpenTelemetry() {
  try {
    // 리소스 설정
    const resource = new Resource({
      [SemanticResourceAttributes.SERVICE_NAME]: 'aks-demo-frontend',
      [SemanticResourceAttributes.SERVICE_VERSION]: '1.0.0',
      [SemanticResourceAttributes.DEPLOYMENT_ENVIRONMENT]: process.env.NODE_ENV || 'development'
    })

    // TracerProvider 설정
    const tracerProvider = new WebTracerProvider({
      resource: resource
    })

    // OTLP Exporter 설정
    const otlpExporter = new OTLPTraceExporter({
      url: process.env.VUE_APP_OTEL_EXPORTER_OTLP_ENDPOINT || 'http://collector-opentelemetry-collector.otel-collector-rnr.svc.cluster.local:4318/v1/traces'
    })

    // Span Processor 설정
    tracerProvider.addSpanProcessor(new BatchSpanProcessor(otlpExporter))

    // TracerProvider 등록
    tracerProvider.register()

    // 자동 계측 설정
    registerInstrumentations({
      instrumentations: [
        new FetchInstrumentation(),
        new XMLHttpRequestInstrumentation()
      ]
    })

    console.log('OpenTelemetry initialized successfully')
    return tracerProvider
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